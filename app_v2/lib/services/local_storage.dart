import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地持久化存储服务
/// 负责游客模式下所有数据的本地读写，登录后作为云端数据的缓存
class LocalStorage {
  static const String _favoritesKey = 'local_favorites';
  static const String _historyKey = 'local_history';
  static const String _vehiclesKey = 'local_vehicles';
  static const String _carSettingsKey = 'car_settings';

  // ---- 收藏（充电站ID集合） ----

  /// 获取本地收藏的充电站ID集合
  static Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoritesKey) ?? [];
    return list.toSet();
  }

  /// 保存本地收藏
  static Future<void> saveFavorites(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, favorites.toList());
  }

  /// 切换收藏状态
  static Future<Set<String>> toggleFavorite(String stationId) async {
    final favs = await loadFavorites();
    if (favs.contains(stationId)) {
      favs.remove(stationId);
    } else {
      favs.add(stationId);
    }
    await saveFavorites(favs);
    return favs;
  }

  /// 批量添加收藏（去重），用于登录后云端数据合并回本地
  static Future<void> addFavoritesBatch(Set<String> stationIds) async {
    final favs = await loadFavorites();
    favs.addAll(stationIds);
    await saveFavorites(favs);
  }

  // ---- 历史记录 ----

  /// 获取本地历史记录，按访问时间倒序
  static Future<List<Map<String, dynamic>>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// 保存历史记录列表
  static Future<void> saveHistory(List<Map<String, dynamic>> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  /// 添加一条历史记录（自动去重，最多保留50条）
  static Future<void> addHistory(Map<String, dynamic> entry) async {
    final history = await loadHistory();
    final stationId = entry['station_id']?.toString() ?? '';

    // 去重：移除同一站点的旧记录
    history.removeWhere(
        (e) => e['station_id']?.toString() == stationId);
    // 插入到最前面
    history.insert(0, entry);
    // 最多保留 50 条
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }
    await saveHistory(history);
  }

  /// 批量添加历史记录（合并时使用），保持最多50条
  static Future<void> addHistoryBatch(
      List<Map<String, dynamic>> entries) async {
    final history = await loadHistory();

    for (final entry in entries.reversed) {
      final sid = entry['station_id']?.toString() ?? '';
      // 去重
      history.removeWhere((e) => e['station_id']?.toString() == sid);
      history.insert(0, entry);
    }

    if (history.length > 50) {
      history.removeRange(50, history.length);
    }
    await saveHistory(history);
  }

  // ---- 车辆管理 ----

  /// 获取本地保存的车辆列表
  static Future<List<Map<String, dynamic>>> loadVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vehiclesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// 保存车辆列表
  static Future<void> saveVehicles(
      List<Map<String, dynamic>> vehicles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vehiclesKey, jsonEncode(vehicles));
  }

  /// 添加车辆（本地自动生成临时ID）
  static Future<List<Map<String, dynamic>>> addVehicle(
      Map<String, dynamic> vehicle) async {
    final vehicles = await loadVehicles();
    // 如果是默认车辆，先取消其他默认
    if (vehicle['is_default'] == true) {
      for (var v in vehicles) {
        v['is_default'] = false;
      }
    }
    // 生成本地临时ID
    vehicle['_local_id'] = DateTime.now().millisecondsSinceEpoch;
    vehicles.add(vehicle);
    await saveVehicles(vehicles);
    return vehicles;
  }

  /// 更新车辆
  static Future<List<Map<String, dynamic>>> updateVehicle(
      int index, Map<String, dynamic> updates) async {
    final vehicles = await loadVehicles();
    if (index < 0 || index >= vehicles.length) return vehicles;
    if (updates['is_default'] == true) {
      for (var v in vehicles) {
        v['is_default'] = false;
      }
    }
    vehicles[index].addAll(updates);
    await saveVehicles(vehicles);
    return vehicles;
  }

  /// 删除车辆
  static Future<List<Map<String, dynamic>>> deleteVehicle(int index) async {
    final vehicles = await loadVehicles();
    if (index < 0 || index >= vehicles.length) return vehicles;
    vehicles.removeAt(index);
    await saveVehicles(vehicles);
    return vehicles;
  }

  /// 用云端数据覆盖本地车辆列表（登录合并后）
  static Future<void> setVehiclesFromCloud(
      List<Map<String, dynamic>> cloudVehicles) async {
    // 保留云端ID，合并本地没有云端ID的车辆
    await saveVehicles(cloudVehicles);
  }

  // ---- 当前活跃车型设置（始终本地存储） ----

  /// 加载当前活跃车型设置
  static Future<Map<String, dynamic>> loadCarSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_carSettingsKey);
    if (raw == null || raw.isEmpty) {
      // 返回默认值：特斯拉 Model Y 标准续航
      return {
        'brand': '特斯拉',
        'car_name': 'Model Y 标准续航',
        'battery_capacity': 60.0,
        'energy_consumption': 14.0,
        'current_soc': 48.0,
      };
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'brand': map['brand'] ?? '特斯拉',
        'car_name': map['car_name'] ?? 'Model Y 标准续航',
        'battery_capacity': (map['battery_capacity'] ?? 60.0).toDouble(),
        'energy_consumption': (map['energy_consumption'] ?? 14.0).toDouble(),
        'current_soc': (map['current_soc'] ?? 48.0).toDouble(),
      };
    } catch (_) {
      return {
        'brand': '特斯拉',
        'car_name': 'Model Y 标准续航',
        'battery_capacity': 60.0,
        'energy_consumption': 14.0,
        'current_soc': 48.0,
      };
    }
  }

  /// 保存当前活跃车型设置
  static Future<void> saveCarSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_carSettingsKey, jsonEncode(settings));
  }
}

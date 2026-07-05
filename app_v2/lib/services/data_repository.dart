import 'local_storage.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// 统一数据仓库
/// 根据登录状态自动切换本地/云端数据源：
/// - 游客：所有数据读写 SharedPreferences（本地）
/// - 登录用户：数据读写云端 API，同时缓存到本地
class DataRepository {
  static final DataRepository _instance = DataRepository._();
  factory DataRepository() => _instance;
  DataRepository._();

  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();

  /// 是否为登录状态
  bool get isLoggedIn => _loggedIn;
  bool _loggedIn = false;

  /// 初始化：检查登录状态并加载本地数据
  Future<void> init() async {
    _loggedIn = await _auth.isLoggedIn();
  }

  // =============================================
  // 收藏管理
  // =============================================

  /// 刷新登录状态并返回收藏
  /// 获取收藏（纯本地，云端同步仅在登录/登出时）
  Future<Set<String>> loadFavorites() async {
    return await LocalStorage.loadFavorites();
  }

  /// 切换收藏状态（实时同步到云端）
  Future<Set<String>> toggleFavorite(String stationId) async {
    _loggedIn = await _auth.isLoggedIn();
    if (_loggedIn) {
      final currentFavs = await LocalStorage.loadFavorites();
      final isFav = currentFavs.contains(stationId);
      try {
        if (isFav) {
          await _api.delete('/api/favorites/$stationId');
        } else {
          await _api.post('/api/favorites', data: {'station_id': stationId});
        }
      } catch (_) {}
    }
    return await LocalStorage.toggleFavorite(stationId);
  }

  /// 判断是否已收藏
  Future<bool> isFavorite(String stationId) async {
    final favs = await LocalStorage.loadFavorites();
    return favs.contains(stationId);
  }

  // =============================================
  // 历史记录管理
  // =============================================

  /// 获取历史记录（纯本地，云端同步仅在登录/登出时）
  Future<List<Map<String, dynamic>>> loadHistory() async {
    return await LocalStorage.loadHistory();
  }

  /// 添加历史记录（实时同步到云端，含站点名）
  Future<void> addHistory(Map<String, dynamic> entry) async {
    await LocalStorage.addHistory(entry);
    _loggedIn = await _auth.isLoggedIn();
    if (_loggedIn) {
      final stationId = entry['station_id']?.toString() ?? '';
      if (stationId.isNotEmpty) {
        final station = entry['station'] as Map<String, dynamic>? ?? {};
        final stationName = station['name']?.toString() ?? '';
        try {
          await _api.post('/api/history', data: {
            'station_id': stationId,
            'station_name': stationName,
          });
        } catch (_) {}
      }
    }
  }

  // =============================================
  // 车辆管理
  // =============================================

  /// 获取车辆列表
  Future<List<Map<String, dynamic>>> loadVehicles() async {
    _loggedIn = await _auth.isLoggedIn();

    if (_loggedIn) {
      try {
        final resp = await _api.get('/api/users/me/vehicles');
        if (resp.statusCode == 200) {
          final list = resp.data as List? ?? [];
          final vehicles = list.map<Map<String, dynamic>>((e) {
            return {
              'id': e['id'],
              'brand': e['brand']?.toString() ?? '',
              'model': e['model']?.toString() ?? '',
              'battery_capacity':
                  (e['battery_capacity'] ?? 60.0).toDouble(),
              'energy_consumption':
                  (e['energy_consumption'] ?? 14.5).toDouble(),
              'is_default': e['is_default'] == true,
            };
          }).toList();
          // 同步到本地
          await LocalStorage.setVehiclesFromCloud(vehicles);
          return vehicles;
        }
      } catch (_) {
        // API 失败回退本地
      }
    }
    return await LocalStorage.loadVehicles();
  }

  /// 添加车辆
  Future<List<Map<String, dynamic>>> addVehicle(
      Map<String, dynamic> vehicle) async {
    _loggedIn = await _auth.isLoggedIn();

    if (_loggedIn) {
      try {
        final resp = await _api.post('/api/users/me/vehicles', data: {
          'brand': vehicle['brand']?.toString() ?? '',
          'model': vehicle['model']?.toString() ?? '',
          'battery_capacity': vehicle['battery_capacity'] ?? 60.0,
          'energy_consumption': vehicle['energy_consumption'] ?? 14.5,
          'is_default': vehicle['is_default'] == true,
        });
        if (resp.statusCode == 200) {
          return await loadVehicles(); // 重新加载以获取云端ID
        }
      } catch (_) {
        // API 失败回退本地
      }
    }
    return await LocalStorage.addVehicle(vehicle);
  }

  /// 删除车辆
  Future<List<Map<String, dynamic>>> deleteVehicle(int index) async {
    _loggedIn = await _auth.isLoggedIn();

    if (_loggedIn) {
      final vehicles = await loadVehicles();
      if (index >= 0 && index < vehicles.length) {
        final vehicleId = vehicles[index]['id'];
        if (vehicleId != null) {
          try {
            await _api.delete('/api/users/me/vehicles/$vehicleId');
            return await loadVehicles();
          } catch (_) {
            // API 失败回退本地
          }
        }
      }
    }
    return await LocalStorage.deleteVehicle(index);
  }

  // =============================================
  // 活跃车型设置（始终本地存储）
  // =============================================

  /// 加载当前活跃车型设置
  Future<Map<String, dynamic>> loadCarSettings() async {
    return await LocalStorage.loadCarSettings();
  }

  /// 保存当前活跃车型设置（实时同步到后端）
  Future<void> saveCarSettings(Map<String, dynamic> settings) async {
    await LocalStorage.saveCarSettings(settings);

    _loggedIn = await _auth.isLoggedIn();
    if (!_loggedIn) return;

    try {
      final brand = settings['brand']?.toString() ?? '';
      final model = settings['car_name']?.toString() ?? '';
      final battery = (settings['battery_capacity'] ?? 60.0).toDouble();
      final consumption = (settings['energy_consumption'] ?? 14.0).toDouble();
      if (brand.isEmpty || model.isEmpty) return;

      final resp = await _api.get('/api/users/me/vehicles');
      if (resp.statusCode != 200) return;
      final list = resp.data as List? ?? [];
      final existing = list.where((v) =>
          v['brand']?.toString() == brand &&
          v['model']?.toString() == model);

      if (existing.isEmpty) {
        await _api.post('/api/users/me/vehicles', data: {
          'brand': brand,
          'model': model,
          'battery_capacity': battery,
          'energy_consumption': consumption,
          'is_default': true,
        });
      } else {
        await _api.put('/api/users/me/vehicles/${existing.first['id']}', data: {
          'is_default': true,
        });
      }
    } catch (_) {}
  }

  // =============================================
  // 站点详情（从后端拉取完整数据）
  // =============================================

  /// 从后端获取单个电站的完整详情数据
  /// [stationId] 电站唯一标识
  /// [lat]/[lng] 用户当前位置（可选，用于计算距离）
  /// 返回与 StationDetailScreen 兼容的 data 对象，失败返回 null
  Future<Map<String, dynamic>?> fetchStationDetail(
    String stationId, {
    double? lat,
    double? lng,
  }) async {
    _loggedIn = await _auth.isLoggedIn();

    // 构建查询参数
    final queryParams = <String, dynamic>{};
    if (lat != null && lng != null) {
      queryParams['lat'] = lat;
      queryParams['lng'] = lng;
    }

    try {
      final resp = _loggedIn
          ? await _api.get('/api/station/$stationId',
              queryParameters: queryParams.isNotEmpty ? queryParams : null)
          : await _api.get('/api/station/$stationId',
              queryParameters: queryParams.isNotEmpty ? queryParams : null);

      if (resp.statusCode == 200) {
        // 后端返回 BaseResponse 格式：{ code, message, data: {...} }
        final body = resp.data;
        if (body is Map<String, dynamic>) {
          // 兼容两种格式：直接返回 data 或整个响应体
          final data = body['data'] ?? body;
          if (data is Map<String, dynamic>) {
            return data;
          }
        }
      }
    } catch (_) {
      // 后端不可用时返回 null
    }
    return null;
  }

  // =============================================
  // 登录/登出时的数据同步
  // =============================================

  /// 登录后：将本地数据合并到云端
  Future<void> onLogin() async {
    _loggedIn = true;

    // 1. 合并本地收藏到云端
    final localFavs = await LocalStorage.loadFavorites();
    if (localFavs.isNotEmpty) {
      for (final stationId in localFavs) {
        try {
          // POST 到云端，已存在的会返回 400（忽略）
          await _api.post('/api/favorites', data: {'station_id': stationId});
        } catch (_) {
          // 已存在或其他错误，忽略
        }
      }
    }

    // 2. 合并本地历史到云端（含站点名）
    final localHistory = await LocalStorage.loadHistory();
    if (localHistory.isNotEmpty) {
      for (final entry in localHistory) {
        final stationId = entry['station_id']?.toString() ?? '';
        if (stationId.isNotEmpty) {
          final station = entry['station'] as Map<String, dynamic>? ?? {};
          final stationName = station['name']?.toString() ?? '';
          try {
            await _api.post('/api/history', data: {
              'station_id': stationId,
              'station_name': stationName,
            });
          } catch (_) {
            // 已存在或其他错误，忽略
          }
        }
      }
    }

    // 3. 合并本地车辆到云端
    final localVehicles = await LocalStorage.loadVehicles();
    if (localVehicles.isNotEmpty) {
      // 先获取云端已有的车辆，避免重复添加
      try {
        final resp = await _api.get('/api/users/me/vehicles');
        if (resp.statusCode == 200) {
          final cloudList = resp.data as List? ?? [];
          final cloudBrands = cloudList
              .map<String>((e) =>
                  '${e['brand']?.toString() ?? ''}_${e['model']?.toString() ?? ''}')
              .toSet();

          for (final v in localVehicles) {
            final key =
                '${v['brand']?.toString() ?? ''}_${v['model']?.toString() ?? ''}';
            if (!cloudBrands.contains(key)) {
              try {
                await _api.post('/api/users/me/vehicles', data: {
                  'brand': v['brand']?.toString() ?? '',
                  'model': v['model']?.toString() ?? '',
                  'battery_capacity': v['battery_capacity'] ?? 60.0,
                  'energy_consumption': v['energy_consumption'] ?? 14.5,
                  'is_default': v['is_default'] == true,
                });
              } catch (_) {
                // 忽略
              }
            }
          }
        }
      } catch (_) {
        // 获取云端车辆失败，尝试直接上传
        for (final v in localVehicles) {
          try {
            await _api.post('/api/users/me/vehicles', data: {
              'brand': v['brand']?.toString() ?? '',
              'model': v['model']?.toString() ?? '',
              'battery_capacity': v['battery_capacity'] ?? 60.0,
              'energy_consumption': v['energy_consumption'] ?? 14.5,
              'is_default': v['is_default'] == true,
            });
          } catch (_) {}
        }
      }
    }

    // 4. 从云端拉取，与本地合并（取并集，保留本地数据不丢失）
    try {
      final favResp = await _api.get('/api/favorites');
      if (favResp.statusCode == 200) {
        final cloudIds = (favResp.data as List? ?? [])
            .map<String>((e) => e['station_id']?.toString() ?? '')
            .toSet();
        if (cloudIds.isNotEmpty) {
          final localIds = await LocalStorage.loadFavorites();
          localIds.addAll(cloudIds); // 合并
          await LocalStorage.saveFavorites(localIds);
        }
        // 云端为空时保留本地，不做任何操作
      }
    } catch (_) {}

    try {
      final histResp = await _api.get('/api/history', queryParameters: {'limit': 50});
      if (histResp.statusCode == 200) {
        final list = histResp.data as List? ?? [];
        if (list.isNotEmpty) {
          final cloudHistory = list.map<Map<String, dynamic>>((e) {
            return {
              'id': e['id'],
              'station_id': e['station_id']?.toString() ?? '',
              'station': {
                'station_id': e['station_id']?.toString() ?? '',
                'name': e['station_name']?.toString() ?? '',
              },
              'visited_at': e['visited_at']?.toString() ?? '',
            };
          }).toList();
          // 合并云端到本地（去重）
          await LocalStorage.addHistoryBatch(cloudHistory);
        }
        // 云端为空时保留本地，不做任何操作
      }
    } catch (_) {}

    // 5. 拉取后端默认车型，设置为当前活跃车型
    try {
      final vehicleResp = await _api.get('/api/users/me/vehicles');
      if (vehicleResp.statusCode == 200) {
        final list = vehicleResp.data as List? ?? [];
        // 优先找默认车辆，没有就取第一辆
        Map? defaultVehicle;
        for (final v in list) {
          if (v['is_default'] == true) {
            defaultVehicle = v;
            break;
          }
        }
        defaultVehicle ??= list.isNotEmpty ? list.first as Map? : null;

        if (defaultVehicle != null) {
          // 保留当前的 SOC，只更新车型和电池信息
          final oldSettings = await LocalStorage.loadCarSettings();
          final savedSoc = (oldSettings['current_soc'] ?? 48.0).toDouble();
          await LocalStorage.saveCarSettings({
            'brand': defaultVehicle['brand']?.toString() ?? '特斯拉',
            'car_name': defaultVehicle['model']?.toString() ?? 'Model Y 标准续航',
            'battery_capacity':
                (defaultVehicle['battery_capacity'] ?? 60.0).toDouble(),
            'energy_consumption':
                (defaultVehicle['energy_consumption'] ?? 14.0).toDouble(),
            'current_soc': savedSoc, // 保持原本的电量
          });
        }
      }
    } catch (_) {}
  }

  /// 登出前：上传当前车型到后端，然后清除云端缓存
  Future<void> onLogout() async {
    try {
      final settings = await LocalStorage.loadCarSettings();
      final brand = settings['brand']?.toString() ?? '';
      final model = settings['car_name']?.toString() ?? '';
      final battery = (settings['battery_capacity'] ?? 60.0).toDouble();
      final consumption = (settings['energy_consumption'] ?? 14.0).toDouble();

      if (brand.isNotEmpty && model.isNotEmpty) {
        // 先获取已有车辆，检查是否存在
        final resp = await _api.get('/api/users/me/vehicles');
        if (resp.statusCode == 200) {
          final list = resp.data as List? ?? [];
          final existing = list.where((v) =>
              v['brand']?.toString() == brand &&
              v['model']?.toString() == model);

          if (existing.isEmpty) {
            await _api.post('/api/users/me/vehicles', data: {
              'brand': brand,
              'model': model,
              'battery_capacity': battery,
              'energy_consumption': consumption,
              'is_default': true,
            });
          } else {
            final vehicleId = existing.first['id'];
            await _api.put('/api/users/me/vehicles/$vehicleId', data: {
              'is_default': true,
            });
          }
        }
      }
    } catch (_) {
      // 静默失败
    }

    // 双向同步收藏：云端删除本地已取消的，上传本地新增的
    try {
      final cloudResp = await _api.get('/api/favorites');
      if (cloudResp.statusCode == 200) {
        final cloudFavs = cloudResp.data as List? ?? [];
        final cloudIds = cloudFavs
            .map<String>((e) => e['station_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        final localFavs = await LocalStorage.loadFavorites();

        // 删除云端有但本地没有的（用户在本地删除了）
        for (final cloudId in cloudIds) {
          if (!localFavs.contains(cloudId)) {
            try {
              await _api.delete('/api/favorites/$cloudId');
            } catch (_) {}
          }
        }

        // 上传本地有但云端没有的（新增的收藏）
        for (final stationId in localFavs) {
          if (!cloudIds.contains(stationId)) {
            try {
              await _api.post('/api/favorites',
                  data: {'station_id': stationId});
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    // 双向同步历史记录：云端删除本地已删的，上传本地新增的
    try {
      final cloudResp =
          await _api.get('/api/history', queryParameters: {'limit': 50});
      if (cloudResp.statusCode == 200) {
        final cloudList = cloudResp.data as List? ?? [];
        final localHistory = await LocalStorage.loadHistory();
        final localStationIds = localHistory
            .map<String>((e) => e['station_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();

        // 删除云端有但本地没有的历史记录
        for (final cloudEntry in cloudList) {
          final cloudStationId =
              cloudEntry['station_id']?.toString() ?? '';
          final cloudEntryId = cloudEntry['id'];
          if (cloudStationId.isNotEmpty &&
              !localStationIds.contains(cloudStationId) &&
              cloudEntryId != null) {
            try {
              await _api.delete('/api/history/$cloudEntryId');
            } catch (_) {}
          }
        }

        // 上传本地没有云端 id 的新增历史记录
        for (final entry in localHistory) {
          final entryId = entry['id'];
          if (entryId == null) {
            final stationId = entry['station_id']?.toString() ?? '';
            if (stationId.isNotEmpty) {
              final station =
                  entry['station'] as Map<String, dynamic>? ?? {};
              final stationName = station['name']?.toString() ?? '';
              try {
                await _api.post('/api/history', data: {
                  'station_id': stationId,
                  'station_name': stationName,
                });
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}

    _loggedIn = false;
    // 本地数据在 LocalStorage 中保持不变
    // ApiClient tokens 由 AuthService.logout() 清除
  }
}

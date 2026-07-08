import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'services/api_client.dart';
import 'services/data_repository.dart';
import 'services/local_storage.dart';
import 'services/auth_service.dart';
import 'services/vehicle_data.dart';

import 'pages/login_page.dart';

// ============== 全局常量 ==============
const String AMAP_KEY = "89feee20b4ad911ee8e1effc2a13bfd3";
const double _OFF_ROUTE_THRESHOLD_METERS = 50.0; // 偏航阈值：50米
const double _ARRIVAL_DISTANCE_METERS = 100.0; // 到达判定距离
const double _GPS_ACCURACY_THRESHOLD = 25.0; // GPS精度过滤阈值
const double _ARRIVAL_SPEED_THRESHOLD = 5.0; // 到达时最大速度 km/h
const int _ARRIVAL_CONFIRM_SECONDS = 3; // 到达需持续多少秒

// ============== 错误重试卡片（与充电站卡片等大，填满 160px） ==============
class _ErrorRetryCard extends StatelessWidget {
  final String errorMsg;
  final VoidCallback onRetry;

  const _ErrorRetryCard({required this.errorMsg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(Icons.signal_wifi_off, size: 24, color: Colors.red.shade400),
          const SizedBox(height: 6),
          const Text('定位失败',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(errorMsg,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重新加载', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ============== 无电站空状态卡片（与充电站卡片等大） ==============
class _EmptyStationsCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyStationsCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(Icons.ev_station_outlined,
              size: 24, color: Colors.grey.shade400),
          const SizedBox(height: 6),
          const Text('附近无可用充电站',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('请检查网络或稍后重试',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('刷新', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF007AFF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// [玻璃拟态核心挂件] - 提供所有卡片的高级呼吸边框
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85), // 增强不透明度，拉开对比
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white, // 实心纯白描边
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.blueGrey.withOpacity(0.12), // 加深下层投影，形成悬空感
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class SleekHomeWrapper extends StatefulWidget {
  final VoidCallback onLogout;
  const SleekHomeWrapper({super.key, required this.onLogout});

  @override
  State<SleekHomeWrapper> createState() => _SleekHomeWrapperState();
}

class _SleekHomeWrapperState extends State<SleekHomeWrapper> {
  final PageController _pageController = PageController(viewportFraction: 0.85);

  List<dynamic> _recommendations = [];
  bool _isLoading = true;
  String _errorMsg = "";

  Set<Marker> _markers = {};
  Map<String, int> _markerIdToIndex = {}; // markerId → 电站索引
  AMapController? _mapController;
  int _selectedMarkerIndex = -1; // 当前选中的电站标记索引
  double _compassHeading = 0; // 罗盘方向角度（手机朝向）
  BitmapDescriptor? _userLocationIcon;

  // 统一的电站标记图标
  late BitmapDescriptor _stationIcon;
  late BitmapDescriptor _stationIconSelected;

  Future<void> _generateStationIcons() async {
    final ByteData bytes72 = await rootBundle.load('assets/station_icon.png');
    _stationIcon = BitmapDescriptor.fromBytes(bytes72.buffer.asUint8List());

    final ByteData bytes80 =
        await rootBundle.load('assets/station_icon_sel.png');
    _stationIconSelected =
        BitmapDescriptor.fromBytes(bytes80.buffer.asUint8List());
  }

  // 动态车型和电量状态（默认值：特斯拉 Model Y 标准续航）
  String _currentBrand = "特斯拉";
  String _currentCar = "Model Y 标准续航";
  double _batteryCapacity = 60.0;
  double _energyConsumption = 14.0;
  double _currentSoc = 48.0;

  // 物理真机动态定位GPS锚点 (预设武汉兜底)
  double _userLat = 30.583547;
  double _userLng = 114.253265;

  // 无道路吸附的精准定位缓存（用于推荐请求，避免被地图道路吸附干扰）
  double? _accurateLat;
  double? _accurateLng;
  DateTime? _accurateTime;
  static const Duration _accurateCacheTTL = Duration(seconds: 30);

  // 天气状态
  int _temperature = 0;
  int _weatherCode = 0;

  // 历史记录状态
  List<dynamic> _history = [];

  // 收藏状态
  Set<String> _favorites = {};
  bool _isFavorite(String stationId) => _favorites.contains(stationId);
  String _getStationId(dynamic station) =>
      station['station_id']?.toString() ?? station['name']?.toString() ?? '';
  String _weatherIcon = '-';

  // 公告状态（仅用于弹窗）
  List<dynamic> _announcements = [];

  @override
  void initState() {
    super.initState();
    // 高德定位 SDK 初始化（隐私合规必须最先执行）
    AMapFlutterLocation.setApiKey(AMAP_KEY, AMAP_KEY);
    AMapFlutterLocation.updatePrivacyShow(true, true);
    AMapFlutterLocation.updatePrivacyAgree(true);
    _initData();
    _fetchWeather();
    _generateStationIcons();
    _loadUserIcon();
    _startCompass();
  }

  /// 初始化数据：加载车型设置、收藏、历史，然后拉取推荐
  Future<void> _initData() async {
    // 加载本地车型设置（始终从本地读取）
    final carSettings = await DataRepository().loadCarSettings();
    // 加载收藏和历史（自动根据登录状态选择数据源）
    final favs = await DataRepository().loadFavorites();
    final history = await DataRepository().loadHistory();

    if (mounted) {
      setState(() {
        _currentBrand = carSettings['brand']?.toString() ?? '特斯拉';
        _currentCar = carSettings['car_name']?.toString() ?? 'Model Y 标准续航';
        _batteryCapacity =
            (carSettings['battery_capacity'] ?? 60.0).toDouble();
        _energyConsumption =
            (carSettings['energy_consumption'] ?? 14.0).toDouble();
        _currentSoc = (carSettings['current_soc'] ?? 48.0).toDouble();
        _favorites = favs;
        _history = history.cast<dynamic>();
      });
    }
    // 加载推荐和公告
    _fetchRealData();
    _fetchAnnouncements();
  }

  Future<void> _loadUserIcon() async {
    final bytes = await rootBundle.load('assets/user_icon.png');
    _userLocationIcon = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
  }

  void _startCompass() {
    FlutterCompass.events?.listen((event) {
      final h = event.heading ?? 0;
      if (mounted) setState(() => _compassHeading = h);
    });
  }

  Future<void> _fetchWeather() async {
    try {
      final url = 'https://api.open-meteo.com/v1/forecast'
          '?latitude=$_userLat&longitude=$_userLng'
          '&current_weather=true';
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final data = jsonDecode(body);
        final cw = data['current_weather'];
        final code = (cw['weathercode'] ?? 0).toInt();
        setState(() {
          _temperature = (cw['temperature'] ?? 0).toInt();
          _weatherCode = code;
          _weatherIcon = _getWeatherIcon(code);
        });
      }
    } catch (_) {
      // 天气获取失败不影响主流程
    }
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final resp = await ApiClient().getLatestAnnouncements();
      if (resp.statusCode == 200 && resp.data['announcements'] != null) {
        final list = resp.data['announcements'] as List;
        if (mounted) {
          setState(() => _announcements = list);
        }
        // 弹窗公告：检查是否有未读的
        _checkPopupAnnouncements(list);
      }
    } catch (_) {
      // 公告获取失败不影响主流程
    }
  }

  /// 检查并展示弹窗公告
  void _checkPopupAnnouncements(List<dynamic> announcements) async {
    if (announcements.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final readIds = prefs.getStringList('read_announcements') ?? [];

    // 找出未读的公告
    final unread = announcements.where((a) {
      final id = a['id']?.toString() ?? '';
      return !readIds.contains(id);
    }).toList();

    if (unread.isEmpty) return;

    // 显示弹窗
    if (mounted) _showPopupDialog(unread);
  }

  /// 弹窗公告对话框（玻璃拟态风格）
  void _showPopupDialog(List<dynamic> announcements) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部标题栏
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.campaign,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('系统公告',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          )),
                    ),
                    const SizedBox(width: 8),
                    if (announcements.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${announcements.length}条',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF007AFF),
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                  ],
                ),
              ),
              // 公告内容
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: announcements.map((a) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a['title'] ?? '',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF007AFF),
                                )),
                            const SizedBox(height: 6),
                            Text(a['content'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.5,
                                )),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // 底部按钮
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      // 标记所有为已读
                      final prefs =
                          await SharedPreferences.getInstance();
                      final readIds = prefs.getStringList(
                              'read_announcements') ??
                          [];
                      for (final a in announcements) {
                        final id = a['id']?.toString() ?? '';
                        if (!readIds.contains(id)) readIds.add(id);
                      }
                      await prefs.setStringList(
                          'read_announcements', readIds);
                      Navigator.pop(ctx);
                    },
                    child: const Text('我知道了',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWeatherIcon(int code) {
    // WMO Weather interpretation codes
    if (code == 0) return '☀️';
    if (code == 1 || code == 2) return '⛅';
    if (code == 3) return '☁️';
    if (code >= 45 && code <= 48) return '🌫️';
    if (code >= 51 && code <= 67) return '🌧️';
    if (code >= 71 && code <= 77) return '🌨️';
    if (code >= 80 && code <= 82) return '🌧️';
    if (code >= 85 && code <= 86) return '🌨️';
    if (code >= 95 && code <= 99) return '⛈️';
    return '❓';
  }

  /// 切换收藏状态（通过数据仓库，登录用户同步到云端）
  Future<void> _toggleFavorite(String stationId) async {
    final favs = await DataRepository().toggleFavorite(stationId);
    if (mounted) setState(() => _favorites = favs);
  }

  /// 添加历史记录（通过数据仓库，登录用户同步到云端）
  Future<void> _addHistory(dynamic data) async {
    final station = data['station'] ?? {};
    final stationId = _getStationId(station);

    // 估算充电数据
    final priceTotal = (station['price']?['total'] ?? 1.5).toDouble();
    final powerKw = (station['power_kw'] ?? 60).toDouble();
    final energyKwh = (_currentSoc > 0)
        ? ((80 - _currentSoc) / 100 * _batteryCapacity).clamp(0, _batteryCapacity).toDouble()
        : 20.0;
    final costYuan = (energyKwh * priceTotal);
    final durationMin = powerKw > 0 ? (energyKwh / powerKw * 60).round() : 20;

    final entry = {
      'station_id': stationId,
      'station': station,
      'visited_at': DateTime.now().toIso8601String(),
      'duration_min': durationMin,
      'cost_yuan': costYuan,
      'energy_kwh': energyKwh,
    };
    await DataRepository().addHistory(entry);
    // 重新加载以保持 UI 同步
    final history = await DataRepository().loadHistory();
    if (mounted) setState(() => _history = history.cast<dynamic>());
  }

  /// 高德定位优先，geolocator 兜底
  /// 始终使用 Device_Sensors 模式（纯GPS，无道路吸附），用于获取真实位置
  Future<Position?> _determinePosition({bool useCache = true}) async {
    // 如果缓存中有 30 秒内的精准定位，直接复用（避免频繁等待定位）
    if (useCache &&
        _accurateLat != null &&
        _accurateLng != null &&
        _accurateTime != null &&
        DateTime.now().difference(_accurateTime!) < _accurateCacheTTL) {
      return Position(
        latitude: _accurateLat!,
        longitude: _accurateLng!,
        timestamp: _accurateTime ?? DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }

    // 1. 先尝试高德定位 SDK，Device_Sensors 模式 = 纯GPS无道路吸附
    try {
      final aMapPos = await _getAMapPosition();
      if (aMapPos != null) {
        // 缓存无道路吸附的精准坐标
        _accurateLat = aMapPos.latitude;
        _accurateLng = aMapPos.longitude;
        _accurateTime = DateTime.now();
        return aMapPos;
      }
    } catch (e) {
      debugPrint('高德定位失败: $e');
    }

    // 2. 高德失败，回退到 geolocator（也无道路吸附）
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMsg = '定位失败：请打开手机定位服务';
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
          forceLocationManager: true,
        ),
      );
      // 缓存精准坐标
      _accurateLat = pos.latitude;
      _accurateLng = pos.longitude;
      _accurateTime = DateTime.now();
      return pos;
    } catch (e) {
      debugPrint('geolocator 定位异常: $e');
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          _accurateLat = lastPos.latitude;
          _accurateLng = lastPos.longitude;
          _accurateTime = DateTime.now();
          return lastPos;
        }
      } catch (_) {}
      _errorMsg = '定位失败：定位超时，请到室外再试';
      return null;
    }
  }

  /// 使用高德定位 SDK 获取位置（和手机高德 App 同一引擎）
  Future<Position?> _getAMapPosition() async {
    final location = AMapFlutterLocation();
    location.setLocationOption(AMapLocationOption(
      onceLocation: true,
      locationMode: AMapLocationMode.Device_Sensors,
      needAddress: false,
    ));

    final completer = Completer<Position?>();
    StreamSubscription? sub;

    sub = location.onLocationChanged().listen((result) {
      final errCode = result['errorCode']?.toString();
      if (errCode != null && errCode != '0') {
        debugPrint('高德定位错误: $errCode ${result['errorInfo']}');
        if (!completer.isCompleted) completer.complete(null);
      } else if (result['latitude'] != null) {
        final lat = (result['latitude'] as num).toDouble();
        final lng = (result['longitude'] as num).toDouble();
        // 过滤无效坐标
        if (lat.abs() > 0.01 && lng.abs() > 0.01 && !completer.isCompleted) {
          completer.complete(Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: (result['accuracy'] as num?)?.toDouble() ?? 0,
            altitude: (result['altitude'] as num?)?.toDouble() ?? 0,
            heading: (result['bearing'] as num?)?.toDouble() ?? 0,
            speed: (result['speed'] as num?)?.toDouble() ?? 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          ));
        }
      }
      sub?.cancel();
      location.destroy();
    });

    location.startLocation();
    return await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        sub?.cancel();
        location.stopLocation();
        location.destroy();
        return null;
      },
    );
  }

  Future<void> _fetchRealData() async {
    try {
      // 只标记推荐数据加载中，不挡收藏和历史
      if (_recommendations.isEmpty) {
        setState(() => _isLoading = true);
      }
      _errorMsg = '';
      // 1. 定位：推荐请求使用独立定位（Device_Sensors 模式，无道路吸附）
      //    注意：地图 onLocationChanged 回调的坐标含道路吸附（定位到路上），推荐请求不能直接用
      //    导航模块 (_startLocationTracking) 的 Hight_Accuracy 含道路吸附，那是对的，不动它
      final isDefaultLocation =
          _userLat == 30.583547 && _userLng == 114.253265;
      final position = await _determinePosition(
        useCache: !isDefaultLocation, // 非首次刷新时优先用缓存，减少等待
      );
      if (position != null) {
        _userLat = position.latitude;
        _userLng = position.longitude;
        // 定位成功：用真实坐标重新获取天气
        _fetchWeather();
      } else if (!isDefaultLocation) {
        // 定位失败时回退到此前的地图坐标兜底（可能含道路吸附，但比没数据强）
      } else {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 2. 使用 ApiClient 请求推荐（支持游客和登录用户）
      final payload = {
        "user_location": {"lat": _userLat, "lng": _userLng},
        "current_soc": _currentSoc,
        "target_soc": 100.0,
        "battery_capacity": _batteryCapacity,
        "energy_consumption": _energyConsumption,
        "preference": {
          "distance_weight": 0.4,
          "price_weight": 0.4,
          "wait_time_weight": 0.1,
          "power_weight": 0.1,
          "prefer_ultra": false
        }
      };

      final resp = await ApiClient().post('/api/recommend', data: payload);
      if (resp.statusCode == 200) {
        final data = resp.data;
        setState(() {
          _recommendations = data['data']['recommendations'] ?? [];
          _isLoading = false;
          _updateMapMarkers();
        });
        // 推荐数据加载完成后，将地图中心移到用户当前位置
        if (_mapController != null &&
            _userLat.abs() > 0.01 &&
            _userLng.abs() > 0.01) {
          _mapController!.moveCamera(CameraUpdate.newCameraPosition(
              CameraPosition(
                  target: LatLng(_userLat, _userLng), zoom: 14.5)));
        }
      } else {
        setState(() {
          _errorMsg = "API Failed: ${resp.statusCode} - ${resp.data}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = "Network Error: $e";
        _isLoading = false;
      });
    }
  }

  void _updateMapMarkers() {
    Set<Marker> newMarkers = {};
    Map<String, int> newIdToIndex = {};

    // 我的位置 - 蓝色自定义图标
    newMarkers.add(Marker(
      position: LatLng(_userLat, _userLng),
      icon: _userLocationIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: '我的位置'),
    ));

    for (int i = 0; i < _recommendations.length; i++) {
      final rec = _recommendations[i];
      final station = rec['station'] ?? {};
      if (station['location'] == null) continue;

      final lat = station['location']['lat'] as double;
      final lng = station['location']['lng'] as double;
      final isSelected = i == _selectedMarkerIndex;

      final Marker marker = Marker(
        position: LatLng(lat, lng),
        icon: isSelected ? _stationIconSelected : _stationIcon,
        infoWindow: InfoWindow(
          title: station['name'] ?? '未知充电站',
          snippet:
              '🕐 ${rec['duration'] ?? 0}分钟 · ${(station['availability'] ?? {})['available'] ?? 0}/${(station['availability'] ?? {})['total'] ?? 0}桩',
        ),
        onTap: (id) => _onMarkerTapped(newIdToIndex[id] ?? i),
      );

      newIdToIndex[marker.id] = i;
      newMarkers.add(marker);
    }

    _markerIdToIndex = newIdToIndex;
    _markers = newMarkers;
  }

  void _onMarkerTapped(int index) {
    setState(() => _selectedMarkerIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(index,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _goToMyLocation() {
    // 校验坐标有效性：避免跳到 (0,0) 或武汉默认值
    if (_userLat.abs() < 0.01 || _userLng.abs() < 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('定位尚未完成，请稍候...'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    if (_mapController != null) {
      _mapController!.moveCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(_userLat, _userLng), zoom: 14.5)));
    }
    // 取消选中状态，但不移动滑块——等用户再次滑动时地图再跟随
    if (_selectedMarkerIndex != -1) {
      setState(() => _selectedMarkerIndex = -1);
    }
  }

  void _runInteractiveDemo() {}

  void _showVehicleSettings() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.only(
                  left: 24, right: 24, top: 24, bottom: 40),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('车辆与电量调节',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 20),

                  // ---- 品牌选择器（横向滚动） ----
                  const Text('选择品牌',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: VehicleData.brands.keys.length,
                      itemBuilder: (ctx, i) {
                        final brand =
                            VehicleData.brands.keys.elementAt(i);
                        final isSelected = _currentBrand == brand;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                _currentBrand = brand;
                                // 切换品牌时自动选该品牌的第一款车型
                                final models =
                                    VehicleData.getModels(brand);
                                if (models.isNotEmpty) {
                                  _currentCar =
                                      models.first['model'] as String;
                                  _batteryCapacity =
                                      (models.first['battery'] as num)
                                          .toDouble();
                                  _energyConsumption =
                                      (models.first['consumption']
                                              as num)
                                          .toDouble();
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF007AFF)
                                    : Colors.grey.shade100,
                                borderRadius:
                                    BorderRadius.circular(18),
                              ),
                              child: Text(
                                brand,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- 车型选择器（Wrap 布局） ----
                  Text('选择车型 - $_currentBrand',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54)),
                  const SizedBox(height: 10),
                  _buildModelSelector(setSheetState),
                  const SizedBox(height: 24),

                  // ---- 当前选中车型规格摘要 ----
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.electric_car,
                            color: Color(0xFF007AFF), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_currentCar · ${_batteryCapacity.toStringAsFixed(1)}kWh · ${_energyConsumption.toStringAsFixed(1)}kWh/100km',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF007AFF),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- SOC 电量滑块 ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('当前剩余电量 (SOC)',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54)),
                      Text('${_currentSoc.toInt()}%',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF007AFF))),
                    ],
                  ),
                  Slider(
                    value: _currentSoc,
                    min: 5,
                    max: 100,
                    activeColor: const Color(0xFF007AFF),
                    onChanged: (val) =>
                        setSheetState(() => _currentSoc = val),
                  ),
                  const SizedBox(height: 24),

                  // ---- 应用按钮 ----
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // 保存车型设置到本地（含品牌信息）
                        DataRepository().saveCarSettings({
                          'brand': _currentBrand,
                          'car_name': _currentCar,
                          'battery_capacity': _batteryCapacity,
                          'energy_consumption': _energyConsumption,
                          'current_soc': _currentSoc,
                        });
                        // 显示加载状态，让用户知道正在重新测算
                        setState(() => _isLoading = true);
                        _fetchRealData();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16))),
                      child: const Text('应用并重新测算',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  )
                ],
              ),
            );
          });
        });
  }

  /// 构建当前品牌下的车型选择器（Wrap 布局）
  Widget _buildModelSelector(StateSetter setSheetState) {
    final models = VehicleData.getModels(_currentBrand);
    if (models.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('暂无车型数据',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: models.map((model) {
        final modelName = model['model'] as String;
        final isSelected = _currentCar == modelName;
        return GestureDetector(
          onTap: () {
            setSheetState(() {
              _currentCar = modelName;
              _batteryCapacity =
                  (model['battery'] as num).toDouble();
              _energyConsumption =
                  (model['consumption'] as num).toDouble();
            });
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF007AFF)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF007AFF)
                    : Colors.grey.shade200,
              ),
            ),
            child: Text(
              modelName,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 构建圆形电量指示器：环形进度条 + 闪电(稍上移) + 百分比(闪电下方，整体在环内)
  Widget _buildBatteryRing() {
    // 根据电量选择颜色：绿(≥50%) / 橙(20-50%) / 红(<20%)
    Color batteryColor;
    if (_currentSoc >= 50) {
      batteryColor = const Color(0xFF34C759); // 绿色
    } else if (_currentSoc >= 20) {
      batteryColor = const Color(0xFFFF9500); // 橙色
    } else {
      batteryColor = const Color(0xFFFF3B30); // 红色
    }

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 环形进度条（背景）
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: _currentSoc / 100.0,
              strokeWidth: 3,
              backgroundColor: Colors.grey.shade200,
              valueColor:
                  AlwaysStoppedAnimation<Color>(batteryColor),
            ),
          ),
          // 闪电(稍上) + 百分比(下)，整体居中于环内
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, color: batteryColor, size: 16),
              Text(
                '${_currentSoc.toInt()}%',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: batteryColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 真高德地图底层
          Positioned.fill(
            child: AMapWidget(
              privacyStatement: const AMapPrivacyStatement(
                  hasContains: true, hasShow: true, hasAgree: true),
              apiKey: const AMapApiKey(androidKey: AMAP_KEY),
              initialCameraPosition: CameraPosition(
                target: LatLng(_userLat, _userLng),
                zoom: 12.0, // 把视野放宽一点以显示更多充电站
              ),
              markers: _markers,
              scaleEnabled: false, // 底部卡片会遮挡比例尺，直接关闭
              myLocationStyleOptions: MyLocationStyleOptions(true),
              onLocationChanged: (AMapLocation location) {
                // 高德地图自带定位（和手机高德 App 同一引擎）
                // 过滤无效坐标：(0,0) 是 SDK 初始化时的占位值
                final lat = location.latLng.latitude;
                final lng = location.latLng.longitude;
                if (mounted &&
                    lat.abs() > 0.01 &&
                    lng.abs() > 0.01) {
                  // 首次拿到有效定位时，自动刷新推荐
                  final wasDefault = _userLat == 30.583547;
                  setState(() {
                    _userLat = lat;
                    _userLng = lng;
                  });
                  if (wasDefault) {
                    _fetchRealData();
                  }
                }
              },
              onMapCreated: (AMapController controller) {
                _mapController = controller;
              },
            ),
          ),

          // 2. 罗盘方向指示器（右上角）
          Positioned(
            right: 16,
            top: 130,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -_compassHeading * math.pi / 180,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.2), blurRadius: 6)
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 向上箭头（指北）
                      Icon(Icons.navigation,
                          color: Colors.red.shade600, size: 28),
                      // 指向标记（东南西北）
                      Positioned(
                          top: 3,
                          child: Icon(Icons.arrow_drop_up,
                              color: Colors.red.shade600, size: 16)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. 顶层悬浮：全局玻璃态搜索与电池摘要 (贴着手机顶部安全区)
          Positioned(
            top: 45, // 原来是 60，更靠上一点
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: _showVehicleSettings,
              child: GlassmorphicContainer(
                height: 64, // 略微压榨一点高度
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // 圆形电量指示器：闪电图标 + 环形进度条
                    _buildBatteryRing(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(_currentCar,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.black87)),
                          ),
                          Text(
                              '$_weatherIcon $_temperature°C · 续航 ${(_batteryCapacity * (_currentSoc / 100) / _energyConsumption * 100).toInt()}km',
                              style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // ⚙️ 设置图标
                    GestureDetector(
                      onTap: _showVehicleSettings,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.tune,
                            color: Color(0xFF007AFF), size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 👤 我的图标
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => MinePage(
                                    favorites: _favorites,
                                    userLat: _userLat,
                                    userLng: _userLng,
                                    carName: _currentCar,
                                    soc: _currentSoc,
                                    batteryCapacity: _batteryCapacity,
                                    energyConsumption: _energyConsumption,
                                    history: _history,
                                    onLogout: widget.onLogout,
                                  )),
                        );
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. 底部悬浮：横向滑动超级卡片 (高度缩减，彻底贴底)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            height: 160,
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text('正在搜索充电站...',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  )
                : _errorMsg.isNotEmpty
                    ? _ErrorRetryCard(
                        errorMsg: _errorMsg, onRetry: _fetchRealData)
                    : _recommendations.isEmpty
                        ? _EmptyStationsCard(onRetry: _fetchRealData)
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: _recommendations.length,
                            physics: const BouncingScrollPhysics(),
                            onPageChanged: (index) {
                              if (_mapController != null &&
                                  index < _recommendations.length) {
                                final station =
                                    _recommendations[index]['station'];
                                if (station != null &&
                                    station['location'] != null) {
                                  double lat = station['location']['lat'];
                                  double lng = station['location']['lng'];
                                  // 滑动时，镜头优雅地平滑位移并放大对准该充电站
                                  _mapController!.moveCamera(
                                      CameraUpdate.newCameraPosition(
                                          CameraPosition(
                                              target: LatLng(lat, lng),
                                              zoom: 14.5)));
                                }
                              }
                            },
                            itemBuilder: (context, index) {
                              return AnimatedBuilder(
                                animation: _pageController,
                                builder: (context, child) {
                                  double value = 1.0;
                                  if (_pageController.position.haveDimensions) {
                                    value = _pageController.page! - index;
                                    value = (1 - (value.abs() * 0.15))
                                        .clamp(0.0, 1.0);
                                  }
                                  return Center(
                                    child: SizedBox(
                                      height:
                                          Curves.easeInOut.transform(value) *
                                              160,
                                      width: Curves.easeInOut.transform(value) *
                                          340,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: StationCarouselCard(
                                    index: index,
                                    data: _recommendations[index],
                                    userLat: _userLat,
                                    userLng: _userLng,
                                    isFavorite: _isFavorite(_getStationId(
                                        _recommendations[index]['station'] ??
                                            {})),
                                    onToggleFavorite: () => _toggleFavorite(
                                        _getStationId(_recommendations[index]
                                                ['station'] ??
                                            {})),
                                    onVisit: () =>
                                        _addHistory(_recommendations[index]),
                                  ),
                                ),
                              );
                            },
                          ),
          ),

          // 悬浮导航定位钮跟随下放
          Positioned(
              bottom: 190,
              right: 16,
              child: FloatingActionButton(
                mini: true, // 使用更精巧的小按钮
                backgroundColor: Colors.white,
                elevation: 4,
                onPressed: _goToMyLocation,
                child: const Icon(Icons.my_location,
                    color: Colors.blueAccent, size: 24),
              ))
        ],
      ),
    );
  }
}

class StationCarouselCard extends StatelessWidget {
  final int index;
  final dynamic data;
  final double userLat;
  final double userLng;
  final bool isFavorite;
  final Future<void> Function() onToggleFavorite;
  final VoidCallback? onVisit;
  const StationCarouselCard({
    super.key,
    required this.index,
    required this.data,
    required this.userLat,
    required this.userLng,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.onVisit,
  });

  @override
  Widget build(BuildContext context) {
    bool isRecommended = index == 0;

    // 解析后端返回的各种复杂数据
    final station = data['station'] ?? {};
    final stationName = station['name'] ?? '未知充电站';
    final distKm = data['distance'] ?? 0;
    final insight = data['insight'] ?? '';
    final power = station['power_kw'] ?? 0;
    final cost = data['estimated_cost'] ?? 0;
    final avail = station['availability'] ?? {};

    // 提取高价值 tag 分配颜色
    Color insightColor = Colors.black54;
    if (insight.contains('🌟')) insightColor = Colors.orange.shade700;
    if (insight.contains('⚠️')) insightColor = Colors.red.shade600;
    if (insight.contains('🛍️')) insightColor = Colors.purple.shade600;
    if (insight.contains('🌙')) insightColor = Colors.blue.shade600;
    if (insight.contains('⏰')) insightColor = Colors.amber.shade700;

    return GestureDetector(
        onTap: () {
          onVisit?.call();
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => StationDetailScreen(
                        data: data,
                        userLat: userLat,
                        userLng: userLng,
                        isFavorite: isFavorite,
                        onToggleFavorite: onToggleFavorite,
                      )));
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    16, 30, 16, 12), // 增加顶部 Padding 完美避开 TOP 标签的物理遮挡
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            stationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                        ),
                        Text(
                          '${distKm}km',
                          style: const TextStyle(
                              color: Color(0xFF007AFF),
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      insight.isNotEmpty ? insight : '常规充电站',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: insightColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _buildTag('${power}kW', Colors.purple),
                        const SizedBox(width: 8),
                        _buildTag(
                            '空闲 ${avail['available'] ?? 0}', Colors.green),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('预估花费',
                                style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                            Text('¥$cost',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87)),
                          ],
                        )
                      ],
                    )
                  ],
                ),
              ),
              if (isRecommended)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF007AFF),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          bottomRight: Radius.circular(16)),
                    ),
                    child: const Text('🌟 TOP 1 推荐',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
        ));
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// 画一个极简网格假地图
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.withOpacity(0.15) // 画格子的细线更深，像路网
      ..strokeWidth = 1.5;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============== 详情页屏 ==============
class StationDetailScreen extends StatefulWidget {
  final dynamic data;
  final double userLat;
  final double userLng;
  final bool isFavorite;
  final Future<void> Function() onToggleFavorite;
  const StationDetailScreen({
    super.key,
    required this.data,
    required this.userLat,
    required this.userLng,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  AMapController? _mapController;
  late bool _isFav;

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorite;
  }

  Future<void> _callStation(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.data['station'] ?? {};
    final name = station['name'] ?? '充电站';
    final distKm = widget.data['distance'] ?? 0;
    final cost = widget.data['estimated_cost'] ?? 0;
    final power = station['power_kw'] ?? 0;
    final avail = station['availability'] ?? {};
    final availableCount = avail['available'] ?? 0;
    final totalCount = avail['total'] ?? 0;
    final waitTime = widget.data['wait_time'] ?? 0;
    final insight = widget.data['insight'] ?? '';
    final address = station['address'] ?? '地址未知';
    final lat = station['location']?['lat'] ?? 0.0;
    final lng = station['location']?['lng'] ?? 0.0;
    final phone = (station['gaode_info'] ?? {})['tel'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // 渐变头部区域
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF007AFF),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back,
                    color: Color(0xFF007AFF), size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFav ? Icons.star : Icons.star_border,
                    color: _isFav ? Colors.amber : Color(0xFF007AFF),
                    size: 20,
                  ),
                ),
                onPressed: () async {
                  await widget.onToggleFavorite();
                  if (mounted) setState(() => _isFav = !_isFav);
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.ev_station,
                            size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          insight.isNotEmpty ? insight : '优质充电站',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 内容区域
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 快速信息卡片
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _DetailStatCard(
                          icon: Icons.straighten,
                          iconColor: const Color(0xFF007AFF),
                          value: '${distKm}km',
                          label: '距离',
                        ),
                        _DetailDivider(),
                        _DetailStatCard(
                          icon: Icons.timer_outlined,
                          iconColor: const Color(0xFFFF9500),
                          value:
                              '${widget.data['estimated_charging_time'] ?? 0}',
                          label: '充电分钟',
                        ),
                        _DetailDivider(),
                        _DetailStatCard(
                          icon: Icons.payments_outlined,
                          iconColor: const Color(0xFF34C759),
                          value: '¥$cost',
                          label: '预估费用',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 充电桩信息卡片
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt,
                                color: Color(0xFF007AFF), size: 22),
                            SizedBox(width: 8),
                            Text('充电桩信息',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoTile(
                                icon: Icons.electric_bolt,
                                label: '最大功率',
                                value: '${power}kW',
                                color: Colors.purple,
                              ),
                            ),
                            Expanded(
                              child: _InfoTile(
                                icon: Icons.event_available,
                                label: '可用数量',
                                value: '$availableCount / $totalCount',
                                color: availableCount > 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoTile(
                                icon: Icons.hourglass_empty,
                                label: '预计等待',
                                value: waitTime > 0 ? '${waitTime}分钟' : '无需等待',
                                color: const Color(0xFFFF9500),
                              ),
                            ),
                            Expanded(
                              child: _InfoTile(
                                icon: Icons.speed,
                                label: '电耗水平',
                                value: '正常',
                                color: const Color(0xFF5856D6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 地址信息卡片
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.location_on,
                                  color: Color(0xFF007AFF), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('地址',
                                      style: TextStyle(
                                          color: Colors.black54, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(address,
                                      style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.directions,
                                  color: Color(0xFF007AFF)),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 140,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AMapWidget(
                              privacyStatement: const AMapPrivacyStatement(
                                  hasContains: true,
                                  hasShow: true,
                                  hasAgree: true),
                              apiKey: const AMapApiKey(androidKey: AMAP_KEY),
                              initialCameraPosition: CameraPosition(
                                target: LatLng(lat, lng),
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  position: LatLng(lat, lng),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueRed),
                                  infoWindow: InfoWindow(title: name),
                                ),
                              },
                              onMapCreated: (AMapController controller) {
                                _mapController = controller;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 导航按钮
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NavigationScreen(
                              routeData: {
                                ...Map<String, dynamic>.from(widget.data),
                                'user_lat': widget.userLat,
                                'user_lng': widget.userLng,
                              },
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.navigation, color: Colors.white, size: 24),
                          SizedBox(width: 8),
                          Text('立即导航',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 辅助按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: phone.isNotEmpty
                              ? () => _callStation(phone)
                              : null,
                          icon: const Icon(Icons.call, size: 20),
                          label: const Text('联系站点'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF007AFF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28)),
                            side: const BorderSide(color: Color(0xFF007AFF)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            widget.onToggleFavorite();
                            setState(() => _isFav = !_isFav);
                          },
                          icon: Icon(
                              _isFav ? Icons.bookmark : Icons.bookmark_border,
                              size: 20),
                          label: Text(_isFav ? '已收藏' : '收藏站点'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                _isFav ? Colors.amber : const Color(0xFF007AFF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28)),
                            side: BorderSide(
                                color: _isFav
                                    ? Colors.amber
                                    : const Color(0xFF007AFF)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _DetailStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 10),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

class _DetailDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 50, width: 1, color: Colors.grey.shade200);
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
          ],
        ),
      ],
    );
  }
}

// ============== 导航页面 ==============
class NavigationScreen extends StatefulWidget {
  final dynamic routeData; // 包含 station + route info

  const NavigationScreen({super.key, required this.routeData});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with WidgetsBindingObserver {
  int _currentStepIndex = 0;
  double _userLat = 0;
  double _userLng = 0;
  double _userBearing = 0; // 用户朝向角度
  bool _isLoading = true; // 导航页初始为加载中
  bool _isArrived = false;
  bool _isOffRoute = false; // 偏航状态
  bool _offRouteAlertShown = false; // 偏航提示已显示（避免重复弹窗）
  String _errorMsg = "";
  List<dynamic> _steps = [];
  List<List<double>> _polyline = [];
  double _totalDistanceKm = 0;
  int _totalDurationMin = 0;
  double _remainingDistanceKm = 0;
  int _remainingDurationMin = 0;
  double _currentSpeed = 0; // 当前速度 km/h
  double _gpsAccuracy = 0; // GPS精度(米)

  // 地图控制器
  AMapController? _mapController;

  // 位置追踪（高德定位 SDK）
  AMapFlutterLocation? _aMapLocation;
  StreamSubscription? _positionSubscription;

  // 目的地坐标
  double _destLat = 0;
  double _destLng = 0;

  // 到达确认计时
  DateTime? _arrivalConfirmStart;

  // 转向图标映射
  static const Map<String, IconData> _actionIcons = {
    "直行": Icons.arrow_upward,
    "左转": Icons.turn_left,
    "右转": Icons.turn_right,
    "掉头": Icons.u_turn_left,
    "向左前方行驶": Icons.turn_left,
    "向右前方行驶": Icons.turn_right,
    "向左后方行驶": Icons.turn_left,
    "向右后方行驶": Icons.turn_right,
    "靠左": Icons.turn_left,
    "靠右": Icons.turn_right,
    "进入环岛": Icons.roundabout_left,
    "驶出环岛": Icons.roundabout_right,
    "减速行驶": Icons.remove_road,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _parseRouteData();
    _fetchRoute();
    _startLocationTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _aMapLocation?.stopLocation();
    _aMapLocation?.destroy();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _positionSubscription?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _positionSubscription?.resume();
    }
  }

  void _parseRouteData() {
    _userLat = widget.routeData['user_lat'] ?? 30.5833;
    _userLng = widget.routeData['user_lng'] ?? 114.3533;
    final station = widget.routeData['station'] ?? {};
    _destLat = station['location']?['lat'] ?? 0.0;
    _destLng = station['location']?['lng'] ?? 0.0;
  }

  void _startLocationTracking() {
    // 导航用高德定位，Hight_Accuracy 模式含道路吸附，适合导航
    _aMapLocation = AMapFlutterLocation();
    _aMapLocation!.setLocationOption(AMapLocationOption(
      onceLocation: false,
      locationMode: AMapLocationMode.Hight_Accuracy,
      needAddress: false,
      locationInterval: 2000, // 每 2 秒更新一次
    ));

    _positionSubscription = _aMapLocation!.onLocationChanged().listen(
      (result) {
        if (_isArrived) return;

        final errCode = result['errorCode']?.toString();
        if (errCode != null && errCode != '0') return;

        final lat = (result['latitude'] as num?)?.toDouble();
        final lng = (result['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) return;

        // 过滤无效坐标
        if (lat.abs() < 0.01 || lng.abs() < 0.01) return;

        final accuracy =
            (result['accuracy'] as num?)?.toDouble() ?? 0;
        // GPS精度过滤：忽略精度过差的定位
        if (accuracy > _GPS_ACCURACY_THRESHOLD) return;

        final speed =
            (result['speed'] as num?)?.toDouble() ?? 0;
        final bearing =
            (result['bearing'] as num?)?.toDouble() ?? 0;

        setState(() {
          _userLat = lat;
          _userLng = lng;
          _userBearing = bearing;
          _currentSpeed = speed * 3.6; // m/s 转 km/h
          _gpsAccuracy = accuracy;
        });

        // 检查偏航
        _checkDeviation(lat, lng);
        _updateNavigation(lat, lng, bearing);
      },
      onError: (e) {
        debugPrint('AMap location error: $e');
      },
    );

    _aMapLocation!.startLocation();
  }

  void _updateNavigation(double lat, double lng, double bearing) {
    if (_polyline.isEmpty) return;

    // 计算沿着路线从当前位置到目的地的距离
    final routeInfo = _calculateRemainingRouteDistance(lat, lng);

    // 增强到达判断：距离 < 100m 且 GPS精度 < 25m 且速度 < 5km/h 持续3秒
    final distMeters = routeInfo['distanceKm'] * 1000;
    if (distMeters < _ARRIVAL_DISTANCE_METERS &&
        _gpsAccuracy < _GPS_ACCURACY_THRESHOLD &&
        _currentSpeed < _ARRIVAL_SPEED_THRESHOLD) {
      if (_arrivalConfirmStart == null) {
        _arrivalConfirmStart = DateTime.now();
      } else if (DateTime.now().difference(_arrivalConfirmStart!).inSeconds >=
          _ARRIVAL_CONFIRM_SECONDS) {
        setState(() {
          _isArrived = true;
          _remainingDistanceKm = 0;
          _remainingDurationMin = 0;
        });
        return;
      }
    } else {
      _arrivalConfirmStart = null; // 重置计时
    }

    // 更新剩余距离和时间
    setState(() {
      _remainingDistanceKm = routeInfo['distanceKm'];
      _remainingDurationMin = routeInfo['durationMin'];
      _currentStepIndex = routeInfo['stepIndex'];
    });

    // 移动地图跟随用户位置
    _moveCameraToUser(lat, lng, bearing);
  }

  /// 检查用户是否偏离路线
  void _checkDeviation(double lat, double lng) {
    if (_polyline.isEmpty || _isOffRoute) return;

    double minDistToRoute = double.infinity;
    for (int i = 0; i < _polyline.length - 1; i++) {
      final p1 = _polyline[i];
      final p2 = _polyline[i + 1];
      final dist =
          _pointToSegmentDistance(lat, lng, p1[0], p1[1], p2[0], p2[1]);
      if (dist < minDistToRoute) {
        minDistToRoute = dist;
      }
    }

    // 转换为米
    final distMeters = minDistToRoute * 1000;
    if (distMeters > _OFF_ROUTE_THRESHOLD_METERS) {
      setState(() {
        _isOffRoute = true;
      });
      _showOffRouteAlert();
    }
  }

  void _showOffRouteAlert() {
    if (_offRouteAlertShown) return;
    _offRouteAlertShown = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.white),
            SizedBox(width: 8),
            Text('您已偏离路线，正在重新规划...'),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '重新导航',
          textColor: Colors.white,
          onPressed: _handleDeviation,
        ),
      ),
    );

    // 自动触发重路由
    Future.delayed(const Duration(seconds: 1), () {
      _handleDeviation();
    });
  }

  /// 处理偏航重算：从当前位置重新规划路线
  void _handleDeviation() {
    setState(() {
      _isOffRoute = false;
      _offRouteAlertShown = false;
      _isLoading = true;
    });
    _fetchRoute();
  }

  void _moveCameraToUser(double lat, double lng, double bearing) {
    if (_mapController == null) return;

    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lng),
          zoom: 17,
          bearing: bearing,
        ),
      ),
    );
  }

  /// 计算沿着路线从当前位置到目的地的剩余距离和时间
  Map<String, dynamic> _calculateRemainingRouteDistance(
      double lat, double lng) {
    if (_polyline.isEmpty) {
      return {'distanceKm': 0.0, 'durationMin': 0, 'stepIndex': 0};
    }

    // 找到 polyline 上距离当前位置最近的点索引
    double minDist = double.infinity;
    int nearestIdx = 0;

    for (int i = 0; i < _polyline.length - 1; i++) {
      final p1 = _polyline[i];
      final p2 = _polyline[i + 1];
      final dist =
          _pointToSegmentDistance(lat, lng, p1[0], p1[1], p2[0], p2[1]);
      if (dist < minDist) {
        minDist = dist;
        nearestIdx = i;
      }
    }

    // 计算从最近点到目的地沿着路线的距离
    double remainingDistMeters = 0;
    for (int i = nearestIdx; i < _polyline.length - 1; i++) {
      remainingDistMeters += _calculateDistance(
            _polyline[i][0],
            _polyline[i][1],
            _polyline[i + 1][0],
            _polyline[i + 1][1],
          ) *
          1000; // 转米
    }

    // 确保剩余距离有效
    remainingDistMeters = remainingDistMeters.isNaN || remainingDistMeters < 0
        ? _totalDistanceKm * 1000
        : remainingDistMeters;

    // 精确计算当前 step 索引：用 polyline 累计距离匹配 step
    int stepIndex = _calculateStepIndexByDistance(nearestIdx);

    // 计算剩余时间
    double effectiveSpeed = _currentSpeed > 5
        ? _currentSpeed
        : (_totalDistanceKm / (_totalDurationMin / 60));
    effectiveSpeed =
        effectiveSpeed.isNaN || effectiveSpeed <= 0 ? 30.0 : effectiveSpeed;

    double remainingMinRaw = remainingDistMeters / 1000 / effectiveSpeed * 60;
    if (remainingMinRaw.isNaN || remainingMinRaw < 0)
      remainingMinRaw = _totalDurationMin.toDouble();
    final remainingMin = remainingMinRaw.ceil().clamp(1, 999);

    return {
      'distanceKm': remainingDistMeters / 1000,
      'durationMin': remainingMin,
      'stepIndex': stepIndex,
    };
  }

  /// 根据 polyline 索引精确计算所在路段
  int _calculateStepIndexByDistance(int nearestPolylineIdx) {
    if (_steps.isEmpty || _polyline.length < 2) return 0;

    // 计算用户已行驶的 polyline 距离（公里）
    double traveledDistKm = 0;
    for (int i = 0; i < nearestPolylineIdx; i++) {
      traveledDistKm += _calculateDistanceKm(
        _polyline[i][0],
        _polyline[i][1],
        _polyline[i + 1][0],
        _polyline[i + 1][1],
      );
    }
    // 加上最近路段的部分距离
    if (nearestPolylineIdx > 0 && nearestPolylineIdx < _polyline.length) {
      final p1 = _polyline[nearestPolylineIdx - 1];
      final p2 = _polyline[nearestPolylineIdx];
      // 粗略估算：取整段路的 50%
      traveledDistKm += _calculateDistanceKm(p1[0], p1[1], p2[0], p2[1]) * 0.5;
    }

    // 遍历 steps，累加 distance_km，找到当前所在 step
    double cumulativeDistKm = 0;
    for (int i = 0; i < _steps.length; i++) {
      final stepDistKm = (_steps[i]['distance_km'] ?? 0).toDouble();
      if (cumulativeDistKm + stepDistKm > traveledDistKm) {
        return i;
      }
      cumulativeDistKm += stepDistKm;
    }
    return _steps.length - 1;
  }

  double _pointToSegmentDistance(
      double px, double py, double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lengthSq = dx * dx + dy * dy;

    if (lengthSq == 0) {
      return _calculateDistance(px, py, x1, y1);
    }

    var t = ((px - x1) * dx + (py - y1) * dy) / lengthSq;
    t = t.clamp(0.0, 1.0);

    final nearestX = x1 + t * dx;
    final nearestY = y1 + t * dy;

    return _calculateDistance(px, py, nearestX, nearestY);
  }

  /// Haversine 距离计算（公里）
  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // 公里
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// 距离计算（公里），直接调用
  double _calculateDistanceKm(
      double lat1, double lng1, double lat2, double lng2) {
    return _calculateDistance(lat1, lng1, lat2, lng2);
  }

  Future<void> _fetchRoute() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMsg = "";
      });

      if (_destLat == 0 || _destLng == 0) {
        setState(() {
          _errorMsg = "目的地坐标无效";
          _isLoading = false;
        });
        return;
      }

      // 使用 ApiClient 请求导航路线
      final payload = {
        "origin_lat": _userLat,
        "origin_lng": _userLng,
        "dest_lat": _destLat,
        "dest_lng": _destLng,
      };
      debugPrint('导航请求payload: $payload');

      final resp = await ApiClient().post('/api/route', data: payload);
      final data = resp.data;
      debugPrint('导航响应: $data');

      if (resp.statusCode == 200 && data['code'] == 200) {
        final routeData = data['data'];
        setState(() {
          _steps = routeData['steps'] ?? [];
          _polyline = List<List<double>>.from(
            (routeData['polyline'] as List?)?.map(
                  (e) => List<double>.from(e),
                ) ??
                [],
          );
          _totalDistanceKm = (routeData['distance_km'] ?? 0).toDouble();
          _totalDurationMin = routeData['duration_min'] ?? 0;
          _remainingDistanceKm = _totalDistanceKm;
          _remainingDurationMin = _totalDurationMin;
          _isLoading = false;
        });

        // 用当前位置初始化导航
        _updateNavigation(_userLat, _userLng, 0);
      } else {
        setState(() {
          _errorMsg = data['message'] ?? '路线规划失败';
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('导航请求异常: $e\n$stack');
      setState(() {
        _errorMsg = "网络错误: $e";
        _isLoading = false;
      });
    }
  }

  IconData _getActionIcon(String action) {
    return _actionIcons[action] ?? Icons.arrow_upward;
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.routeData['station'] ?? {};
    final stationName = station['name'] ?? '充电站';

    return Scaffold(
      body: Stack(
        children: [
          // 地图
          Positioned.fill(
            child: AMapWidget(
              privacyStatement: const AMapPrivacyStatement(
                hasContains: true,
                hasShow: true,
                hasAgree: true,
              ),
              apiKey: const AMapApiKey(androidKey: AMAP_KEY),
              initialCameraPosition: CameraPosition(
                target: LatLng(_destLat > 0 ? _destLat : _userLat,
                    _destLng > 0 ? _destLng : _userLng),
                zoom: 15,
              ),
              myLocationStyleOptions: MyLocationStyleOptions(true),
              markers: {
                // 目的地标记
                if (_destLat > 0 && _destLng > 0)
                  Marker(
                    position: LatLng(_destLat, _destLng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed),
                    infoWindow: InfoWindow(title: stationName),
                  ),
              },
              polylines: _polyline.isNotEmpty
                  ? {
                      Polyline(
                        points:
                            _polyline.map((p) => LatLng(p[0], p[1])).toList(),
                        width: 12,
                        color: const Color(0xFF007AFF),
                      ),
                    }
                  : {},
              onMapCreated: (AMapController controller) {
                _mapController = controller;
              },
            ),
          ),

          // 顶部信息栏 - 高德风格
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC1A1A1A),
                    Color(0x991A1A1A),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // 关闭按钮
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 目的地信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.trip_origin,
                                    color: Color(0xFF00C853), size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    stationName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isArrived
                                  ? '已进入目的地'
                                  : '剩余 ${_remainingDistanceKm.toStringAsFixed(1)} km · 约 $_remainingDurationMin 分钟',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 路线概览按钮
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.route, color: Colors.white, size: 18),
                            SizedBox(width: 4),
                            Text('路线',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_isArrived && _totalDistanceKm > 0) ...[
                    const SizedBox(height: 12),
                    // 路线进度条
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: 1 -
                                  (_remainingDistanceKm / _totalDistanceKm)
                                      .clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C853),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${((1 - _remainingDistanceKm / _totalDistanceKm) * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 右上角速度显示（实时GPS速度）
          if (!_isLoading && !_isArrived)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed, color: Colors.white, size: 20),
                    const SizedBox(height: 2),
                    Text(
                      _currentSpeed > 1
                          ? _currentSpeed.toStringAsFixed(0)
                          : '--',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text('km/h',
                        style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ),

          // 偏航重算按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 16,
            child: GestureDetector(
              onTap: _handleDeviation,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.replay, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('偏航重算',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),

          // 加载中
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.white70,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          // 错误
          if (_errorMsg.isNotEmpty)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white70,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMsg,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMsg = "";
                          });
                          _fetchRoute();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 到达提示
          if (_isArrived)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFF34C759),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 48),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '已到达目的地',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          stationName,
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 48, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28)),
                          ),
                          child: const Text('完成导航',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 底部引导卡片
          if (!_isLoading &&
              _errorMsg.isEmpty &&
              _steps.isNotEmpty &&
              !_isArrived)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildGuideCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildGuideCard() {
    final currentStep = _currentStepIndex < _steps.length
        ? _steps[_currentStepIndex]
        : _steps.last;
    final nextStep = _currentStepIndex + 1 < _steps.length
        ? _steps[_currentStepIndex + 1]
        : null;

    final action = currentStep['action'] ?? '直行';
    final instruction = currentStep['instruction'] ?? '';
    final road = currentStep['road'] ?? '';
    // 使用剩余距离和时间
    final remainingDist = _remainingDistanceKm;
    final remainingTime = _remainingDurationMin;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 左侧大转向图标
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getActionIcon(action),
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        action,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 中间引导信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            remainingDist < 1
                                ? '${(remainingDist * 1000).toStringAsFixed(0)}'
                                : remainingDist.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              remainingDist < 1 ? '米' : '公里',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule,
                                    size: 14, color: Colors.black45),
                                const SizedBox(width: 4),
                                Text(
                                  '约${remainingTime}分钟',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        instruction,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (road.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 14, color: Color(0xFF007AFF)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                road,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF007AFF),
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 下一路口提示
          if (nextStep != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getActionIcon(nextStep['action'] ?? '直行'),
                      color: Colors.black54,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '下一个路口',
                          style: TextStyle(fontSize: 10, color: Colors.black38),
                        ),
                        Text(
                          '${nextStep['action'] ?? '直行'}至${nextStep['road'] ?? '目的地'}',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    nextStep['distance_km'] < 1
                        ? '${((nextStep['distance_km'] ?? 0) * 1000).toStringAsFixed(0)}米'
                        : '${(nextStep['distance_km'] ?? 0).toStringAsFixed(1)}公里',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black45,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============== 我的页面（支持游客/登录双模式） ==============
class MinePage extends StatefulWidget {
  final Set<String> favorites;
  final double userLat;
  final double userLng;
  final String carName;
  final double soc;
  final double batteryCapacity;
  final double energyConsumption;
  final List<dynamic> history;
  final VoidCallback onLogout;

  const MinePage({
    super.key,
    required this.favorites,
    required this.userLat,
    required this.userLng,
    required this.carName,
    required this.soc,
    required this.batteryCapacity,
    required this.energyConsumption,
    required this.history,
    required this.onLogout,
  });

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  final AuthService _auth = AuthService();
  bool _isLoggedIn = false;
  String _displayName = '';
  String _myCarName = '';
  double _mySoc = 48.0;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  /// 刷新所有状态：先从缓存秒读，再异步网络更新
  Future<void> _refreshAll() async {
    // 1. 本地缓存秒读（SharedPreferences 在本地，瞬间完成）
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('user_id');
    final nickname = prefs.getString('nickname');
    final username = prefs.getString('username');
    final carSettings = await DataRepository().loadCarSettings();
    if (mounted) {
      setState(() {
        _isLoggedIn = uid != null && uid > 0;
        _displayName = (nickname?.isNotEmpty == true)
            ? nickname!
            : (username ?? '');
        _myCarName = carSettings['car_name']?.toString() ?? widget.carName;
        _mySoc = (carSettings['current_soc'] ?? widget.soc).toDouble();
      });
    }

    // 2. 异步网络更新（静默，不影响已显示的内容）
    final loggedIn = await _auth.isLoggedIn();
    if (!loggedIn || !mounted) return;
    final user = await _auth.getCurrentUser();
    if (user != null) {
      final carSettings2 = await DataRepository().loadCarSettings();
      setState(() {
        _isLoggedIn = true;
        _displayName = (user['nickname']?.toString().isNotEmpty == true)
            ? user['nickname']
            : (user['username']?.toString() ?? '');
        _myCarName = carSettings2['car_name']?.toString() ?? _myCarName;
        _mySoc = (carSettings2['current_soc'] ?? _mySoc).toDouble();
      });
    }
  }

  /// 登录成功后的回调：刷新本页状态并通知父页面重建
  void _onLoginSuccess() {
    _refreshAll();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('我的',
            style:
                TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 用户信息卡片（游客/登录不同展示） ----
          _buildUserCard(context),
          const SizedBox(height: 24),
          _buildListTile(Icons.history, '历史记录', context, onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => HistoryListPage(
                        history: widget.history,
                        favorites: widget.favorites,
                        userLat: widget.userLat,
                        userLng: widget.userLng)));
          }),
          _buildListTile(Icons.star, '收藏站点', context, onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => FavoritesListPage(
                          favorites: widget.favorites,
                          userLat: widget.userLat,
                          userLng: widget.userLng,
                          carName: widget.carName,
                          soc: widget.soc,
                        )));
          }),
          _buildDivider(),
          _buildListTile(Icons.settings, '设置', context, onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SettingsPage(
                          isLoggedIn: _isLoggedIn,
                          onLogout: () async {
                            await _auth.logout();
                            setState(() => _isLoggedIn = false);
                            widget.onLogout();
                          },
                        )));
          }),
        ],
      ),
    );
  }

  /// 构建用户信息卡片：未登录显示登录引导，已登录显示用户信息
  Widget _buildUserCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF007AFF),
            child: Icon(
              _isLoggedIn ? Icons.person : Icons.person_outline,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoggedIn ? _displayName : '游客模式',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoggedIn
                      ? '$_myCarName · ${_mySoc.toInt()}%'
                      : '登录后同步数据到云端',
                  style: TextStyle(
                      fontSize: 14,
                      color: _isLoggedIn
                          ? Colors.black54
                          : Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (!_isLoggedIn)
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            LoginPage(onLoginSuccess: _onLoginSuccess)));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('登录',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, BuildContext context,
      {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF007AFF), size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 15, color: Colors.black87)),
        trailing:
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: onTap ?? () {},
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: const Divider(height: 1, color: Color(0xFFF0F0F0)),
    );
  }
}

// ============== 收藏站点列表页 ==============
// ============== 收藏站点页面（重构版） ==============
// 不再依赖当前推荐列表过滤，而是直接从后端获取站点详情
class FavoritesListPage extends StatefulWidget {
  final Set<String> favorites;
  final double userLat;
  final double userLng;
  final String carName;
  final double soc;

  const FavoritesListPage({
    super.key,
    required this.favorites,
    required this.userLat,
    required this.userLng,
    required this.carName,
    required this.soc,
  });

  @override
  State<FavoritesListPage> createState() => _FavoritesListPageState();
}

class _FavoritesListPageState extends State<FavoritesListPage> {
  /// 站点信息缓存：stationId → 完整站点对象（名称、类型、可用桩数、电价等）
  Map<String, Map<String, dynamic>> _stationCache = {};
  /// 是否正在加载站点详情列表（页面级加载状态）
  bool _isLoadingCache = false;
  /// 正在加载详情的站点 ID（点击进入详情页时的加载状态）
  String? _loadingStationId;
  /// 当前收藏集合（用于详情页返回后刷新）
  late Set<String> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = Set<String>.from(widget.favorites);
    _loadStationCache();
  }

  @override
  void didUpdateWidget(FavoritesListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favorites != widget.favorites) {
      _favorites = Set<String>.from(widget.favorites);
      _loadStationCache();
    }
  }

  /// 加载收藏站点的完整信息用于列表展示
  /// 1. 先从本地历史记录快速加载（秒显基本信息）
  /// 2. 再并行拉取后端完整数据（类型、桩数、电价等）
  Future<void> _loadStationCache() async {
    // 第一步：从历史记录加载基本信息作为秒显缓存
    final history = await LocalStorage.loadHistory();
    final cache = <String, Map<String, dynamic>>{};
    for (final entry in history) {
      final station = entry['station'] as Map<String, dynamic>?;
      final stationId = entry['station_id']?.toString() ?? '';
      if (station != null &&
          stationId.isNotEmpty &&
          _favorites.contains(stationId) &&
          !cache.containsKey(stationId)) {
        cache[stationId] = station;
      }
    }
    if (mounted) setState(() => _stationCache = cache);

    // 第二步：并行从后端拉取所有收藏站点的完整数据
    if (_favorites.isEmpty) return;
    setState(() => _isLoadingCache = true);

    final results = await Future.wait(
      _favorites.map((stationId) =>
          DataRepository().fetchStationDetail(stationId).then((detail) {
            // 从响应中提取 station 对象（不含距离等计算字段）
            if (detail != null && detail['station'] is Map<String, dynamic>) {
              return MapEntry(stationId, detail['station'] as Map<String, dynamic>);
            }
            return null;
          }).catchError((_) => null)),
    );

    // 将后端数据合并到缓存（后端数据更完整，覆盖历史记录中的残数据）
    for (final result in results) {
      if (result is MapEntry<String, Map<String, dynamic>>) {
        cache[result.key] = result.value;
      }
    }

    if (mounted) {
      setState(() {
        _stationCache = cache;
        _isLoadingCache = false;
      });
    }
  }

  /// 点击收藏项：从后端获取完整详情，然后导航到详情页
  Future<void> _openStationDetail(String stationId) async {
    setState(() => _loadingStationId = stationId);

    // 从后端获取站点完整数据（含距离计算）
    final detail = await DataRepository().fetchStationDetail(
      stationId,
      lat: widget.userLat,
      lng: widget.userLng,
    );

    if (!mounted) return;
    setState(() => _loadingStationId = null);

    // 后端不可用时，尝试用本地缓存数据兜底
    final dataToUse = detail ?? _buildFallbackData(stationId);
    if (dataToUse == null) {
      _showErrorSnackBar('无法获取站点信息，请检查网络连接');
      return;
    }

    final isFav = _favorites.contains(stationId);

    // 导航到详情页，返回后刷新收藏状态
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StationDetailScreen(
          data: dataToUse,
          userLat: widget.userLat,
          userLng: widget.userLng,
          isFavorite: isFav,
          onToggleFavorite: () async {
            await DataRepository().toggleFavorite(stationId);
          },
        ),
      ),
    );
    // 返回后重新加载本地缓存和收藏状态
    if (mounted) {
      final updatedFavs = await DataRepository().loadFavorites();
      setState(() {
        _favorites = updatedFavs;
      });
      _loadStationCache();
    }
  }

  /// 后端不可用时，用本地历史记录数据构造兜底 data 对象
  Map<String, dynamic>? _buildFallbackData(String stationId) {
    final cached = _stationCache[stationId];
    if (cached == null) return null;
    return {
      'station': cached,
      'distance': 0,
      'estimated_cost': 0,
      'wait_time': 0,
      'insight': '',
      'estimated_charging_time': 30,
    };
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoriteIds = _favorites.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('收藏站点',
            style:
                TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
      ),
      body: favoriteIds.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('暂无收藏站点',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('在电站详情页点击星标收藏',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                ],
              ),
            )
          : Column(
              children: [
                // 列表数据加载中指示器
                if (_isLoadingCache)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: favoriteIds.length,
              itemBuilder: (context, index) {
                final stationId = favoriteIds[index];
                final cachedStation = _stationCache[stationId];
                final isLoading = _loadingStationId == stationId;
                return _FavoriteStationCard(
                  station: cachedStation ?? {'station_id': stationId},
                  data: cachedStation != null
                      ? {'station': cachedStation}
                      : {'station': {'station_id': stationId}},
                  isFavorite: true,
                  userLat: widget.userLat,
                  userLng: widget.userLng,
                  isLoading: isLoading,
                  onTap: isLoading
                      ? null
                      : () => _openStationDetail(stationId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteStationCard extends StatelessWidget {
  final dynamic station;
  final dynamic data;
  final bool isFavorite;
  final double userLat;
  final double userLng;
  final VoidCallback? onTap;
  final bool isLoading;

  const _FavoriteStationCard({
    required this.station,
    required this.data,
    required this.isFavorite,
    required this.userLat,
    required this.userLng,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _getTypeColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_getTypeIcon(), color: _getTypeColor(), size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (station['name']?.toString() ?? '').isEmpty
                                ? (station['station_id'] ?? '未知站点')
                                : station['name'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      const SizedBox(height: 6),
                      Wrap(
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getTypeColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              station['type_name'] ?? station['type'] ?? '快充',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _getTypeColor(),
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.ev_station,
                                  size: 14, color: _getAvailColor()),
                              const SizedBox(width: 2),
                              Text(
                                '${_getAvailable()}/${_getTotal()}桩',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _getAvailColor(),
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '¥${((station['price'] ?? {})['electricity'] ?? 0).toStringAsFixed(2)}/度',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
          // 加载中遮罩
          if (isLoading)
            const Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
);
  }

  IconData _getTypeIcon() {
    switch (station['type']) {
      case 'ultra':
        return Icons.bolt;
      case 'fast':
        return Icons.flash_on;
      case 'slow':
        return Icons.power;
      case 'destination':
        return Icons.store;
      case 'fleet':
        return Icons.local_shipping;
      case 'swap':
        return Icons.swap_horiz;
      default:
        return Icons.ev_station;
    }
  }

  Color _getTypeColor() {
    switch (station['type']) {
      case 'ultra':
        return Colors.orange;
      case 'fast':
        return Colors.blue;
      case 'slow':
        return Colors.green;
      case 'destination':
        return Colors.purple;
      case 'fleet':
        return Colors.teal;
      case 'swap':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  int _getAvailable() => (station['availability'] ?? {})['available'] ?? 0;
  int _getTotal() => (station['availability'] ?? {})['total'] ?? 0;
  Color _getAvailColor() =>
      _getAvailable() > 0 ? Colors.green.shade600 : Colors.red;
}

// ============== 历史记录页面 ==============
class HistoryListPage extends StatefulWidget {
  final List<dynamic> history;
  final Set<String> favorites;
  final double userLat;
  final double userLng;

  const HistoryListPage(
      {super.key,
      required this.history,
      required this.favorites,
      required this.userLat,
      required this.userLng});

  @override
  State<HistoryListPage> createState() => _HistoryListPageState();
}

class _HistoryListPageState extends State<HistoryListPage> {
  bool _selectionMode = false;
  String? _loadingStationId; // 正在加载详情的站点 ID
  final Set<int> _selected = {};

  void _toggleSelection(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selected.length} 条记录吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 从本地删除，按索引从大到小避免偏移
    final allHistory = await LocalStorage.loadHistory();
    final sorted = _selected.toList()..sort((a, b) => b.compareTo(a));
    final isLoggedIn = await AuthService().isLoggedIn();

    for (final i in sorted) {
      if (i < allHistory.length) {
        final entry = allHistory[i];
        final entryId = entry['id'];
        // 登录用户同步删除云端记录
        if (isLoggedIn && entryId != null) {
          try {
            await ApiClient().delete('/api/history/$entryId');
          } catch (_) {}
        }
        allHistory.removeAt(i);
      }
    }
    await LocalStorage.saveHistory(allHistory);

    // 同步更新父页面持有的 history 引用（widget.history 即 _SleekHomeWrapperState._history）
    widget.history
      ..clear()
      ..addAll(allHistory);

    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    // 通知父页面刷新
    if (mounted) Navigator.pop(context);
  }

  /// 点击历史记录项：从后端获取最新站点详情，然后导航到详情页
  Future<void> _openStationDetail(String stationId, Map<String, dynamic> cachedStation) async {
    setState(() => _loadingStationId = stationId);

    // 从后端获取站点完整数据（含距离计算）
    final detail = await DataRepository().fetchStationDetail(
      stationId,
      lat: widget.userLat,
      lng: widget.userLng,
    );

    if (!mounted) return;
    setState(() => _loadingStationId = null);

    // 后端不可用时，用历史记录中缓存的站点数据兜底
    final dataToUse = detail ?? {
      'station': cachedStation,
      'distance': 0,
      'estimated_cost': 0,
      'wait_time': 0,
      'insight': '',
      'estimated_charging_time': 30,
    };

    final isFav = widget.favorites.contains(stationId);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StationDetailScreen(
          data: dataToUse,
          userLat: widget.userLat,
          userLng: widget.userLng,
          isFavorite: isFav,
          onToggleFavorite: () async {
            await DataRepository().toggleFavorite(stationId);
          },
        ),
      ),
    );
    // 返回后刷新页面状态
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: Icon(_selectionMode ? Icons.close : Icons.arrow_back,
                color: Colors.black87),
            onPressed: () {
              if (_selectionMode) {
                setState(() {
                  _selectionMode = false;
                  _selected.clear();
                });
              } else {
                Navigator.pop(context);
              }
            }),
        title: Text(
          _selectionMode ? '已选 ${_selected.length} 项' : '历史记录',
          style: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _selected.isNotEmpty ? _deleteSelected : null,
              tooltip: '删除选中',
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: widget.history.isNotEmpty
                  ? () => setState(() => _selectionMode = true)
                  : null,
              tooltip: '选择删除',
            ),
        ],
      ),
      body: widget.history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('暂无历史记录',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('访问电站详情即会自动记录',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.history.length,
              itemBuilder: (context, index) {
                final entry = widget.history[index];
                final station = entry['station'] ?? {};
                final visitedAt =
                    DateTime.tryParse(entry['visited_at'] ?? '') ??
                        DateTime.now();
                final isSelected = _selected.contains(index);
                final stationId = entry['station_id']?.toString() ?? '';

                return _HistoryStationCard(
                  station: station,
                  visitedAt: visitedAt,
                  entry: entry,
                  isSelected: isSelected,
                  showCheckbox: _selectionMode,
                  isLoading: _loadingStationId == stationId,
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelection(index);
                    } else if (_loadingStationId == null) {
                      _openStationDetail(stationId, station is Map<String, dynamic> ? station : {});
                    }
                  },
                );
              },
            ),
    );
  }
}

class _HistoryStationCard extends StatelessWidget {
  final dynamic station;
  final DateTime visitedAt;
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  final bool isSelected;
  final bool showCheckbox;
  final bool isLoading;

  const _HistoryStationCard(
      {required this.station,
      required this.visitedAt,
      required this.entry,
      required this.onTap,
      this.isSelected = false,
      this.showCheckbox = false,
      this.isLoading = false});

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  Widget _statChip(String icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: TextStyle(fontSize: 11)),
        const SizedBox(width: 2),
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? Colors.red.shade300 : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    if (showCheckbox)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected ? Colors.red : Colors.grey,
                          size: 24,
                        ),
                      ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getTypeColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_getTypeIcon(), color: _getTypeColor(), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((station['name']?.toString() ?? '').isEmpty
                              ? (station['station_id'] ?? '未知站点')
                              : station['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('访问于 ${_formatTime(visitedAt)}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500)),
                          // 充电数据
                          if ((entry['energy_kwh'] ?? 0) > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _statChip('⚡', '${(entry['energy_kwh'] as num).toStringAsFixed(1)}度', const Color(0xFF007AFF)),
                                const SizedBox(width: 12),
                                _statChip('💰', '¥${(entry['cost_yuan'] as num).toStringAsFixed(1)}', const Color(0xFFF59E0B)),
                                const SizedBox(width: 12),
                                _statChip('⏱', '${entry['duration_min'] ?? 0}分钟', const Color(0xFF10B981)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isLoading)
                      const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
              // 加载中遮罩
              if (isLoading)
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (station['type']) {
      case 'ultra':
        return Icons.bolt;
      case 'fast':
        return Icons.flash_on;
      case 'slow':
        return Icons.power;
      case 'destination':
        return Icons.store;
      case 'fleet':
        return Icons.local_shipping;
      case 'swap':
        return Icons.swap_horiz;
      default:
        return Icons.ev_station;
    }
  }

  Color _getTypeColor() {
    switch (station['type']) {
      case 'ultra':
        return Colors.orange;
      case 'fast':
        return Colors.blue;
      case 'slow':
        return Colors.green;
      case 'destination':
        return Colors.purple;
      case 'fleet':
        return Colors.teal;
      case 'swap':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}

// ============== 我的车型页面 ==============
class MyCarPage extends StatefulWidget {
  final String carName;
  final double soc;
  final double batteryCapacity;
  final double energyConsumption;

  const MyCarPage(
      {super.key,
      required this.carName,
      required this.soc,
      required this.batteryCapacity,
      required this.energyConsumption});

  @override
  State<MyCarPage> createState() => _MyCarPageState();
}

class _MyCarPageState extends State<MyCarPage> {
  late String _carName;
  late double _soc;
  late double _batteryCapacity;
  late double _energyConsumption;

  @override
  void initState() {
    super.initState();
    _carName = widget.carName;
    _soc = widget.soc;
    _batteryCapacity = widget.batteryCapacity;
    _energyConsumption = widget.energyConsumption;
    _loadCarData();
  }

  Future<void> _loadCarData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _carName = prefs.getString('car_name') ?? widget.carName;
      _soc = prefs.getDouble('soc') ?? widget.soc;
      _batteryCapacity =
          prefs.getDouble('battery_capacity') ?? widget.batteryCapacity;
      _energyConsumption =
          prefs.getDouble('energy_consumption') ?? widget.energyConsumption;
    });
  }

  Future<void> _saveCarData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('car_name', _carName);
    await prefs.setDouble('soc', _soc);
    await prefs.setDouble('battery_capacity', _batteryCapacity);
    await prefs.setDouble('energy_consumption', _energyConsumption);
  }

  @override
  Widget build(BuildContext context) {
    final range =
        (_batteryCapacity * (_soc / 100) / _energyConsumption * 100).toInt();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context)),
        title: const Text('我的车型',
            style:
                TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
              onPressed: () async {
                await _saveCarData();
                if (mounted)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('保存成功')));
              },
              child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]),
            child: Column(
              children: [
                Icon(Icons.directions_car,
                    size: 48, color: Colors.blue.shade600),
                const SizedBox(height: 12),
                Text(_carName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('预估续航 ${range}km',
                    style:
                        TextStyle(fontSize: 14, color: Colors.blue.shade600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSliderItem('剩余电量', '${_soc.toInt()}%', _soc, 0, 100,
              (v) => setState(() => _soc = v)),
          _buildSliderItem(
              '电池容量',
              '${_batteryCapacity.toInt()} kWh',
              _batteryCapacity,
              40,
              120,
              (v) => setState(() => _batteryCapacity = v)),
          _buildSliderItem(
              '能耗',
              '${_energyConsumption.toStringAsFixed(1)} kWh/100km',
              _energyConsumption,
              10,
              30,
              (v) => setState(() => _energyConsumption = v)),
          const SizedBox(height: 16),
          _buildCarSelector(),
        ],
      ),
    );
  }

  Widget _buildSliderItem(String label, String value, double val, double min,
      double max, ValueChanged<double> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007AFF))),
            ],
          ),
          Slider(
              value: val.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildCarSelector() {
    final cars = [
      {'name': 'Model Y', 'capacity': 60.0, 'consumption': 14.5},
      {'name': 'Model 3', 'capacity': 55.0, 'consumption': 13.0},
      {'name': 'Model X', 'capacity': 75.0, 'consumption': 17.0},
      {'name': '汉EV', 'capacity': 77.0, 'consumption': 15.0},
      {'name': '小鹏P7', 'capacity': 70.0, 'consumption': 14.5},
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('快速选择车型',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cars.map((car) {
                final isSelected = _carName == car['name'];
                return GestureDetector(
                  onTap: () => setState(() {
                    _carName = car['name'] as String;
                    _batteryCapacity = car['capacity'] as double;
                    _energyConsumption = car['consumption'] as double;
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF007AFF)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(car['name'] as String,
                        style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 13)),
                  ),
                );
              }).toList()),
        ],
      ),
    );
  }
}

// ============== 设置页面 ==============
class SettingsPage extends StatefulWidget {
  final bool isLoggedIn;
  final VoidCallback? onLogout;

  const SettingsPage({super.key, this.isLoggedIn = false, this.onLogout});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _controller = TextEditingController(text: "https://3aa33e7d.cpolar.io");
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('server_url');
    if (saved != null && saved.isNotEmpty) {
      _controller.text = saved;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后数据将保留在本地，重新登录后可同步到云端。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定退出')),
        ],
      ),
    );
    if (confirmed == true && widget.onLogout != null) {
      widget.onLogout!();
      Navigator.pop(context); // 退出后返回上一页
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('设置',
            style:
                TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.link, color: Color(0xFF007AFF), size: 22),
                    SizedBox(width: 8),
                    Text('服务器地址',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '例如: https://xxx.cpolar.io',
                    filled: true,
                    fillColor: const Color(0xFFF7F9FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('修改后需重启 App 才能生效',
                            style:
                                TextStyle(fontSize: 13, color: Colors.black54)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final url = _controller.text.trim();
                      if (url.isNotEmpty) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('server_url', url);
                        setState(() => _saved = true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(_saved ? '已保存，请重启 App' : '保存'),
                  ),
                ),
              ],
            ),
          ),
          // 退出登录（仅登录用户可见）
          if (widget.isLoggedIn) ...[
            const SizedBox(height: 20),
            _buildListTile(Icons.logout, '退出登录', Colors.red, onTap: _logout),
          ],
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, Color color,
      {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: TextStyle(fontSize: 15, color: color)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: onTap ?? () {},
      ),
    );
  }
}

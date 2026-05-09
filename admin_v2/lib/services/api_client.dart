import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── API Client ──────────────────────────────────────────
class ApiClient {
  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessKey);
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
    _initialized = true;
  }

  void _setToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    _initialized = false;
  }

  // ── Auth ───────────────────────────────────────────────
  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final resp = await dio.post('/auth/login', data: {
        'username': username, 'password': password,
      });
      if (resp.statusCode == 200 && resp.data['access_token'] != null) {
        await saveTokens(resp.data['access_token'], resp.data['refresh_token']);
        _setToken(resp.data['access_token']);
        return await getProfile();
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final resp = await dio.get('/users/me');
      return resp.data;
    } catch (_) { return null; }
  }

  // ── Stats ──────────────────────────────────────────────
  Future<Map<String, dynamic>?> getStats() async {
    try {
      final resp = await dio.get('/admin/stats');
      return resp.data;
    } catch (_) { return null; }
  }

  Future<Map<String, dynamic>?> getOverviewStats() async {
    try {
      final resp = await dio.get('/admin/stats/overview');
      return resp.data;
    } catch (_) { return null; }
  }

  Future<Map<String, dynamic>?> getDailyUsers({int days = 30}) async {
    try {
      final resp = await dio.get('/admin/stats/daily-users', queryParameters: {'days': days});
      return resp.data;
    } catch (_) { return null; }
  }

  Future<Map<String, dynamic>?> getChargingByHour() async {
    try {
      final resp = await dio.get('/admin/stats/charging-by-hour');
      return resp.data;
    } catch (_) { return null; }
  }

  Future<Map<String, dynamic>?> getTopStations({int limit = 10}) async {
    try {
      final resp = await dio.get('/admin/stats/top-stations', queryParameters: {'limit': limit});
      return resp.data;
    } catch (_) { return null; }
  }

  Future<Map<String, dynamic>?> getVehicleBrands() async {
    try {
      final resp = await dio.get('/admin/stats/vehicle-brands');
      return resp.data;
    } catch (_) { return null; }
  }

  // ── Users ──────────────────────────────────────────────
  Future<List<dynamic>?> getUsers({String username = '', String phone = '', int offset = 0, int limit = 20}) async {
    try {
      final resp = await dio.get('/users', queryParameters: {
        'username': username, 'phone': phone, 'offset': offset, 'limit': limit,
      });
      return resp.data['users'];
    } catch (_) { return null; }
  }

  Future<int> getTotalUsers({String username = '', String phone = ''}) async {
    try {
      final resp = await dio.get('/users', queryParameters: {'username': username, 'phone': phone, 'limit': 1});
      return resp.data['total'] ?? 0;
    } catch (_) { return 0; }
  }

  Future<bool> deleteUser(int userId) async {
    try {
      await dio.delete('/users/$userId');
      return true;
    } catch (_) { return false; }
  }

  // ── User Detail ───────────────────────────────────────
  Future<List<dynamic>?> getUserVehicles(int userId) async {
    try {
      final resp = await dio.get('/users/$userId/vehicles');
      return resp.data is List ? resp.data : null;
    } catch (_) { return null; }
  }

  Future<List<dynamic>?> getUserHistory(int userId, {int limit = 5}) async {
    try {
      final resp = await dio.get('/history', queryParameters: {'user_id': userId, 'limit': limit});
      return resp.data is List ? resp.data : null;
    } catch (_) { return null; }
  }

  // ── Announcements ───────────────────────────────────────
  Future<Map<String, dynamic>?> getAnnouncements({int offset = 0, int limit = 20}) async {
    try {
      final resp = await dio.get('/admin/announcements', queryParameters: {'offset': offset, 'limit': limit});
      return resp.data;
    } catch (_) { return null; }
  }

  Future<bool> createAnnouncement(Map<String, dynamic> data) async {
    try {
      await dio.post('/admin/announcements', data: data);
      return true;
    } catch (_) { return false; }
  }

  Future<bool> updateAnnouncement(int id, Map<String, dynamic> data) async {
    try {
      await dio.put('/admin/announcements/$id', data: data);
      return true;
    } catch (_) { return false; }
  }

  Future<bool> deleteAnnouncement(int id) async {
    try {
      await dio.delete('/admin/announcements/$id');
      return true;
    } catch (_) { return false; }
  }

  // ── Admin Users ──────────────────────────────────────────
  Future<Map<String, dynamic>?> getAdminUsers() async {
    try {
      final resp = await dio.get('/admin/users');
      return resp.data;
    } catch (_) { return null; }
  }

  Future<bool> createAdminUser(Map<String, dynamic> data) async {
    try {
      await dio.post('/admin/users', data: data);
      return true;
    } catch (_) { return false; }
  }

  Future<bool> updateAdminPassword(int userId, String newPassword) async {
    try {
      await dio.put('/admin/users/$userId/password', data: {'new_password': newPassword});
      return true;
    } catch (_) { return false; }
  }

  Future<bool> deleteAdminUser(int userId) async {
    try {
      await dio.delete('/admin/users/$userId');
      return true;
    } catch (_) { return false; }
  }

  // ── Admin Stations ────────────────────────────────────────
  Future<Map<String, dynamic>?> getAdminStations({
    String? district,
    String? type,
    String? keyword,
    String sort = 'name',
    String order = 'asc',
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final params = <String, dynamic>{
        'offset': offset,
        'limit': limit,
        'sort': sort,
        'order': order,
      };
      if (district != null) params['district'] = district;
      if (type != null) params['station_type'] = type;
      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
      final resp = await dio.get('/admin/stations', queryParameters: params);
      return resp.data;
    } catch (_) { return null; }
  }
}

// ── Singleton ───────────────────────────────────────────
final client = ApiClient();

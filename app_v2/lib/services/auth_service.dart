import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'data_repository.dart';

/// 认证服务：负责登录/注册/登出 + 登录时本地数据同步到云端
class AuthService {
  final ApiClient _client = ApiClient();

  static const String _uidKey = 'user_id';
  static const String _nicknameKey = 'nickname';
  static const String _usernameKey = 'username';

  /// 注册：成功后自动登录并合并本地数据到云端
  Future<Map<String, dynamic>?> register({
    required String username,
    required String password,
    String nickname = '',
    String phone = '',
  }) async {
    final resp = await _client.post('/api/auth/register', data: {
      'username': username,
      'password': password,
      if (nickname.isNotEmpty) 'nickname': nickname,
      if (phone.isNotEmpty) 'phone': phone,
    });

    final d = resp.data;
    if (resp.statusCode == 200 && d['access_token'] != null) {
      await _client.saveTokens(d['access_token'], d['refresh_token']);
      final profile = await _fetchAndSaveProfile();
      // 注册成功后，将本地游客数据合并到云端
      await DataRepository().onLogin();
      return profile;
    }
    return null;
  }

  /// 登录：成功后合并本地数据到云端
  Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    final resp = await _client.post('/api/auth/login', data: {
      'username': username,
      'password': password,
    });

    final d = resp.data;
    if (resp.statusCode == 200 && d['access_token'] != null) {
      await _client.saveTokens(d['access_token'], d['refresh_token']);
      final profile = await _fetchAndSaveProfile();
      // 登录成功后，将本地游客数据合并到云端
      await DataRepository().onLogin();
      return profile;
    }
    return null;
  }

  /// 登出：先上传车型到后端，再清除本地 token
  Future<void> logout() async {
    // 1. 上传当前车型（需要 token 权限）
    await DataRepository().onLogout();
    // 2. 清除 token 和本地用户缓存
    await _client.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uidKey);
    await prefs.remove(_nicknameKey);
    await prefs.remove(_usernameKey);
  }

  /// 获取当前用户信息
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final resp = await _client.get('/api/users/me');
    if (resp.statusCode == 200) {
      final d = resp.data;
      await _saveProfile(d);
      return d;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchAndSaveProfile() async {
    try {
      return await getCurrentUser();
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveProfile(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_uidKey, data['id'] ?? 0);
    await prefs.setString(_nicknameKey, data['nickname'] ?? '');
    await prefs.setString(_usernameKey, data['username'] ?? '');
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_uidKey);
  }

  Future<bool> isLoggedIn() async {
    return await _client.hasValidToken();
  }
}

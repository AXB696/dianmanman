import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  static const String _uidKey = 'user_id';
  static const String _nicknameKey = 'nickname';
  static const String _usernameKey = 'username';

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
      // Fetch user profile
      return await _fetchAndSaveProfile();
    }
    return null;
  }

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
      return await _fetchAndSaveProfile();
    }
    return null;
  }

  Future<void> logout() async {
    await _client.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uidKey);
    await prefs.remove(_nicknameKey);
    await prefs.remove(_usernameKey);
  }

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

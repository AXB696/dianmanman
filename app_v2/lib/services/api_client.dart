import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';
  static const String _serverUrlKey = 'server_url';

  late final Dio _dio;
  String _baseUrl = '';
  bool _isRefreshing = false;
  final List<_QueuedRequest> _pending = [];

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
    ));
    _dio.interceptors.add(_AuthInterceptor(this));
  }

  String get baseUrl => _baseUrl;

  Future<void> init(String url) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _dio.options.baseUrl = _baseUrl;
  }

  Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
    await init(url);
  }

  Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
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

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── HTTP Methods ──────────────────────────────────

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  // ── Announcements ─────────────────────────────────
  Future<Response> getLatestAnnouncements() {
    return get('/announcements/latest');
  }

  // ── Internal: Token Refresh ───────────────────────

  Future<void> _doRefresh() async {
    final refresh = await getRefreshToken();
    if (refresh == null) throw Exception("No refresh token");

    final resp = await Dio().post(
      '$_baseUrl/api/auth/refresh',
      data: {'refresh_token': refresh},
    );
    final d = resp.data;
    if (resp.statusCode == 200 && d['access_token'] != null) {
      await saveTokens(d['access_token'], d['refresh_token']);
    } else {
      await clearTokens();
      throw Exception("Refresh failed");
    }
  }

  void _flushPending(bool success) {
    for (final req in _pending) {
      if (success) {
        req.completer.complete(req.future);
      } else {
        req.completer.completeError(Exception("Token refresh failed"));
      }
    }
    _pending.clear();
  }

  Future<Response> _retry(String path, String method, {dynamic data}) async {
    final token = await getAccessToken();
    final opts = Options(headers: {'Authorization': 'Bearer $token'});
    switch (method) {
      case 'GET': return _dio.get(path, options: opts);
      case 'POST': return _dio.post(path, data: data, options: opts);
      case 'PUT': return _dio.put(path, data: data, options: opts);
      case 'DELETE': return _dio.delete(path, options: opts);
      default: return _dio.request(path, options: opts, data: data);
    }
  }
}

// ── Queued request wrapper ─────────────────────────────

class _QueuedRequest {
  final String path;
  final String method;
  final dynamic data;
  final Completer<Response> completer;

  _QueuedRequest(this.path, this.method, this.data) : completer = Completer<Response>();

  Future<Response> get future => completer.future;
}

// ── Auth Interceptor ──────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final ApiClient client;

  _AuthInterceptor(this.client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    // Public endpoints: skip auth
    if (path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh')) {
      return handler.next(options);
    }

    // Inject token synchronously is tricky with async; we use a trick:
    // We resolve it before proceeding. Since getAccessToken is async,
    // we attach to the request as a future that will be resolved.
    client.getAccessToken().then((token) {
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    }).catchError((e) {
      handler.next(options);
    });
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) return handler.next(err);

    if (client._isRefreshing) {
      // Queue this request
      final req = _QueuedRequest(
        err.requestOptions.path,
        err.requestOptions.method,
        err.requestOptions.data,
      );
      client._pending.add(req);
      req.future.then((r) => handler.resolve(r)).catchError((e) => handler.next(err));
      return;
    }

    client._isRefreshing = true;
    try {
      await client._doRefresh();
      client._isRefreshing = false;
      client._flushPending(true);

      final token = await client.getAccessToken();
      err.requestOptions.headers['Authorization'] = 'Bearer $token';
      final resp = await client._retry(
        err.requestOptions.path,
        err.requestOptions.method,
        data: err.requestOptions.data,
      );
      return handler.resolve(resp);
    } catch (e) {
      client._isRefreshing = false;
      client._flushPending(false);
      await client.clearTokens();
      return handler.next(err);
    }
  }
}

import 'package:flutter/material.dart';
import 'services/api_client.dart';
import 'pages/dashboard_page.dart';
import 'pages/users_page.dart';
import 'pages/admins_page.dart';
import 'pages/announcements_page.dart';
import 'pages/stations_page.dart';

void main() {
  runApp(const SmartChargeAdminApp());
}

class SmartChargeAdminApp extends StatelessWidget {
  const SmartChargeAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '电满满 管理系统',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF007AFF),
        colorScheme: const ColorScheme.light(primary: Color(0xFF007AFF)),
        fontFamily: 'Noto Sans SC',
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const AuthGate(),
        '/dashboard': (ctx) => const AuthGate(),
        '/users': (ctx) => const AuthGate(),
      },
    );
  }
}

// ── Auth Gate ──────────────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _loggedIn = false;
  Map<String, dynamic>? _adminUser;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await client.init();
    final token = await client.getAccessToken();
    if (token != null) {
      final user = await client.getProfile();
      if (user != null && (user['role'] == 'admin' || user['role'] == 'super_admin')) {
        _loggedIn = true;
        _adminUser = user;
      }
    }
    // token 刷新失败时强制退回登录页
    client.onForceLogout = () {
      if (mounted) setState(() { _loggedIn = false; _adminUser = null; });
    };
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_loggedIn) return AdminLoginPage(onLogin: (user) {
      setState(() { _loggedIn = true; _adminUser = user; });
      client.onForceLogout = () {
        if (mounted) setState(() { _loggedIn = false; _adminUser = null; });
      };
    });
    return AdminScaffold(user: _adminUser!, onLogout: () async {
      await client.clearTokens();
      setState(() { _loggedIn = false; _adminUser = null; });
    });
  }
}

// ── Admin Scaffold with Sidebar ──────────────────────────
class AdminScaffold extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  const AdminScaffold({super.key, required this.user, required this.onLogout});

  @override
  State<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<AdminScaffold> {
  int _selectedIndex = 0;

  late final bool _isSuper;

  @override
  void initState() {
    super.initState();
    _isSuper = widget.user['role'] == 'super_admin';
  }

  final List<_NavDef> _navs = [];

  void _buildNavs() {
    _navs.clear();
    _navs.addAll([
      _NavDef('Dashboard', Icons.dashboard, 0),
      _NavDef('用户管理', Icons.people, 1),
    ]);
    if (_isSuper) {
      _navs.addAll([
        _NavDef('管理员账号', Icons.admin_panel_settings, 2),
        _NavDef('站内公告', Icons.campaign, 3),
      ]);
    }
    _navs.add(_NavDef('电站总览', Icons.ev_station, _isSuper ? 4 : 2));
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return DashboardPage(user: widget.user, onLogout: widget.onLogout);
      case 1:
        return UsersPage(adminUser: widget.user, onLogout: widget.onLogout);
      case 2:
        return _isSuper
            ? AdminsPage(adminUser: widget.user, onLogout: widget.onLogout)
            : StationsPage(adminUser: widget.user, onLogout: widget.onLogout);
      case 3:
        return AnnouncementsPage(adminUser: widget.user, onLogout: widget.onLogout);
      case 4:
        return StationsPage(adminUser: widget.user, onLogout: widget.onLogout);
      default:
        return DashboardPage(user: widget.user, onLogout: widget.onLogout);
    }
  }

  @override
  Widget build(BuildContext context) {
    _buildNavs();
    return Scaffold(
      body: Row(
        children: [
          // 侧边栏
          Container(
            width: 220,
            color: const Color(0xFF1A1A2E),
            child: Column(
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.ev_station, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '电满满',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                // Nav items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _navs.length,
                    itemBuilder: (ctx, i) {
                      final nav = _navs[i];
                      final active = _selectedIndex == nav.index;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF007AFF).withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            nav.icon,
                            color: active ? const Color(0xFF007AFF) : Colors.white60,
                            size: 20,
                          ),
                          title: Text(
                            nav.label,
                            style: TextStyle(
                              color: active ? Colors.white : Colors.white70,
                              fontSize: 14,
                              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          onTap: () => setState(() => _selectedIndex = nav.index),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    },
                  ),
                ),
                // User info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white12)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF007AFF),
                        child: Text(
                          (widget.user['nickname'] ?? widget.user['username'] ?? 'A')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user['username'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _isSuper ? '超级管理员' : '管理员',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white54, size: 18),
                        onPressed: () async {
                          await client.clearTokens();
                          widget.onLogout();
                        },
                        tooltip: '退出',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 内容区
          Expanded(
            child: _buildPage(_selectedIndex),
          ),
        ],
      ),
    );
  }
}

class _NavDef {
  final String label;
  final IconData icon;
  final int index;
  _NavDef(this.label, this.icon, this.index);
}

// ── Admin Login ─────────────────────────────────────────
class AdminLoginPage extends StatefulWidget {
  final void Function(Map<String, dynamic>) onLogin;
  const AdminLoginPage({super.key, required this.onLogin});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _uCtrl = TextEditingController();
  final _pCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final user = await client.login(_uCtrl.text, _pCtrl.text);
    if (!mounted) return;
    if (user != null && (user['role'] == 'admin' || user['role'] == 'super_admin')) {
      widget.onLogin(user);
    } else {
      setState(() { _loading = false; _error = '需要管理员权限，请使用 admin 账号登录'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              const Text('管理系统', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('电满满 充电桩管理平台', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              TextField(
                controller: _uCtrl,
                decoration: InputDecoration(
                  labelText: '管理员账号', prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '密码', prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(width:24, height:24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

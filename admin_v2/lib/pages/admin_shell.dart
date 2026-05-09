import 'package:flutter/material.dart';
import '../services/api_client.dart';

/// 侧边栏导航项
class NavItem {
  final String label;
  final IconData icon;
  final String route;
  final bool superAdminOnly;

  const NavItem(this.label, this.icon, this.route, {this.superAdminOnly = false});
}

/// 管理员后台外壳：侧边栏 + 内容区
class AdminShell extends StatefulWidget {
  final String initialRoute;
  final Map<String, dynamic> adminUser;
  final VoidCallback onLogout;

  const AdminShell({
    super.key,
    required this.initialRoute,
    required this.adminUser,
    required this.onLogout,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late String _currentRoute;
  late List<NavItem> _navItems;

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.initialRoute;
    _initNav();
  }

  void _initNav() {
    final isSuper = widget.adminUser['role'] == 'super_admin';
    _navItems = [
      const NavItem('Dashboard', Icons.dashboard, '/dashboard'),
      const NavItem('用户管理', Icons.people, '/users'),
      if (isSuper) const NavItem('管理员账号', Icons.admin_panel_settings, '/admins'),
      if (isSuper) const NavItem('站内公告', Icons.campaign, '/announcements'),
      const NavItem('电站总览', Icons.ev_station, '/stations'),
    ];
  }

  void _navigate(String route) {
    if (route == '/dashboard') {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    itemCount: _navItems.length,
                    itemBuilder: (ctx, i) {
                      final item = _navItems[i];
                      final active = _currentRoute == item.route;
                      return _NavTile(
                        icon: item.icon,
                        label: item.label,
                        active: active,
                        onTap: () => setState(() => _currentRoute = item.route),
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
                          (widget.adminUser['nickname'] ?? widget.adminUser['username'] ?? 'A')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.adminUser['username'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.adminUser['role'] == 'super_admin' ? '超级管理员' : '管理员',
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
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Placeholder - actual content is handled by page routes
    return const SizedBox.shrink();
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF007AFF).withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: active ? const Color(0xFF007AFF) : Colors.white60, size: 20),
        title: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

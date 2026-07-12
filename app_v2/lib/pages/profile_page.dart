import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfilePage({super.key, required this.onLogout});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _user;
  List<dynamic> _vehicles = [];
  List<dynamic> _favorites = [];
  bool _loading = true;

  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = await _auth.getCurrentUser();
      final client = ApiClient();
      final vehiclesResp = await client.get('/api/users/me/vehicles');
      final favoritesResp = await client.get('/api/favorites');
      if (mounted) {
        setState(() {
          _user = user;
          _vehicles = vehiclesResp.data is List ? vehiclesResp.data : [];
          _favorites = favoritesResp.data is List ? favoritesResp.data : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (confirmed == true) {
      await _auth.logout();
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('个人中心'),
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 用户信息卡片
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFF007AFF),
                          child: Text(
                            (_user?['nickname'] ?? _user?['username'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user?['nickname'] ?? _user?['username'] ?? '未登录',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _user?['phone'] != null && _user!['phone'].isNotEmpty
                                    ? _user!['phone']
                                    : '@${_user?['username']}',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _user?['role'] == 'admin' ? Colors.orange.shade50 : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _user?['role'] == 'admin' ? '管理员' : '普通用户',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _user?['role'] == 'admin' ? Colors.orange.shade700 : Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.red),
                          onPressed: _logout,
                          tooltip: '退出登录',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 车辆管理
                  _sectionTitle('🚗 我的车辆'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _vehicles.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text('暂无车辆，点击添加', style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _vehicles.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final v = _vehicles[i];
                              return ListTile(
                                leading: Icon(
                                  Icons.directions_car,
                                  color: v['is_default'] == true ? const Color(0xFF007AFF) : Colors.grey,
                                ),
                                title: Text('${v['brand']} ${v['model']}'),
                                subtitle: Text(
                                  '电池 ${v['battery_capacity']}kWh · 能耗 ${v['energy_consumption']}kWh/100km',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: v['is_default'] == true
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF007AFF).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text('默认', style: TextStyle(fontSize: 11, color: Color(0xFF007AFF))),
                                      )
                                    : null,
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 20),

                  // 收藏站点
                  _sectionTitle('⭐ 收藏站点 (${_favorites.length})'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _favorites.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text('暂无收藏', style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _favorites.length,
                            itemBuilder: (ctx, i) {
                              final f = _favorites[i];
                              return ListTile(
                                leading: const Icon(Icons.ev_station, color: Color(0xFF007AFF)),
                                title: Text('站点: ${f['station_id']}'),
                                subtitle: Text(
                                  '收藏于 ${f['created_at'] != null ? f['created_at'].toString().substring(0, 10) : ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
    );
  }
}

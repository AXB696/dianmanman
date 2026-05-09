import 'package:flutter/material.dart';
import '../services/api_client.dart';

class UsersPage extends StatefulWidget {
  final Map<String, dynamic> adminUser;
  final VoidCallback onLogout;
  const UsersPage({super.key, required this.adminUser, required this.onLogout});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<dynamic> _users = [];
  int _totalUsers = 0;
  bool _loading = true;
  String _searchUsername = '';
  String _searchPhone = '';
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // 展开的用户ID
  int? _expandedUserId;
  List<dynamic>? _expandedVehicles;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final users = await client.getUsers(
      username: _searchUsername,
      phone: _searchPhone,
    );
    final total = await client.getTotalUsers(
      username: _searchUsername,
      phone: _searchPhone,
    );
    if (mounted) {
      setState(() {
        _users = users ?? [];
        _totalUsers = total;
        _loading = false;
        _expandedUserId = null;
        _expandedVehicles = null;
      });
    }
  }

  Future<void> _toggleExpand(int userId) async {
    if (_expandedUserId == userId) {
      setState(() { _expandedUserId = null; _expandedVehicles = null; });
      return;
    }
    setState(() => _expandedUserId = userId);
    final vehicles = await client.getUserVehicles(userId);
    if (mounted) {
      setState(() {
        _expandedUserId = userId;
        _expandedVehicles = vehicles;
      });
    }
  }

  Future<void> _deleteUser(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除用户 ID=$id 吗？该操作不可恢复！'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await client.deleteUser(id);
      _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('用户管理'),
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              (widget.adminUser['nickname'] ?? widget.adminUser['username'] ?? 'A')[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text(widget.adminUser['username'] ?? 'admin', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: widget.onLogout,
            tooltip: '退出',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜索栏
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _usernameCtrl,
                            decoration: InputDecoration(
                              hintText: '搜索用户名...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _phoneCtrl,
                            decoration: InputDecoration(
                              hintText: '搜索手机号...',
                              prefixIcon: const Icon(Icons.phone, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(60, 38),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          _searchUsername = _usernameCtrl.text;
                          _searchPhone = _phoneCtrl.text;
                          _loadUsers();
                        },
                        child: const Text('搜索'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadUsers,
                        tooltip: '刷新',
                      ),
                    ],
                  ),
                ),
                // Table
                Expanded(
                  child: _users.isEmpty
                      ? const Center(child: Text('暂无用户'))
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildUserTable(),
                                const SizedBox(height: 8),
                                Text(
                                  '共 $_totalUsers 位用户',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildUserTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                _th('ID', width: 50),
                _th('用户名', flex: 2),
                _th('昵称', flex: 2),
                _th('手机号', flex: 2),
                _th('角色', flex: 2),
                _th('注册时间', flex: 2),
                _th('车辆数', width: 70),
                _th('操作', width: 80),
              ],
            ),
          ),
          // Rows
          ..._users.map((u) => _buildUserRow(u)),
        ],
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> u) {
    final isExpanded = _expandedUserId == u['id'];
    final vehicleCount = _expandedVehicles?.length ?? '...';

    return Column(
      children: [
        InkWell(
          onTap: () => _toggleExpand(u['id']),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
              color: isExpanded ? const Color(0xFFF0F7FF) : Colors.white,
            ),
            child: Row(
              children: [
                _td('${u['id']}', width: 50),
                _td(u['username'] ?? '', flex: 2, bold: true),
                _td(u['nickname'] ?? '-', flex: 2),
                _td(u['phone'] ?? '-', flex: 2),
                _td(_roleLabel(u['role'] ?? 'user'), flex: 2,
                    color: _roleColor(u['role'] ?? 'user')),
                _td(
                  u['created_at'] != null
                      ? u['created_at'].toString().substring(0, 10)
                      : '-',
                  flex: 2,
                  fontSize: 12,
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    u['id'] == _expandedUserId ? '$vehicleCount' : '-',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: vehicleCount != '-' ? const Color(0xFF007AFF) : Colors.grey,
                      fontWeight: vehicleCount != '-' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey,
                        size: 20,
                      ),
                      if (u['role'] != 'admin' && u['role'] != 'super_admin')
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          onPressed: () => _deleteUser(u['id']),
                          tooltip: '删除',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // 展开详情
        if (isExpanded) _buildUserDetail(u),
      ],
    );
  }

  Widget _buildUserDetail(Map<String, dynamic> u) {
    final vehicles = _expandedVehicles ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF8FAFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '👤 ${u['username']} 的详情信息',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 基本信息
              Expanded(
                child: _infoCard([
                  _infoRow('ID', '${u['id']}'),
                  _infoRow('用户名', u['username'] ?? '-'),
                  _infoRow('昵称', u['nickname'] ?? '-'),
                  _infoRow('手机号', u['phone'] ?? '-'),
                  _infoRow('角色', _roleLabel(u['role'] ?? 'user')),
                  _infoRow(
                    '注册时间',
                    u['created_at'] != null ? u['created_at'].toString().substring(0, 19) : '-',
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              // 车辆信息
              Expanded(
                child: _infoCard([
                  const Text('🚗 车辆列表', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (vehicles.isEmpty)
                    const Text('- 暂无车辆', style: TextStyle(color: Colors.grey, fontSize: 12))
                  else
                    ...vehicles.map((v) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                v['is_default'] == true ? Icons.directions_car : Icons.directions_car_outlined,
                                size: 14,
                                color: v['is_default'] == true ? const Color(0xFF007AFF) : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${v['brand']} ${v['model']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: v['is_default'] == true ? Colors.black87 : Colors.grey,
                                  ),
                                ),
                              ),
                              if (v['is_default'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF007AFF).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('默认', style: TextStyle(fontSize: 10, color: Color(0xFF007AFF))),
                                ),
                            ],
                          ),
                        )),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text('$label：', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    if (role == 'super_admin') return '👑 超级管理员';
    if (role == 'admin') return '👑 管理员';
    return '👤 用户';
  }

  Color _roleColor(String role) {
    if (role == 'super_admin') return Colors.red;
    if (role == 'admin') return Colors.orange;
    return Colors.blue;
  }
}

class _th extends StatelessWidget {
  final String text;
  final double? width;
  final int? flex;
  const _th(this.text, {this.width, this.flex});
  @override
  Widget build(BuildContext ctx) {
    final style = const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E));
    if (width != null) return SizedBox(width: width, child: Text(text, style: style));
    return Expanded(flex: flex ?? 1, child: Text(text, style: style));
  }
}

class _td extends StatelessWidget {
  final String text;
  final double? width;
  final int? flex;
  final Color? color;
  final double fontSize;
  final bool bold;
  const _td(this.text, {this.width, this.flex, this.color, this.fontSize = 13, this.bold = false});
  @override
  Widget build(BuildContext ctx) {
    final style = TextStyle(
      fontSize: fontSize,
      color: color ?? Colors.black87,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    if (width != null) return SizedBox(width: width, child: Text(text, style: style));
    return Expanded(flex: flex ?? 1, child: Text(text, style: style));
  }
}

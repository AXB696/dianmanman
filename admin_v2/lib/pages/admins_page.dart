import 'package:flutter/material.dart';
import '../services/api_client.dart';

class AdminsPage extends StatefulWidget {
  final Map<String, dynamic> adminUser;
  final VoidCallback onLogout;
  const AdminsPage({super.key, required this.adminUser, required this.onLogout});

  @override
  State<AdminsPage> createState() => _AdminsPageState();
}

class _AdminsPageState extends State<AdminsPage> {
  List<dynamic> _admins = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() { _loading = true; _error = null; });
    final data = await client.getAdminUsers();
    if (mounted) {
      setState(() {
        _admins = (data?['users'] as List<dynamic>?) ?? [];
        _loading = false;
      });
    }
  }

  Future<void> _deleteAdmin(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除该管理员账号吗？'),
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
      final ok = await client.deleteAdminUser(id);
      if (ok) {
        _loadAdmins();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败')),
          );
        }
      }
    }
  }

  void _showAddDialog() {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nicknameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String role = 'admin';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新增管理员'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: '用户名（登录账号）', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '初始密码', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nicknameCtrl,
                  decoration: const InputDecoration(labelText: '昵称（选填）', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: '手机号（选填）', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                const Text('角色', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Radio<String>(
                      value: 'admin',
                      groupValue: role,
                      onChanged: (v) => setDialogState(() => role = v!),
                    ),
                    const Text('管理员'),
                    const SizedBox(width: 20),
                    Radio<String>(
                      value: 'super_admin',
                      groupValue: role,
                      onChanged: (v) => setDialogState(() => role = v!),
                    ),
                    const Text('超级管理员'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (usernameCtrl.text.trim().isEmpty || passwordCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('用户名和密码不能为空')),
                  );
                  return;
                }
                final ok = await client.createAdminUser({
                  'username': usernameCtrl.text.trim(),
                  'password': passwordCtrl.text.trim(),
                  'nickname': nicknameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'role': role,
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  if (ok) {
                    _loadAdmins();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('创建失败，用户名可能已存在')),
                    );
                  }
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordDialog(int userId, String username) {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改 $username 的密码'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密码', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认密码', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (passwordCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('密码不能为空')),
                );
                return;
              }
              if (passwordCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('两次密码输入不一致')),
                );
                return;
              }
              final ok = await client.updateAdminPassword(userId, passwordCtrl.text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '密码修改成功' : '修改失败')),
                );
              }
            },
            child: const Text('确认修改'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('管理员账号'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('新增管理员'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _admins.isEmpty
              ? const Center(child: Text('暂无管理员', style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)],
                        ),
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FA)),
                            columns: const [
                              DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('用户名', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('昵称', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('手机号', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('角色', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('创建时间', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _admins.map((u) => DataRow(cells: [
                              DataCell(Text('${u['id']}')),
                              DataCell(Text(u['username'] ?? '')),
                              DataCell(Text(u['nickname'] ?? '-')),
                              DataCell(Text(u['phone'] ?? '-')),
                              DataCell(Text(
                                _roleLabel(u['role'] ?? 'admin'),
                                style: TextStyle(
                                  color: u['role'] == 'super_admin' ? Colors.red : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                              DataCell(Text(
                                u['created_at'] != null ? u['created_at'].toString().substring(0, 10) : '-',
                                style: const TextStyle(fontSize: 12),
                              )),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.key, size: 18, color: Color(0xFF007AFF)),
                                    onPressed: () => _showPasswordDialog(u['id'], u['username'] ?? ''),
                                    tooltip: '修改密码',
                                  ),
                                  if (u['id'] != widget.adminUser['id'])
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      onPressed: u['role'] == 'super_admin' ? null : () => _deleteAdmin(u['id']),
                                      tooltip: '删除',
                                    ),
                                ],
                              )),
                            ])).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '共 ${_admins.length} 位管理员',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '超级管理员不可删除；不可删除自己。',
                                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _roleLabel(String role) {
    if (role == 'super_admin') return '👑 超级管理员';
    return '👑 管理员';
  }
}

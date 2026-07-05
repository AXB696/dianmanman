import 'package:flutter/material.dart';
import '../services/api_client.dart';

class AnnouncementsPage extends StatefulWidget {
  final Map<String, dynamic> adminUser;
  final VoidCallback onLogout;
  const AnnouncementsPage({super.key, required this.adminUser, required this.onLogout});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  List<dynamic> _announcements = [];
  int _total = 0;
  bool _loading = true;
  int _page = 0;
  static const int _pageSize = 20;
  String? _displayDate; // 弹窗截止时间

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _loading = true);
    final data = await client.getAnnouncements(offset: _page * _pageSize, limit: _pageSize);
    if (mounted) {
      setState(() {
        _announcements = (data?['announcements'] as List?) ?? [];
        _total = data?['total'] ?? 0;
        _loading = false;
      });
    }
  }

  Future<void> _deleteAnnouncement(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条公告吗？'),
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
      try {
        await client.deleteAnnouncement(id);
        _loadAnnouncements();
      } catch (_) {}
    }
  }

  void _showAddDialog() {
    _showFormDialog(null);
  }

  void _showEditDialog(Map<String, dynamic> ann) {
    _showFormDialog(ann);
  }

  void _showFormDialog(Map<String, dynamic>? ann) {
    final isEdit = ann != null;
    final titleCtrl = TextEditingController(text: ann?['title'] ?? '');
    final contentCtrl = TextEditingController(text: ann?['content'] ?? '');
    String status = ann?['status'] ?? 'draft';
    _displayDate = ann?['display_until'] as String?;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? '编辑公告' : '新增公告'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: '标题（必填，最多50字）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: '内容（必填，最多500字）',
                    border: OutlineInputBorder(),
                  ),
                ),
                // 弹窗截止日期
                const SizedBox(height: 12),
                const Text('弹窗截止日期（留空不弹窗）',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _displayDate ?? '选择截止日期',
                    style: TextStyle(
                        color: _displayDate != null
                            ? Colors.black87
                            : Colors.grey),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: const TimeOfDay(hour: 23, minute: 59),
                      );
                      if (time != null) {
                        final dt = DateTime(picked.year, picked.month,
                            picked.day, time.hour, time.minute);
                        _displayDate = dt.toIso8601String();
                        setDialogState(() {});
                      }
                    }
                  },
                ),
                if (_displayDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('截止：$_displayDate',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ),
                const SizedBox(height: 12),
                const Text('状态',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Radio<String>(
                      value: 'draft',
                      groupValue: status,
                      onChanged: (v) =>
                          setDialogState(() => status = v!),
                    ),
                    const Text('草稿'),
                    const SizedBox(width: 20),
                    Radio<String>(
                      value: 'published',
                      groupValue: status,
                      onChanged: (v) =>
                          setDialogState(() => status = v!),
                    ),
                    const Text('已发布'),
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
                if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('标题和内容不能为空')),
                  );
                  return;
                }
                try {
                  if (isEdit) {
                    await client.updateAnnouncement(ann['id'], {
                      'title': titleCtrl.text.trim(),
                      'content': contentCtrl.text.trim(),
                      'status': status,
                      if (_displayDate != null)
                        'display_until': _displayDate,
                    });
                  } else {
                    await client.createAnnouncement({
                      'title': titleCtrl.text.trim(),
                      'content': contentCtrl.text.trim(),
                      'status': status,
                      if (_displayDate != null)
                        'display_until': _displayDate,
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAnnouncements();
                } catch (_) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('操作失败')),
                    );
                  }
                }
              },
              child: Text(isEdit ? '保存' : '创建'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('站内公告'),
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
        icon: const Icon(Icons.add),
        label: const Text('新增公告'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? const Center(child: Text('暂无公告', style: TextStyle(color: Colors.grey)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _announcements.length,
                        itemBuilder: (ctx, i) => _buildAnnouncementCard(_announcements[i]),
                      ),
                    ),
                    // 分页
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _page > 0
                                ? () { _page--; _loadAnnouncements(); }
                                : null,
                          ),
                          Text('第 ${_page + 1} 页，共 ${(_total / _pageSize).ceil()} 页'),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: (_page + 1) * _pageSize < _total
                                ? () { _page++; _loadAnnouncements(); }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> ann) {
    final isPublished = ann['status'] == 'published';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showEditDialog(ann),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPublished ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPublished ? '已发布' : '草稿',
                      style: TextStyle(
                        fontSize: 12,
                        color: isPublished ? Colors.green.shade700 : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ID: ${ann['id']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    ann['created_at']?.toString().substring(0, 19) ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                ann['title'] ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ann['content'] ?? '',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showEditDialog(ann),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('编辑'),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteAnnouncement(ann['id']),
                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                    label: const Text('删除', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

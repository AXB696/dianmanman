import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';

class StationsPage extends StatefulWidget {
  final Map<String, dynamic> adminUser;
  final VoidCallback onLogout;
  const StationsPage({super.key, required this.adminUser, required this.onLogout});

  @override
  State<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends State<StationsPage> {
  List<dynamic> _stations = [];
  int _total = 0;
  bool _loading = true;

  // 统计摘要
  int _ultraCount = 0;
  int _fastCount = 0;
  double _avgRating = 0.0;

  String? _district;
  String? _type;
  String _keyword = '';
  String _sort = 'name';
  String _sortOrder = 'asc';

  int _page = 0;
  static const int _pageSize = 20;

  String _viewMode = 'card'; // 'card' or 'table'
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() => _loading = true);
    final data = await client.getAdminStations(
      district: _district,
      type: _type,
      keyword: _keyword.isEmpty ? null : _keyword,
      sort: _sort,
      order: _sortOrder,
      offset: _page * _pageSize,
      limit: _pageSize,
    );
    if (mounted) {
      final summary = data?['summary'] as Map<String, dynamic>?;
      setState(() {
        _stations = (data?['stations'] as List?) ?? [];
        _total = data?['total'] ?? 0;
        _ultraCount = summary?['ultra_count'] ?? 0;
        _fastCount = summary?['fast_count'] ?? 0;
        _avgRating = (summary?['avg_rating'] ?? 0.0).toDouble();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    _page = 0;
    _loadStations();
  }

  void _toggleSort(String field) {
    if (_sort == field) {
      setState(() => _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc');
    } else {
      setState(() {
        _sort = field;
        _sortOrder = 'desc';
      });
    }
    _applyFilters();
  }

  void _showDetailDialog(Map<String, dynamic> station) {
    final avail = station['availability'] as Map<String, dynamic>? ?? {};
    final availTotal = avail['total'] ?? 0;
    final availAvail = avail['available'] ?? 0;
    final availPct = availTotal > 0 ? (availAvail / availTotal * 100).round() : 0;
    final price = station['price'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(station['name'] ?? '电站详情'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部标签行
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildDetailChip(station['type_name'] ?? _typeShortLabel(station['type'] ?? ''), Colors.blue),
                    if (station['operator'] != null && station['operator'] != '未知运营商')
                      _buildDetailChip(station['operator'] ?? '', Colors.green),
                    if (station['rating'] != null)
                      _buildDetailChip('⭐ ${station['rating']}', Colors.amber),
                  ],
                ),
                const SizedBox(height: 12),
                _detailRow('电站ID', station['station_id'] ?? '-'),
                _detailRow('区域', station['district_group'] ?? '-'),
                _detailRow('地址', station['address'] ?? '-'),
                _detailRow('营业时间', station['open_hours'] ?? '-'),
                const Divider(),
                // 可用桩数
                Row(
                  children: [
                    const Text('可用桩数：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text('$availAvail / $availTotal', style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: availTotal > 0 ? availAvail / availTotal : 0,
                        backgroundColor: Colors.grey.shade200,
                        color: _availColor(availPct),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$availPct%', style: TextStyle(fontSize: 12, color: _availColor(availPct), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                _detailRow('功率', '${station['power_kw'] ?? '-'} kW'),
                _detailRow('桩数', '${station['pile_count'] ?? '-'} 个'),
                const Divider(),
                // 价格
                const Text('充电价格', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                _detailRow('电费', '¥${price['electricity'] ?? '-'} 元/kWh'),
                _detailRow('服务费', '¥${price['service_fee'] ?? '-'} 元/kWh'),
                _detailRow('合计', '¥${price['total'] ?? '-'} 元/kWh', highlight: true),
                _detailRow('停车费', price['parking_fee'] != null && price['parking_fee'] > 0 ? '¥${price['parking_fee']} 元' : '免费'),
                const Divider(),
                // 设施
                if ((station['facilities'] as List?)?.isNotEmpty ?? false) ...[
                  const Text('设施', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: (station['facilities'] as List).take(10).map<Widget>((f) =>
                      Chip(
                        label: Text('$f', style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )
                    ).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                // 联系电话
                if (station['tel'] != null && station['tel'].toString().isNotEmpty) ...[
                  Row(
                    children: [
                      const Text('联系电话：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      Text(station['tel'] ?? '', style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _callPhone(station['tel'] ?? ''),
                        icon: const Icon(Icons.phone, size: 16),
                        label: const Text('拨打'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF007AFF),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  Widget _buildDetailChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _detailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text('$label：', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: highlight ? const Color(0xFF007AFF) : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callPhone(String tel) async {
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Color _availColor(int pct) {
    if (pct >= 50) return Colors.green;
    if (pct >= 25) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('电站数据总览'),
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
      body: Column(
        children: [
          // ── 顶部统计摘要栏 ────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: _loading
                ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
                : Row(
                    children: [
                      _statCard('🏪', '电站总数', '$_total', const Color(0xFF007AFF)),
                      const SizedBox(width: 12),
                      _statCard('⚡', '超充站', '$_ultraCount', Colors.orange),
                      const SizedBox(width: 12),
                      _statCard('🚗', '快充站', '$_fastCount', Colors.green),
                      const SizedBox(width: 12),
                      _statCard('⭐', '平均评分', _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '-', const Color(0xFFFF8F00)),
                    ],
                  ),
          ),
          const Divider(height: 1),
          // ── 筛选栏 ────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 区域
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String?>(
                    value: _district,
                    decoration: const InputDecoration(
                      labelText: '区域',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('全部', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: '汉口', child: Text('汉口', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: '武昌', child: Text('武昌', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: '汉阳', child: Text('汉阳', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) { setState(() => _district = v); _applyFilters(); },
                  ),
                ),
                const SizedBox(width: 10),
                // 类型
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String?>(
                    value: _type,
                    decoration: const InputDecoration(
                      labelText: '类型',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('全部', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'ultra', child: Text('⚡ 超充', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'fast', child: Text('🚗 快充', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'slow', child: Text('🐢 慢充', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'destination', child: Text('🏨 目的地', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'fleet', child: Text('🚚 车队', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'swap', child: Text('🔄 换电', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) { setState(() => _type = v); _applyFilters(); },
                  ),
                ),
                const SizedBox(width: 10),
                // 搜索
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: '搜索电站/地址/运营商',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _keyword = '';
                                _applyFilters();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) { _keyword = _searchCtrl.text; _applyFilters(); },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () { _keyword = _searchCtrl.text; _applyFilters(); },
                  child: const Text('搜索', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 8),
                // 视图切换
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.view_module,
                          size: 20,
                          color: _viewMode == 'card' ? const Color(0xFF007AFF) : Colors.grey,
                        ),
                        onPressed: () => setState(() => _viewMode = 'card'),
                        tooltip: '卡片视图',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.view_list,
                          size: 20,
                          color: _viewMode == 'table' ? const Color(0xFF007AFF) : Colors.grey,
                        ),
                        onPressed: () => setState(() => _viewMode = 'table'),
                        tooltip: '表格视图',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── 内容区 ────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _stations.isEmpty
                    ? const Center(child: Text('暂无电站数据', style: TextStyle(color: Colors.grey)))
                    : _viewMode == 'card'
                        ? _buildCardList()
                        : _buildTableView(),
          ),
          // ── 分页 ─────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _page > 0 ? () { _page--; _loadStations(); } : null,
                ),
                Text(
                  '第 ${_page + 1} / ${(_total / _pageSize).ceil()} 页  共 $_total 条',
                  style: const TextStyle(fontSize: 13),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: (_page + 1) * _pageSize < _total
                      ? () { _page++; _loadStations(); }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 统计卡 ──────────────────────────────────────────────
  Widget _statCard(String emoji, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 卡片列表 ────────────────────────────────────────────
  Widget _buildCardList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _stations.length,
      itemBuilder: (ctx, i) => _buildStationCard(_stations[i]),
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station) {
    final avail = station['availability'] as Map<String, dynamic>? ?? {};
    final availTotal = avail['total'] ?? 0;
    final availAvail = avail['available'] ?? 0;
    final availPct = availTotal > 0 ? (availAvail / availTotal * 100).round() : 0;
    final price = station['price'] as Map<String, dynamic>? ?? {};
    final facilities = (station['facilities'] as List?) ?? [];
    final hasParking = (price['parking_fee'] ?? 0) > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showDetailDialog(station),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：类型图标 + 名称 + 评分 + 运营商
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text(_typeIcon(station['type'] ?? ''), style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station['name'] ?? '-',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          station['address'] ?? '-',
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (station['rating'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⭐ ${station['rating']}',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade800, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // 第二行：标签 + 可用桩数 + 功率
              Row(
                children: [
                  _tag(station['district_group'] ?? '-', Colors.blue),
                  const SizedBox(width: 5),
                  _tag(station['type_name'] ?? _typeShortLabel(station['type'] ?? ''), Colors.orange),
                  if (station['operator'] != null && station['operator'] != '未知运营商') ...[
                    const SizedBox(width: 5),
                    _tag(station['operator'] ?? '', Colors.green),
                  ],
                  const Spacer(),
                  // 可用桩数
                  if (availTotal > 0) ...[
                    Icon(Icons.ev_station, size: 14, color: _availColor(availPct)),
                    const SizedBox(width: 3),
                    Text(
                      '$availAvail/$availTotal',
                      style: TextStyle(fontSize: 12, color: _availColor(availPct), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // 功率
                  if (station['power_kw'] != null)
                    Text(
                      '${station['power_kw']}kW',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // 第三行：价格 + 设施
              Row(
                children: [
                  Text(
                    '💰 ${price['total'] ?? '-'}元/kWh',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
                  ),
                  if (hasParking) ...[
                    const SizedBox(width: 8),
                    Text(
                      '🚗 停车${price['parking_fee']}元',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                  const Spacer(),
                  if (facilities.isNotEmpty) ...[
                    ...facilities.take(2).map((f) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _miniTag('$f'),
                    )),
                    if (facilities.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _miniTag('+${facilities.length - 2}'),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 表格视图 ────────────────────────────────────────────
  Widget _buildTableView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FA)),
                sortColumnIndex: _sort == 'power_kw' ? 4 : (_sort == 'rating' ? 5 : (_sort == 'available' ? 6 : null)),
                sortAscending: _sortOrder == 'asc',
                columns: [
                  const DataColumn(label: Text('名称', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('区域', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('类型', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('运营商', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('功率', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 2),
                        Icon(_sort == 'power_kw' ? (_sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more, size: 14, color: _sort == 'power_kw' ? const Color(0xFF007AFF) : Colors.grey),
                      ],
                    ),
                    onSort: (_, __) => _toggleSort('power_kw'),
                  ),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('桩数', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 2),
                        Icon(_sort == 'available' ? (_sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more, size: 14, color: _sort == 'available' ? const Color(0xFF007AFF) : Colors.grey),
                      ],
                    ),
                    onSort: (_, __) => _toggleSort('available'),
                  ),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('评分', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 2),
                        Icon(_sort == 'rating' ? (_sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more, size: 14, color: _sort == 'rating' ? const Color(0xFF007AFF) : Colors.grey),
                      ],
                    ),
                    onSort: (_, __) => _toggleSort('rating'),
                  ),
                  const DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _stations.map((s) {
                  final avail = s['availability'] as Map<String, dynamic>? ?? {};
                  final availTotal = avail['total'] ?? 0;
                  final availAvail = avail['available'] ?? 0;
                  final availPct = availTotal > 0 ? (availAvail / availTotal * 100).round() : 0;
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(s['name'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                        ),
                        onTap: () => _showDetailDialog(s),
                      ),
                      DataCell(Text(s['district_group'] ?? '-', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(s['type_name'] ?? _typeShortLabel(s['type'] ?? ''), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(s['operator'] ?? '-', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${s['power_kw'] ?? '-'} kW', style: const TextStyle(fontSize: 12))),
                      DataCell(
                        availTotal > 0
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: _availColor(availPct)),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$availAvail/$availTotal', style: TextStyle(fontSize: 12, color: _availColor(availPct))),
                                ],
                              )
                            : Text('-', style: const TextStyle(fontSize: 12)),
                      ),
                      DataCell(s['rating'] != null
                          ? Text('⭐ ${s['rating']}', style: const TextStyle(fontSize: 12))
                          : const Text('-', style: TextStyle(fontSize: 12))),
                      DataCell(
                        TextButton(
                          onPressed: () => _showDetailDialog(s),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF007AFF),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('详情', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 工具 ────────────────────────────────────────────────
  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _miniTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
    );
  }

  String _typeIcon(String type) {
    const map = {'ultra': '⚡', 'fast': '🚗', 'slow': '🐢', 'destination': '🏨', 'fleet': '🚚', 'swap': '🔄'};
    return map[type] ?? '⚡';
  }

  String _typeShortLabel(String type) {
    const map = {'ultra': '超充', 'fast': '快充', 'slow': '慢充', 'destination': '目的地', 'fleet': '车队', 'swap': '换电'};
    return map[type] ?? type;
  }
}

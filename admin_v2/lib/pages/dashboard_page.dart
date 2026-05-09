import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_client.dart';

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const DashboardPage({super.key, required this.user, required this.onLogout});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Stats data
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _overview;
  List<dynamic> _users = [];
  int _totalUsers = 0;
  bool _loading = true;

  // Chart data
  Map<String, dynamic>? _dailyUsers;
  Map<String, dynamic>? _chargingByHour;
  Map<String, dynamic>? _topStations;
  Map<String, dynamic>? _vehicleBrands;

  String _searchUsername = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await client.init();

    // Load all data in parallel
    final results = await Future.wait([
      client.getStats(),
      client.getOverviewStats(),
      client.getUsers(username: _searchUsername),
      client.getTotalUsers(username: _searchUsername),
      client.getDailyUsers(),
      client.getChargingByHour(),
      client.getTopStations(limit: 10),
      client.getVehicleBrands(),
    ]);

    if (mounted) {
      setState(() {
        _stats = results[0] as Map<String, dynamic>?;
        _overview = results[1] as Map<String, dynamic>?;
        _users = (results[2] as List<dynamic>?) ?? [];
        _totalUsers = results[3] as int;
        _dailyUsers = results[4] as Map<String, dynamic>?;
        _chargingByHour = results[5] as Map<String, dynamic>?;
        _topStations = results[6] as Map<String, dynamic>?;
        _vehicleBrands = results[7] as Map<String, dynamic>?;
        _loading = false;
      });
    }
  }

  Future<void> _deleteUser(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除用户 ID($id) 吗？'),
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
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('电满满 管理后台'),
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  (widget.user['nickname'] ?? widget.user['username'] ?? 'A')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(widget.user['username'] ?? 'admin', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.logout, size: 20),
                onPressed: widget.onLogout,
                tooltip: '退出',
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 第一行：统计卡片 ──
                    const Text('数据概览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16, runSpacing: 16,
                      children: [
                        _statCard('累计用户', '${_stats?['user_count'] ?? 0}', Icons.people, Colors.blue),
                        _statCard('今日新增', '${_overview?['today_new_users'] ?? 0}', Icons.person_add, Colors.teal),
                        _statCard('累计车辆', '${_stats?['vehicle_count'] ?? 0}', Icons.directions_car, Colors.green),
                        _statCard('累计收藏', '${_stats?['favorite_count'] ?? 0}', Icons.star, Colors.amber),
                        _statCard('累计充电', '${_stats?['history_count'] ?? 0}', Icons.bolt, Colors.purple),
                        _statCard('今日充电', '${_overview?['today_charging'] ?? 0}', Icons.ev_station, Colors.orange),
                        _statCard('活跃电站', '${_overview?['active_stations'] ?? 0}', Icons.local_fire_department, Colors.red),
                        _statCard('人均充电', '${_overview?['avg_charging'] ?? 0} 次', Icons.analytics, Colors.indigo),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── 第二行：用户增长趋势 ──
                    const Text('用户增长趋势（近30天）', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: _buildLineChart(),
                    ),
                    const SizedBox(height: 32),

                    // ── 第三行：充电时段 + 车辆品牌 ──
                    const Text('充电行为分析', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 280,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildChargingHourChart(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4,
                            child: _buildVehicleBrandChart(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── 第四行：热门站点 ──
                    const Text('热门充电站点 TOP 10', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 320,
                      child: _buildTopStationsChart(),
                    ),
                    const SizedBox(height: 32),

                    // ── 用户管理 ──
                    SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          const Text('用户管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          SizedBox(
                            width: 200, height: 38,
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: '搜索用户名...',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onSubmitted: (v) { _searchUsername = v; _loadData(); },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadData,
                            tooltip: '刷新',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)],
                        ),
                        child: _users.isEmpty
                            ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('暂无数据')))
                            : DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FA)),
                                columns: const [
                                  DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('用户名', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('昵称', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('手机号', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('角色', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('注册时间', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: _users.map((u) => DataRow(cells: [
                                  DataCell(Text('${u['id']}')),
                                  DataCell(Text(u['username'] ?? '')),
                                  DataCell(Text(u['nickname'] ?? '')),
                                  DataCell(Text(u['phone'] ?? '-')),
                                  DataCell(Text(_roleLabel(u['role'] ?? 'user'),
                                    style: TextStyle(color: _roleColor(u['role'] ?? 'user')),
                                  )),
                                  DataCell(Text(
                                    u['created_at'] != null ? u['created_at'].toString().substring(0, 10) : '-',
                                    style: const TextStyle(fontSize: 12),
                                  )),
                                  DataCell(
                                    u['role'] != 'admin' && u['role'] != 'super_admin'
                                        ? IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            onPressed: () => _deleteUser(u['id']),
                                            tooltip: '删除',
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ])).toList(),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('共 $_totalUsers 位用户', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
    );
  }

  // ── 折线图：用户增长趋势（增强版）─────────────────────
  Widget _buildLineChart() {
    final dates = (_dailyUsers?['dates'] as List<dynamic>?) ?? [];
    final counts = (_dailyUsers?['counts'] as List<dynamic>?) ?? [];

    if (dates.isEmpty || counts.isEmpty || counts.every((c) => c == 0)) {
      return _emptyChart('暂无用户增长数据');
    }

    final maxY = (counts.map((c) => (c as num).toDouble()).reduce((a, b) => a > b ? a : b) * 1.4).clamp(1.0, double.infinity);
    final step = (dates.length / 10).ceil().clamp(1, dates.length);

    final spots = <FlSpot>[];
    for (int i = 0; i < counts.length; i += step) {
      spots.add(FlSpot(i.toDouble(), (counts[i] as num).toDouble()));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)],
      ),
      child: LineChart(
        LineChartData(
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY / 4).clamp(1, double.infinity),
            getDrawingHorizontalLine: (v) => FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: (maxY / 4).clamp(1, double.infinity),
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: step.toDouble(),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= dates.length) return const SizedBox();
                  final date = dates[idx].toString();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(date.substring(5), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              gradient: const LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
              ),
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF007AFF).withOpacity(0.2),
                    const Color(0xFF007AFF).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final idx = s.x.toInt();
                final dateStr = idx >= 0 && idx < dates.length ? dates[idx].toString() : '';
                return LineTooltipItem(
                  '$dateStr\n${s.y.toInt()} 位新用户',
                  const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ── 柱状图：充电时段 ─────────────────────────────────
  Widget _buildChargingHourChart() {
    final periods = (_chargingByHour?['periods'] as List<dynamic>?) ?? [];
    final counts = (_chargingByHour?['counts'] as List<dynamic>?) ?? [];

    if (periods.isEmpty || counts.isEmpty || counts.every((c) => c == 0)) {
      return _emptyChart('暂无充电时段数据');
    }

    final maxY = (counts.map((c) => (c as num).toDouble()).reduce((a, b) => a > b ? a : b) * 1.3).clamp(1.0, double.infinity);
    const periodColors = [Color(0xFF4ECDC4), Color(0xFFFF6B6B), Color(0xFFFFE66D), Color(0xFF007AFF)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)],
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY / 4).clamp(1, double.infinity),
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: (maxY / 4).clamp(1, double.infinity),
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= periods.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(periods[idx].toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(counts.length, (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: (counts[i] as num).toDouble(),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [periodColors[i % periodColors.length].withOpacity(0.7), periodColors[i % periodColors.length]],
                ),
                width: 32,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ],
          )),
        ),
      ),
    );
  }

  // ── 饼图：车辆品牌 ────────────────────────────────────
  Widget _buildVehicleBrandChart() {
    final brands = (_vehicleBrands?['brands'] as List<dynamic>?) ?? [];

    if (brands.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)],
        ),
        child: Center(child: _emptyChart('暂无车辆数据')),
      );
    }

    const pieColors = [
      Color(0xFF007AFF), Color(0xFF34C759), Color(0xFFFF9500),
      Color(0xFFFF2D55), Color(0xFF5856D6), Color(0xFFAF52DE),
      Color(0xFFFF3B30), Color(0xFF00C7BE),
    ];

    final sections = brands.asMap().entries.map<PieChartSectionData>((entry) {
      final brand = entry.value as Map<String, dynamic>;
      return PieChartSectionData(
        color: pieColors[entry.key % pieColors.length],
        value: (brand['percent'] as num).toDouble(),
        title: '${brand['percent']}%',
        radius: 58,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)],
      ),
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 28,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 4,
            children: brands.asMap().entries.map((entry) {
              final brand = entry.value as Map<String, dynamic>;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: pieColors[entry.key % pieColors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${brand['brand']} (${brand['count']})',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 热门站点榜单 ───────────────────────────────────────
  Widget _buildTopStationsChart() {
    final stations = (_topStations?['stations'] as List<dynamic>?) ?? [];

    if (stations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)],
        ),
        child: Center(child: _emptyChart('暂无站点数据')),
      );
    }

    final maxCount = stations.map((s) => (s['count'] as num)).reduce((a, b) => a > b ? a : b).toDouble();
    final medalColors = [const Color(0xFFFF6B6B), const Color(0xFFFF9500), const Color(0xFFFFCC00)];
    final rowColors = [
      const Color(0xFF007AFF), const Color(0xFF5856D6), const Color(0xFFAF52DE),
      const Color(0xFFFF2D55), const Color(0xFF00C7BE), const Color(0xFF34C759),
      const Color(0xFFFF6B6B), const Color(0xFFFF9500), const Color(0xFFFFCC00),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏（固定不滚动）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                const Text(
                  '热门充电站 TOP 10',
                  style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${stations.length} 个站点',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          // 榜单内容（可滚动）
          Expanded(
            child: Scrollbar(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: stations.length,
                itemBuilder: (ctx, i) {
                  final s = stations[i] as Map<String, dynamic>;
                  final name = s['name']?.toString() ?? '';
                  final count = (s['count'] as num).toInt();
                  final pct = maxCount > 0 ? (count / maxCount) : 0.0;
                  final isTop3 = i < 3;
                  final color = isTop3 ? medalColors[i] : rowColors[i - 3];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        // 排名
                        SizedBox(
                          width: 28,
                          child: isTop3
                              ? Text(
                                  ['🥇', '🥈', '🥉'][i],
                                  style: const TextStyle(fontSize: 18),
                                )
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                        ),
                        // 站名
                        Expanded(
                          flex: 3,
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 13, fontWeight: isTop3 ? FontWeight.bold : FontWeight.w500,
                              color: isTop3 ? Colors.black87 : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 进度条
                        Expanded(
                          flex: 4,
                          child: Stack(
                            children: [
                              Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: pct.clamp(0.0, 1.0),
                                child: Container(
                                  height: 14,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [color.withOpacity(0.8), color],
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 次数
                        SizedBox(
                          width: 52,
                          child: Text(
                            '$count 次',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold,
                              color: isTop3 ? color : Colors.grey[700],
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyChart(String msg) {
    return Center(
      child: Text(msg, style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 170, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    if (role == 'super_admin') return '超级管理员';
    if (role == 'admin') return '管理员';
    return '用户';
  }

  Color _roleColor(String role) {
    if (role == 'super_admin') return Colors.red;
    if (role == 'admin') return Colors.orange;
    return Colors.blue;
  }
}

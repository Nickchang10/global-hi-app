// lib/pages/vendor/vendor_reports_page.dart
//
// ✅ VendorReportsPage（最終完整版｜免 vendorIds + status 複合索引）
// ------------------------------------------------------------
// - vendorId 取得：先讀 custom claims，拿不到就 fallback 讀 users/{uid}.vendorId
// - 查詢策略：只呼叫 ReportService.exportOrders(range)（status + createdAt）
// - 回來後在 App 端依 vendorId / vendorIds 過濾彙總，避免 index 地獄
// - 顯示：總營收、訂單數、平均客單、每日營收折線圖、熱銷商品 Top10
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/report_service.dart';

class VendorReportsPage extends StatefulWidget {
  const VendorReportsPage({super.key});

  @override
  State<VendorReportsPage> createState() => _VendorReportsPageState();
}

class _VendorReportsPageState extends State<VendorReportsPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
  final _dateFmt = DateFormat('yyyy-MM-dd');

  final _reportService = ReportService();

  bool _loadingProfile = true;
  String? _vendorId;

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );

  Future<_VendorReportData>? _future;

  @override
  void initState() {
    super.initState();
    _loadVendorId();
  }

  // ------------------------------------------------------------
  // vendorId loader（claims -> users/{uid}.vendorId）
  // ------------------------------------------------------------
  Future<void> _loadVendorId() async {
    setState(() => _loadingProfile = true);

    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _vendorId = null;
        _loadingProfile = false;
      });
      return;
    }

    String? vid;

    // 1) custom claims
    try {
      final token = await user.getIdTokenResult(true);
      final c = token.claims?['vendorId'];
      if (c != null) {
        final s = c.toString().trim();
        if (s.isNotEmpty) vid = s;
      }
    } catch (_) {
      // ignore, fallback firestore
    }

    // 2) fallback: users/{uid}.vendorId
    if (vid == null || vid.isEmpty) {
      try {
        final snap = await _db.collection('users').doc(user.uid).get();
        final data = snap.data() ?? {};
        final s = (data['vendorId'] ?? '').toString().trim();
        if (s.isNotEmpty) vid = s;
      } catch (_) {
        // ignore
      }
    }

    setState(() {
      _vendorId = (vid != null && vid.isNotEmpty) ? vid : null;
      _loadingProfile = false;
    });

    _reload();
  }

  void _reload() {
    final vid = _vendorId;
    if (vid == null || vid.isEmpty) {
      setState(() => _future = null);
      return;
    }

    setState(() {
      _future = _buildReportData(vendorId: vid, range: _range);
    });
  }

  Future<_VendorReportData> _buildReportData({
    required String vendorId,
    required DateTimeRange range,
  }) async {
    // ✅ 只做 status + createdAt（由 ReportService.exportOrders 負責）
    final orders = await _reportService.exportOrders(range);

    // ✅ App 端過濾：支援 vendorId(string) / vendorIds(list)
    final filtered = orders.where((o) => _orderBelongsToVendor(o, vendorId)).toList();

    double totalRevenue = 0;
    int orderCount = 0;
    final dailyRevenue = <String, double>{};
    final productSales = <String, double>{};

    for (final o in filtered) {
      final createdAt = o['createdAt'];
      if (createdAt is! DateTime) continue;

      final amount = (o['finalAmount'] ?? o['amount'] ?? 0).toDouble();
      totalRevenue += amount;
      orderCount++;

      final dayKey = _dateFmt.format(createdAt);
      dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + amount;

      final items = (o['items'] as List?) ?? const [];
      for (final it in items) {
        if (it is! Map) continue;
        final m = Map<String, dynamic>.from(it as Map);

        final name = (m['name'] ?? m['productName'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final qty = (m['quantity'] ?? m['qty'] ?? 1).toDouble();
        productSales[name] = (productSales[name] ?? 0) + qty;
      }
    }

    // 補齊每日（確保折線圖連續）
    final normalizedDaily = <String, double>{};
    final startDate = DateTime(range.start.year, range.start.month, range.start.day);
    final endDate = DateTime(range.end.year, range.end.month, range.end.day);
    final days = endDate.difference(startDate).inDays;

    for (int i = 0; i <= days; i++) {
      final d = startDate.add(Duration(days: i));
      final k = _dateFmt.format(d);
      normalizedDaily[k] = dailyRevenue[k] ?? 0;
    }

    return _VendorReportData(
      vendorId: vendorId,
      totalRevenue: totalRevenue,
      orderCount: orderCount,
      dailyRevenue: normalizedDaily,
      productSales: productSales,
    );
  }

  bool _orderBelongsToVendor(Map<String, dynamic> o, String vendorId) {
    try {
      final v1 = (o['vendorId'] ?? '').toString().trim();
      if (v1.isNotEmpty) return v1 == vendorId;

      final vIds = (o['vendorIds'] as List?) ?? const [];
      return vIds.map((e) => e.toString()).contains(vendorId);
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      locale: const Locale('zh', 'TW'),
    );
    if (picked == null) return;

    setState(() => _range = picked);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_vendorId == null) {
      return const Scaffold(
        body: Center(child: Text('尚未綁定廠商帳號（找不到 vendorId）')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('銷售報表', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: '選擇日期區間',
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
          ),
          IconButton(
            tooltip: '重新整理',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final rangeText = '${_dateFmt.format(_range.start)} ~ ${_dateFmt.format(_range.end)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text('區間：$rangeText', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final f = _future;
    if (f == null) {
      return const Center(child: Text('尚未載入資料'));
    }

    return FutureBuilder<_VendorReportData>(
      future: f,
      builder: (context, snap) {
        if (snap.hasError) {
          return _errorCard('讀取報表失敗：${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final d = snap.data!;
        if (d.orderCount == 0) {
          return const Center(child: Text('目前尚無營收資料'));
        }

        return Column(
          children: [
            _buildSummaryCards(d),
            const SizedBox(height: 16),
            _buildRevenueChart(d),
            const SizedBox(height: 16),
            _buildTopProducts(d),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards(_VendorReportData d) {
    final avg = d.orderCount == 0 ? 0 : d.totalRevenue / d.orderCount;

    return Row(
      children: [
        Expanded(
          child: _metricCard(
            title: '總營收',
            value: _moneyFmt.format(d.totalRevenue),
            icon: Icons.payments,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            title: '訂單數',
            value: d.orderCount.toString(),
            icon: Icons.receipt_long,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            title: '平均客單',
            value: _moneyFmt.format(avg),
            icon: Icons.trending_up,
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // 每日營收折線
  // --------------------------------------------------
  Widget _buildRevenueChart(_VendorReportData d) {
    final keys = d.dailyRevenue.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (int i = 0; i < keys.length; i++) {
      spots.add(FlSpot(i.toDouble(), d.dailyRevenue[keys[i]] ?? 0));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('每日營收', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (keys.length / 6).clamp(1, 999).toDouble(),
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                          return Text(keys[i].substring(5), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (v, meta) {
                          if (v == 0) return const Text('0');
                          if (v >= 1000000) return Text('${(v / 1000000).toStringAsFixed(1)}M');
                          if (v >= 1000) return Text('${(v / 1000).toStringAsFixed(0)}K');
                          return Text(v.toStringAsFixed(0));
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.green,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // 熱銷商品 Top10
  // --------------------------------------------------
  Widget _buildTopProducts(_VendorReportData d) {
    final entries = d.productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('尚無商品銷售資料'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('熱銷商品 Top 10', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...entries.take(10).map(
                  (e) => ListTile(
                    dense: true,
                    title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text('銷售量 ${e.value.toInt()}'),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Data model
// --------------------------------------------------
class _VendorReportData {
  final String vendorId;
  final double totalRevenue;
  final int orderCount;
  final Map<String, double> dailyRevenue;
  final Map<String, double> productSales;

  _VendorReportData({
    required this.vendorId,
    required this.totalRevenue,
    required this.orderCount,
    required this.dailyRevenue,
    required this.productSales,
  });
}

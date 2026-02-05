// lib/pages/admin/vendors/admin_vendors_report_page.dart
//
// ✅ AdminVendorReportPage（最終完整版｜不寫任何 orders 複合查詢，徹底避免 index 地獄）
// ------------------------------------------------------------
// 核心原則：
// - ❌ 本頁面不直接對 orders 做 where(status) / arrayContains / orderBy 等複合查詢
// - ✅ 只呼叫 ReportService（你貼的 V9 版：以 createdAt range 查詢 + 前端過濾 status/vendor）
// - ✅ vendor 清單讀取也不 orderBy（避免任何 index 需求），改成前端排序
//
// 功能：
// - 管理員下拉選擇廠商
// - 日期區間選擇
// - 營收總覽：區間營收、訂單數、平均客單、本月營收
// - 每日營收折線圖
// - 熱銷商品 Top10
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/report_service.dart';

class AdminVendorReportPage extends StatefulWidget {
  /// AdminShell 會用 const AdminVendorReportPage(vendorId:'', vendorName:'')
  final String vendorId;
  final String vendorName;

  /// 可指定預設日期區間（不指定則預設近 30 天）
  final DateTimeRange? initialRange;

  const AdminVendorReportPage({
    super.key,
    required this.vendorId,
    required this.vendorName,
    this.initialRange,
  });

  @override
  State<AdminVendorReportPage> createState() => _AdminVendorReportPageState();
}

class _AdminVendorReportPageState extends State<AdminVendorReportPage> {
  final _db = FirebaseFirestore.instance;
  final _report = ReportService();

  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
  final _dateFmt = DateFormat('yyyy-MM-dd');

  String? _selectedVendorId;
  String? _selectedVendorName;

  late DateTimeRange _range;

  Future<ReportStats>? _future;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _range = widget.initialRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 29)),
          end: DateTime.now(),
        );

    final vid = widget.vendorId.trim();
    if (vid.isNotEmpty) {
      _selectedVendorId = vid;
      _selectedVendorName =
          widget.vendorName.trim().isNotEmpty ? widget.vendorName.trim() : null;
      _reload();
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

  void _reload() {
    final vid = _selectedVendorId;
    if (vid == null || vid.isEmpty) {
      setState(() => _future = null);
      return;
    }

    setState(() {
      _loading = true;
      _future = _report.getSalesReport(range: _range, vendorId: vid).whenComplete(() {
        if (mounted) setState(() => _loading = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final rangeText = '${_dateFmt.format(_range.start)} ~ ${_dateFmt.format(_range.end)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('營收報表', style: TextStyle(fontWeight: FontWeight.w900)),
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
          _buildHeader(rangeText),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          _buildBody(),
        ],
      ),
    );
  }

  // ===========================================================
  // Header: Vendor picker + range
  // ===========================================================

  Widget _buildHeader(String rangeText) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('區間：$rangeText', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _buildVendorDropdown(),
          ],
        ),
      ),
    );
  }

  /// ✅ 不 orderBy，不加 where（避免任何 index 需求）
  Widget _buildVendorDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('vendors').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Text('讀取廠商列表失敗');
        if (!snap.hasData) return const LinearProgressIndicator();

        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Text('尚無廠商資料（vendors 集合為空）');

        final vendors = docs.map((d) {
          final data = d.data();
          final name = (data['name'] ?? data['title'] ?? d.id).toString().trim();
          return _VendorItem(id: d.id, name: name.isEmpty ? d.id : name);
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        // 若目前沒有選到 vendor，預設第一個
        if ((_selectedVendorId == null || _selectedVendorId!.isEmpty) && vendors.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedVendorId = vendors.first.id;
              _selectedVendorName = vendors.first.name;
            });
            _reload();
          });
        }

        return DropdownButtonFormField<String>(
          value: _selectedVendorId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '選擇廠商',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: vendors
              .map((v) => DropdownMenuItem<String>(
                    value: v.id,
                    child: Text(v.name, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) {
            final picked = vendors.firstWhere((e) => e.id == v, orElse: () => vendors.first);
            setState(() {
              _selectedVendorId = v;
              _selectedVendorName = picked.name;
            });
            _reload();
          },
        );
      },
    );
  }

  // ===========================================================
  // Body
  // ===========================================================

  Widget _buildBody() {
    final vid = _selectedVendorId;
    if (vid == null || vid.isEmpty) {
      return const Center(child: Text('請先選擇廠商'));
    }

    final future = _future;
    if (future == null) {
      return const Center(child: Text('尚未載入資料'));
    }

    return FutureBuilder<ReportStats>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          // ✅ 這裡若仍出現 failed-precondition，代表頁面還在跑舊的 orders 複合查詢
          return _errorCard(
            '載入失敗：${snap.error}\n'
            '若你仍看到「query requires an index」，請確認此頁面沒有任何 orders 的 whereIn/arrayContains/orderBy 複合查詢。',
          );
        }
        if (!snap.hasData) {
          return const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(),
          ));
        }

        final stats = snap.data!;
        final vendorName = _selectedVendorName ?? vid;

        if (stats.orderCount == 0) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('廠商：$vendorName\n此區間沒有可計入營收的訂單（paid/shipping/completed 等）。'),
            ),
          );
        }

        final normalizedDaily = _normalizeDailyRevenue(stats.dailyRevenue, _range);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _vendorTitleCard(vendorName),
            const SizedBox(height: 12),
            _summaryCards(stats),
            const SizedBox(height: 12),
            _dailyLineChart(normalizedDaily),
            const SizedBox(height: 12),
            _topProducts(stats.productSales),
          ],
        );
      },
    );
  }

  Widget _vendorTitleCard(String vendorName) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.store_mall_directory_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '廠商：$vendorName',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards(ReportStats s) {
    final avg = s.orderCount == 0 ? 0.0 : (s.periodRevenue / s.orderCount);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _metricCard('區間營收', _moneyFmt.format(s.periodRevenue), Icons.payments_outlined),
        _metricCard('訂單數', s.orderCount.toString(), Icons.receipt_long_outlined),
        _metricCard('平均客單', _moneyFmt.format(avg), Icons.trending_up_outlined),
        _metricCard('本月營收', _moneyFmt.format(s.monthRevenue), Icons.calendar_month_outlined),
      ],
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return Card(
      child: SizedBox(
        width: 220,
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
                    Text(title, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================
  // Chart: Daily revenue
  // ===========================================================

  Widget _dailyLineChart(Map<String, double> daily) {
    final keys = daily.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (int i = 0; i < keys.length; i++) {
      spots.add(FlSpot(i.toDouble(), daily[keys[i]] ?? 0));
    }

    final total = daily.values.fold<double>(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('每日營收', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '合計：${_moneyFmt.format(total)}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (v, meta) {
                          if (v == 0) return const Text('0');
                          if (v >= 1000000) return Text('${(v / 1000000).toStringAsFixed(1)}M');
                          if (v >= 1000) return Text('${(v / 1000).toStringAsFixed(0)}K');
                          return Text(v.toStringAsFixed(0));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (keys.length / 6).clamp(1, 999).toDouble(),
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                          // MM-dd
                          return Text(keys[i].substring(5), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
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
                        color: Colors.green.withOpacity(0.16),
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

  // ===========================================================
  // Top products
  // ===========================================================

  Widget _topProducts(Map<String, double> sales) {
    final entries = sales.entries.toList()
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
            ...entries.take(10).map((e) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text('銷售量 ${e.value.toInt()}'),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // Helpers
  // ===========================================================

  Map<String, double> _normalizeDailyRevenue(Map<String, double> input, DateTimeRange range) {
    final out = <String, double>{};

    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);

    final days = end.difference(start).inDays;
    for (int i = 0; i <= days; i++) {
      final d = start.add(Duration(days: i));
      final key = _dateFmt.format(d);
      out[key] = input[key] ?? 0.0;
    }

    return out;
  }

  Widget _errorCard(String msg) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }
}

class _VendorItem {
  final String id;
  final String name;
  _VendorItem({required this.id, required this.name});
}
 
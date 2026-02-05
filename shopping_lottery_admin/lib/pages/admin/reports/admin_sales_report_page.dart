// lib/pages/admin/reports/admin_sales_report_page.dart
//
// ✅ AdminSalesReportPage（完整版 V3｜可編譯｜型別防呆｜RouteNames 路由版）
// ------------------------------------------------------------
// - 日期區間篩選（自訂 / 快速 7/30/90 天）
// - 匯出頁共用區間：按「匯出」自動帶入同區間
// - 修正你遇到的：
//   1) List.asMap().entries / values 迭代導致 e.value 變成 double 而不是 MapEntry（e.value.key / e.value.value 報錯）
//   2) maxVal 型別與 nullable 問題（Operator '>' cannot be called on 'double?'）
// - 使用 RouteNames 統一管理路由名稱（避免 Unknown route）
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:osmile_admin/services/report_service.dart';
import 'package:osmile_admin/routes/route_names.dart';

class AdminSalesReportPage extends StatefulWidget {
  const AdminSalesReportPage({super.key});

  /// ✅ 統一路由名稱（避免 Unknown route）
  static const routeName = RouteNames.adminSalesReport;

  @override
  State<AdminSalesReportPage> createState() => _AdminSalesReportPageState();
}

class _AdminSalesReportPageState extends State<AdminSalesReportPage> {
  final _report = ReportService();

  bool loading = true;
  Object? error;

  late DateTimeRange range;
  ReportStats? stats;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    range = DateTimeRange(
      start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final s = await _report.getSalesReport(range: range);
      setState(() {
        stats = s;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('營收報表')),
        body: _ErrorView(
          title: '載入失敗',
          message: '$error',
          onRetry: _load,
        ),
      );
    }

    final s = stats;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('營收報表')),
        body: _ErrorView(
          title: '資料為空',
          message: 'ReportStats 為 null，請重試或檢查 ReportService 回傳。',
          onRetry: _load,
        ),
      );
    }

    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final rangeText =
        '${DateFormat('yyyy/MM/dd').format(range.start)} - ${DateFormat('yyyy/MM/dd').format(range.end)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('營收報表', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '匯出（自動帶入此區間）',
            icon: const Icon(Icons.download),
            onPressed: _goExportWithSameRange,
          ),
          IconButton(
            tooltip: '選擇日期區間',
            icon: const Icon(Icons.date_range),
            onPressed: _pickRange,
          ),
          PopupMenuButton<int>(
            tooltip: '快速區間',
            icon: const Icon(Icons.filter_alt),
            onSelected: _setQuickRange,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('最近 7 天')),
              PopupMenuItem(value: 30, child: Text('最近 30 天')),
              PopupMenuItem(value: 90, child: Text('最近 90 天')),
            ],
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('期間：$rangeText', style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 12),
            _summaryCard(fmtMoney, s),
            const SizedBox(height: 16),
            _chartCard(s),
            const SizedBox(height: 16),
            _vendorRankingCard(fmtMoney, s),
            const SizedBox(height: 16),
            _productRankingCard(s),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ✅ 導向匯出頁（使用 RouteNames，不用硬編字串）
  // =====================================================
  void _goExportWithSameRange() {
    Navigator.pushNamed(
      context,
      RouteNames.adminSalesExport,
      arguments: range,
    );
  }

  // =====================================================
  // 日期選擇（normalize end 到 23:59:59）
  // =====================================================
  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      initialDateRange: range,
    );
    if (picked == null) return;

    setState(() {
      range = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    });

    await _load();
  }

  Future<void> _setQuickRange(int days) async {
    final now = DateTime.now();
    setState(() {
      range = DateTimeRange(
        start: DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1)),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    });
    await _load();
  }

  // =====================================================
  // Summary Card
  // =====================================================
  Widget _summaryCard(NumberFormat fmtMoney, ReportStats s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('期間總營收', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              fmtMoney.format(_toDouble(s.totalRevenue)),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat('訂單數', s.orderCount.toString()),
                _miniStat('本月營收', fmtMoney.format(_toDouble(s.monthRevenue))),
                _miniStat('廠商數', (s.vendorRevenue).length.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ],
    );
  }

  // =====================================================
  // Chart - 每日營收趨勢（型別防呆 + maxY 防呆）
  // =====================================================
  Widget _chartCard(ReportStats s) {
    final dailyRaw = s.dailyRevenue;

    // dailyRevenue 可能是 Map<String, num/double/int>，這裡做安全轉換
    final daily = <String, double>{};
    for (final entry in dailyRaw.entries) {
      daily[entry.key.toString()] = _toDouble(entry.value);
    }

    if (daily.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16), child: Text('尚無每日營收資料')),
      );
    }

    final sortedKeys = daily.keys.toList()..sort();

    double maxVal = 0.0;
    for (final k in sortedKeys) {
      final v = daily[k] ?? 0.0;
      if (v > maxVal) maxVal = v;
    }
    final maxY = (maxVal <= 0 ? 1000.0 : maxVal * 1.2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('每日營收趨勢', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (sortedKeys.length <= 7) ? 1 : (sortedKeys.length / 7).ceilToDouble(),
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < 0 || i >= sortedKeys.length) return const SizedBox.shrink();
                          final key = sortedKeys[i];
                          final label = key.length >= 10 ? key.substring(5, 10) : key;
                          return Text(label, style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, _) {
                          if (value == 0) return const Text('0');
                          // 顯示整千
                          if (value % 1000 == 0) {
                            return Text('NT\$${(value / 1000).round()}k', style: const TextStyle(fontSize: 10));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      spots: [
                        for (int i = 0; i < sortedKeys.length; i++)
                          FlSpot(i.toDouble(), (daily[sortedKeys[i]] ?? 0).toDouble()),
                      ],
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

  // =====================================================
  // Vendor Ranking（修正你遇到的 e.value.key / e.value.value 報錯來源）
  // =====================================================
  Widget _vendorRankingCard(NumberFormat fmtMoney, ReportStats s) {
    final entries = s.vendorRevenue.entries.toList()
      ..sort((a, b) => _toDouble(b.value).compareTo(_toDouble(a.value)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('廠商營收排行', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('尚無資料')
            else
              ...entries.take(10).toList().asMap().entries.map((row) {
                final idx = row.key + 1;
                final item = row.value; // MapEntry<String, dynamic>
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text('$idx', style: const TextStyle(color: Colors.blue)),
                  ),
                  title: Text(item.key.toString()),
                  trailing: Text(fmtMoney.format(_toDouble(item.value))),
                );
              }),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // Product Ranking
  // =====================================================
  Widget _productRankingCard(ReportStats s) {
    final entries = s.productSales.entries.toList()
      ..sort((a, b) => _toDouble(b.value).compareTo(_toDouble(a.value)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('商品銷售排行', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('尚無資料')
            else
              ...entries.take(10).toList().asMap().entries.map((row) {
                final idx = row.key + 1;
                final item = row.value; // MapEntry<String, dynamic>
                final qty = _toDouble(item.value).round();
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text('$idx', style: const TextStyle(color: Colors.blue)),
                  ),
                  title: Text(item.key.toString()),
                  trailing: Text('x$qty'),
                );
              }),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // Helpers（型別防呆）
  // =====================================================
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

// =====================================================
// Error View
// =====================================================
class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

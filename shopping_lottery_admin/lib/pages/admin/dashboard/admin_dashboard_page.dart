// lib/pages/admin/dashboard/admin_dashboard_page.dart
//
// ✅ AdminDashboardPage（完整版 V6）
// ------------------------------------------------------------
// - 即時摘要統計（今日營收、本月營收、訂單數、用戶數、廠商數）
// - 使用 ReportService.getDashboardStats()
// - 當日 / 7 日 / 30 日營收趨勢圖（FlChart）
// - 自動刷新 / 下拉更新 / 錯誤重試
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:osmile_admin/services/report_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _report = ReportService();

  bool loading = true;
  Object? error;
  late DashboardStats stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      stats = await _report.getDashboardStats();
      setState(() => loading = false);
    } catch (e) {
      setState(() {
        loading = false;
        error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('儀表板')),
        body: _ErrorView(
          message: '$error',
          onRetry: _load,
        ),
      );
    }

    final fmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理儀表板', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard('今日營收', fmt.format(stats.todayRevenue), Icons.attach_money, cs.primary),
                _statCard('本月營收', fmt.format(stats.monthRevenue), Icons.bar_chart, cs.secondary),
                _statCard('訂單數', stats.orderCount.toString(), Icons.receipt_long, cs.tertiary),
                _statCard('新用戶', stats.newUsers.toString(), Icons.person_add_alt, cs.primaryContainer),
                _statCard('廠商數', stats.vendorCount.toString(), Icons.store_mall_directory, cs.secondaryContainer),
              ],
            ),
            const SizedBox(height: 20),
            _chartCard(cs),
            const SizedBox(height: 30),
            _summaryTable(fmt),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // 統計卡片
  // =====================================================
  Widget _statCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 180,
      height: 100,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ],
              ),
              const Spacer(),
              Text(value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // 營收趨勢圖
  // =====================================================
  Widget _chartCard(ColorScheme cs) {
    final daily = stats.dailyRevenue;
    if (daily.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('尚無每日營收資料'),
        ),
      );
    }

    final sorted = daily.keys.toList()..sort();
    final maxY = (daily.values.reduce((a, b) => a > b ? a : b)) * 1.3;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('最近 30 日營收趨勢',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY.toDouble(),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < 0 || i >= sorted.length) return const SizedBox.shrink();
                          final day = sorted[i].substring(5);
                          return Text(day, style: const TextStyle(fontSize: 9));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, _) {
                          if (value == 0) return const Text('0');
                          if (value % 1000 == 0) {
                            return Text('${value ~/ 1000}k',
                                style: const TextStyle(fontSize: 9));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: cs.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      spots: [
                        for (int i = 0; i < sorted.length; i++)
                          FlSpot(i.toDouble(), (daily[sorted[i]] ?? 0).toDouble()),
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
  // 摘要資料表
  // =====================================================
  Widget _summaryTable(NumberFormat fmt) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('系統摘要', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const Divider(),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
              children: [
                _row('總營收', fmt.format(stats.totalRevenue)),
                _row('平均客單價 AOV', fmt.format(stats.aov)),
                _row('已完成訂單數', stats.completedOrders.toString()),
                _row('未付款訂單', stats.pendingOrders.toString()),
                _row('廠商活躍數', stats.activeVendors.toString()),
                _row('更新時間', DateFormat('yyyy/MM/dd HH:mm').format(stats.updatedAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _row(String key, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(key,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(value, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

// =====================================================
// ErrorView
// =====================================================
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: cs.error, size: 48),
              const SizedBox(height: 10),
              Text('載入失敗', style: TextStyle(fontWeight: FontWeight.bold, color: cs.error)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
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
    );
  }
}

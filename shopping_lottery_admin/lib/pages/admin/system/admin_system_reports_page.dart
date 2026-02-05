// lib/pages/admin/system/admin_system_reports_page.dart
//
// ✅ AdminSystemReportsPage（完整版｜系統報表分析）
// ------------------------------------------------------------
// - 資料來源：Firestore analytics, logs, users, orders
// - 功能：登入量、交易量、錯誤統計、匯出 CSV
// - 使用 fl_chart 顯示折線圖與長條圖
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:html' as html;

class AdminSystemReportsPage extends StatefulWidget {
  const AdminSystemReportsPage({super.key});

  @override
  State<AdminSystemReportsPage> createState() => _AdminSystemReportsPageState();
}

class _AdminSystemReportsPageState extends State<AdminSystemReportsPage> {
  final _db = FirebaseFirestore.instance;

  DateTimeRange? _range;
  bool _loading = false;
  _ReportData? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final start = _range?.start ?? now.subtract(const Duration(days: 14));
      final end = _range?.end ?? now;

      final usersSnap = await _db
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThanOrEqualTo: end)
          .get();

      final ordersSnap = await _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThanOrEqualTo: end)
          .get();

      final logsSnap = await _db
          .collection('system_logs')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThanOrEqualTo: end)
          .get();

      final data = _ReportData.fromSnapshots(usersSnap, ordersSnap, logsSnap);
      setState(() => _data = data);
    } catch (e) {
      _toast('載入失敗：$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('系統報表分析', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '匯出報表',
            icon: const Icon(Icons.download),
            onPressed: _data == null ? null : _exportCSV,
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('無資料'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(_range == null
                              ? '選擇日期範圍'
                              : '${fmt.format(_range!.start)} - ${fmt.format(_range!.end)}'),
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2023),
                              lastDate: DateTime.now(),
                              initialDateRange: _range,
                            );
                            if (picked != null) {
                              setState(() => _range = picked);
                              _loadData();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _summarySection(cs, _data!),
                    const SizedBox(height: 16),
                    _chartSection(cs, _data!),
                    const SizedBox(height: 16),
                    _errorLogsSection(cs, _data!.errorLogs),
                  ],
                ),
    );
  }

  Widget _summarySection(ColorScheme cs, _ReportData data) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryCard(cs, '新註冊用戶', data.newUsers.toString(), Icons.person_add),
        _summaryCard(cs, '總訂單數', data.totalOrders.toString(), Icons.shopping_cart_outlined),
        _summaryCard(cs, '完成訂單', data.completedOrders.toString(), Icons.task_alt_outlined),
        _summaryCard(cs, '錯誤紀錄', data.errorLogs.length.toString(), Icons.error_outline),
      ],
    );
  }

  Widget _summaryCard(ColorScheme cs, String label, String value, IconData icon) {
    return Card(
      elevation: 0,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(value,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: cs.primary)),
          ],
        ),
      ),
    );
  }

  Widget _chartSection(ColorScheme cs, _ReportData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('每日登入與訂單趨勢',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: d.loginTrend.entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                      .toList(),
                  isCurved: true,
                  color: cs.primary,
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: d.orderTrend.entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                      .toList(),
                  isCurved: true,
                  color: Colors.green,
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _legendDot(cs.primary, '登入數'),
            const SizedBox(width: 10),
            _legendDot(Colors.green, '訂單數'),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _errorLogsSection(ColorScheme cs, List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return const Text('無錯誤紀錄');
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('錯誤日誌',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            for (final log in logs.take(10))
              ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(log['message'] ?? '未知錯誤'),
                subtitle: Text(log['createdAt'] ?? ''),
              ),
          ],
        ),
      ),
    );
  }

  void _exportCSV() {
    if (_data == null) return;
    final rows = [
      ['日期', '新用戶', '訂單數', '完成訂單', '錯誤數'],
      ..._data!.loginTrend.keys.map((day) {
        return [
          'Day $day',
          _data!.loginTrend[day].toString(),
          _data!.orderTrend[day].toString(),
          _data!.completedOrders.toString(),
          _data!.errorLogs.length.toString(),
        ];
      }),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'system_report.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
    _toast('已匯出報表');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ============================================================
// 資料模型
// ============================================================

class _ReportData {
  final int newUsers;
  final int totalOrders;
  final int completedOrders;
  final List<Map<String, dynamic>> errorLogs;
  final Map<int, int> loginTrend;
  final Map<int, int> orderTrend;

  _ReportData({
    required this.newUsers,
    required this.totalOrders,
    required this.completedOrders,
    required this.errorLogs,
    required this.loginTrend,
    required this.orderTrend,
  });

  factory _ReportData.fromSnapshots(
      QuerySnapshot<Map<String, dynamic>> users,
      QuerySnapshot<Map<String, dynamic>> orders,
      QuerySnapshot<Map<String, dynamic>> logs) {
    final loginTrend = <int, int>{};
    final orderTrend = <int, int>{};

    for (final d in users.docs) {
      final day = _dayKey(d.data()['createdAt']);
      loginTrend[day] = (loginTrend[day] ?? 0) + 1;
    }

    for (final d in orders.docs) {
      final day = _dayKey(d.data()['createdAt']);
      orderTrend[day] = (orderTrend[day] ?? 0) + 1;
    }

    final errors = logs.docs
        .map((e) => {
              'message': e.data()['message'] ?? '未知錯誤',
              'createdAt': DateFormat('MM/dd HH:mm').format(
                  (e.data()['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now()),
            })
        .toList();

    return _ReportData(
      newUsers: users.size,
      totalOrders: orders.size,
      completedOrders:
          orders.docs.where((d) => d.data()['status'] == 'completed').length,
      errorLogs: errors,
      loginTrend: loginTrend,
      orderTrend: orderTrend,
    );
  }

  static int _dayKey(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return dt.day;
    }
    return DateTime.now().day;
  }
}

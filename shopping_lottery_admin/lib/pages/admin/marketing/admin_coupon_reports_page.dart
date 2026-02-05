import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

class AdminCouponReportsPage extends StatefulWidget {
  const AdminCouponReportsPage({super.key});

  @override
  State<AdminCouponReportsPage> createState() => _AdminCouponReportsPageState();
}

class _AdminCouponReportsPageState extends State<AdminCouponReportsPage> {
  bool _loading = true;

  final List<Map<String, dynamic>> _couponStats = [];
  num _totalIssued = 0;
  num _totalUsed = 0;
  double _useRate = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);

    try {
      final coupons = await FirebaseFirestore.instance.collection('coupons').get();
      final now = DateTime.now();
      final df = DateFormat('yyyy/MM/dd');

      for (final doc in coupons.docs) {
        final data = doc.data();
        final couponId = doc.id;
        final title = (data['title'] ?? '').toString();
        final code = (data['code'] ?? '').toString();

        final userCouponsSnap = await FirebaseFirestore.instance
            .collectionGroup('user_coupons')
            .where('couponId', isEqualTo: couponId)
            .get();

        final total = userCouponsSnap.size;
        final used = userCouponsSnap.docs.where((d) => d.data()['status'] == 'used').length;
        final rate = total > 0 ? (used / total * 100).toDouble() : 0.0;

        _couponStats.add({
          'couponId': couponId,
          'title': title,
          'code': code,
          'total': total,
          'used': used,
          'rate': rate,
          'startAt': data['startAt'],
          'endAt': data['endAt'],
        });

        _totalIssued += total;
        _totalUsed += used;
      }

      if (_totalIssued > 0) {
        _useRate = _totalUsed / _totalIssued * 100;
      }

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('讀取報表資料失敗：$e')));
      setState(() => _loading = false);
    }
  }

  // =====================================================
  // 匯出報表
  // =====================================================

  void _exportCsv() {
    if (_couponStats.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('目前沒有報表資料可匯出')));
      return;
    }

    final rows = <List<dynamic>>[
      ['優惠券代碼', '名稱', '發送數', '使用數', '使用率(%)']
    ];
    for (final s in _couponStats) {
      rows.add([
        s['code'],
        s['title'],
        s['total'],
        s['used'],
        s['rate'].toStringAsFixed(2),
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([Uint8List.fromList(bytes)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'Osmile_Coupon_Report.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final df = NumberFormat('#,##0');
    final rf = NumberFormat('0.0#');

    return Scaffold(
      appBar: AppBar(
        title: const Text('優惠券使用報表', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
          IconButton(
            tooltip: '匯出 CSV',
            icon: const Icon(Icons.download),
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryCard(df, rf),
                const SizedBox(height: 20),
                _usageChart(),
                const SizedBox(height: 20),
                _couponRankingCard(),
              ],
            ),
    );
  }

  // =====================================================
  // Summary Card
  // =====================================================

  Widget _summaryCard(NumberFormat df, NumberFormat rf) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryTile('總發送數', df.format(_totalIssued), Colors.blueAccent),
            _summaryTile('已使用數', df.format(_totalUsed), Colors.teal),
            _summaryTile('使用率', '${rf.format(_useRate)}%', Colors.deepOrange),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: color.withOpacity(0.8))),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // 使用率折線圖
  // =====================================================

  Widget _usageChart() {
    if (_couponStats.isEmpty) {
      return const Center(child: Text('尚無資料可顯示'));
    }

    final sorted = _couponStats.toList()
      ..sort((a, b) => b['rate'].compareTo(a['rate']));
    final maxY = sorted.isNotEmpty
        ? sorted.map((e) => e['rate'] as double).reduce((a, b) => a > b ? a : b) + 10
        : 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('各優惠券使用率', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= sorted.length) return const SizedBox.shrink();
                          return Text(
                            sorted[i]['code'],
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  maxY: maxY,
                  barGroups: [
                    for (int i = 0; i < sorted.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: (sorted[i]['rate'] as double),
                            color: Colors.teal,
                            width: 18,
                            borderRadius: BorderRadius.circular(6),
                          )
                        ],
                      )
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
  // 使用率排行
  // =====================================================

  Widget _couponRankingCard() {
    if (_couponStats.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = _couponStats.toList()
      ..sort((a, b) => b['rate'].compareTo(a['rate']));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('使用率排行 TOP 10',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            ...sorted.take(10).map((s) {
              final rank = sorted.indexOf(s) + 1;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Text('$rank', style: const TextStyle(color: Colors.blue)),
                ),
                title: Text('${s['code']}｜${s['title']}'),
                trailing: Text(
                  '${s['rate'].toStringAsFixed(1)}%',
                  style: const TextStyle(
                      color: Colors.teal, fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

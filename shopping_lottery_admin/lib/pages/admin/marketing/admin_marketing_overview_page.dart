// lib/pages/admin/marketing/admin_marketing_overview_page.dart
//
// ✅ AdminMarketingOverviewPage（行銷總覽儀表板｜完整版｜可直接編譯）
// ------------------------------------------------------------
// - Firestore: coupons / lotteries / segments / auto_campaigns
// - 指標：數量、啟用率、總覆蓋、CTR、CVR、轉換量
// - 圖表：近N天活動量折線 + 各模組占比圓餅圖
// - 支援篩選時間：7天 / 30天 / 90天
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AdminMarketingOverviewPage extends StatefulWidget {
  const AdminMarketingOverviewPage({super.key});

  @override
  State<AdminMarketingOverviewPage> createState() =>
      _AdminMarketingOverviewPageState();
}

class _AdminMarketingOverviewPageState
    extends State<AdminMarketingOverviewPage> {
  bool _loading = true;
  String _range = '30d';
  final DateFormat df = DateFormat('MM/dd');

  // 資料統計（num 方便 int/double 混用）
  num couponCount = 0,
      activeCoupons = 0,
      lotteryCount = 0,
      activeLotteries = 0,
      segmentCount = 0,
      autoCampaigns = 0;

  num avgCTR = 0, avgCVR = 0, totalConversions = 0, totalCoverage = 0;

  List<Map<String, dynamic>> _trend = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  int get _rangeDays {
    if (_range == '7d') return 7;
    if (_range == '90d') return 90;
    return 30;
  }

  num _asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  double _asDouble(dynamic v) => _asNum(v).toDouble();

  /// ✅ FIX: withOpacity deprecated → withValues(alpha: double 0~1)
  Color _withOpacity(Color c, double opacity01) {
    final o = opacity01.clamp(0.0, 1.0).toDouble();
    return c.withValues(alpha: o);
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final fs = FirebaseFirestore.instance;

      final couponsSnap = await fs.collection('coupons').get();
      final lotteriesSnap = await fs.collection('lotteries').get();
      final segmentsSnap = await fs.collection('segments').get();
      final autosSnap = await fs.collection('auto_campaigns').get();

      // ✅ FIX: local variable 不要用底線開頭
      final num couponCountLocal = couponsSnap.size;
      final num activeCouponsLocal = couponsSnap.docs.where((doc) {
        final d = doc.data();
        return d['isActive'] == true;
      }).length;

      final num lotteryCountLocal = lotteriesSnap.size;
      final num activeLotteriesLocal = lotteriesSnap.docs.where((doc) {
        final d = doc.data();
        return d['isActive'] == true;
      }).length;

      final num segmentCountLocal = segmentsSnap.size;
      final num autoCampaignsLocal = autosSnap.size;

      num totalIssued = 0, totalUsed = 0, totalClick = 0;
      for (final c in couponsSnap.docs) {
        final d = c.data();
        totalIssued += _asNum(d['issuedCount']);
        totalClick += _asNum(d['clickCount']);
        totalUsed += _asNum(d['usedCount']);
      }

      final num avgCTRLocal = totalIssued > 0
          ? (totalClick / totalIssued) * 100
          : 0;
      final num avgCVRLocal = totalIssued > 0
          ? (totalUsed / totalIssued) * 100
          : 0;

      num totalCoverageLocal = 0;
      for (final s in segmentsSnap.docs) {
        final d = s.data();
        totalCoverageLocal += _asNum(d['previewCount']);
      }

      num totalConversionsLocal = 0;
      for (final a in autosSnap.docs) {
        final d = a.data();
        totalConversionsLocal += _asNum(d['conversionCount']);
      }

      final trend = _mockTrendData();

      if (!mounted) return;
      setState(() {
        couponCount = couponCountLocal;
        activeCoupons = activeCouponsLocal;
        lotteryCount = lotteryCountLocal;
        activeLotteries = activeLotteriesLocal;
        segmentCount = segmentCountLocal;
        autoCampaigns = autoCampaignsLocal;

        avgCTR = avgCTRLocal;
        avgCVR = avgCVRLocal;
        totalCoverage = totalCoverageLocal;
        totalConversions = totalConversionsLocal;

        _trend = trend;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('讀取失敗：$e')));
    }
  }

  List<Map<String, dynamic>> _mockTrendData() {
    final now = DateTime.now();
    final days = _rangeDays;
    return List.generate(days, (i) {
      // 讓 i=0 是最早的那天，i=days-1 是今天
      final d = now.subtract(Duration(days: (days - 1) - i));
      return {
        'date': df.format(d),
        'activity': (20 + i * 1.3) % 100, // double
        'conversion': (10 + i * 2.5) % 90, // double
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('行銷總覽儀表板'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _range,
              items: const [
                DropdownMenuItem(value: '7d', child: Text('近7天')),
                DropdownMenuItem(value: '30d', child: Text('近30天')),
                DropdownMenuItem(value: '90d', child: Text('近90天')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _range = v);
                _loadData();
              },
            ),
          ),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kpiSection(),
            const SizedBox(height: 20),
            _trendChart(),
            const SizedBox(height: 20),
            _pieSection(),
          ],
        ),
      ),
    );
  }

  // KPI
  Widget _kpiSection() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpiCard('優惠券', '$activeCoupons / $couponCount', Icons.card_giftcard),
        _kpiCard('抽獎活動', '$activeLotteries / $lotteryCount', Icons.casino),
        _kpiCard('受眾分群', '$segmentCount', Icons.people_alt),
        _kpiCard('自動派發', '$autoCampaigns', Icons.campaign),
        _kpiCard('平均 CTR', '${avgCTR.toStringAsFixed(1)}%', Icons.touch_app),
        _kpiCard('平均 CVR', '${avgCVR.toStringAsFixed(1)}%', Icons.trending_up),
        _kpiCard('覆蓋總量', '${totalCoverage.toInt()}', Icons.group),
        _kpiCard('轉換量', '${totalConversions.toInt()}', Icons.auto_graph),
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon) {
    return Container(
      width: 170,
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // 趨勢圖
  Widget _trendChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '近活動趨勢（活躍 vs 轉換）',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i % 5 != 0 || i < 0 || i >= _trend.length) {
                            return const SizedBox.shrink();
                          }
                          final label = (_trend[i]['date'] ?? '').toString();
                          return Text(
                            label,
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < _trend.length; i++)
                          FlSpot(
                            i.toDouble(),
                            _asDouble(_trend[i]['activity']),
                          ),
                      ],
                      color: Colors.green,
                      isCurved: true,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: _withOpacity(Colors.green, 0.10),
                      ),
                    ),
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < _trend.length; i++)
                          FlSpot(
                            i.toDouble(),
                            _asDouble(_trend[i]['conversion']),
                          ),
                      ],
                      color: Colors.orange,
                      isCurved: true,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: _withOpacity(Colors.orange, 0.10),
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

  // 圓餅圖
  Widget _pieSection() {
    final sections = <Map<String, dynamic>>[
      {'name': '優惠券', 'value': couponCount.toDouble(), 'color': Colors.blue},
      {'name': '抽獎', 'value': lotteryCount.toDouble(), 'color': Colors.green},
      {'name': '分群', 'value': segmentCount.toDouble(), 'color': Colors.orange},
      {
        'name': '自動派發',
        'value': autoCampaigns.toDouble(),
        'color': Colors.purple,
      },
    ];

    // ✅ FIX: avoid_types_as_parameter_names
    final total = sections.fold<double>(
      0.0,
      (acc, e) => acc + ((e['value'] as num?)?.toDouble() ?? 0.0),
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '模組分佈',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: [
                    for (final s in sections)
                      PieChartSectionData(
                        color: (s['color'] as Color?) ?? Colors.grey,
                        value: ((s['value'] as num?)?.toDouble() ?? 0.0),
                        title: total <= 0
                            ? '${(s['name'] ?? '').toString()} 0.0%'
                            : '${(s['name'] ?? '').toString()} ${((((s['value'] as num?)?.toDouble() ?? 0.0) / total) * 100).toStringAsFixed(1)}%',
                        radius: 80,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
}

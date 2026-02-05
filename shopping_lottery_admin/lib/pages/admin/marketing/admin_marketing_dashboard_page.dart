import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// ✅ AdminMarketingDashboardPage（行銷中心儀表板｜完整版 v2.0.0）
/// ------------------------------------------------------------
/// - 整合 Firestore 集合：coupons / lotteries / segments / auto_campaigns
/// - 指標：CTR、CVR、抽獎轉換率、自動派發成效
/// - 圖表：CTR/CVR 對比、Top5 優惠券使用率、Top5 自動派發轉換量
/// - 含完整錯誤處理與容錯保護
/// ------------------------------------------------------------
class AdminMarketingDashboardPage extends StatefulWidget {
  const AdminMarketingDashboardPage({super.key});

  @override
  State<AdminMarketingDashboardPage> createState() =>
      _AdminMarketingDashboardPageState();
}

class _AdminMarketingDashboardPageState
    extends State<AdminMarketingDashboardPage> {
  bool _loading = true;
  int couponCount = 0;
  int activeCoupons = 0;
  int lotteryCount = 0;
  int activeLotteries = 0;
  int segmentCount = 0;
  int autoCampaigns = 0;

  num avgCTR = 0;
  num avgCVR = 0;
  num avgLotteryCVR = 0;
  num totalConversions = 0;

  List<MapEntry<String, double>> topCoupons = [];
  List<MapEntry<String, double>> topAuto = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final fs = FirebaseFirestore.instance;

      final couponSnap = await fs.collection('coupons').get();
      final lotterySnap = await fs.collection('lotteries').get();
      final segSnap = await fs.collection('segments').get();
      final autoSnap = await fs.collection('auto_campaigns').get();

      // 基本統計
      couponCount = couponSnap.size;
      activeCoupons = couponSnap.docs.where((d) => d['isActive'] == true).length;
      lotteryCount = lotterySnap.size;
      activeLotteries =
          lotterySnap.docs.where((d) => d['isActive'] == true).length;
      segmentCount = segSnap.size;
      autoCampaigns = autoSnap.size;

      // CTR / CVR
      num totalIssued = 0, totalClicks = 0, totalUsed = 0;
      for (final e in couponSnap.docs) {
        final issued = (e['issuedCount'] ?? 0) as num;
        final clicks = (e['clickCount'] ?? 0) as num;
        final used = (e['usedCount'] ?? 0) as num;
        if (issued > 0) {
          totalIssued += issued;
          totalClicks += clicks;
          totalUsed += used;
        }
      }
      avgCTR = totalIssued > 0 ? (totalClicks / totalIssued) * 100 : 0;
      avgCVR = totalIssued > 0 ? (totalUsed / totalIssued) * 100 : 0;

      // 抽獎平均轉換率
      num totalParticipants = 0, totalWinners = 0;
      for (final e in lotterySnap.docs) {
        final p = (e['participants'] as List?)?.length ?? 0;
        final w = (e['winners'] as List?)?.length ?? 0;
        totalParticipants += p;
        totalWinners += w;
      }
      avgLotteryCVR =
          totalParticipants > 0 ? (totalWinners / totalParticipants) * 100 : 0;

      // 自動派發總轉換量
      totalConversions = autoSnap.docs.fold<num>(
          0, (sum, e) => sum + ((e['conversionCount'] ?? 0) as num));

      // Top 5 優惠券
      final couponEntries = couponSnap.docs.map((e) {
        final issued = (e['issuedCount'] ?? 0) as num;
        final used = (e['usedCount'] ?? 0) as num;
        final rate = issued > 0 ? (used / issued) * 100 : 0.0;
        return MapEntry((e['title'] ?? '未命名').toString(), rate.toDouble());
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topCoupons = couponEntries.take(5).toList();

      // Top 5 自動派發活動
      final autoEntries = autoSnap.docs.map((e) {
        final conv = (e['conversionCount'] ?? 0) as num;
        return MapEntry((e['title'] ?? '未命名').toString(), conv.toDouble());
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topAuto = autoEntries.take(5).toList();

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('資料讀取失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('行銷中心儀表板'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh))
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCards(),
          const SizedBox(height: 20),
          _buildRateChart('優惠券 CTR / CVR', avgCTR.toDouble(), avgCVR.toDouble()),
          const SizedBox(height: 20),
          _buildBarChart('Top 5 優惠券使用率', topCoupons, Colors.green),
          const SizedBox(height: 20),
          _buildBarChart('Top 5 自動派發轉換量', topAuto, Colors.orange),
        ],
      ),
    );
  }

  // =====================================================
  // 統計卡片區
  // =====================================================
  Widget _summaryCards() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _statCard('優惠券', '$activeCoupons / $couponCount', Icons.local_offer),
        _statCard('抽獎活動', '$activeLotteries / $lotteryCount', Icons.casino),
        _statCard('受眾分群', '$segmentCount', Icons.people_alt),
        _statCard('自動派發', '$autoCampaigns', Icons.campaign),
        _statCard('平均 CTR', '${avgCTR.toStringAsFixed(1)}%', Icons.touch_app),
        _statCard('平均 CVR', '${avgCVR.toStringAsFixed(1)}%', Icons.trending_up),
        _statCard('抽獎轉換率', '${avgLotteryCVR.toStringAsFixed(1)}%', Icons.card_giftcard),
        _statCard('總轉換量', '$totalConversions', Icons.auto_graph),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
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
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // =====================================================
  // CTR / CVR 比較圖
  // =====================================================
  Widget _buildRateChart(String title, double ctr, double cvr) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [
                      BarChartRodData(toY: ctr, color: Colors.blueAccent, width: 40)
                    ]),
                    BarChartGroupData(x: 1, barRods: [
                      BarChartRodData(toY: cvr, color: Colors.green, width: 40)
                    ]),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          if (v.toInt() == 0) return const Text('CTR');
                          if (v.toInt() == 1) return const Text('CVR');
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  maxY: 100,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // Top 5 柱狀圖（優惠券 / 自動派發）
  // =====================================================
  Widget _buildBarChart(String title, List<MapEntry<String, double>> entries, Color color) {
    if (entries.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$title：無資料'),
        ),
      );
    }

    final maxY =
        entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) + 5.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 70,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= entries.length)
                            return const SizedBox.shrink();
                          return Text(
                            entries[i].key,
                            style: const TextStyle(fontSize: 10),
                            textAlign: TextAlign.center,
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) =>
                            Text('${v.toInt()}'),
                      ),
                    ),
                  ),
                  maxY: maxY,
                  barGroups: [
                    for (int i = 0; i < entries.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: entries[i].value,
                          color: color,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ]),
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

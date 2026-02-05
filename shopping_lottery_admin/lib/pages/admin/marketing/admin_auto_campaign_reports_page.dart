import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// ✅ AdminAutoCampaignReportsPage（自動派發活動報表｜完整可編譯）
/// ------------------------------------------------------------
/// Firestore 集合：auto_campaigns
/// - 顯示活動名稱、轉換率、觸發次數、啟用狀態
/// - 長條圖：各活動轉換量排行
/// - 折線圖：每週轉換趨勢
/// ------------------------------------------------------------
class AdminAutoCampaignReportsPage extends StatefulWidget {
  const AdminAutoCampaignReportsPage({super.key});

  @override
  State<AdminAutoCampaignReportsPage> createState() =>
      _AdminAutoCampaignReportsPageState();
}

class _AdminAutoCampaignReportsPageState
    extends State<AdminAutoCampaignReportsPage> {
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> campaigns = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('auto_campaigns')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        campaigns = snap.docs;
        _loading = false;
      });
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('自動派發活動報表'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh))
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(),
          const SizedBox(height: 20),
          _conversionBarChart(),
          const SizedBox(height: 20),
          _weeklyLineChart(),
        ],
      ),
    );
  }

  // =====================================================
  // Summary Card
  // =====================================================

  Widget _summaryCard() {
    final total = campaigns.length;
    final active = campaigns.where((e) => e['isActive'] == true).length;
    final totalConversions = campaigns.fold<num>(
        0, (sum, e) => sum + (e['conversionCount'] ?? 0) as num);
    final avgConversion = total > 0 ? totalConversions / total : 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _metric('活動數量', '$total'),
            _metric('啟用中', '$active'),
            _metric('總轉換量', '$totalConversions'),
            _metric('平均轉換量', avgConversion.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }

  Widget _metric(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      ],
    );
  }

  // =====================================================
  // Conversion Bar Chart
  // =====================================================

  Widget _conversionBarChart() {
    final entries = campaigns.map((e) {
      final conv = (e['conversionCount'] ?? 0) as num;
      return MapEntry((e['title'] ?? '未命名').toString(), conv.toDouble());
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final limited = entries.take(10).toList();
    final maxY = limited.isEmpty
        ? 10.0
        : limited.map((e) => e.value).reduce((a, b) => a > b ? a : b) + 5.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('轉換量排行（前 10 名）',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (limited.isEmpty)
              const Text('目前沒有資料')
            else
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            if (i < 0 || i >= limited.length)
                              return const SizedBox.shrink();
                            return Text(
                              limited[i].key,
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                          getTitlesWidget: (v, meta) => Text('${v.toInt()}'),
                        ),
                      ),
                    ),
                    maxY: maxY,
                    barGroups: [
                      for (int i = 0; i < limited.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: limited[i].value,
                              color: Colors.blueAccent,
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                            ),
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
  // Weekly Line Chart (Simulated Trend)
  // =====================================================

  Widget _weeklyLineChart() {
    // 模擬每週轉換成長（實務上可用 Firestore aggregate 記錄每日 conversion）
    final now = DateTime.now();
    final weeks = List.generate(6, (i) => now.subtract(Duration(days: i * 7)))
      ..sort((a, b) => a.compareTo(b));

    final randomData = List.generate(weeks.length, (i) => (i * 20 + 50).toDouble());
    final spots = List.generate(
      weeks.length,
      (i) => FlSpot(i.toDouble(), randomData[i]),
    );

    final df = DateFormat('MM/dd');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('近 6 週轉換趨勢',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: Colors.orangeAccent,
                      barWidth: 4,
                      belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.2)),
                      spots: spots,
                    )
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= weeks.length)
                            return const SizedBox.shrink();
                          return Text(df.format(weeks[i]),
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (v, meta) => Text('${v.toInt()}'),
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

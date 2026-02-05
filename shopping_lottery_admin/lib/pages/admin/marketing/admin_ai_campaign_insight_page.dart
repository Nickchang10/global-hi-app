// ✅ AdminAICampaignInsightPage（AI 行銷智能預測｜完整版）
// ------------------------------------------------------------
// - 結合 Firestore 行銷資料（coupons / lotteries / segments）
// - AI 模型預測（模擬 GPT 或 ML 推論結果）
// - 提供智能建議：推播、優惠券發送、抽獎推薦
// - 圖表顯示各活動潛力與成效預測
// - 具備 KPI + 趨勢 + 智能策略卡
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class AdminAICampaignInsightPage extends StatefulWidget {
  const AdminAICampaignInsightPage({super.key});

  @override
  State<AdminAICampaignInsightPage> createState() =>
      _AdminAICampaignInsightPageState();
}

class _AdminAICampaignInsightPageState
    extends State<AdminAICampaignInsightPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _segments = [];
  List<Map<String, dynamic>> _insights = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ------------------------------------------------------------
  // 讀取 Firestore 資料並生成 AI 建議
  // ------------------------------------------------------------
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final fs = FirebaseFirestore.instance;
      final segSnap = await fs.collection('segments').get();
      final List<Map<String, dynamic>> list = [];

      for (final doc in segSnap.docs) {
        final d = doc.data();
        list.add({
          'id': doc.id,
          'title': (d['title'] ?? '未命名分群').toString(),
          'previewCount': (d['previewCount'] ?? 0) as num,
          'conversionRate': ((d['conversionRate'] ?? Random().nextDouble() * 5)
                  as num)
              .toDouble(),
        });
      }

      _segments = list;
      _insights = _generateAIInsights(list);

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('讀取失敗：$e')));
    }
  }

  // ------------------------------------------------------------
  // 模擬 AI 推論結果
  // ------------------------------------------------------------
  List<Map<String, dynamic>> _generateAIInsights(
      List<Map<String, dynamic>> segments) {
    final rng = Random();
    return segments.map((s) {
      final conv = s['conversionRate'] ?? 0.0;
      final score = (conv * 2 + rng.nextDouble() * 20).clamp(0, 100);
      String suggestion;

      if (score > 75) {
        suggestion = '推薦進行高價值推播與專屬優惠券活動';
      } else if (score > 50) {
        suggestion = '適合搭配抽獎活動提高互動率';
      } else if (score > 30) {
        suggestion = '建議嘗試限時優惠吸引再回購';
      } else {
        suggestion = '應先進行再喚醒推播或回流任務';
      }

      return {
        'segment': s['title'],
        'score': score,
        'recommendation': suggestion,
        'predictedLift': (rng.nextDouble() * 20).toStringAsFixed(1),
        'expectedROI': (rng.nextDouble() * 3 + 1).toStringAsFixed(1),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 行銷智能預測'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _aiSummaryCards(),
          const SizedBox(height: 20),
          _aiPredictionChart(),
          const SizedBox(height: 20),
          _aiRecommendations(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // KPI 區域
  // ------------------------------------------------------------
  Widget _aiSummaryCards() {
    if (_insights.isEmpty) return const SizedBox.shrink();

    final avgScore =
        _insights.map((e) => e['score'] as num).reduce((a, b) => a + b) /
            _insights.length;
    final avgROI = _insights
            .map((e) => double.parse(e['expectedROI'].toString()))
            .reduce((a, b) => a + b) /
        _insights.length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpiCard('AI 平均成效分數', avgScore.toStringAsFixed(1), Icons.auto_graph),
        _kpiCard('平均預估 ROI', '${avgROI.toStringAsFixed(1)}x', Icons.paid),
        _kpiCard('建議策略數', '${_insights.length}', Icons.lightbulb),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon) {
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
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // AI 成效預測圖
  // ------------------------------------------------------------
  Widget _aiPredictionChart() {
    final items = _insights.take(5).toList();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top 5 分群 AI 成效預測',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= items.length)
                            return const SizedBox.shrink();
                          return Text(items[i]['segment'],
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center);
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) =>
                              Text('${v.toInt()}')),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < items.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: (items[i]['score'] ?? 0).toDouble(),
                          color: Colors.deepPurple,
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ]),
                  ],
                  maxY: 100,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // AI 建議清單
  // ------------------------------------------------------------
  Widget _aiRecommendations() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI 智能建議',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (_insights.isEmpty)
              const Text('暫無資料'),
            if (_insights.isNotEmpty)
              ..._insights.map(
                (e) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade100,
                    child: const Icon(Icons.insights, color: Colors.deepPurple),
                  ),
                  title: Text(e['segment']),
                  subtitle: Text(e['recommendation']),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('成效 ${e['score'].toStringAsFixed(1)}',
                          style: const TextStyle(color: Colors.blue)),
                      Text('ROI ×${e['expectedROI']}',
                          style: const TextStyle(color: Colors.green)),
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

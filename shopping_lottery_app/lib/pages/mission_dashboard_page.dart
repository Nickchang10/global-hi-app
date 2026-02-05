import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

/// 📊 任務進度儀表板（MissionDashboardPage）
///
/// 功能：
/// ✅ 顯示使用者總積分與近七日變化
/// ✅ 顯示任務完成率圓環圖
/// ✅ 顯示每日、每週、活動任務分佈統計
/// ✅ 資料來源：point_history（SharedPreferences）
class MissionDashboardPage extends StatefulWidget {
  const MissionDashboardPage({super.key});

  @override
  State<MissionDashboardPage> createState() => _MissionDashboardPageState();
}

class _MissionDashboardPageState extends State<MissionDashboardPage> {
  int totalPoints = 0;
  List<Map<String, dynamic>> _history = [];
  Map<String, int> _categoryCount = {};
  List<FlSpot> _trendPoints = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList("point_history") ?? [];
    final parsed = data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    // 🧮 計算總積分
    totalPoints = parsed.fold(0, (sum, e) => sum + (e["value"] as int? ?? 0));

    // 📊 類別統計
    final Map<String, int> categoryCount = {};
    for (var e in parsed) {
      final src = e["source"] ?? "其他";
      categoryCount[src] = (categoryCount[src] ?? 0) + 1;
    }

    // 📈 趨勢圖資料（近 7 天）
    final now = DateTime.now();
    final Map<String, int> dayPoints = {};
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final label = "${day.month}/${day.day}";
      dayPoints[label] = 0;
    }

    for (var e in parsed) {
      final date = DateTime.tryParse(e["time"] ?? "");
      if (date != null && now.difference(date).inDays <= 6) {
        final label = "${date.month}/${date.day}";
        dayPoints[label] = (dayPoints[label] ?? 0) + (e["value"] ?? 0);
      }
    }

    final trend = <FlSpot>[];
    int x = 0;
    for (var v in dayPoints.values) {
      trend.add(FlSpot(x.toDouble(), v.toDouble()));
      x++;
    }

    setState(() {
      _history = parsed;
      _categoryCount = categoryCount;
      _trendPoints = trend;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 任務進度儀表板"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F9FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 20),
            _buildTrendChart(),
            const SizedBox(height: 20),
            _buildCategoryChart(),
            const SizedBox(height: 20),
            _buildRecentMissions(),
          ],
        ),
      ),
    );
  }

  // 🧾 總積分
  Widget _buildSummaryCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("目前累積積分",
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 6),
            Text(
              "$totalPoints 分",
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }

  // 📈 趨勢折線圖
  Widget _buildTrendChart() {
    if (_trendPoints.isEmpty) {
      return const Center(child: Text("尚無任務趨勢資料"));
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("📈 最近七日積分趨勢",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _trendPoints,
                      isCurved: true,
                      color: Colors.blueAccent,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blueAccent.withOpacity(0.2),
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

  // 🥧 任務類別統計圖
  Widget _buildCategoryChart() {
    if (_categoryCount.isEmpty) {
      return const Center(child: Text("尚無任務類別資料"));
    }

    final total = _categoryCount.values.fold(0, (a, b) => a + b);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("🧩 任務完成類別分佈",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Column(
              children: _categoryCount.entries.map((e) {
                final ratio = (e.value / total * 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text("${e.key}（$ratio%）",
                            style: const TextStyle(fontSize: 14)),
                      ),
                      SizedBox(
                        width: 140,
                        child: LinearProgressIndicator(
                          value: e.value / total,
                          color: Colors.blueAccent,
                          backgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // 🕓 最近任務列表
  Widget _buildRecentMissions() {
    if (_history.isEmpty) return const SizedBox();

    final recent = _history.take(5).toList();
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("🕓 最近任務紀錄",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...recent.map((h) {
              return ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(h["note"] ?? "任務"),
                subtitle: Text(h["source"] ?? "未知"),
                trailing: Text("+${h["value"]}",
                    style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold)),
              );
            }),
          ],
        ),
      ),
    );
  }
}

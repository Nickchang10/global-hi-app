import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

/// 💰 積分明細頁（PointsHistoryPage）
///
/// 功能：
/// ✅ 顯示所有積分變化（任務、購物、登入等）
/// ✅ 顯示積分折線趨勢圖
/// ✅ 支援搜尋、排序、清除紀錄
class PointsHistoryPage extends StatefulWidget {
  const PointsHistoryPage({super.key});

  @override
  State<PointsHistoryPage> createState() => _PointsHistoryPageState();
}

class _PointsHistoryPageState extends State<PointsHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filtered = [];
  List<FlSpot> _trend = [];
  String _keyword = "";
  bool _desc = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// 📦 從 SharedPreferences 讀取積分紀錄
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList("point_history") ?? [];

    final parsed =
        data.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    parsed.sort((a, b) =>
        _desc ? b["time"].compareTo(a["time"]) : a["time"].compareTo(b["time"]));

    _generateTrend(parsed);

    setState(() {
      _history = parsed;
      _filtered = parsed;
    });
  }

  /// 📈 產生近七日積分折線資料
  void _generateTrend(List<Map<String, dynamic>> data) {
    final now = DateTime.now();
    final Map<String, int> daily = {};

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = "${day.month}/${day.day}";
      daily[key] = 0;
    }

    for (var e in data) {
      final t = DateTime.tryParse(e["time"] ?? "");
      if (t != null && now.difference(t).inDays <= 6) {
        final key = "${t.month}/${t.day}";
        final addedValue = e["value"] ?? 0;
        daily[key] = ((daily[key] ?? 0) as int) +
            (addedValue is int
                ? addedValue
                : int.tryParse(addedValue.toString()) ?? 0);
      }
    }

    final List<FlSpot> trend = [];
    int x = 0;
    for (var v in daily.values) {
      trend.add(FlSpot(x.toDouble(), v.toDouble()));
      x++;
    }

    _trend = trend;
  }

  /// 🔍 搜尋紀錄
  void _search(String keyword) {
    setState(() {
      _keyword = keyword.trim();
      _filtered = _history
          .where((h) =>
              h["source"].toString().contains(_keyword) ||
              h["note"].toString().contains(_keyword))
          .toList();
    });
  }

  /// 🧹 清除所有積分紀錄
  Future<void> _clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("point_history");
    setState(() {
      _history.clear();
      _filtered.clear();
      _trend.clear();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("已清除積分紀錄")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("💰 積分明細"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert),
            tooltip: "切換排序",
            onPressed: () {
              setState(() {
                _desc = !_desc;
                _history = _history.reversed.toList();
                _filtered = _filtered.reversed.toList();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "清除紀錄",
            onPressed: _clearAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildSearchBar(),
          ),
        ),
      ),
      body: _filtered.isEmpty
          ? const Center(
              child: Text("目前沒有積分紀錄",
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
            )
          : ListView(
              children: [
                const SizedBox(height: 10),
                _buildTrendChart(),
                const SizedBox(height: 20),
                _buildHistoryList(),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  // 🔍 搜尋框
  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: "搜尋任務名稱、來源...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        suffixIcon: _keyword.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _search(""),
              )
            : null,
      ),
      onChanged: _search,
    );
  }

  // 📈 積分趨勢折線圖
  Widget _buildTrendChart() {
    if (_trend.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("📈 最近七日積分趨勢",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _trend,
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

  // 📜 積分明細清單
  Widget _buildHistoryList() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Column(
        children: _filtered.map((h) {
          final date = DateTime.tryParse(h["time"] ?? "");
          final timeLabel = date == null
              ? ""
              : "${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
          return ListTile(
            leading: const Icon(Icons.stars, color: Colors.amber),
            title: Text(h["note"] ?? "未知任務"),
            subtitle: Text("${h["source"] ?? "系統"} ・ $timeLabel"),
            trailing: Text(
              "+${h["value"]}",
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

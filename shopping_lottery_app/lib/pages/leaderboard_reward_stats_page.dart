import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

class LeaderboardRewardStatsPage extends StatefulWidget {
  const LeaderboardRewardStatsPage({super.key});

  @override
  State<LeaderboardRewardStatsPage> createState() =>
      _LeaderboardRewardStatsPageState();
}

class _LeaderboardRewardStatsPageState
    extends State<LeaderboardRewardStatsPage> {
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// 📥 讀取 7 日歷史獎勵
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('leaderboardRewardHistory') ?? [];
    setState(() {
      _history = data
          .map((e) => Map<String, dynamic>.from(jsonDecode(e)))
          .toList()
          .reversed
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPoints =
        _history.fold<int>(0, (sum, e) => sum + (e["reward"] as int));
    final average = _history.isEmpty ? 0 : totalPoints / _history.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 排行榜獎勵統計"),
      ),
      body: _history.isEmpty
          ? const Center(
              child: Text("目前沒有足夠資料顯示統計圖 😅",
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  Text(
                    "最近 ${_history.length} 天統計",
                    style: GoogleFonts.notoSansTc(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "總獎勵：$totalPoints 積分｜平均每日：${average.toStringAsFixed(1)} 積分",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  // 📊 長條圖
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            "📅 每日獎勵變化圖（Bar Chart）",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 220,
                            child: BarChart(
                              BarChartData(
                                borderData: FlBorderData(show: false),
                                gridData: const FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles:
                                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles:
                                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles:
                                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        int index = value.toInt();
                                        if (index < 0 || index >= _history.length) {
                                          return const SizedBox();
                                        }
                                        final date = _history[index]["date"];
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            date.split('-').last,
                                            style: const TextStyle(
                                                fontSize: 10, color: Colors.grey),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: _history
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) => BarChartGroupData(
                                        x: entry.key,
                                        barRods: [
                                          BarChartRodData(
                                            toY: (entry.value["reward"] as int).toDouble(),
                                            color: Colors.blueAccent,
                                            width: 14,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(4)),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 🍩 圓餅圖
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            "🥇 名次佔比圖（Pie Chart）",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 220,
                            child: PieChart(
                              PieChartData(
                                sections: _buildPieSections(),
                                centerSpaceRadius: 40,
                                sectionsSpace: 2,
                              ),
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

  /// 🥧 產生圓餅圖資料
  List<PieChartSectionData> _buildPieSections() {
    final rankCounts = <int, int>{1: 0, 2: 0, 3: 0};
    for (var e in _history) {
      final rank = e["rank"] as int;
      if (rankCounts.containsKey(rank)) {
        rankCounts[rank] = rankCounts[rank]! + 1;
      }
    }

    final colors = {
      1: Colors.amber,
      2: Colors.grey,
      3: Colors.brown,
    };

    return rankCounts.entries
        .map((e) => PieChartSectionData(
              color: colors[e.key],
              value: e.value.toDouble(),
              title: "第${e.key}名\n${e.value}天",
              titleStyle: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ))
        .toList();
  }
}

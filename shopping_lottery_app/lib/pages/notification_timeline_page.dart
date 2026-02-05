import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

/// 📈 通知分析儀表板頁面（含圓餅圖、折線圖、來源排行榜）
class NotificationTimelinePage extends StatefulWidget {
  const NotificationTimelinePage({super.key});

  @override
  State<NotificationTimelinePage> createState() =>
      _NotificationTimelinePageState();
}

class _NotificationTimelinePageState extends State<NotificationTimelinePage> {
  bool _onlyUnread = false;

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<NotificationService>(context);
    final all = notifier.notifications;

    final filtered =
        _onlyUnread ? all.where((n) => n["unread"] == true).toList() : all;

    // 日期分組
    final now = DateTime.now();
    final today = <Map<String, dynamic>>[];
    final yesterday = <Map<String, dynamic>>[];
    final earlier = <Map<String, dynamic>>[];

    for (final n in filtered) {
      final t = n["time"] as DateTime;
      final d = DateTime(t.year, t.month, t.day);
      final todayDate = DateTime(now.year, now.month, now.day);
      final yestDate = todayDate.subtract(const Duration(days: 1));

      if (d == todayDate) {
        today.add(n);
      } else if (d == yestDate) {
        yesterday.add(n);
      } else {
        earlier.add(n);
      }
    }

    final sections = [
      if (today.isNotEmpty) ("今天", today),
      if (yesterday.isNotEmpty) ("昨天", yesterday),
      if (earlier.isNotEmpty) ("更早以前", earlier),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("通知分析儀表板"),
        backgroundColor: const Color(0xFF007BFF),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => setState(() => _onlyUnread = !_onlyUnread),
            child: Text(
              _onlyUnread ? "顯示全部" : "只看未讀",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: filtered.isEmpty
          ? Center(
              child: Text(
                _onlyUnread ? "目前沒有未讀通知" : "目前沒有通知記錄",
                style: const TextStyle(color: Colors.black54, fontSize: 16),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatsChart(filtered),
                const SizedBox(height: 16),
                _buildTrendChart(filtered),
                const SizedBox(height: 16),
                _buildSourceRanking(filtered),
                const SizedBox(height: 24),
                for (final (title, list) in sections) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF007BFF),
                      ),
                    ),
                  ),
                  ...list.map(
                      (n) => _buildNotificationItem(context, notifier, n)),
                ],
              ],
            ),
    );
  }

  /// 📊 圓餅統計圖（類型比例）
  Widget _buildStatsChart(List<Map<String, dynamic>> list) {
    final Map<String, int> counts = {
      "優惠": 0,
      "出貨": 0,
      "公告": 0,
      "其他": 0,
    };

    for (final n in list) {
      final title = n["title"]?.toString() ?? "";
      if (title.contains("優惠") || title.contains("折扣")) {
        counts["優惠"] = counts["優惠"]! + 1;
      } else if (title.contains("出貨") || title.contains("物流")) {
        counts["出貨"] = counts["出貨"]! + 1;
      } else if (title.contains("公告") || title.contains("通知")) {
        counts["公告"] = counts["公告"]! + 1;
      } else {
        counts["其他"] = counts["其他"]! + 1;
      }
    }

    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox();

    final sections = counts.entries
        .where((e) => e.value > 0)
        .map(
          (e) => PieChartSectionData(
            color: _getColor(e.key),
            value: e.value.toDouble(),
            title: "${e.key}\n${e.value}",
            radius: 60,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "推播類型統計",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF007BFF)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 📈 推播趨勢折線圖
  Widget _buildTrendChart(List<Map<String, dynamic>> list) {
    final now = DateTime.now();
    final Map<String, int> daily = {};

    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = "${d.month}/${d.day}";
      daily[key] = 0;
    }

    for (final n in list) {
      final t = n["time"] as DateTime;
      final key = "${t.month}/${t.day}";
      if (daily.containsKey(key)) daily[key] = daily[key]! + 1;
    }

    final spots = <FlSpot>[];
    var index = 0;
    for (final e in daily.entries) {
      spots.add(FlSpot(index.toDouble(), e.value.toDouble()));
      index++;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "近 7 日推播趨勢",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF007BFF)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: true)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= daily.keys.length) {
                          return const SizedBox();
                        }
                        return Text(
                          daily.keys.elementAt(i),
                          style:
                              const TextStyle(fontSize: 10, color: Colors.black54),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    spots: spots,
                    color: const Color(0xFF007BFF),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🏆 通知來源排行榜
  Widget _buildSourceRanking(List<Map<String, dynamic>> list) {
    final Map<String, int> sources = {
      "行銷中心": 0,
      "物流部門": 0,
      "系統公告": 0,
      "其他": 0,
    };

    for (final n in list) {
      final msg = n["message"]?.toString() ?? "";
      if (msg.contains("折扣") || msg.contains("優惠")) {
        sources["行銷中心"] = sources["行銷中心"]! + 1;
      } else if (msg.contains("出貨") || msg.contains("物流")) {
        sources["物流部門"] = sources["物流部門"]! + 1;
      } else if (msg.contains("公告") || msg.contains("更新")) {
        sources["系統公告"] = sources["系統公告"]! + 1;
      } else {
        sources["其他"] = sources["其他"]! + 1;
      }
    }

    final sorted = sources.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final data = sorted.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "通知來源排行榜 (Top 3)",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF007BFF),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: true)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i >= data.length) return const SizedBox();
                        return Text(
                          data[i].key,
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(data.length, (i) {
                  final e = data[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.toDouble(),
                        color: const Color(0xFF007BFF),
                        width: 24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      );

  Color _getColor(String category) {
    switch (category) {
      case "優惠":
        return Colors.blue;
      case "出貨":
        return Colors.green;
      case "公告":
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildNotificationItem(
      BuildContext context, NotificationService notifier, Map<String, dynamic> n) {
    final unread = n["unread"] == true;
    final DateTime time = n["time"];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              unread ? const Color(0xFF007BFF).withOpacity(0.6) : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF007BFF).withOpacity(0.1),
            child: Icon(n["icon"] ?? Icons.notifications,
                color: const Color(0xFF007BFF), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n["title"] ?? "",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: unread ? const Color(0xFF007BFF) : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  n["message"] ?? "",
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTime(time),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}

// lib/pages/leaderboard_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<Map<String, dynamic>> _players = <Map<String, dynamic>>[];
  DateTime? _lastReset;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initLeaderboard();
  }

  Future<void> _initLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetStr = prefs.getString('leaderboard_last_reset');
    if (lastResetStr != null) {
      _lastReset = DateTime.tryParse(lastResetStr);
    }

    final now = DateTime.now();
    if (_lastReset == null || _isNewWeek(now, _lastReset!)) {
      _players = List.generate(10, (i) => {'name': '玩家${i + 1}', 'points': 0});
      await prefs.setString('leaderboard_last_reset', now.toIso8601String());
    } else {
      _players = List.generate(
        10,
        (i) => {'name': '玩家${i + 1}', 'points': 500 - i * 30},
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  bool _isNewWeek(DateTime now, DateTime lastReset) {
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    final lastMonday = lastReset.subtract(
      Duration(days: lastReset.weekday - 1),
    );
    return thisMonday.isAfter(lastMonday);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final now = DateTime.now();
    final weekEnd = now.add(Duration(days: 7 - now.weekday));

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 本週積分排行榜'),
        backgroundColor: Colors.blue,
      ),
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._players.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    final rank = i + 1;

                    Color badgeColor;
                    IconData? icon;
                    switch (rank) {
                      case 1:
                        badgeColor = Colors.amber;
                        icon = Icons.emoji_events;
                        break;
                      case 2:
                        badgeColor = Colors.grey.shade400;
                        icon = Icons.emoji_events_outlined;
                        break;
                      case 3:
                        badgeColor = Colors.brown.shade300;
                        icon = Icons.emoji_events_outlined;
                        break;
                      default:
                        badgeColor = Colors.blue.shade100;
                        break;
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: rank <= 3
                            ? LinearGradient(
                                colors: [
                                  badgeColor.withValues(alpha: 0.9),
                                  badgeColor.withValues(alpha: 0.6),
                                ],
                              )
                            : null,
                        color: rank > 3 ? Colors.white : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: badgeColor,
                          child: icon != null
                              ? Icon(icon, size: 20, color: Colors.white)
                              : Text(
                                  '$rank',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        title: Text(p['name'] as String),
                        trailing: Text(
                          '${p['points']} 分',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    '📅 本週截止：${weekEnd.year}/${weekEnd.month}/${weekEnd.day}',
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

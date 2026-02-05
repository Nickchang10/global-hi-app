import 'package:flutter/material.dart';
import '../services/level_service.dart';
import '../services/leaderboard_service.dart';

class BadgeWallPage extends StatelessWidget {
  const BadgeWallPage({super.key});

  @override
  Widget build(BuildContext context) {
    final level = LevelService.instance;
    final lb = LeaderboardService.instance;

    return AnimatedBuilder(
      animation: level,
      builder: (context, _) {
        final badge = lb.getBadge(level.xp);
        return Scaffold(
          backgroundColor: const Color(0xFFF2F6F9),
          appBar: AppBar(
            title: const Text("🏅 我的勳章牆"),
            backgroundColor: Colors.teal,
            centerTitle: true,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  badge,
                  style: const TextStyle(fontSize: 60),
                ),
                const SizedBox(height: 20),
                Text(
                  "XP: ${level.xp}",
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    lb.notifyLevelUp(badge);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("🎉 恭喜獲得徽章：$badge"),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text("分享榮耀"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

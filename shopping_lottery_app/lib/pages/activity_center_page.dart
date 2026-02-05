import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/daily_reward_service.dart';
import 'package:osmile_shopping_app/services/leaderboard_reward_service.dart';
import 'package:osmile_shopping_app/services/firestore_mock_service.dart';

/// 🎯 活動任務中心頁
///
/// 顯示每日登入獎勵 + 抽獎排行榜
class ActivityCenterPage extends StatelessWidget {
  const ActivityCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final daily = context.watch<DailyRewardService>();
    final board = context.watch<LeaderboardRewardService>();
    final points = context.watch<FirestoreMockService>().userPoints;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🎯 活動任務中心"),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await daily.checkDailyReward();
          await board.checkDailyLeaderboardReward();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 💎 積分總覽
            Card(
              elevation: 3,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.stars, color: Colors.amber, size: 40),
                title: Text("目前積分：$points",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: const Text("積分可用於抽獎與兌換商品 🎁"),
              ),
            ),

            const SizedBox(height: 20),

            // 🎁 每日登入獎勵
            Card(
              elevation: 2,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.lightBlue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("🎁 每日登入獎勵",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      daily.hasClaimedToday
                          ? "✅ 今日已領取"
                          : "點擊下方按鈕領取每日獎勵 (+10 積分)",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.card_giftcard),
                      label: Text(
                        daily.hasClaimedToday ? "已領取" : "領取獎勵",
                      ),
                      onPressed:
                          daily.hasClaimedToday ? null : daily.claimReward,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 🏆 抽獎排行榜
            const Text(
              "🏆 抽獎次數排行榜",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...board.leaderboard.map((u) {
              final index = board.leaderboard.indexOf(u) + 1;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: index == 1
                        ? Colors.amber
                        : index == 2
                            ? Colors.grey
                            : index == 3
                                ? Colors.brown
                                : Colors.blueGrey,
                    child: Text(
                      "$index",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(u["name"]),
                  subtitle: Text("抽獎次數：${u["spins"]}"),
                  trailing: index <= 3
                      ? const Icon(Icons.emoji_events, color: Colors.amber)
                      : null,
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

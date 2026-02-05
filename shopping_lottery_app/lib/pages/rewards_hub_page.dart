import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../services/firestore_mock_service.dart';
import '../services/language_service.dart';

class RewardsHubPage extends StatelessWidget {
  const RewardsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreMockService.instance;
    final lang = Provider.of<LanguageService>(context);
    final tr = lang.tr;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr("rewards_hub_title")),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🪙 積分區塊
            _buildPointsCard(firestore, tr),
            const SizedBox(height: 20),

            // 🎰 抽獎紀錄
            Text(tr("lottery_history"),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildLotteryHistory(firestore, tr),
            const SizedBox(height: 30),

            // 🔔 最新通知
            Text(tr("latest_notifications"),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildNotifications(firestore, tr),
            const SizedBox(height: 30),

            // ✨ Lottie 動畫
            Center(
              child: Lottie.asset(
                'assets/lottie/reward_celebration.json',
                height: 160,
                repeat: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard(
      FirestoreMockService firestore, String Function(String) tr) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr("your_points"),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("${firestore.userPoints}",
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.deepPurple)),
              ],
            ),
            const Icon(Icons.stars, size: 48, color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }

  Widget _buildLotteryHistory(
      FirestoreMockService firestore, String Function(String) tr) {
    final records = firestore.lotteryRecords;
    if (records.isEmpty) {
      return Center(child: Text(tr("no_luck_today")));
    }
    return Column(
      children: records
          .map(
            (r) => ListTile(
              leading: const Icon(Icons.casino, color: Colors.deepPurple),
              title: Text(r["reward"]),
              subtitle: Text(r["time"]),
            ),
          )
          .toList(),
    );
  }

  Widget _buildNotifications(
      FirestoreMockService firestore, String Function(String) tr) {
    final list = firestore.notifications.take(3).toList();
    if (list.isEmpty) {
      return Center(child: Text(tr("no_notifications")));
    }
    return Column(
      children: list
          .map(
            (n) => Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading:
                    const Icon(Icons.notifications_active, color: Colors.orange),
                title: Text(n["title"]),
                subtitle: Text(n["message"]),
                trailing: n["unread"]
                    ? const Icon(Icons.circle, color: Colors.red, size: 10)
                    : const SizedBox(),
              ),
            ),
          )
          .toList(),
    );
  }
}

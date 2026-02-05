import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_mock_service.dart';
import '../services/notification_service.dart';

/// 🎯 積分任務中心（完整可用）
///
/// 功能：
/// - 每日簽到獎勵
/// - 分享 App 任務
/// - 抽獎任務
/// - 自動發送積分通知
/// - 顯示當前積分與任務完成狀態
class PointsMissionPage extends StatefulWidget {
  const PointsMissionPage({super.key});

  @override
  State<PointsMissionPage> createState() => _PointsMissionPageState();
}

class _PointsMissionPageState extends State<PointsMissionPage> {
  bool signedInToday = false;
  bool sharedApp = false;
  bool didLottery = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FirestoreMockService>();
    final notifier = NotificationService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🎯 積分任務中心"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "重置任務",
            onPressed: () {
              setState(() {
                signedInToday = false;
                sharedApp = false;
                didLottery = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ 今日任務已重置")),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F9FB),
      body: Column(
        children: [
          // 積分狀態列
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.lightBlueAccent],
              ),
            ),
            child: Column(
              children: [
                Text(
                  "💎 目前積分：${store.userPoints}",
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  "完成任務可獲得更多積分！",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildMissionCard(
                  icon: Icons.calendar_today,
                  title: "每日簽到",
                  desc: "簽到即可獲得 20 積分。",
                  done: signedInToday,
                  onPressed: () {
                    if (signedInToday) return;
                    store.addPoints(20);
                    notifier.addNotification(
                      title: "📅 每日簽到成功",
                      message: "您獲得了 20 積分！",
                      type: "mission",
                      icon: Icons.check_circle,
                    );
                    setState(() => signedInToday = true);
                  },
                ),
                _buildMissionCard(
                  icon: Icons.share,
                  title: "分享 Osmile App",
                  desc: "邀請朋友一起使用即可獲得 50 積分。",
                  done: sharedApp,
                  onPressed: () {
                    if (sharedApp) return;
                    store.addPoints(50);
                    notifier.addNotification(
                      title: "🤝 分享成功",
                      message: "感謝您的分享！獲得 50 積分！",
                      type: "mission",
                      icon: Icons.share,
                    );
                    setState(() => sharedApp = true);
                  },
                ),
                _buildMissionCard(
                  icon: Icons.casino,
                  title: "完成一次抽獎",
                  desc: "體驗抽獎活動可獲得 30 積分。",
                  done: didLottery,
                  onPressed: () {
                    if (didLottery) return;
                    store.addPoints(30);
                    notifier.addNotification(
                      title: "🎰 抽獎任務完成",
                      message: "恭喜！獲得 30 積分！",
                      type: "mission",
                      icon: Icons.casino,
                    );
                    setState(() => didLottery = true);
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  color: Colors.lightBlue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          "🔥 額外任務：連續簽到 7 天可再得 200 積分！",
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            store.addPoints(200);
                            notifier.addNotification(
                              title: "🏅 連續簽到達成",
                              message: "恭喜您！額外獲得 200 積分！",
                              type: "mission",
                              icon: Icons.emoji_events,
                            );
                          },
                          icon: const Icon(Icons.emoji_events),
                          label: const Text("領取獎勵"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🧩 任務卡片組件
  Widget _buildMissionCard({
    required IconData icon,
    required String title,
    required String desc,
    required bool done,
    required VoidCallback onPressed,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: done ? Colors.grey : Colors.blueAccent,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: done ? Colors.grey : Colors.black87,
          ),
        ),
        subtitle: Text(
          done ? "任務已完成 🎉" : desc,
          style: TextStyle(
            color: done ? Colors.grey : Colors.black54,
            fontSize: 13,
          ),
        ),
        trailing: done
            ? const Icon(Icons.check_circle, color: Colors.grey)
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onPressed,
                child: const Text("領取"),
              ),
      ),
    );
  }
}

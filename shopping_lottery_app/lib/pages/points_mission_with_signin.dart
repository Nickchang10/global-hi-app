import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_mock_service.dart';
import '../services/notification_service.dart';

/// 💎 積分任務中心 + 每日簽到整合版
///
/// 功能：
/// - 七日簽到系統（含進度條、獎勵、動畫）
/// - 每日任務：簽到、分享、抽獎
/// - 任務完成即時同步積分與通知
/// - 結合 FirestoreMockService 與 NotificationService
class PointsMissionPage extends StatefulWidget {
  const PointsMissionPage({super.key});

  @override
  State<PointsMissionPage> createState() => _PointsMissionPageState();
}

class _PointsMissionPageState extends State<PointsMissionPage> {
  int signedDays = 0;
  bool todaySigned = false;
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
      ),
      backgroundColor: const Color(0xFFF7F9FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSignInSection(store, notifier),
            const SizedBox(height: 24),
            _buildMissionList(store, notifier),
          ],
        ),
      ),
    );
  }

  /// 📅 七日簽到區域
  Widget _buildSignInSection(
      FirestoreMockService store, NotificationService notifier) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("📅 七日簽到挑戰",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: signedDays / 7,
              color: Colors.blueAccent,
              backgroundColor: Colors.grey.shade300,
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Text("已連續簽到：$signedDays / 7 天",
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 12),
            _buildCalendar(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: todaySigned
                  ? null
                  : () {
                      setState(() {
                        todaySigned = true;
                        signedDays++;
                      });
                      store.addPoints(20);
                      notifier.addNotification(
                        title: "📅 今日簽到成功",
                        message: "您獲得 20 積分！目前已簽到 $signedDays 天 🎉",
                        type: "mission",
                        icon: Icons.calendar_today,
                      );
                      _showRewardDialog(context, "簽到成功！", "今日簽到 +20 積分 🎉");

                      // 🎁 七日連續簽滿
                      if (signedDays == 7) {
                        store.addPoints(200);
                        notifier.addNotification(
                          title: "🏆 連續簽到 7 天",
                          message: "恭喜您額外獲得 200 積分！",
                          type: "mission",
                          icon: Icons.emoji_events,
                        );
                        _showRewardDialog(
                            context, "連續簽滿七天！", "再得 200 積分 🏆");
                      }
                    },
              icon: const Icon(Icons.touch_app),
              label: Text(todaySigned ? "今日已簽到" : "立即簽到"),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    todaySigned ? Colors.grey : Colors.blueAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📆 七日簽到格
  Widget _buildCalendar() {
    return GridView.builder(
      shrinkWrap: true,
      itemCount: 7,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemBuilder: (_, i) {
        final signed = i < signedDays;
        return Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: signed ? Colors.blueAccent : Colors.grey.shade300,
              child: signed
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text("${i + 1}",
                      style: const TextStyle(color: Colors.black87)),
            ),
            const SizedBox(height: 3),
            Text("Day ${i + 1}",
                style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        );
      },
    );
  }

  /// 🎯 任務列表
  Widget _buildMissionList(
      FirestoreMockService store, NotificationService notifier) {
    return Column(
      children: [
        _missionCard(
          "🤝 分享 Osmile App",
          "邀請好友使用可獲得 50 積分。",
          sharedApp,
          () {
            store.addPoints(50);
            notifier.addNotification(
              title: "分享成功",
              message: "感謝分享，獲得 50 積分！",
              type: "mission",
              icon: Icons.share,
            );
            setState(() => sharedApp = true);
            _showRewardDialog(context, "任務完成", "分享獎勵 +50 積分 🎁");
          },
        ),
        _missionCard(
          "🎰 完成一次抽獎",
          "體驗抽獎活動可得 30 積分。",
          didLottery,
          () {
            store.addPoints(30);
            notifier.addNotification(
              title: "🎰 抽獎任務完成",
              message: "恭喜獲得 30 積分！",
              type: "mission",
              icon: Icons.casino,
            );
            setState(() => didLottery = true);
            _showRewardDialog(context, "任務完成", "抽獎獎勵 +30 積分 🎰");
          },
        ),
      ],
    );
  }

  /// 📦 任務卡片
  Widget _missionCard(String title, String desc, bool done, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading:
            Icon(Icons.star, color: done ? Colors.grey : Colors.blueAccent),
        title: Text(title,
            style: TextStyle(
                color: done ? Colors.grey : Colors.black,
                fontWeight: FontWeight.bold)),
        subtitle: Text(done ? "已完成 🎉" : desc),
        trailing: done
            ? const Icon(Icons.check_circle, color: Colors.grey)
            : ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent),
                child: const Text("領取"),
              ),
      ),
    );
  }

  /// 🎁 動畫彈窗
  void _showRewardDialog(BuildContext context, String title, String message) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "RewardDialog",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 400),
          builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 4))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.card_giftcard,
                    color: Colors.orangeAccent, size: 80),
                const SizedBox(height: 12),
                Text(title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("太棒了！"),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }
}

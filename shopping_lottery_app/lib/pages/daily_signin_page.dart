import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_mock_service.dart';
import '../services/notification_service.dart';

/// 📅 每日簽到系統（完整版）
///
/// 功能：
/// ✅ 顯示連續 7 日簽到進度  
/// ✅ 單日簽到 + 積分獎勵  
/// ✅ 連續簽滿七天額外送 200 積分  
/// ✅ 動畫彈窗與通知整合  
class DailySignInPage extends StatefulWidget {
  const DailySignInPage({super.key});

  @override
  State<DailySignInPage> createState() => _DailySignInPageState();
}

class _DailySignInPageState extends State<DailySignInPage> {
  int signedDays = 0; // 已簽到天數
  bool todaySigned = false; // 今天是否已簽到

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FirestoreMockService>();
    final notifier = NotificationService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text("📅 每日簽到"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "重置簽到紀錄",
            onPressed: () {
              setState(() {
                signedDays = 0;
                todaySigned = false;
              });
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("✅ 簽到紀錄已重置")));
            },
          )
        ],
      ),
      backgroundColor: const Color(0xFFF7F9FB),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildProgressHeader(),
          const SizedBox(height: 16),
          _buildCalendar(),
          const SizedBox(height: 24),
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

                    _showRewardDialog(context, signedDays);

                    // 七日額外獎勵
                    if (signedDays == 7) {
                      store.addPoints(200);
                      notifier.addNotification(
                        title: "🏆 連續簽到 7 天",
                        message: "恭喜您額外獲得 200 積分！",
                        type: "mission",
                        icon: Icons.emoji_events,
                      );

                      // 顯示七日完成特別彈窗
                      Future.delayed(const Duration(milliseconds: 500), () {
                        _showBonusDialog(context);
                      });
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: todaySigned ? Colors.grey : Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.touch_app),
            label: Text(todaySigned ? "今日已簽到" : "立即簽到"),
          ),
          const SizedBox(height: 12),
          Text(
            "已連續簽到：$signedDays 天",
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const Spacer(),
          Image.asset(
            "assets/images/calendar_banner.png",
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.calendar_month,
                color: Colors.blueAccent, size: 100),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// 🔵 標題 + 進度
  Widget _buildProgressHeader() {
    return Column(
      children: [
        const Text(
          "簽到七日挑戰",
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: signedDays / 7,
          backgroundColor: Colors.grey.shade300,
          color: Colors.blueAccent,
          minHeight: 8,
        ),
        const SizedBox(height: 6),
        Text(
          "進度：$signedDays / 7 天",
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }

  /// 📆 顯示七日簽到格
  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
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
                radius: 20,
                backgroundColor: signed ? Colors.blueAccent : Colors.grey.shade300,
                child: signed
                    ? const Icon(Icons.check, color: Colors.white)
                    : Text("${i + 1}",
                        style: const TextStyle(color: Colors.black87)),
              ),
              const SizedBox(height: 4),
              Text("Day ${i + 1}",
                  style: const TextStyle(fontSize: 10, color: Colors.black54)),
            ],
          );
        },
      ),
    );
  }

  /// 🎁 單日簽到獎勵彈窗
  void _showRewardDialog(BuildContext context, int day) {
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
                const Text(
                  "簽到成功！",
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "第 $day 天簽到 🎉\n獲得 20 積分！",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
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

  /// 🏆 七日特別獎勵彈窗
  void _showBonusDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🏆 恭喜完成 7 日挑戰！"),
        content: const Text("您已連續簽到 7 天，獲得額外 200 積分 🎉"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("太棒了！"),
          )
        ],
      ),
    );
  }
}

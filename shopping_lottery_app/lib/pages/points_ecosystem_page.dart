import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_mock_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

/// 💎 Osmile 積分生態系統（最終整合版）
///
/// 包含：
/// 1️⃣ 七日簽到（每日 +20、滿7天 +200）
/// 2️⃣ 任務中心（分享、抽獎）
/// 3️⃣ 積分商城（積分兌換）
/// 4️⃣ 排行榜（即時排名）
/// 5️⃣ 積分紀錄（歷史查詢）
class PointsEcosystemPage extends StatefulWidget {
  const PointsEcosystemPage({super.key});

  @override
  State<PointsEcosystemPage> createState() => _PointsEcosystemPageState();
}

class _PointsEcosystemPageState extends State<PointsEcosystemPage> {
  int signedDays = 0;
  bool todaySigned = false;
  bool sharedApp = false;
  bool didLottery = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FirestoreMockService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("💎 積分生態系統"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF7F9FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(store.userPoints),
          const SizedBox(height: 16),
          _buildSignInCard(context),
          const SizedBox(height: 16),
          _buildMissionCard(context),
          const SizedBox(height: 16),
          _buildMallCard(context),
          const SizedBox(height: 16),
          _buildLeaderboardCard(context),
          const SizedBox(height: 16),
          _buildHistoryCard(context),
        ],
      ),
    );
  }

  // ------------------------------------------------------
  // 📌 Header 顯示目前積分
  Widget _buildHeader(int points) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlueAccent]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text("目前積分",
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            Text("$points",
                style: const TextStyle(
                    fontSize: 42,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );

  // ------------------------------------------------------
  // 📅 簽到區域
  Widget _buildSignInCard(BuildContext context) {
    final store = context.read<FirestoreMockService>();
    final notifier = NotificationService.instance;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
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
              backgroundColor: Colors.grey.shade300,
              color: Colors.blueAccent,
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Text("已簽到 $signedDays / 7 天",
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            _buildCalendar(),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.touch_app),
              label: Text(todaySigned ? "今日已簽到" : "立即簽到"),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    todaySigned ? Colors.grey : Colors.blueAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
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
                        message: "獲得 20 積分！已簽到 $signedDays 天 🎉",
                        type: "mission",
                        icon: Icons.calendar_today,
                      );
                      _showDialog(context, "簽到成功 🎉", "獲得 20 積分");

                      if (signedDays == 7) {
                        store.addPoints(200);
                        notifier.addNotification(
                          title: "🏆 連續簽到 7 天",
                          message: "恭喜您額外獲得 200 積分！",
                          type: "mission",
                          icon: Icons.emoji_events,
                        );
                        _showDialog(context, "連續七天達成 🏆", "額外 +200 積分");
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 7,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemBuilder: (_, i) {
        final signed = i < signedDays;
        return Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: signed ? Colors.blueAccent : Colors.grey.shade300,
              child: signed
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text("${i + 1}",
                      style: const TextStyle(color: Colors.black87)),
            ),
            const SizedBox(height: 2),
            Text("Day ${i + 1}",
                style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------
  // 🎯 任務中心
  Widget _buildMissionCard(BuildContext context) {
    final store = context.read<FirestoreMockService>();
    final notifier = NotificationService.instance;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("🎯 任務中心",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent)),
            const SizedBox(height: 12),
            _missionItem("🤝 分享 Osmile App", 50, sharedApp, () {
              setState(() => sharedApp = true);
              store.addPoints(50);
              notifier.addNotification(
                title: "分享成功 🎉",
                message: "您獲得 50 積分！",
                type: "mission",
                icon: Icons.share,
              );
              _showDialog(context, "分享任務完成", "獲得 50 積分");
            }),
            const SizedBox(height: 8),
            _missionItem("🎰 完成一次抽獎", 30, didLottery, () {
              setState(() => didLottery = true);
              store.addPoints(30);
              notifier.addNotification(
                title: "抽獎任務完成 🎰",
                message: "恭喜獲得 30 積分！",
                type: "mission",
                icon: Icons.casino,
              );
              _showDialog(context, "抽獎任務完成", "獲得 30 積分");
            }),
          ],
        ),
      ),
    );
  }

  Widget _missionItem(
      String title, int reward, bool done, VoidCallback onPressed) {
    return ListTile(
      leading: Icon(Icons.flag, color: done ? Colors.grey : Colors.blueAccent),
      title: Text(title,
          style:
              TextStyle(color: done ? Colors.grey : Colors.black, fontSize: 15)),
      subtitle: Text(done ? "已完成 ✅" : "完成可得 $reward 積分"),
      trailing: done
          ? const Icon(Icons.check_circle, color: Colors.grey)
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent),
              child: const Text("領取"),
            ),
    );
  }

  // ------------------------------------------------------
  // 🏪 積分商城
  Widget _buildMallCard(BuildContext context) {
    final store = context.read<FirestoreMockService>();
    final notifier = NotificationService.instance;
    final mallItems = [
      {"name": "Lumi 2 手環", "points": 500, "image": "assets/images/lumi2.png"},
      {"name": "ED1000 手錶", "points": 800, "image": "assets/images/ed1000.png"},
      {"name": "智慧體脂秤", "points": 400, "image": "assets/images/scale.png"},
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: ExpansionTile(
        leading: const Icon(Icons.store, color: Colors.orange),
        title: const Text("🏪 積分商城"),
        children: mallItems.map((item) {
          final can = store.userPoints >= item["points"];
          return ListTile(
            leading: Image.asset(item["image"], width: 50, height: 50,
                errorBuilder: (_, __, ___) => const Icon(Icons.watch)),
            title: Text(item["name"]),
            subtitle: Text("需 ${item["points"]} 積分"),
            trailing: ElevatedButton(
              onPressed: can
                  ? () {
                      store.usePoints(item["points"]);
                      notifier.addNotification(
                        title: "🎁 兌換成功",
                        message: "您已兌換 ${item["name"]}",
                        type: "redeem",
                        icon: Icons.card_giftcard,
                      );
                      _showDialog(context, "兌換成功", "${item["name"]} ✅");
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: can ? Colors.blueAccent : Colors.grey),
              child: const Text("兌換"),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ------------------------------------------------------
  // 📊 排行榜
  Widget _buildLeaderboardCard(BuildContext context) {
    final store = context.watch<FirestoreMockService>();
    final user = context.watch<AuthService>().currentUser ?? "訪客";
    final random = Random();
    final names = ["小明", "阿華", "Lumi粉", "健康達人", "阿姨", user];
    final list = names
        .map((n) => {
              "name": n,
              "points": n == user ? store.userPoints : 300 + random.nextInt(600)
            })
        .toList()
      ..sort((a, b) => b["points"].compareTo(a["points"]));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: ExpansionTile(
        leading: const Icon(Icons.leaderboard, color: Colors.blueAccent),
        title: const Text("📊 積分排行榜"),
        children: list.map((u) {
          final isMe = u["name"] == user;
          return ListTile(
            leading: CircleAvatar(
                backgroundColor:
                    isMe ? Colors.amber : Colors.blueAccent,
                child: Text(u["name"][0],
                    style: const TextStyle(color: Colors.white))),
            title: Text(u["name"],
                style: TextStyle(
                    color: isMe ? Colors.amber : Colors.black,
                    fontWeight: FontWeight.bold)),
            trailing:
                Text("${u["points"]} 分", style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
      ),
    );
  }

  // ------------------------------------------------------
  // 📜 積分紀錄
  Widget _buildHistoryCard(BuildContext context) {
    final orders = context.watch<FirestoreMockService>().orderHistory;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: ExpansionTile(
        leading: const Icon(Icons.receipt_long, color: Colors.purple),
        title: const Text("📜 積分紀錄"),
        children: orders.isEmpty
            ? [const ListTile(title: Text("目前沒有兌換紀錄 🕓"))]
            : orders.map((o) {
                return ListTile(
                  title: Text("訂單 #${o["id"]}"),
                  subtitle:
                      Text("總金額 NT\$${o["total"].toStringAsFixed(0)}"),
                  trailing: Text(
                    o["time"].toString().split('.')[0],
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                );
              }).toList(),
      ),
    );
  }

  // ------------------------------------------------------
  // 🎁 彈窗動畫
  void _showDialog(BuildContext context, String title, String message) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "RewardDialog",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 400),
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 15)
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
                      backgroundColor: Colors.blueAccent),
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

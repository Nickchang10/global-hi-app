import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_mock_service.dart';
import '../services/notification_service.dart';
import '../services/coupon_service.dart';
import '../services/auth_service.dart';

/// 💎 Osmile 積分系統模組整合版
///
/// 📦 包含五大頁面：
/// 1️⃣ 積分主頁（總覽）
/// 2️⃣ 積分任務中心
/// 3️⃣ 積分商城（可兌換）
/// 4️⃣ 積分排行榜
/// 5️⃣ 積分歷史紀錄
///
/// 📲 已整合積分變化通知、任務完成提示與 FirestoreMockService。

// -----------------------------
// 1️⃣ 積分主頁 (Dashboard)
// -----------------------------
class PointsDashboardPage extends StatelessWidget {
  const PointsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FirestoreMockService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("💎 積分中心"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF7F9FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(store.userPoints),
          const SizedBox(height: 20),
          _buildTile(
            icon: Icons.flag,
            title: "每日任務中心",
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PointsMissionPage()),
            ),
          ),
          _buildTile(
            icon: Icons.shopping_bag,
            title: "積分兌換商城",
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PointsMallPage()),
            ),
          ),
          _buildTile(
            icon: Icons.leaderboard,
            title: "積分排行榜",
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardPage()),
            ),
          ),
          _buildTile(
            icon: Icons.receipt_long,
            title: "兌換紀錄",
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PointsOrderHistoryPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int points) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.blueAccent, Colors.lightBlueAccent],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text("目前積分", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              "$points",
              style: const TextStyle(
                fontSize: 38,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  Widget _buildTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) =>
      Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 3,
        child: ListTile(
          leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

// -----------------------------
// 2️⃣ 積分任務中心
// -----------------------------
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _missionCard(
            "📅 每日簽到",
            "簽到可獲得 20 積分。",
            signedInToday,
            () {
              store.addPoints(20);
              notifier.addNotification(title: "📅 每日簽到成功", message: "您獲得了 20 積分！", type: "mission", icon: Icons.check);
              setState(() => signedInToday = true);
            },
          ),
          _missionCard(
            "🤝 分享 Osmile App",
            "邀請好友使用可獲得 50 積分。",
            sharedApp,
            () {
              store.addPoints(50);
              notifier.addNotification(title: "分享成功", message: "感謝分享，獲得 50 積分！", type: "mission", icon: Icons.share);
              setState(() => sharedApp = true);
            },
          ),
          _missionCard(
            "🎰 完成一次抽獎",
            "體驗抽獎活動可得 30 積分。",
            didLottery,
            () {
              store.addPoints(30);
              notifier.addNotification(title: "🎰 抽獎任務完成", message: "恭喜獲得 30 積分！", type: "mission", icon: Icons.casino);
              setState(() => didLottery = true);
            },
          ),
        ],
      ),
    );
  }

  Widget _missionCard(String title, String desc, bool done, VoidCallback onTap) => Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: Icon(Icons.star, color: done ? Colors.grey : Colors.blueAccent),
          title: Text(title, style: TextStyle(color: done ? Colors.grey : Colors.black87)),
          subtitle: Text(done ? "已完成 🎉" : desc),
          trailing: done
              ? const Icon(Icons.check_circle, color: Colors.grey)
              : ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  child: const Text("領取"),
                ),
        ),
      );
}

// -----------------------------
// 3️⃣ 積分兌換商城
// -----------------------------
class PointsMallPage extends StatelessWidget {
  const PointsMallPage({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<FirestoreMockService>();
    final notifier = NotificationService.instance;

    final items = [
      {"name": "Lumi 2 手環", "points": 500, "image": "assets/images/lumi2.png"},
      {"name": "ED1000 手錶", "points": 800, "image": "assets/images/ed1000.png"},
      {"name": "智慧體脂秤", "points": 400, "image": "assets/images/scale.png"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("🏪 積分兌換商城"), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final p = items[i];
          final can = store.userPoints >= p["points"];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Image.asset(p["image"], width: 60, height: 60, errorBuilder: (_, __, ___) => const Icon(Icons.watch)),
              title: Text(p["name"]),
              subtitle: Text("需 ${p["points"]} 積分"),
              trailing: ElevatedButton(
                onPressed: can
                    ? () {
                        store.usePoints(p["points"]);
                        notifier.addNotification(
                          title: "🎁 兌換成功",
                          message: "您兌換了 ${p["name"]}",
                          type: "redeem",
                          icon: Icons.card_giftcard,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("已兌換 ${p["name"]} ✅")),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: can ? Colors.blueAccent : Colors.grey),
                child: const Text("兌換"),
              ),
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------
// 4️⃣ 積分排行榜
// -----------------------------
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<Map<String, dynamic>> leaders = [];

  @override
  void initState() {
    super.initState();
    _genMock();
  }

  void _genMock() {
    final r = Random();
    final names = ["小明", "阿華", "Lumi粉", "健康達人", "阿姨", "運動咖"];
    leaders = List.generate(names.length, (i) => {"name": names[i], "points": 300 + r.nextInt(600)});
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FirestoreMockService>();
    final user = context.watch<AuthService>().currentUser ?? "訪客";
    if (!leaders.any((x) => x["name"] == user)) {
      leaders.add({"name": user, "points": store.userPoints});
    }
    leaders.sort((a, b) => b["points"].compareTo(a["points"]));
    final rank = leaders.indexWhere((x) => x["name"] == user) + 1;

    return Scaffold(
      appBar: AppBar(title: const Text("📊 積分排行榜"), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: leaders.length,
        itemBuilder: (_, i) {
          final u = leaders[i];
          final me = u["name"] == user;
          return Card(
            color: me ? Colors.blue.shade50 : Colors.white,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: i < 3 ? Colors.amber : Colors.blueAccent,
                child: Text("${i + 1}", style: const TextStyle(color: Colors.white)),
              ),
              title: Text(u["name"], style: TextStyle(color: me ? Colors.blueAccent : Colors.black87)),
              subtitle: Text("積分：${u["points"]}"),
              trailing: me ? const Icon(Icons.star, color: Colors.orangeAccent) : null,
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.blueAccent,
        child: Text("您的排名：第 $rank 名　積分：${store.userPoints}",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// -----------------------------
// 5️⃣ 積分歷史紀錄頁
// -----------------------------
class PointsOrderHistoryPage extends StatelessWidget {
  const PointsOrderHistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final orders = context.watch<FirestoreMockService>().orderHistory;
    return Scaffold(
      appBar: AppBar(title: const Text("📜 積分兌換紀錄"), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
      body: orders.isEmpty
          ? const Center(child: Text("目前沒有兌換紀錄 🕓"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (_, i) {
                final o = orders[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long, color: Colors.blueAccent),
                    title: Text("訂單 #${o["id"]}"),
                    subtitle: Text("總金額：NT\$${o["total"].toStringAsFixed(0)}"),
                    trailing: Text("${o["time"]}".split('.')[0],
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                );
              },
            ),
    );
  }
}

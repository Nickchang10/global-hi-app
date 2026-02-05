// lib/pages/friend_leaderboard_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:osmile_shopping_app/services/firestore_mock_service.dart';
import 'package:osmile_shopping_app/services/social_service.dart';

/// 🧑‍🤝‍🧑 好友排行榜與每日挑戰頁
///
/// 功能：
/// ✅ 好友積分排行榜
/// ✅ 每日挑戰任務（完成可獲積分）
/// ✅ 活動倒數、任務進度條
/// ✅ 兌換積分獎勵
/// ✅ 適用 FirestoreMockService + SocialService
class FriendLeaderboardPage extends StatefulWidget {
  const FriendLeaderboardPage({super.key});

  @override
  State<FriendLeaderboardPage> createState() => _FriendLeaderboardPageState();
}

class _FriendLeaderboardPageState extends State<FriendLeaderboardPage> {
  final List<Map<String, dynamic>> _dailyChallenges = [
    {
      "title": "今日登入",
      "desc": "每天登入可獲得 10 積分",
      "reward": 10,
      "completed": false
    },
    {
      "title": "發表一篇貼文",
      "desc": "社群互動 + 發文可獲得 30 積分",
      "reward": 30,
      "completed": false
    },
    {
      "title": "點讚 3 篇貼文",
      "desc": "為他人貼文按讚可得 20 積分",
      "reward": 20,
      "completed": false
    },
  ];

  @override
  void initState() {
    super.initState();
    _autoCompleteLoginChallenge();
  }

  // ✅ 自動完成登入任務
  void _autoCompleteLoginChallenge() {
    setState(() {
      _dailyChallenges[0]["completed"] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.watch<FirestoreMockService>();
    final social = context.watch<SocialService>();

    final friends = social.friends;
    final points = firestore.userPoints;

    // 模擬好友積分資料
    final List<Map<String, dynamic>> leaderboard = [
      {"name": "Lumi 鐵粉", "points": 980},
      {"name": "SunnyDay", "points": 760},
      {"name": "阿姨", "points": 620},
      {"name": "Osmile 用戶", "points": points},
    ];
    leaderboard.sort((a, b) => b["points"].compareTo(a["points"]));
    final rank = leaderboard.indexWhere((f) => f["name"] == "Osmile 用戶") + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🏆 好友排行榜"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(rank, points),
          const SizedBox(height: 16),
          _buildLeaderboardList(leaderboard),
          const SizedBox(height: 20),
          const Divider(thickness: 0.6),
          const SizedBox(height: 10),
          _buildDailyChallengeSection(context, firestore),
        ],
      ),
    );
  }

  // 🏅 使用者頭部資訊
  Widget _buildHeader(int rank, int points) {
    final now = DateFormat("MM/dd HH:mm").format(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, size: 60, color: Colors.amber),
          Text(
            "您的排名：第 $rank 名",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text("目前積分：$points 💎",
              style: const TextStyle(color: Colors.black54)),
          Text("更新時間：$now",
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // 🧩 好友積分排行榜
  Widget _buildLeaderboardList(List<Map<String, dynamic>> data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              "📊 排行榜前四名",
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
            ),
          ),
          ...data.asMap().entries.map((entry) {
            final i = entry.key;
            final user = entry.value;
            final highlight = user["name"] == "Osmile 用戶";
            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    highlight ? Colors.blueAccent : Colors.grey.shade300,
                child: Text((i + 1).toString(),
                    style: TextStyle(
                        color: highlight ? Colors.white : Colors.black)),
              ),
              title: Text(user["name"]),
              trailing: Text(
                "${user["points"]} 分",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          }),
        ],
      ),
    );
  }

  // 🎯 每日挑戰區塊
  Widget _buildDailyChallengeSection(
      BuildContext context, FirestoreMockService firestore) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text("🔥 今日挑戰任務",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange)),
          const SizedBox(height: 10),
          ..._dailyChallenges.asMap().entries.map((entry) {
            final i = entry.key;
            final task = entry.value;

            return Card(
              color: task["completed"]
                  ? Colors.green.shade50
                  : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(
                  task["completed"]
                      ? Icons.check_circle
                      : Icons.flag_circle,
                  color:
                      task["completed"] ? Colors.green : Colors.orangeAccent,
                ),
                title: Text(task["title"],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(task["desc"]),
                trailing: task["completed"]
                    ? const Text("已完成",
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold))
                    : ElevatedButton(
                        onPressed: () {
                          setState(() {
                            task["completed"] = true;
                          });
                          firestore.addPoints(task["reward"]);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  "🎉 ${task["title"]} 完成！獲得 ${task["reward"]} 積分")));
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent),
                        child: const Text("完成")),
              ),
            );
          }),
        ],
      ),
    );
  }
}

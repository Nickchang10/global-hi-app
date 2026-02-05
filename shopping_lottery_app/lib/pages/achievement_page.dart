// lib/pages/achievement_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:osmile_shopping_app/services/firestore_mock_service.dart';
import 'package:osmile_shopping_app/services/social_service.dart';

/// 🏅 Osmile 勳章 & 排行榜頁（完整版）
///
/// 功能：
/// ✅ 顯示使用者排名、積分、等級徽章
/// ✅ 顯示貼文、抽獎、積分三項排行榜
/// ✅ 顯示動態勳章牆（依活動自動獲得）
/// ✅ 點擊可顯示勳章詳情
class AchievementPage extends StatelessWidget {
  const AchievementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.watch<FirestoreMockService>();
    final social = context.watch<SocialService>();

    final userPoints = firestore.userPoints;
    final postCount = social.posts.length;
    final lotteryCount = firestore.lotteryRecords.length;

    final level = _getLevel(userPoints);

    return Scaffold(
      appBar: AppBar(
        title: const Text("🏅 排行榜與勳章系統"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(level, userPoints, postCount, lotteryCount),
          const SizedBox(height: 20),
          _buildLeaderboardSection(firestore, social),
          const SizedBox(height: 24),
          const Divider(thickness: 0.8),
          const SizedBox(height: 12),
          _buildMedalWall(context, userPoints, postCount, lotteryCount),
        ],
      ),
    );
  }

  // 🧱 頭部資訊
  Widget _buildHeader(String level, int points, int posts, int lotteryCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.military_tech, color: Colors.amber, size: 60),
          const SizedBox(height: 10),
          Text(
            "您的等級：$level",
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text("積分：$points 　貼文數：$posts 　抽獎次數：$lotteryCount",
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ],
      ),
    );
  }

  // 🧩 排行榜
  Widget _buildLeaderboardSection(
      FirestoreMockService firestore, SocialService social) {
    // 模擬排行榜資料
    final List<Map<String, dynamic>> leaderboard = [
      {"name": "Lumi 鐵粉", "points": 980},
      {"name": "SunnyDay", "points": 760},
      {"name": "小明", "points": 620},
      {"name": "Osmile 用戶", "points": firestore.userPoints},
    ];

    leaderboard.sort((a, b) => b["points"].compareTo(a["points"]));
    final userRank =
        leaderboard.indexWhere((u) => u["name"] == "Osmile 用戶") + 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 5,
              offset: const Offset(0, 3))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text("🌍 全球排行榜",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blueAccent)),
          const SizedBox(height: 10),
          ...leaderboard.asMap().entries.map((entry) {
            final i = entry.key;
            final user = entry.value;
            final rank = i + 1;
            final highlight = user["name"] == "Osmile 用戶";
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: highlight ? Colors.blue[50] : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      rank == 1 ? Colors.amber : Colors.grey.shade300,
                  child: Text(
                    rank.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(user["name"]),
                trailing: Text("${user["points"]} 分",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            );
          }),
          const Divider(height: 24),
          Text("🏆 您目前排名第 $userRank 名！",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        ],
      ),
    );
  }

  // 🧿 勳章牆
  Widget _buildMedalWall(
      BuildContext context, int points, int posts, int lotteries) {
    final medals = _getEarnedMedals(points, posts, lotteries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("🎖 我的勳章",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10),
          itemCount: medals.length,
          itemBuilder: (_, i) {
            final m = medals[i];
            return GestureDetector(
              onTap: () => _showMedalDetail(context, m),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(m["icon"], color: m["color"], size: 36),
                    const SizedBox(height: 6),
                    Text(m["title"],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 🏆 勳章詳情
  void _showMedalDetail(BuildContext context, Map<String, dynamic> medal) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(medal["icon"], color: medal["color"]),
            const SizedBox(width: 8),
            Text(medal["title"]),
          ],
        ),
        content: Text(medal["desc"]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("關閉"),
          ),
        ],
      ),
    );
  }

  // 🧠 計算等級
  String _getLevel(int points) {
    if (points >= 1000) return "鑽石會員 💎";
    if (points >= 500) return "白金會員 🏆";
    if (points >= 200) return "黃金會員 🌟";
    if (points >= 100) return "銀牌會員 🪙";
    return "銅牌會員 🧩";
  }

  // 🎯 獲得的勳章清單
  List<Map<String, dynamic>> _getEarnedMedals(
      int points, int posts, int lotteries) {
    final List<Map<String, dynamic>> medals = [];

    // 積分類
    if (points >= 100) {
      medals.add({
        "title": "積分達人",
        "desc": "獲得超過 100 積分！保持努力！",
        "icon": Icons.star,
        "color": Colors.amber,
      });
    }
    if (points >= 500) {
      medals.add({
        "title": "白金榮耀",
        "desc": "累積積分達 500，晉升白金等級！",
        "icon": Icons.workspace_premium,
        "color": Colors.blueAccent,
      });
    }

    // 貼文類
    if (posts >= 1) {
      medals.add({
        "title": "初次分享",
        "desc": "發表你的第一篇貼文 🎉",
        "icon": Icons.edit_note,
        "color": Colors.green,
      });
    }
    if (posts >= 5) {
      medals.add({
        "title": "社群熱血",
        "desc": "連續發文超過 5 篇，成為社群達人 💬",
        "icon": Icons.people,
        "color": Colors.teal,
      });
    }

    // 抽獎類
    if (lotteries >= 1) {
      medals.add({
        "title": "初次試手氣",
        "desc": "參與一次抽獎活動 🎰",
        "icon": Icons.casino,
        "color": Colors.purple,
      });
    }
    if (lotteries >= 10) {
      medals.add({
        "title": "幸運之星",
        "desc": "參與超過 10 次抽獎，運氣加倍 🍀",
        "icon": Icons.auto_awesome,
        "color": Colors.pinkAccent,
      });
    }

    if (medals.isEmpty) {
      medals.add({
        "title": "尚無勳章",
        "desc": "多參與活動即可獲得勳章 🏅",
        "icon": Icons.lock_outline,
        "color": Colors.grey,
      });
    }

    return medals;
  }
}

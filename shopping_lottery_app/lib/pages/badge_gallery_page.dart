import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/firestore_mock_service.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';
import 'package:osmile_shopping_app/services/mission_notify_service.dart';

/// 🏅 成就徽章畫廊頁面（整合任務 + 排行榜）
class BadgeGalleryPage extends StatefulWidget {
  const BadgeGalleryPage({super.key});

  @override
  State<BadgeGalleryPage> createState() => _BadgeGalleryPageState();
}

class _BadgeGalleryPageState extends State<BadgeGalleryPage> {
  late List<Map<String, dynamic>> _badges;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  void _loadBadges() {
    _badges = [
      {
        "title": "新手冒險者",
        "desc": "首次登入 Osmile App",
        "icon": Icons.emoji_emotions,
        "rarity": "普通",
        "points": 10,
        "unlocked": true,
      },
      {
        "title": "連續登入 7 天",
        "desc": "持續登入達 7 天",
        "icon": Icons.calendar_month,
        "rarity": "進階",
        "points": 30,
        "unlocked": false,
      },
      {
        "title": "完成 10 個任務",
        "desc": "努力完成 10 次任務挑戰",
        "icon": Icons.flag,
        "rarity": "進階",
        "points": 50,
        "unlocked": false,
      },
      {
        "title": "頂級收藏家",
        "desc": "收藏 20 件商品",
        "icon": Icons.favorite,
        "rarity": "傳說",
        "points": 100,
        "unlocked": false,
      },
      {
        "title": "社群熱力王",
        "desc": "發表 10 篇貼文並獲得 50 個讚",
        "icon": Icons.people,
        "rarity": "傳說",
        "points": 150,
        "unlocked": false,
      },
    ];
  }

  void _unlockBadge(Map<String, dynamic> badge) {
    if (badge["unlocked"] == true) return;

    final firestore = FirestoreMockService.instance;
    final notify = NotificationService.instance;
    final mission = MissionNotifyService.instance;

    firestore.addPoints(badge["points"]);
    notify.addNotification(
      title: "🏅 成就解鎖！",
      message: "你獲得了「${badge["title"]}」徽章 +${badge["points"]} 積分！",
      type: "badge",
    );

    // 同步到排行榜
    mission.syncBadgeToLeaderboard(
      badgeTitle: badge["title"],
      points: badge["points"],
    );

    setState(() {
      badge["unlocked"] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("🎉 ${badge["title"]} 解鎖！+${badge["points"]} 積分"),
      backgroundColor: Colors.green,
    ));
  }

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case "進階":
        return Colors.deepPurpleAccent;
      case "傳說":
        return Colors.orangeAccent;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.watch<FirestoreMockService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("🏅 成就徽章"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(firestore.points),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _badges.length,
            itemBuilder: (context, index) {
              final badge = _badges[index];
              return _buildBadgeCard(badge);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int points) {
    return Card(
      color: Colors.blueAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.white, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "目前積分：$points\n解鎖更多徽章可提升排行榜！",
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge) {
    final unlocked = badge["unlocked"] == true;
    final rarityColor = _rarityColor(badge["rarity"]);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: unlocked ? rarityColor.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? rarityColor : Colors.grey.shade300,
          width: unlocked ? 2 : 1,
        ),
        boxShadow: [
          if (unlocked)
            BoxShadow(
              color: rarityColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: InkWell(
        onTap: () => _unlockBadge(badge),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                badge["icon"],
                size: 46,
                color: unlocked ? rarityColor : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                badge["title"],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: unlocked ? Colors.black87 : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                badge["rarity"],
                style: TextStyle(
                    fontSize: 12,
                    color: unlocked ? rarityColor : Colors.grey.shade500,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Text(
                badge["desc"],
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: unlocked
                        ? Colors.black54
                        : Colors.grey.shade400),
              ),
              const Spacer(),
              unlocked
                  ? const Text("✅ 已解鎖",
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _unlockBadge(badge),
                      child: const Text("解鎖"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

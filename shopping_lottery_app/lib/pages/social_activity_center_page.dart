// lib/pages/social_activity_center_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:osmile_shopping_app/services/firestore_mock_service.dart';
import 'package:osmile_shopping_app/services/social_service.dart';
import 'package:osmile_shopping_app/services/auth_service.dart';

// 其他頁面
import 'package:osmile_shopping_app/pages/lottery_page.dart';
import 'package:osmile_shopping_app/pages/friend_leaderboard_page.dart';
import 'package:osmile_shopping_app/pages/achievement_page.dart';
import 'package:osmile_shopping_app/widgets/social_post_card.dart';

/// 🌐 社群活動中心頁
///
/// 功能：
/// ✅ 上方顯示自己社群戰力（發文數、按讚數、好友數）
/// ✅ 快速入口（發文牆 / 抽獎 / 排行榜 / 成就徽章）
/// ✅ 熱門貼文區（依讚數排序，點擊可放大觀看）
/// ✅ 社群小任務建議，鼓勵使用者多互動
class SocialActivityCenterPage extends StatelessWidget {
  const SocialActivityCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.watch<FirestoreMockService>();
    final social = context.watch<SocialService>();
    final auth = context.watch<AuthService>();

    final username = auth.currentUser ?? "Osmile 用戶";

    // 自己的貼文數
    final myPosts =
        social.posts.where((p) => p["user"] == username).toList();

    // 總按讚數（自己的貼文）
    final int myLikes = myPosts.fold<int>(
      0,
      (sum, p) => sum + (p["likes"] ?? 0 as int),
    );

    // 好友數（用 SocialService 模擬）
    final friendsCount = social.friends.length;

    // 熱門貼文（依 likes 排序，取前 3 筆）
    final List<Map<String, dynamic>> trending = List.from(social.posts);
    trending.sort(
        (a, b) => (b["likes"] ?? 0 as int).compareTo(a["likes"] ?? 0 as int));
    final topTrending = trending.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("🎮 社群活動中心"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileStatsCard(
            username: username,
            points: firestore.userPoints,
            postCount: myPosts.length,
            likeCount: myLikes,
            friendsCount: friendsCount,
          ),
          const SizedBox(height: 16),
          _buildQuickActions(context),
          const SizedBox(height: 20),
          _buildTrendingSection(context, topTrending),
          const SizedBox(height: 20),
          _buildSocialMissions(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 🧾 上方個人社群戰力卡
  Widget _buildProfileStatsCard({
    required String username,
    required int points,
    required int postCount,
    required int likeCount,
    required int friendsCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            child: Icon(Icons.person, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "社群積分：$points 💎",
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildStatItem("貼文", postCount.toString()),
                    _buildStatItem("獲讚", likeCount.toString()),
                    _buildStatItem("好友", friendsCount.toString()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  /// ⚡ 快速入口列
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "⚡ 快速開始互動",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          children: [
            _quickActionItem(
              icon: Icons.dynamic_feed,
              color: Colors.blueAccent,
              title: "前往貼文牆",
              subtitle: "發一篇貼文或按讚",
              onTap: () {
                // 切到 SocialPage：透過 BottomNavigation 的 index
                // 這裡只發事件，由上層處理也可以；簡單版直接提示
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("請切換下方底部『社群』分頁進入貼文牆 📱"),
                  ),
                );
              },
            ),
            _quickActionItem(
              icon: Icons.casino,
              color: Colors.purple,
              title: "轉盤抽獎",
              subtitle: "用積分試手氣",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LotteryPage()),
                );
              },
            ),
            _quickActionItem(
              icon: Icons.leaderboard,
              color: Colors.orange,
              title: "好友排行榜",
              subtitle: "看看你排第幾",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FriendLeaderboardPage()),
                );
              },
            ),
            _quickActionItem(
              icon: Icons.military_tech,
              color: Colors.teal,
              title: "成就徽章館",
              subtitle: "解鎖你的榮譽",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AchievementPage()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black54, height: 1.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔥 熱門貼文區
  Widget _buildTrendingSection(
      BuildContext context, List<Map<String, dynamic>> trending) {
    if (trending.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "🔥 熱門貼文",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...trending.asMap().entries.map((entry) {
          final i = entry.key;
          final post = entry.value;
          final likes = post["likes"] ?? 0;

          return GestureDetector(
            onTap: () {
              // 點擊後用 bottomSheet 顯示完整 SocialPostCard
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    child: SocialPostCard(
                      post: post,
                      index: i,
                    ),
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFDFE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${post["user"]}：${post["content"]}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        likes.toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 📌 社群小任務建議
  Widget _buildSocialMissions() {
    final missions = [
      "今天按讚 5 則貼文，幫朋友集氣 👍",
      "發一篇照片貼文，分享你與 Osmile 的一天 📷",
      "在貼文底下留 3 則鼓勵留言，讓社群更溫暖 💬",
      "完成後記得去『好友排行榜』看看有沒有往上爬 🏃‍♂️",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "📌 社群任務小提示",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...missions.map(
          (m) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("• "),
                Expanded(
                  child: Text(
                    m,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

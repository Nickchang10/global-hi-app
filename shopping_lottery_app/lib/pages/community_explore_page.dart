import 'package:flutter/material.dart';
import 'group_chat_page.dart';

class CommunityExplorePage extends StatelessWidget {
  const CommunityExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> trendingCommunities = [
      {
        "name": "📱 智慧手錶玩家俱樂部",
        "desc": "分享使用心得、健康監測技巧、最新穿戴設備消息！",
        "members": 1280,
        "color": Colors.pinkAccent
      },
      {
        "name": "🎯 每日運動挑戰團",
        "desc": "每天簽到、打卡運動挑戰，堅持就是勝利 💪",
        "members": 840,
        "color": Colors.orangeAccent
      },
      {
        "name": "💬 抽獎心得社群",
        "desc": "分享中獎經驗、互抽贈品、快來當幸運王！🍀",
        "members": 560,
        "color": Colors.blueAccent
      },
      {
        "name": "🎥 短影音創作者圈",
        "desc": "學抖音剪輯、IG Reels、Osmile 影音挑戰都在這！",
        "members": 420,
        "color": Colors.purpleAccent
      },
    ];

    final List<Map<String, dynamic>> hotTopics = [
      {"tag": "#健康監測", "count": 120},
      {"tag": "#每日簽到", "count": 88},
      {"tag": "#抽獎活動", "count": 76},
      {"tag": "#智慧手環", "count": 63},
      {"tag": "#Osmile好物", "count": 58},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("🌍 探索社群"),
        backgroundColor: Colors.pinkAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "🔥 熱門社群",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 熱門社群卡片
          ...trendingCommunities.map((c) => _buildCommunityCard(context, c)),

          const SizedBox(height: 24),
          const Divider(thickness: 1.5),

          const Text(
            "💡 熱門話題標籤",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: hotTopics
                .map((t) => Chip(
                      backgroundColor: Colors.pink.shade50,
                      avatar: const Icon(Icons.tag, size: 18, color: Colors.pinkAccent),
                      label: Text(
                        "${t['tag']} (${t['count']})",
                        style: const TextStyle(color: Colors.pinkAccent, fontSize: 13),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: 24),
          const Divider(thickness: 1.5),

          const Text(
            "🎯 為你推薦",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildSuggestedCard(
            "👨‍👩‍👧‍👦 家長守護圈",
            "討論孩童安全手錶使用心得、定位技巧。",
            Colors.greenAccent,
            context,
          ),
          _buildSuggestedCard(
            "❤️ 長輩健康社群",
            "關心爸媽健康、血壓手環、用錶互動。",
            Colors.tealAccent,
            context,
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityCard(BuildContext context, Map<String, dynamic> c) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: c["color"],
          radius: 26,
          child: const Icon(Icons.groups, color: Colors.white, size: 26),
        ),
        title: Text(c["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(c["desc"], maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("${c["members"]} 位成員",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c["color"],
                minimumSize: const Size(60, 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupChatPage()),
                );
              },
              child: const Text("加入", style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedCard(
      String title, String desc, Color color, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: color.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(Icons.lightbulb_outline, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GroupChatPage()),
            );
          },
          child: const Text("查看", style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 👥 首頁下方「社交互動」橫向卡片列表
class FriendCardSection extends StatelessWidget {
  const FriendCardSection({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> friends = [
      {
        "name": "小明",
        "status": "今日步數 8231 👣",
        "avatar": "https://randomuser.me/api/portraits/men/12.jpg",
      },
      {
        "name": "小美",
        "status": "完成每日運動 💪",
        "avatar": "https://randomuser.me/api/portraits/women/45.jpg",
      },
      {
        "name": "阿成",
        "status": "剛完成 5 公里跑步 🏃‍♂️",
        "avatar": "https://randomuser.me/api/portraits/men/67.jpg",
      },
      {
        "name": "佳怡",
        "status": "分享了健康貼文 ❤️",
        "avatar": "https://randomuser.me/api/portraits/women/39.jpg",
      },
    ];

    return SizedBox(
      height: 120,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final f = friends[index];
          return Container(
            width: 160,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(f["avatar"]!),
                  radius: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f["name"]!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        f["status"]!,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

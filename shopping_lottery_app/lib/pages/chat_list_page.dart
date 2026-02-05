import 'package:flutter/material.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final List<Map<String, dynamic>> friends = [
    {
      "name": "小美",
      "avatar": "https://randomuser.me/api/portraits/women/65.jpg",
      "lastMsg": "昨天買的錶真的超棒！",
      "lastTime": "下午 2:32",
      "unread": 2,
      "isOnline": true,
    },
    {
      "name": "阿明",
      "avatar": "https://randomuser.me/api/portraits/men/45.jpg",
      "lastMsg": "明天要不要去健身？",
      "lastTime": "上午 9:10",
      "unread": 0,
      "isOnline": false,
    },
    {
      "name": "小倩",
      "avatar": "https://randomuser.me/api/portraits/women/29.jpg",
      "lastMsg": "你抽中代金券了嗎？😆",
      "lastTime": "昨天",
      "unread": 5,
      "isOnline": true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("聊天室 💬"),
        backgroundColor: Colors.pinkAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("好友邀請功能即將開放 🚀")),
              );
            },
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: friends.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final friend = friends[index];
          return ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(friend["avatar"]),
                  radius: 26,
                ),
                if (friend["isOnline"])
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              friend["name"],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              friend["lastMsg"],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  friend["lastTime"],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                if (friend["unread"] > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      friend["unread"].toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    friendName: friend["name"],
                    friendAvatar: friend["avatar"],
                  ),
                ),
              );
              setState(() {
                friend["unread"] = 0;
              });
            },
          );
        },
      ),
    );
  }
}

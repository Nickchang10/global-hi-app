import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/friend_service.dart';

/// 📰 好友動態牆
class FriendFeedPage extends StatelessWidget {
  const FriendFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = context.watch<FriendService>().friendPosts;
    return Scaffold(
      appBar: AppBar(title: const Text("好友動態")),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: posts.length,
        itemBuilder: (_, i) {
          final p = posts[i];
          final time = DateFormat("MM/dd HH:mm").format(p["time"]);
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person, color: Colors.white)),
                  title: Text(p["user"], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(time),
                ),
                if (p["image"] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(p["image"], fit: BoxFit.cover),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(p["content"]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.pinkAccent),
                      Text(" ${p["likes"]}"),
                      const SizedBox(width: 12),
                      const Icon(Icons.comment, color: Colors.grey),
                      Text(" ${(p["comments"] as List).length}"),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

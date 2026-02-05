import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/points_provider.dart';

class FriendInvitePage extends StatefulWidget {
  const FriendInvitePage({super.key});

  @override
  State<FriendInvitePage> createState() => _FriendInvitePageState();
}

class _FriendInvitePageState extends State<FriendInvitePage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final friend = Provider.of<FriendProvider>(context);
    final notify = Provider.of<NotificationProvider>(context, listen: false);
    final points = Provider.of<PointsProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("好友邀請"),
        backgroundColor: Colors.pinkAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔍 搜尋欄位
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "輸入使用者名稱...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final name = _searchController.text.trim();
                    if (name.isEmpty) return;

                    friend.sendFriendRequest(name, context, notify, points);
                    _searchController.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                  ),
                  child: const Text("發送邀請"),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 📬 收到的邀請
            if (friend.requests.isEmpty)
              const Expanded(
                child: Center(
                    child: Text("目前沒有新的好友邀請",
                        style: TextStyle(color: Colors.grey))),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: friend.requests.length,
                  itemBuilder: (context, index) {
                    final req = friend.requests[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(req["avatar"]),
                        ),
                        title: Text("${req["name"]} 邀請你成為好友"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () {
                                friend.acceptRequest(req, context, notify, points);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                friend.declineRequest(req);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

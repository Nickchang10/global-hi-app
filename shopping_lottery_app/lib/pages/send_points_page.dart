import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_provider.dart';
import '../providers/notification_provider.dart';

class SendPointsPage extends StatefulWidget {
  const SendPointsPage({super.key});

  @override
  State<SendPointsPage> createState() => _SendPointsPageState();
}

class _SendPointsPageState extends State<SendPointsPage> {
  int _amount = 10;

  @override
  Widget build(BuildContext context) {
    final friends = context.watch<FriendProvider>().friends;
    final notify = context.read<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("💌 贈送積分"),
        backgroundColor: Colors.orangeAccent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: friends.length,
        itemBuilder: (_, i) {
          final f = friends[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.pinkAccent,
                child: Text(f.name[0]),
              ),
              title: Text(f.name),
              subtitle: Text("目前積分：${f.points}"),
              trailing: ElevatedButton(
                onPressed: () {
                  f.points += _amount;
                  notify.notifications.insert(
                    0,
                    NotificationItem(
                      id: DateTime.now().toIso8601String(),
                      title: "💖 ${f.name} 收到積分禮物！",
                      message:
                          "你贈送了 $_amount 積分給 ${f.name}，友情值 +1！",
                    ),
                  );
                  notify.notifyListeners();

                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("已贈送 $_amount 積分給 ${f.name} 🎁"),
                  ));
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent),
                child: const Text("贈送"),
              ),
            ),
          );
        },
      ),
    );
  }
}

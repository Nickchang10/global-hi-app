import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/friend_service.dart';

class FriendChatPage extends StatefulWidget {
  final String friendName;
  const FriendChatPage({super.key, required this.friendName});

  @override
  State<FriendChatPage> createState() => _FriendChatPageState();
}

class _FriendChatPageState extends State<FriendChatPage> {
  final ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FriendService>();
    final chats = service.getChat(widget.friendName);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName),
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            onPressed: () => _showGiftSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: chats.length,
              itemBuilder: (_, i) {
                final msg = chats[i];
                final isMe = msg["from"] == "我";
                final time = DateFormat("HH:mm").format(msg["time"]);
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blueAccent : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(msg["text"],
                            style: TextStyle(
                                color: isMe ? Colors.white : Colors.black)),
                        const SizedBox(height: 2),
                        Text(time,
                            style: TextStyle(
                                fontSize: 10,
                                color: isMe ? Colors.white70 : Colors.black54)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: "輸入訊息...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blueAccent),
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  context
                      .read<FriendService>()
                      .sendMessage(widget.friendName, "我", ctrl.text.trim());
                  ctrl.clear();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGiftSheet(BuildContext context) {
    final gifts = [
      {"name": "💎 藍鑽", "value": 50},
      {"name": "🌹 玫瑰", "value": 20},
      {"name": "🎁 神秘禮物", "value": 100},
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("送出禮物 🎁",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          for (var g in gifts)
            ListTile(
              leading: const Icon(Icons.card_giftcard, color: Colors.pinkAccent),
              title: Text("${g["name"]}"),
              trailing: Text("-${g["value"]}P"),
              onTap: () {
                context
                    .read<FriendService>()
                    .sendGift(widget.friendName, g["name"], g["value"]);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("已送出 ${g["name"]} 給 ${widget.friendName} 🎉")));
              },
            ),
        ],
      ),
    );
  }
}

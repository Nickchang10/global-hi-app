import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/friend_service.dart';

/// 👥 群組聊天室頁面
class GroupChatPage extends StatefulWidget {
  final String groupId;
  const GroupChatPage({super.key, required this.groupId});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FriendService>();
    final group = service.groups.firstWhere((g) => g["id"] == widget.groupId);
    final messages = List<Map<String, dynamic>>.from(group["messages"]);

    return Scaffold(
      appBar: AppBar(
        title: Text(group["name"]),
        actions: [
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              const PopupMenuItem(value: "members", child: Text("查看成員")),
              const PopupMenuItem(value: "leave", child: Text("離開群組")),
            ],
            onSelected: (v) {
              if (v == "members") _showMembers(context, group);
              if (v == "leave") Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final msg = messages[i];
                final isMe = msg["from"] == "我";
                final time = DateFormat("HH:mm").format(msg["time"]);
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.tealAccent[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(msg["from"],
                            style: TextStyle(
                                fontSize: 11,
                                color: isMe ? Colors.white70 : Colors.black54)),
                        Text(msg["text"],
                            style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87)),
                        Text(time,
                            style: TextStyle(
                                fontSize: 10,
                                color: isMe ? Colors.white54 : Colors.black45)),
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
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: "輸入訊息...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.teal),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<FriendService>().sendGroupMessage(
                      widget.groupId,
                      "我",
                      ctrl.text.trim(),
                    );
                ctrl.clear();
              }
            },
          )
        ]),
      ),
    );
  }

  void _showMembers(BuildContext context, Map group) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("群組成員"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            (group["members"] as List).length,
            (i) => ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(group["members"][i]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("關閉"))
        ],
      ),
    );
  }
}

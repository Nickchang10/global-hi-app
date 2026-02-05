import 'package:flutter/material.dart';
import '../services/firestore_mock_service.dart';
import '../services/auth_service.dart';

/// 📨 訊息中心頁面（顯示 AI 對話記錄）
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final messages = FirestoreMockService.instance.aiMessages;

    return Scaffold(
      appBar: AppBar(
        title: const Text("訊息中心"),
        backgroundColor: const Color(0xFF007BFF),
      ),
      body: user == null
          ? const Center(
              child: Text("請先登入以查看訊息紀錄"),
            )
          : messages.isEmpty
              ? const Center(
                  child: Text(
                    "目前沒有任何對話紀錄",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final fromAI = m["from"] == "ai";
                    final time = m["time"] as DateTime;
                    return Align(
                      alignment: fromAI
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 260),
                        decoration: BoxDecoration(
                          color: fromAI
                              ? Colors.grey[200]
                              : const Color(0xFF007BFF),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: fromAI
                                ? const Radius.circular(0)
                                : const Radius.circular(12),
                            bottomRight: fromAI
                                ? const Radius.circular(12)
                                : const Radius.circular(0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m["text"],
                              style: TextStyle(
                                color: fromAI ? Colors.black87 : Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(time),
                              style: TextStyle(
                                fontSize: 11,
                                color: fromAI
                                    ? Colors.black45
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/ai');
        },
        backgroundColor: const Color(0xFF007BFF),
        label: const Text("與 AI 對話"),
        icon: const Icon(Icons.chat_outlined),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return "剛剛";
    if (diff.inHours < 1) return "${diff.inMinutes} 分鐘前";
    if (diff.inDays < 1) return "${diff.inHours} 小時前";
    return "${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}";
  }
}

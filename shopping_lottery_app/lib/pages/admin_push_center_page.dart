import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class AdminPushCenterPage extends StatefulWidget {
  const AdminPushCenterPage({super.key});

  @override
  State<AdminPushCenterPage> createState() => _AdminPushCenterPageState();
}

class _AdminPushCenterPageState extends State<AdminPushCenterPage> {
  final titleCtrl = TextEditingController();
  final msgCtrl = TextEditingController();

  void _send() {
    if (titleCtrl.text.isEmpty || msgCtrl.text.isEmpty) return;
    NotificationService.instance.addNotification(
      title: titleCtrl.text,
      message: msgCtrl.text,
      icon: Icons.campaign,
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("推播已發送至所有用戶"),
    ));
    titleCtrl.clear();
    msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("推播中心"),
        backgroundColor: const Color(0xFF007BFF),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "推播標題")),
            TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: "推播內容")),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _send,
              icon: const Icon(Icons.send),
              label: const Text("發送推播"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48)),
            )
          ],
        ),
      ),
    );
  }
}

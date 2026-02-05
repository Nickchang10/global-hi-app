import 'package:flutter/material.dart';
import '../services/security_service.dart';

class SecurityLogPage extends StatelessWidget {
  const SecurityLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = SecurityService.instance.logs;

    return Scaffold(
      appBar: AppBar(
        title: const Text("📋 安全事件日誌"),
        backgroundColor: const Color(0xFF007BFF),
        foregroundColor: Colors.white,
      ),
      body: logs.isEmpty
          ? const Center(child: Text("目前沒有安全事件"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (_, i) {
                final log = logs[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.security, color: Color(0xFF007BFF)),
                    title: Text(log["category"]),
                    subtitle: Text(log["message"]),
                    trailing: Text(
                      _formatTime(log["time"]),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatTime(DateTime t) {
    return "${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}";
  }
}

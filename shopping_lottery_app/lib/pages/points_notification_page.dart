import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

/// 💬 積分通知中心（整合所有任務與獎勵訊息）
///
/// 功能：
/// - 顯示所有通知（簽到 / 任務 / 兌換 / 一般）
/// - 按下可展開內容
/// - 一鍵清除所有通知
/// - 實時更新 (Provider)
class PointsNotificationPage extends StatefulWidget {
  const PointsNotificationPage({super.key});

  @override
  State<PointsNotificationPage> createState() => _PointsNotificationPageState();
}

class _PointsNotificationPageState extends State<PointsNotificationPage> {
  @override
  Widget build(BuildContext context) {
    final notificationService = context.watch<NotificationService>();
    final notifications = notificationService.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text("💬 積分通知中心"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "清除全部通知",
            icon: const Icon(Icons.cleaning_services_rounded),
            onPressed: () {
              if (notifications.isEmpty) return;
              setState(() => notificationService.clearAll());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("通知已清除 ✅"),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F9FB),
      body: notifications.isEmpty
          ? const Center(
              child: Text(
                "目前沒有任何通知 🕓",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: notifications.length,
              itemBuilder: (_, i) {
                final n = notifications[i];
                final type = n["type"] ?? "general";
                final icon = _iconForType(type);
                final color = _colorForType(type);
                final time = n["time"] as DateTime?;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.9),
                      child: Icon(icon, color: Colors.white),
                    ),
                    title: Text(
                      n["title"] ?? "通知",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      _timeString(time),
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    children: [
                      ListTile(
                        title: Text(n["message"] ?? ""),
                        subtitle: type == "mission"
                            ? const Text("任務完成 🎯",
                                style: TextStyle(color: Colors.blue))
                            : null,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // 🔔 通知類型對應圖示
  IconData _iconForType(String type) {
    switch (type) {
      case "mission":
        return Icons.flag_rounded;
      case "redeem":
        return Icons.card_giftcard;
      case "order":
        return Icons.receipt_long;
      case "lottery":
        return Icons.casino;
      case "points":
        return Icons.star;
      case "milestone":
        return Icons.emoji_events;
      default:
        return Icons.notifications;
    }
  }

  // 🎨 顏色對應
  Color _colorForType(String type) {
    switch (type) {
      case "mission":
        return Colors.blueAccent;
      case "redeem":
        return Colors.orangeAccent;
      case "order":
        return Colors.green;
      case "lottery":
        return Colors.purpleAccent;
      case "points":
        return Colors.amber;
      case "milestone":
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  // 🕓 時間格式化
  String _timeString(DateTime? t) {
    if (t == null) return "";
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return "${t.month}/${t.day} $h:$m";
  }
}

import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../widgets/points_push_overlay.dart';

/// 🚀 啟動推播管理器
///
/// 在 App 啟動時，自動讀取最新一條通知並以動畫方式顯示。
///
/// 使用方式：
///
/// ```dart
/// // 在 main.dart 或 SplashPage 初始化後呼叫
/// StartupPushManager.showLatestNotification(context);
/// ```
class StartupPushManager {
  static Future<void> showLatestNotification(BuildContext context) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final notifications = NotificationService.instance.notifications;
    if (notifications.isEmpty) return;

    final latest = notifications.first;
    final title = latest["title"] ?? "通知";
    final message = latest["message"] ?? "您有一則新通知";
    final icon = latest["icon"];
    final type = latest["type"] ?? "general";

    // 顏色依照通知類型變化
    final color = _colorForType(type);

    PointsPushOverlay.show(
      context,
      title: title,
      message: message,
      icon: icon ?? Icons.notifications_active,
      color: color,
      duration: const Duration(seconds: 4),
    );
  }

  static Color _colorForType(String type) {
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
}

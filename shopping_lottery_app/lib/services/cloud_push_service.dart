import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class CloudPushService {
  static final CloudPushService instance = CloudPushService._internal();
  CloudPushService._internal();

  /// 模擬雲端推播事件
  Future<void> simulateRemotePush(String title, String msg) async {
    await Future.delayed(const Duration(seconds: 2));
    NotificationService.instance.addNotification(
      title: "📡 $title",
      message: msg,
      icon: Icons.cloud_outlined,
    );
    debugPrint("📨 Simulated cloud push received: $title");
  }
}

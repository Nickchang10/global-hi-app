import 'package:flutter/material.dart';
import 'dart:async';
import 'notification_service.dart';

/// 📦 模擬 FCM 推播中心
/// 即使 App 在背景，也能以 Overlay 或 Dialog 形式模擬推播通知
class MockFCMService {
  static final MockFCMService instance = MockFCMService._internal();
  MockFCMService._internal();

  final _notify = NotificationService.instance;
  Timer? _mockTimer;

  /// 啟動模擬 FCM：會定期發送假推播事件
  void startSimulation(BuildContext context, {String orderId = "A123456"}) {
    _mockTimer?.cancel();
    debugPrint("🔔 Mock FCM started for order $orderId");

    _mockTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final now = DateTime.now();
      final msgType = [
        "📦 商品打包中",
        "🚚 配送中",
        "✅ 已送達",
      ][timer.tick % 3];

      final msgDesc = [
        "您的包裹正在準備出貨。",
        "物流人員正前往送達中。",
        "包裹已送達，感謝支持！",
      ][timer.tick % 3];

      // ✅ 寫入通知系統
      _notify.addNotification(
        title: msgType,
        message: msgDesc,
        icon: Icons.notifications_active_outlined,
        orderId: orderId,
        context: context,
        showOverlay: true,
      );
    });
  }

  /// 停止模擬
  void stop() {
    _mockTimer?.cancel();
    _mockTimer = null;
    debugPrint("🛑 Mock FCM stopped");
  }
}

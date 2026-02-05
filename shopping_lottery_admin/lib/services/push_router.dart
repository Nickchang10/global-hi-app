// lib/services/push_router.dart
//
// ✅ PushRouter（完整最終版）
// ------------------------------------------------------------
// - 處理 Firebase Messaging 推播點擊邏輯
// - 支援前景、背景、terminated 狀態
// - 自動導向 /admin/orders/detail（含 orderId）
// ------------------------------------------------------------

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class PushRouter {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// 初始化（App 啟動時呼叫）
  static Future<void> init(BuildContext context) async {
    // ✅ App 在背景被點擊推播打開
    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) => _handleMessage(context, message),
    );

    // ✅ App 關閉（terminated）後由推播開啟
    final initialMsg = await _fcm.getInitialMessage();
    if (initialMsg != null) {
      _handleMessage(context, initialMsg);
    }
  }

  /// 處理推播導向邏輯
  static void _handleMessage(BuildContext context, RemoteMessage message) {
    final data = message.data;

    // 🔍 偵測類型（order_shipping / order_paid / etc.）
    final type = data['type'] ?? '';
    final orderId = data['orderId'] ?? '';

    if (type == 'order_shipping' && orderId.isNotEmpty) {
      Navigator.pushNamed(
        context,
        '/admin/orders/detail',
        arguments: orderId,
      );
      return;
    }

    // 其他類型可擴充（例如活動推播）
    debugPrint('[PushRouter] Unhandled message type: $type');
  }
}

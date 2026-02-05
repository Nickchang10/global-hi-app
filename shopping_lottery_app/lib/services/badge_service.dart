// lib/services/badge_service.dart
import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'firestore_mock_service.dart';

/// 🔴 全域紅點狀態管理服務
///
/// 功能：
/// - 監控購物車數量、未讀通知數、社群提醒
/// - 即時更新底部導航紅點
/// - 可供其他頁面觸發（如新訊息、好友請求等）
class BadgeService extends ChangeNotifier {
  BadgeService._internal();
  static final BadgeService instance = BadgeService._internal();

  int _cartCount = 0;
  int _socialCount = 0;

  int get cartCount => _cartCount;
  int get socialCount => _socialCount;

  /// 通知紅點（取自 NotificationService）
  bool get hasUnreadNotifications =>
      NotificationService.instance.hasUnread;

  /// 🛍 更新購物車數量
  void updateCartCount(int count) {
    _cartCount = count;
    notifyListeners();
  }

  /// 💬 更新社群互動提醒（留言 / 按讚）
  void updateSocialCount(int count) {
    _socialCount = count;
    notifyListeners();
  }

  /// 🔄 全部更新（供首頁定期刷新）
  void refreshAll() {
    _cartCount = FirestoreMockService.instance.cartItems.length;
    notifyListeners();
  }

  /// 清除社群紅點
  void clearSocial() {
    _socialCount = 0;
    notifyListeners();
  }
}

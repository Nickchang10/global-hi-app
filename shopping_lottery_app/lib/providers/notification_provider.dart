import 'package:flutter/material.dart';

/// 通知類型：可以依來源分類顏色／icon
enum NotificationType {
  system,   // 系統 / 一般
  order,    // 訂單
  lottery,  // 抽獎
  social,   // 社交互動（按讚 / 留言）
  chat,     // 聊天訊息
}

/// 單一通知物件
class NotificationItem {
  final String title;
  final String message;
  final DateTime time;
  final NotificationType type;
  bool read;

  NotificationItem({
    required this.title,
    required this.message,
    this.type = NotificationType.system,
    this.read = false,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class NotificationProvider extends ChangeNotifier {
  final List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications =>
      List.unmodifiable(_notifications);

  /// 全部未讀數（用在首頁通知鈴鐺）
  int get unreadCount =>
      _notifications.where((n) => !n.read).length;

  /// 聊天未讀數（用在底部「社交」小紅點）
  int get unreadChatCount => _notifications
      .where((n) => !n.read && n.type == NotificationType.chat)
      .length;

  /// 新增一筆通知
  void addNotification(
    String title,
    String message, {
    NotificationType type = NotificationType.system,
  }) {
    _notifications.insert(
      0,
      NotificationItem(
        title: title,
        message: message,
        type: type,
      ),
    );
    notifyListeners();
  }

  /// 全部標記為已讀
  void markAllAsRead() {
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  /// 只把「聊天類型」標記為已讀（如果之後你要用得到）
  void markChatAsRead() {
    for (final n in _notifications) {
      if (n.type == NotificationType.chat) {
        n.read = true;
      }
    }
    notifyListeners();
  }

  /// 全部清空
  void clear() {
    _notifications.clear();
    notifyListeners();
  }
}

// lib/services/notification_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

class AppNotification {
  final String id;
  final String type; // 互動 / 系統 / 訂單 / lottery ...
  final String title;
  final String message;
  final DateTime createdAt;
  bool read;

  /// 可選：附帶資料（例如 deep link、payload）
  final Map<String, dynamic> data;

  /// 可選：這則通知要送給哪個 uid（後台/多帳號測試時方便）
  final String? uid;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.read = false,
    this.data = const <String, dynamic>{},
    this.uid,
  });
}

class NotificationService extends ChangeNotifier {
  final List<AppNotification> _items = [];

  // ✅ unreadCount stream（dashboard_page.dart 用）
  final StreamController<int> _unreadCountCtrl =
      StreamController<int>.broadcast();

  NotificationService() {
    _emitUnreadCount();
  }

  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.read).length;

  /// ✅ dashboard_page.dart 需要的方法：streamUnreadCount()
  Stream<int> streamUnreadCount() => _unreadCountCtrl.stream;

  void addNotification({
    required String type,
    required String title,
    required String message,
    Map<String, dynamic> data = const <String, dynamic>{},
    String? uid,
  }) {
    final n = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: title,
      message: message,
      createdAt: DateTime.now(),
      read: false,
      data: data,
      uid: uid,
    );

    _items.insert(0, n);

    // 最多保留 200 筆，避免越跑越肥
    if (_items.length > 200) {
      _items.removeRange(200, _items.length);
    }

    _emitUnreadCount();
    notifyListeners();
  }

  Map<String, dynamic> _mergePayload({
    Map<String, dynamic>? data,
    Map<String, dynamic>? extra, // ✅ 相容 lottery_admin_page.dart 的 extra
    String? route,
  }) {
    final payload = <String, dynamic>{};
    if (data != null) payload.addAll(data);
    if (extra != null) payload.addAll(extra);
    if (route != null && route.trim().isNotEmpty) {
      payload['route'] = route.trim();
    }
    return payload;
  }

  /// ✅ 單一使用者（本機記憶體版）
  /// - data / extra 會被合併
  /// - route 會被放入 `payload['route']`
  Future<void> sendToUser({
    required String uid,
    required String title,
    required String body,
    String type = 'system',
    String? route,
    Map<String, dynamic>? data,
    Map<String, dynamic>? extra, // ✅ FIX: 支援 extra:
  }) async {
    final payload = _mergePayload(data: data, extra: extra, route: route);

    addNotification(
      type: type,
      title: title,
      message: body,
      data: payload,
      uid: uid,
    );
  }

  /// ✅ 多使用者（AdminNotificationLogsPage 需要）
  /// - 支援 extra 參數（相容 lottery_admin_page.dart）
  Future<void> sendToUsers({
    required List<String> uids,
    required String title,
    required String body,
    String type = 'system',
    String? route,
    Map<String, dynamic>? data,
    Map<String, dynamic>? extra, // ✅ FIX: 支援 extra:
  }) async {
    final uniq = uids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (uniq.isEmpty) return;
    if (title.trim().isEmpty || body.trim().isEmpty) return;

    final payload = _mergePayload(data: data, extra: extra, route: route);

    for (final uid in uniq) {
      addNotification(
        type: type,
        title: title,
        message: body,
        data: payload,
        uid: uid,
      );
    }
  }

  /// ✅ 既有：同步全部已讀（保留給舊呼叫）
  void markAllRead() {
    for (final n in _items) {
      n.read = true;
    }
    _emitUnreadCount();
    notifyListeners();
  }

  /// ✅ ✅ 給 UserNotificationsPage 用：可 await 的版本
  /// （你頁面用 await service.markAllAsRead()，所以要回傳 `Future<void>`）
  Future<void> markAllAsRead() async {
    markAllRead();
  }

  void markRead(String id, {bool read = true}) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _items[idx].read = read;

    _emitUnreadCount();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _emitUnreadCount();
    notifyListeners();
  }

  void _emitUnreadCount() {
    if (_unreadCountCtrl.isClosed) return;
    _unreadCountCtrl.add(unreadCount);
  }

  @override
  void dispose() {
    _unreadCountCtrl.close();
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';

/// ✅ MockFcmService（完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - type 不再 required（避免 missing_required_argument）
/// - 統一用 String type，預設 'general'
/// - 提供 stream + inbox，方便 UI 監聽與除錯
/// - 提供多個別名方法（send/notify/pushToUser），提高舊碼相容性
/// ------------------------------------------------------------
class MockFcmService extends ChangeNotifier {
  MockFcmService._();

  /// ✅ singleton
  static final MockFcmService instance = MockFcmService._();

  final List<MockFcmMessage> _inbox = [];
  final StreamController<MockFcmMessage> _controller =
      StreamController<MockFcmMessage>.broadcast();

  /// 近期訊息（記憶體）
  List<MockFcmMessage> get inbox => List.unmodifiable(_inbox);

  /// 模擬「前景收到推播」事件流
  Stream<MockFcmMessage> get stream => _controller.stream;

  /// 未讀數（optional）
  int get unreadCount => _inbox.where((e) => !e.isRead).length;

  /// 推送（核心方法）
  /// - ✅ type 改成可選：String? type
  Future<MockFcmMessage> pushToUser(
    String uid, {
    required String title,
    required String body,
    String? type, // ✅ 不再 required
    Map<String, dynamic>? data,
  }) async {
    final msg = MockFcmMessage(
      id: _genId(),
      uid: uid,
      title: title,
      body: body,
      type: (type == null || type.trim().isEmpty) ? 'general' : type.trim(),
      data: data ?? const {},
      sentAtMs: DateTime.now().millisecondsSinceEpoch,
      isRead: false,
    );

    _inbox.insert(0, msg);
    if (_inbox.length > 200) _inbox.removeLast();

    // 發事件（模擬 FCM onMessage）
    _controller.add(msg);
    notifyListeners();
    return msg;
  }

  // -------------------------
  // ✅ 相容舊碼的別名（避免你其他檔案叫不同方法名）
  // -------------------------
  Future<MockFcmMessage> push(
    String uid, {
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) => pushToUser(uid, title: title, body: body, type: type, data: data);

  Future<MockFcmMessage> send(
    String uid, {
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) => pushToUser(uid, title: title, body: body, type: type, data: data);

  Future<MockFcmMessage> notify(
    String uid, {
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) => pushToUser(uid, title: title, body: body, type: type, data: data);

  // -------------------------
  // 操作：標記已讀 / 清除
  // -------------------------
  void markRead(String id) {
    final idx = _inbox.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _inbox[idx] = _inbox[idx].copyWith(isRead: true);
    notifyListeners();
  }

  void markAllRead() {
    if (_inbox.isEmpty) return;
    for (int i = 0; i < _inbox.length; i++) {
      if (!_inbox[i].isRead) _inbox[i] = _inbox[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  void remove(String id) {
    _inbox.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void clear() {
    _inbox.clear();
    notifyListeners();
  }

  // -------------------------
  // Demo / debug seed
  // -------------------------
  void seedDemo(String uid) {
    // ✅ 這裡即使不傳 type 也不會再報錯
    pushToUser(uid, title: '歡迎使用 Osmile', body: '這是一則示範推播通知');
    pushToUser(uid, title: '任務更新', body: '新的每日任務已刷新！', type: 'mission');
    pushToUser(
      uid,
      title: '訂單狀態',
      body: '你的訂單已出貨',
      type: 'order',
      data: {'status': 'shipped'},
    );
  }

  String _genId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final r = (ts % 100000).toString().padLeft(5, '0');
    return 'fcm_$ts$r';
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

/// ✅ 推播訊息模型
@immutable
class MockFcmMessage {
  const MockFcmMessage({
    required this.id,
    required this.uid,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.sentAtMs,
    required this.isRead,
  });

  final String id;
  final String uid;
  final String title;
  final String body;

  /// general / mission / order / promo / security / chat ...
  final String type;

  final Map<String, dynamic> data;
  final int sentAtMs;
  final bool isRead;

  MockFcmMessage copyWith({
    String? id,
    String? uid,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    int? sentAtMs,
    bool? isRead,
  }) {
    return MockFcmMessage(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      sentAtMs: sentAtMs ?? this.sentAtMs,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'uid': uid,
    'title': title,
    'body': body,
    'type': type,
    'data': data,
    'sentAtMs': sentAtMs,
    'isRead': isRead,
  };

  factory MockFcmMessage.fromMap(Map<String, dynamic> map) {
    return MockFcmMessage(
      id: (map['id'] ?? '').toString(),
      uid: (map['uid'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      type: (map['type'] ?? 'general').toString(),
      data: map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : const {},
      sentAtMs: _toInt(map['sentAtMs']),
      isRead: map['isRead'] == true,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

// lib/services/firestore_mock_service.dart

/// 簡單的本地 mock，供 LotteryService 在缺乏專屬後端時回退使用。
/// 你可以不用，如果你有完整後端就移除或替換。
library;

import 'dart:math';

class FirestoreMockService {
  FirestoreMockService._internal();
  static final FirestoreMockService instance = FirestoreMockService._internal();

  static const String _defaultUser = '__default__';

  final Map<String, int> _pointsByUser = <String, int>{};

  // 簡單通知暫存（可選用）
  final List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];

  String _uid(String? userId) {
    final s = (userId ?? '').trim();
    return s.isEmpty ? _defaultUser : s;
  }

  // ------------------------------------------------------------
  // Points (Mock)
  // ------------------------------------------------------------

  /// 相容舊用法：未指定 userId 時，會落在 default user
  int get userPoints => _pointsByUser[_defaultUser] ?? 0;
  set userPoints(int v) => _pointsByUser[_defaultUser] = v;

  Future<int> getPoints(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return _pointsByUser[_uid(userId)] ?? 0;
  }

  Future<void> addPoints(int value, {String? userId}) async {
    final id = _uid(userId);
    final cur = _pointsByUser[id] ?? 0;
    _pointsByUser[id] = cur + value;
  }

  Future<bool> spendPoints(int value, {String? userId}) async {
    final id = _uid(userId);
    final cur = _pointsByUser[id] ?? 0;
    if (cur < value) return false;
    _pointsByUser[id] = cur - value;
    return true;
  }

  Future<void> deductPoints(int value, {String? userId}) async {
    final id = _uid(userId);
    final cur = _pointsByUser[id] ?? 0;
    _pointsByUser[id] = (cur - value).clamp(0, 1 << 30);
  }

  /// fallback helpers used by LotteryService.resetPoints
  Future<void> setPoints(String userId, int value) async {
    _pointsByUser[_uid(userId)] = value;
  }

  /// 重置所有 mock 狀態
  Future<void> reset() async {
    _pointsByUser.clear();
    _notifications.clear();
  }

  // ------------------------------------------------------------
  // Notifications (Mock) - optional but helps compile when used
  // ------------------------------------------------------------

  /// 避免 LotteryService / 其他 service 呼叫時噴:
  /// "The method 'addNotification' isn't defined for the type 'FirestoreMockService'."
  ///
  /// 這裡只做「本地暫存」，不會真的寫 Firestore。
  Future<void> addNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'system',
    String level = 'info',
    String? refId,
    Map<String, dynamic>? data,
    DateTime? createdAt,
  }) async {
    final now = createdAt ?? DateTime.now();
    _notifications.add(<String, dynamic>{
      'id': _genId(),
      'userId': _uid(userId),
      'title': title.trim(),
      'body': body.trim(),
      'type': type.trim(),
      'level': level.trim(),
      'refId': (refId ?? '').trim(),
      if (data != null) 'data': data,
      'createdAt': now.toIso8601String(),
      'isRead': false,
    });
  }

  /// 取得某使用者通知（本地）
  List<Map<String, dynamic>> getNotifications(String userId) {
    final id = _uid(userId);
    final items = _notifications
        .where((n) => (n['userId'] ?? '') == id)
        .toList();
    items.sort(
      (a, b) => (b['createdAt'] ?? '').toString().compareTo(
        (a['createdAt'] ?? '').toString(),
      ),
    );
    return items;
  }

  /// 清除某使用者通知（本地）；不帶 userId 則清全部
  Future<void> clearNotifications({String? userId}) async {
    final id = (userId ?? '').trim();
    if (id.isEmpty) {
      _notifications.clear();
      return;
    }
    _notifications.removeWhere((n) => (n['userId'] ?? '') == _uid(id));
  }

  String _genId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final r = Random().nextInt(1 << 30);
    return 'mock_${ts}_$r';
  }
}

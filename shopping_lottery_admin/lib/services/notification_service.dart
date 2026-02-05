// lib/services/notification_service.dart
//
// ✅ NotificationService（v1.5 Final｜Production Ready｜最終完整版）
// ------------------------------------------------------------
// 改進重點（最終穩定版）：
// 1) Firestore Index Error 自動捕捉與提示（Debug 可印出建立索引連結）
// 2) ✅ 所有 Stream 都「吞錯 + 回傳 fallback」，避免 error 往上丟造成 UI crash
// 3) ✅ onlyUnread 查詢不加 orderBy（避免 composite index），改 client 端排序
// 4) ✅ 所有批次寫入（sendToUsers / markAllRead / clearAll）都做 chunk（避免超過 500 operations）
// 5) 與 Dashboard / NotificationsPage / Lottery 完全相容
// ------------------------------------------------------------
// Firestore 結構：
// notifications/{uid}/items/{notificationId}
// fields:
//   - title: String
//   - body: String
//   - type: String
//   - isRead: bool
//   - route: String
//   - extra: Map<String,dynamic>
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
// ------------------------------------------------------------

import 'dart:async'; // ✅ 必須：StreamTransformer 來源

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class AppNotification {
  final String id;
  final String uid;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> extra;
  final String route;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppNotification({
    required this.id,
    required this.uid,
    required this.title,
    required this.body,
    required this.type,
    required this.extra,
    required this.route,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      // seconds or milliseconds
      if (v < 10000000000) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    return null;
  }

  factory AppNotification.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String uid,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    final type = _s(data['type']);
    final extraRaw = data['extra'];

    return AppNotification(
      id: doc.id,
      uid: uid,
      title: _s(data['title']),
      body: _s(data['body']),
      type: type.isEmpty ? 'system' : type,
      isRead: data['isRead'] == true,
      route: _s(data['route']),
      extra: (extraRaw is Map)
          ? Map<String, dynamic>.from(extraRaw as Map)
          : <String, dynamic>{},
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'body': body,
        'type': type,
        'isRead': isRead,
        'route': route,
        'extra': extra,
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
        'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      };

  Map<String, dynamic> toUiMap() => <String, dynamic>{
        'id': id,
        'uid': uid,
        'title': title,
        'body': body,
        'type': type,
        'isRead': isRead,
        'route': route,
        'extra': extra,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  bool get read => isRead;
}

class NotificationService extends ChangeNotifier {
  NotificationService({
    FirebaseFirestore? firestore,
    bool enableDebugLog = false,
    void Function(String message)? logger,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _enableDebugLog = enableDebugLog,
        _logger = logger;

  final FirebaseFirestore _db;
  final bool _enableDebugLog;
  final void Function(String message)? _logger;

  // ============================================================
  // 🔧 Helpers
  // ============================================================

  CollectionReference<Map<String, dynamic>> _itemsRef(String uid) =>
      _db.collection('notifications').doc(uid).collection('items');

  void _log(String s) {
    if (!_enableDebugLog) return;
    if (_logger != null) {
      _logger!(s);
    } else if (kDebugMode) {
      // ignore: avoid_print
      print(s);
    }
  }

  void _handleFirestoreError(dynamic e, String tag) {
    final msg = e.toString();
    if (msg.contains('failed-precondition') && msg.contains('index')) {
      _log('⚠️ Firestore 索引錯誤（$tag）：請至 Firebase Console 建立索引。');
      final match =
          RegExp(r'https:\/\/console\.firebase\.google\.com[^\s]+').stringMatch(msg);
      if (match != null) {
        _log('👉 建立索引連結：$match');
      } else {
        _log('請至 Firestore Console → Indexes → 建立 composite index。');
      }
    } else {
      _log('[NotificationService][$tag] error: $e');
    }
  }

  int _limitInt(int value, {int min = 1, int max = 300}) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Firestore batch 一次最多 500 ops；保守用 450
  static const int _batchLimit = 450;

  /// ✅ 讓 Stream「吞錯 + 回傳 fallback」，避免 error 往上冒泡造成 UI crash
  Stream<T> _guardStream<T>(
    Stream<T> source, {
    required T fallback,
    required String tag,
  }) {
    return source.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          _handleFirestoreError(error, tag);
          sink.add(fallback);
          // 不再 addError，確保 UI 不會收到 error event
        },
      ),
    );
  }

  // ============================================================
  // 📡 Streams
  // ============================================================

  Stream<int> streamUnreadCount(String uid) {
    final u = uid.trim();
    if (u.isEmpty) return Stream<int>.value(0);

    final source = _itemsRef(u)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);

    return _guardStream<int>(source, fallback: 0, tag: 'streamUnreadCount');
  }

  /// ✅ 主通知串流
  /// - onlyUnread=true：不加 orderBy（避免 composite index），client 排序
  /// - onlyUnread=false：orderBy createdAt desc（一般情況 OK）
  Stream<List<AppNotification>> streamItems(
    String uid, {
    int limit = 100,
    bool onlyUnread = false,
  }) {
    final u = uid.trim();
    if (u.isEmpty) return Stream<List<AppNotification>>.value(<AppNotification>[]);

    final lim = _limitInt(limit, min: 1, max: 300);

    Query<Map<String, dynamic>> q;
    if (onlyUnread) {
      q = _itemsRef(u).where('isRead', isEqualTo: false).limit(lim);
    } else {
      q = _itemsRef(u).orderBy('createdAt', descending: true).limit(lim);
    }

    final source = q.snapshots().map((snap) {
      try {
        final list =
            snap.docs.map((d) => AppNotification.fromDoc(d, uid: u)).toList();

        if (onlyUnread) {
          list.sort((a, b) {
            final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bd.compareTo(ad);
          });
        }
        return list;
      } catch (e) {
        _handleFirestoreError(e, 'streamItems.map');
        return <AppNotification>[];
      }
    });

    return _guardStream<List<AppNotification>>(
      source,
      fallback: <AppNotification>[],
      tag: 'streamItems',
    );
  }

  Stream<List<Map<String, dynamic>>> streamNotifications(
    String uid, {
    bool unreadOnly = false,
    int limit = 50,
  }) {
    final source = streamItems(uid, onlyUnread: unreadOnly, limit: limit)
        .map((list) => list.map((n) => n.toUiMap()).toList());

    return _guardStream<List<Map<String, dynamic>>>(
      source,
      fallback: <Map<String, dynamic>>[],
      tag: 'streamNotifications',
    );
  }

  // ============================================================
  // ✉️ Create / Send
  // ============================================================

  Future<String> createNotification({
    required String uid,
    required String title,
    String body = '',
    String type = 'system',
    String route = '',
    Map<String, dynamic>? extra,
  }) async {
    final u = uid.trim();
    if (u.isEmpty) throw StateError('Invalid uid');

    final ref = _itemsRef(u).doc();
    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
      'type': type.trim().isEmpty ? 'system' : type.trim(),
      'isRead': false,
      'route': route.trim(),
      'extra': extra ?? <String, dynamic>{},
      'createdAt': now,
      'updatedAt': now,
    };

    await ref.set(data, SetOptions(merge: true));
    _log('[NotificationService] createNotification uid=$u id=${ref.id}');
    return ref.id;
  }

  Future<void> sendToUser({
    required String uid,
    required String title,
    String body = '',
    String type = 'system',
    String route = '',
    Map<String, dynamic>? extra,
  }) async {
    await createNotification(
      uid: uid,
      title: title,
      body: body,
      type: type,
      route: route,
      extra: extra,
    );
  }

  /// ✅ 批次發送（自動 chunk，避免超過 500 ops）
  Future<void> sendToUsers({
    required List<String> uids,
    required String title,
    String body = '',
    String type = 'system',
    String route = '',
    Map<String, dynamic>? extra,
  }) async {
    final targets =
        uids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (targets.isEmpty) return;

    _log('[NotificationService] sendToUsers count=${targets.length} type=$type');

    for (int i = 0; i < targets.length; i += _batchLimit) {
      final end = (i + _batchLimit > targets.length) ? targets.length : i + _batchLimit;
      final chunk = targets.sublist(i, end);

      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();

      for (final uid in chunk) {
        final ref = _itemsRef(uid).doc();
        batch.set(ref, <String, dynamic>{
          'title': title.trim(),
          'body': body.trim(),
          'type': type.trim().isEmpty ? 'system' : type.trim(),
          'isRead': false,
          'route': route.trim(),
          'extra': extra ?? <String, dynamic>{},
          'createdAt': now,
          'updatedAt': now,
        });
      }

      await batch.commit();
    }
  }

  /// ✅ 廣播給所有 vendor（依 users.role == vendor）
  Future<void> broadcastToAllVendors({
    required String title,
    required String body,
    String type = 'announcement',
    String route = '',
    Map<String, dynamic>? extra,
  }) async {
    try {
      final qs =
          await _db.collection('users').where('role', isEqualTo: 'vendor').get();
      final uids = qs.docs.map((d) => d.id).toList();
      if (uids.isEmpty) {
        _log('[NotificationService] broadcastToAllVendors: no vendor found');
        return;
      }
      await sendToUsers(
        uids: uids,
        title: title,
        body: body,
        type: type,
        route: route,
        extra: extra,
      );
    } catch (e) {
      _handleFirestoreError(e, 'broadcastToAllVendors');
    }
  }

  // ============================================================
  // ✅ Update Read State
  // ============================================================

  Future<void> markRead(
    String uid,
    String notificationId, {
    bool read = true,
  }) async {
    final u = uid.trim();
    final id = notificationId.trim();
    if (u.isEmpty || id.isEmpty) return;

    try {
      await _itemsRef(u).doc(id).set(
        <String, dynamic>{
          'isRead': read,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      _handleFirestoreError(e, 'markRead');
    }
  }

  Future<void> markAsRead(String uid, String notificationId) =>
      markRead(uid, notificationId, read: true);

  Future<void> toggleRead(String uid, String notificationId) async {
    final u = uid.trim();
    final id = notificationId.trim();
    if (u.isEmpty || id.isEmpty) return;

    final ref = _itemsRef(u).doc(id);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? <String, dynamic>{};
        final cur = data['isRead'] == true;

        tx.set(
          ref,
          <String, dynamic>{
            'isRead': !cur,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      _handleFirestoreError(e, 'toggleRead');
    }
  }

  /// ✅ 全部標已讀（自動 chunk；limit 是最多處理筆數）
  Future<void> markAllRead(String uid, {int limit = 500}) async {
    final u = uid.trim();
    if (u.isEmpty) return;

    final maxTotal = _limitInt(limit, min: 1, max: 5000);
    int processed = 0;

    try {
      while (processed < maxTotal) {
        final chunkSize =
            (maxTotal - processed) > _batchLimit ? _batchLimit : (maxTotal - processed);

        final snap = await _itemsRef(u)
            .where('isRead', isEqualTo: false)
            .limit(chunkSize)
            .get();

        if (snap.docs.isEmpty) break;

        final batch = _db.batch();
        for (final d in snap.docs) {
          batch.set(
            d.reference,
            <String, dynamic>{
              'isRead': true,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
        processed += snap.docs.length;

        if (snap.docs.length < chunkSize) break;
      }
    } catch (e) {
      _handleFirestoreError(e, 'markAllRead');
    }
  }

  Future<void> markAllAsRead(String uid, {int limit = 500}) =>
      markAllRead(uid, limit: limit);

  // ============================================================
  // 🗑 Delete / Clear
  // ============================================================

  Future<void> deleteOne(String uid, String notificationId) async {
    final u = uid.trim();
    final id = notificationId.trim();
    if (u.isEmpty || id.isEmpty) return;

    try {
      await _itemsRef(u).doc(id).delete();
    } catch (e) {
      _handleFirestoreError(e, 'deleteOne');
    }
  }

  /// ✅ 清空（自動 chunk；limit 是最多刪除筆數）
  Future<void> clearAll(String uid, {int limit = 500}) async {
    final u = uid.trim();
    if (u.isEmpty) return;

    final maxTotal = _limitInt(limit, min: 1, max: 5000);
    int deleted = 0;

    try {
      while (deleted < maxTotal) {
        final chunkSize =
            (maxTotal - deleted) > _batchLimit ? _batchLimit : (maxTotal - deleted);

        Query<Map<String, dynamic>> q = _itemsRef(u).orderBy('createdAt', descending: true);

        final snap = await q.limit(chunkSize).get();
        if (snap.docs.isEmpty) break;

        final batch = _db.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();

        deleted += snap.docs.length;
        if (snap.docs.length < chunkSize) break;
      }
    } catch (e) {
      _handleFirestoreError(e, 'clearAll');
    }
  }

  // ============================================================
  // 🔢 Aggregate Count
  // ============================================================

  Future<int> getUnreadCount(String uid) async {
    final u = uid.trim();
    if (u.isEmpty) return 0;

    try {
      final agg = await _itemsRef(u).where('isRead', isEqualTo: false).count().get();
      final dynamic c = agg.count;
      return (c is int) ? c : int.tryParse('$c') ?? 0;
    } catch (e) {
      _handleFirestoreError(e, 'getUnreadCount');
      return 0;
    }
  }
}

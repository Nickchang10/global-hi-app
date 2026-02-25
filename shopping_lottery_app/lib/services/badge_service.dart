// lib/services/badge_service.dart
//
// ✅ BadgeService（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// ✅ 監聽 users/{uid}/notifications 未讀數 read=false
// ✅ 提供：
//   - unreadNotificationsCount / hasUnread / hasUnreadNotifications
//   - socialCount / countOf(type)
// ✅ 監聽 users/{uid}/cart 的筆數
//   - cartCount（✅ 修正 bottom_nav_bar 需要）
// ✅ 提供：markAllRead() / clearAll() / clearSocial()
// ----------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class BadgeService extends ChangeNotifier {
  BadgeService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  static final BadgeService instance = BadgeService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  StreamSubscription<User?>? _authSub;

  // unread notifications
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _unreadSub;

  // cart count
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cartSub;

  bool _started = false;

  int _unreadNotifications = 0;
  Map<String, int> _unreadByType = const <String, int>{};

  int _cartCount = 0;

  // ---------- getters ----------
  int get unreadNotificationsCount => _unreadNotifications;

  /// 新命名
  bool get hasUnread => _unreadNotifications > 0;

  /// 舊命名相容（bottom_nav_bar 用到）
  bool get hasUnreadNotifications => hasUnread;

  /// bottom_nav_bar 常用（未讀 social 類型數量）
  int get socialCount => _unreadByType['social'] ?? 0;

  /// 泛用：order/lottery/...
  int countOf(String type) => _unreadByType[type] ?? 0;

  /// ✅ bottom_nav_bar 需要的購物車數量
  int get cartCount => _cartCount;

  bool get hasCart => _cartCount > 0;

  /// ✅ App 啟動後呼叫一次即可（可重複呼叫，不會重複訂閱）
  void start() {
    if (_started) return;
    _started = true;

    _handleUser(_auth.currentUser);

    _authSub?.cancel();
    _authSub = _auth.userChanges().listen((u) => _handleUser(u));
  }

  void _handleUser(User? user) {
    if (user == null) {
      _cancelUnreadSub();
      _cancelCartSub();
      _setUnreadCounts(total: 0, byType: const {});
      _setCartCount(0);
      return;
    }

    _listenUnreadNotifications(user.uid);
    _listenCartCount(user.uid);
  }

  // -----------------------------
  // Unread notifications listener
  // -----------------------------
  void _listenUnreadNotifications(String uid) {
    _cancelUnreadSub();

    final q = _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false);

    _unreadSub = q.snapshots().listen(
      (snap) {
        final byType = <String, int>{};
        for (final d in snap.docs) {
          final data = d.data();
          final t = (data['type'] ?? '').toString();
          if (t.isEmpty) continue;
          byType[t] = (byType[t] ?? 0) + 1;
        }
        _setUnreadCounts(total: snap.size, byType: byType);
      },
      onError: (_) {
        // 監聽錯誤不讓 UI 爆炸：維持現狀
      },
    );
  }

  void _setUnreadCounts({
    required int total,
    required Map<String, int> byType,
  }) {
    final changed =
        total != _unreadNotifications || !_mapEquals(byType, _unreadByType);
    if (!changed) return;

    _unreadNotifications = total;
    _unreadByType = Map<String, int>.unmodifiable(byType);
    notifyListeners();
  }

  void _cancelUnreadSub() {
    _unreadSub?.cancel();
    _unreadSub = null;
  }

  // -----------------------------
  // Cart count listener
  // -----------------------------
  void _listenCartCount(String uid) {
    _cancelCartSub();

    // ✅ 預設以 users/{uid}/cart 子集合做計數（沒有集合也會是 0）
    final q = _db.collection('users').doc(uid).collection('cart');

    _cartSub = q.snapshots().listen(
      (snap) => _setCartCount(snap.size),
      onError: (_) {
        // 若權限/規則不允許，避免卡 UI：退回 0
        _setCartCount(0);
      },
    );
  }

  void _setCartCount(int v) {
    if (v == _cartCount) return;
    _cartCount = v;
    notifyListeners();
  }

  void _cancelCartSub() {
    _cartSub?.cancel();
    _cartSub = null;
  }

  // -----------------------------
  // Actions
  // -----------------------------

  /// ✅ 全部通知標已讀
  Future<void> markAllRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final col = _db.collection('users').doc(uid).collection('notifications');
    final snap = await col.where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  /// ✅ 相容別名
  Future<void> clearAll() => markAllRead();

  /// ✅ 清掉 social 類型未讀（bottom_nav_bar 常用）
  Future<void> clearSocial({String type = 'social'}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final col = _db.collection('users').doc(uid).collection('notifications');

    try {
      final snap = await col
          .where('read', isEqualTo: false)
          .where('type', isEqualTo: type)
          .get();
      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.update(d.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {
      // 若沒有 type 欄位或缺索引：退回全清，避免卡住
      await markAllRead();
    }
  }

  // -----------------------------
  // Utils / lifecycle
  // -----------------------------
  bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  void stop() {
    _authSub?.cancel();
    _authSub = null;
    _cancelUnreadSub();
    _cancelCartSub();
    _started = false;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// lib/services/badge_service.dart
//
// ✅ BadgeService（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// 修正：不再使用 NotificationService.hasUnread（避免 undefined_getter）
// 改為：BadgeService 直接監聽 Firestore users/{uid}/notifications 未讀數量
//
// Firestore 結構（配合你前面 cloud_push_service）：
// - users/{uid}/notifications/{autoId}
//   - read: bool
//
// 需要套件：cloud_firestore, firebase_auth, flutter foundation
// ----------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class BadgeService extends ChangeNotifier {
  BadgeService._({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  static final BadgeService instance = BadgeService._();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _unreadSub;

  bool _started = false;

  int _unreadNotifications = 0;
  int get unreadNotificationsCount => _unreadNotifications;

  /// ✅ 你原本要的「是否有未讀」：直接提供同名概念（不再靠 NotificationService）
  bool get hasUnreadNotifications => _unreadNotifications > 0;

  /// （有些 UI 可能直接用 hasUnread）
  bool get hasUnread => _unreadNotifications > 0;

  /// ✅ 建議在 App 啟動後呼叫一次（例如 main.dart Provider 建好後）
  void start() {
    if (_started) return;
    _started = true;

    // 先用當前 user 初始化
    _handleUser(_auth.currentUser);

    // 監聽登入狀態
    _authSub?.cancel();
    _authSub = _auth.userChanges().listen((u) {
      _handleUser(u);
    });
  }

  void _handleUser(User? user) {
    // 登出：清空 badge + 停止監聽
    if (user == null) {
      _cancelUnreadSub();
      _setUnread(0);
      return;
    }

    // 登入：監聽未讀通知數
    _listenUnreadNotifications(user.uid);
  }

  void _listenUnreadNotifications(String uid) {
    _cancelUnreadSub();

    // users/{uid}/notifications where read == false
    final q = _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false);

    _unreadSub = q.snapshots().listen(
      (snap) {
        _setUnread(snap.size);
      },
      onError: (_) {
        // 出錯時不要炸 UI：保留現值或歸零都可
        // 這裡採保留現值，避免 badge 突然閃爍
      },
    );
  }

  void _setUnread(int v) {
    if (v == _unreadNotifications) return;
    _unreadNotifications = v;
    notifyListeners();
  }

  void _cancelUnreadSub() {
    _unreadSub?.cancel();
    _unreadSub = null;
  }

  /// ✅ 手動停止（通常不需要，除非你做了明確的 lifecycle 管理）
  void stop() {
    _authSub?.cancel();
    _authSub = null;
    _cancelUnreadSub();
    _started = false;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

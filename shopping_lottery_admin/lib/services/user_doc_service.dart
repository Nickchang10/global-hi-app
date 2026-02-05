// lib/services/user_doc_service.dart
//
// UserDocService（完整版）
// - Firestore users/{uid} 文件的建立 / 同步 / 讀取 / 監聽
// - 適用：登入後初始化、Profile 顯示、後台權限/資料共用
//
// users/{uid} 建議欄位：
//   email: String
//   name: String
//   role: String (admin/vendor/pending/unknown)
//   vendorId: String
//   createdAt: Timestamp
//   updatedAt: Timestamp
//   lastLoginAt: Timestamp
//
// 注意：
// - AdminGate 也會 ensureSelfUserDoc；此服務可以更通用（前台/後台都可用）
// - Firestore rules 需允許使用者讀寫自己的 users/{uid}（至少 allow read/write: if request.auth.uid == uid）

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDocService {
  UserDocService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String uid) => _db.collection('users').doc(uid);

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// 建立或同步 users/{uid}
  ///
  /// - 若不存在：建立（role 預設 pending）
  /// - 若存在：merge 更新 email/name/updatedAt/lastLoginAt（不覆蓋 role/vendorId）
  ///
  /// 你可以在登入成功後呼叫一次，確保 doc 存在。
  Future<void> ensureUserDoc(
    User user, {
    Duration timeout = const Duration(seconds: 6),
    bool updateLastLogin = true,
    Map<String, dynamic>? extraMerge,
  }) async {
    final uid = _s(user.uid);
    if (uid.isEmpty) return;

    final ref = _ref(uid);

    Future<void> work() async {
      final snap = await ref.get();
      final email = _s(user.email);
      final name = _s(user.displayName);

      if (!snap.exists) {
        await ref.set({
          'email': email,
          'name': name,
          'role': 'pending',
          'vendorId': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (updateLastLogin) 'lastLoginAt': FieldValue.serverTimestamp(),
          if (extraMerge != null && extraMerge.isNotEmpty) ...extraMerge,
        }, SetOptions(merge: true));
      } else {
        // merge 更新：不要覆蓋 role/vendorId
        final payload = <String, dynamic>{
          if (email.isNotEmpty) 'email': email,
          if (name.isNotEmpty) 'name': name,
          'updatedAt': FieldValue.serverTimestamp(),
          if (updateLastLogin) 'lastLoginAt': FieldValue.serverTimestamp(),
          if (extraMerge != null && extraMerge.isNotEmpty) ...extraMerge,
        };
        await ref.set(payload, SetOptions(merge: true));
      }
    }

    await _withTimeout(work(), timeout: timeout, label: 'ensureUserDoc');
  }

  /// 讀取 users/{uid}（一次性）
  Future<Map<String, dynamic>?> getUserDoc(String uid, {Duration timeout = const Duration(seconds: 6)}) async {
    final u = _s(uid);
    if (u.isEmpty) return null;

    Future<Map<String, dynamic>?> work() async {
      final snap = await _ref(u).get();
      if (!snap.exists) return null;
      return snap.data();
    }

    return _withTimeout(work(), timeout: timeout, label: 'getUserDoc');
  }

  /// 監聽 users/{uid}（即時）
  Stream<Map<String, dynamic>?> streamUserDoc(String uid) {
    final u = _s(uid);
    if (u.isEmpty) return const Stream.empty();

    return _ref(u).snapshots().map((snap) {
      if (!snap.exists) return null;
      return snap.data();
    });
  }

  /// 更新自己的 name（不涉及角色）
  Future<void> updateName(String uid, String name, {Duration timeout = const Duration(seconds: 6)}) async {
    final u = _s(uid);
    final n = _s(name);
    if (u.isEmpty) return;

    Future<void> work() async {
      await _ref(u).set({
        'name': n,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _withTimeout(work(), timeout: timeout, label: 'updateName');
  }

  /// 更新自己的 vendorId（通常 admin 才會改；此方法不做權限判斷，交給 rules）
  Future<void> updateVendorId(String uid, String vendorId, {Duration timeout = const Duration(seconds: 6)}) async {
    final u = _s(uid);
    if (u.isEmpty) return;

    Future<void> work() async {
      await _ref(u).set({
        'vendorId': _s(vendorId),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _withTimeout(work(), timeout: timeout, label: 'updateVendorId');
  }

  /// 取得 role（快速用；若 doc 不存在回 unknown）
  Future<String> getRole(String uid, {Duration timeout = const Duration(seconds: 6)}) async {
    final data = await getUserDoc(uid, timeout: timeout);
    final role = _s(data?['role']).toLowerCase();
    return role.isEmpty ? 'unknown' : role;
  }

  /// 取得 vendorId（快速用；若無回空字串）
  Future<String> getVendorId(String uid, {Duration timeout = const Duration(seconds: 6)}) async {
    final data = await getUserDoc(uid, timeout: timeout);
    return _s(data?['vendorId']);
  }

  // ----------------------------
  // Helpers
  // ----------------------------

  Future<T> _withTimeout<T>(
    Future<T> future, {
    required Duration timeout,
    required String label,
  }) async {
    return Future.any<T>([
      future,
      Future<T>.delayed(timeout, () {
        throw TimeoutException('$label timeout after ${timeout.inSeconds}s');
      }),
    ]);
  }
}

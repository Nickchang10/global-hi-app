// lib/services/admin_gate.dart
//
// ✅ AdminGate Ultra v7.3 Final（最終穩定可編譯版）
// ------------------------------------------------------------
// - 僅保留：instance getRoleInfo() 與 static getRoleInfoStatic()
// - 支援 Admin / SuperAdmin / Vendor / Customer 四角色
// - 自動建立 Firestore users 文件（不存在就建立）
// - Provider 相容：cachedRoleInfo / cachedVendorId / ensureAndGetRole / clearCache
// - ✅ 補齊 signOut()（AdminShell 常用）
// ------------------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

@immutable
class RoleInfo {
  final String uid;
  final String role; // admin / super_admin / vendor / customer
  final String? vendorId;
  final String? email;
  final String? displayName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? error;

  const RoleInfo({
    required this.uid,
    required this.role,
    this.vendorId,
    this.email,
    this.displayName,
    this.createdAt,
    this.updatedAt,
    this.error,
  });

  String get roleKey => role.toLowerCase().trim();

  bool get isAdmin => roleKey == 'admin' || roleKey == 'super_admin';
  bool get isVendor => roleKey == 'vendor';
  bool get isCustomer => !isAdmin && !isVendor;

  bool get hasError => (error ?? '').trim().isNotEmpty;

  static RoleInfo errorInfo(String msg, {String uid = ''}) =>
      RoleInfo(uid: uid, role: 'customer', error: msg);

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      // 秒/毫秒兼容
      if (v < 10000000000) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    return null;
  }

  static String? _toStr(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  factory RoleInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return RoleInfo(
      uid: doc.id,
      role: (d['role'] ?? 'customer').toString(),
      vendorId: _toStr(d['vendorId']),
      email: _toStr(d['email']),
      displayName: _toStr(d['displayName']),
      createdAt: _toDate(d['createdAt']),
      updatedAt: _toDate(d['updatedAt']),
    );
  }
}

// ------------------------------------------------------------
// ✅ AdminGate 主體（ChangeNotifier service）
// ------------------------------------------------------------
class AdminGate extends ChangeNotifier {
  AdminGate({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String usersCollection = 'users',
    bool listenAuthState = true,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _usersCollection = usersCollection {
    if (listenAuthState) _initAuthListener();
  }

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final String _usersCollection;
  StreamSubscription<User?>? _authSub;

  RoleInfo? _cachedRole;
  String? _cachedUid;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  RoleInfo? get cachedRoleInfo => _cachedRole;
  String? get currentUserId => _cachedUid;
  String? get cachedVendorId => _cachedRole?.vendorId;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(_usersCollection).doc(uid);

  // ------------------------------------------------------------
  // ✅ 初始化監聽登入狀態
  // ------------------------------------------------------------
  void _initAuthListener() {
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        _cachedUid = null;
        _cachedRole = null;
        _isLoading = false;
        _notify();
      } else {
        await ensureAndGetRole(user, forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------
  // ✅ 清除快取
  // ------------------------------------------------------------
  void clearCache() {
    _cachedRole = null;
    _cachedUid = null;
    _isLoading = false;
    _notify();
  }

  // ------------------------------------------------------------
  // ✅ 登出（shell 常用）
  // ------------------------------------------------------------
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } finally {
      clearCache();
    }
  }

  // ------------------------------------------------------------
  // ✅ 保證 users/{uid} 存在（不存在就建立）
  // ------------------------------------------------------------
  Future<void> _ensureUserDocExists(User user) async {
    final uid = user.uid.trim();
    if (uid.isEmpty) return;

    final ref = _userRef(uid);
    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'role': 'customer',
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ------------------------------------------------------------
  // ✅ 主方法：確保 users/{uid} 存在並回傳 RoleInfo
  // ------------------------------------------------------------
  Future<RoleInfo> ensureAndGetRole(
    User user, {
    bool forceRefresh = false,
  }) async {
    final uid = user.uid.trim();
    if (uid.isEmpty) return RoleInfo.errorInfo('無效 UID');

    if (!forceRefresh && _cachedRole != null && _cachedUid == uid) {
      return _cachedRole!;
    }

    _isLoading = true;
    _notify();

    try {
      await _ensureUserDocExists(user);

      final ref = _userRef(uid);
      final snap = await ref.get();

      // 若 doc 存在但缺欄位，可補 updatedAt（不影響 role）
      if (snap.exists) {
        await ref.set(
          {'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }

      final doc = await ref.get();
      final info = RoleInfo.fromDoc(doc);

      _cachedUid = uid;
      _cachedRole = info;
      _isLoading = false;
      _notify();
      return info;
    } catch (e, st) {
      _isLoading = false;
      _notify();
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AdminGate] ensureAndGetRole error: $e\n$st');
      }
      return RoleInfo.errorInfo('讀取角色失敗：$e', uid: uid);
    }
  }

  // ------------------------------------------------------------
  // ✅ Instance 用法（Provider 相容）
  // ------------------------------------------------------------
  Future<RoleInfo?> getRoleInfo({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return RoleInfo.errorInfo('未登入');
    return ensureAndGetRole(user, forceRefresh: forceRefresh);
  }

  // ------------------------------------------------------------
  // ✅ Static 用法（新版明確入口）
  // ------------------------------------------------------------
  static Future<RoleInfo?> getRoleInfoStatic({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String usersCollection = 'users',
  }) async {
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      final a = auth ?? FirebaseAuth.instance;
      final user = a.currentUser;
      if (user == null) return RoleInfo.errorInfo('未登入');

      final uid = user.uid.trim();
      if (uid.isEmpty) return RoleInfo.errorInfo('無效 UID');

      final ref = db.collection(usersCollection).doc(uid);
      final snap = await ref.get();

      if (!snap.exists) {
        await ref.set({
          'role': 'customer',
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 輕量補更新時間（不影響權限）
        await ref.set(
          {'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }

      final doc = await ref.get();
      return RoleInfo.fromDoc(doc);
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AdminGate] getRoleInfoStatic error: $e\n$st');
      }
      return RoleInfo.errorInfo('讀取角色失敗：$e');
    }
  }

  // ------------------------------------------------------------
  // ✅ 安全通知（非同步 microtask）
  // ------------------------------------------------------------
  void _notify() {
    Future.microtask(() {
      if (hasListeners) notifyListeners();
    });
  }
}

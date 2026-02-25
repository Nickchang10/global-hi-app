// lib/services/admin_gate.dart
//
// ✅ AdminGate（完整版｜可編譯｜RoleInfo 統一模型 + hasError）
// - 提供 cachedRole / cachedRoleInfo（相容舊頁面）
// - RoleInfo.empty() / RoleInfo.error(...)（相容 hasError 用法）
// - RoleInfo.raw（修 user_info_badge.dart 報錯）
// - ensureAndGetRole(...)：從 Firestore users/{uid} 讀角色並快取
//
// Firestore users/{uid} 建議欄位：
// - role: 'admin' | 'vendor' | ...
// - vendorId: String（vendor 必填）
// - displayName/email（可選）

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

@immutable
class RoleInfo {
  final String uid;
  final String? email;
  final String role; // admin / vendor / unknown
  final String vendorId;

  /// 原始 users/{uid} 文件資料（給 UserInfoBadge / debug 用）
  final Map<String, dynamic> raw;

  /// ✅ 讓 UI 能用 roleInfo.hasError 判斷（修你現在的編譯錯）
  /// 你可以把任何「讀取失敗訊息」塞進來
  final String errorMessage;

  const RoleInfo({
    required this.uid,
    required this.email,
    required this.role,
    required this.vendorId,
    required this.raw,
    this.errorMessage = '',
  });

  /// ✅ 讓舊程式能用 RoleInfo.empty()
  factory RoleInfo.empty() => const RoleInfo(
    uid: '',
    email: null,
    role: '',
    vendorId: '',
    raw: <String, dynamic>{},
    errorMessage: '',
  );

  /// ✅ 讓你遇到例外時回傳有錯誤狀態的 RoleInfo（hasError=true）
  factory RoleInfo.error(String message, {String uid = '', String? email}) =>
      RoleInfo(
        uid: uid,
        email: email,
        role: 'unknown',
        vendorId: '',
        raw: const <String, dynamic>{},
        errorMessage: message.trim(),
      );

  bool get isAdmin => role.toLowerCase().trim() == 'admin';
  bool get isVendor => role.toLowerCase().trim() == 'vendor';

  /// ✅ 你現在缺的 getter
  bool get hasError => errorMessage.trim().isNotEmpty;

  RoleInfo copyWith({
    String? uid,
    String? email,
    String? role,
    String? vendorId,
    Map<String, dynamic>? raw,
    String? errorMessage,
  }) {
    return RoleInfo(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      vendorId: vendorId ?? this.vendorId,
      raw: raw ?? this.raw,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AdminGate extends ChangeNotifier {
  AdminGate({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.usersCollection = 'users',
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  final String usersCollection;

  RoleInfo _cached = RoleInfo.empty();

  // ✅ 新舊相容 getter（你多個頁面會用到）
  RoleInfo get cachedRole => _cached;
  RoleInfo get cachedRoleInfo => _cached;

  // 某些頁面會直接用 cachedVendorId
  String get cachedVendorId => _cached.vendorId;

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// ✅ 主要入口：確保 role 已讀取並快取
  Future<RoleInfo> ensureAndGetRole(
    User user, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cached.uid == user.uid &&
        _cached.role.trim().isNotEmpty &&
        !_cached.hasError) {
      return _cached;
    }

    try {
      final doc = await _db.collection(usersCollection).doc(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      final role = _s(data['role']).toLowerCase();
      final vendorId = _s(data['vendorId']);

      _cached = RoleInfo(
        uid: user.uid,
        email: user.email,
        role: role.isEmpty ? 'unknown' : role,
        vendorId: vendorId,
        raw: data,
        errorMessage: '',
      );

      notifyListeners();
      return _cached;
    } catch (e) {
      _cached = RoleInfo.error('讀取角色失敗：$e', uid: user.uid, email: user.email);
      notifyListeners();
      return _cached;
    }
  }

  /// （可選）用目前登入者快速確保角色
  Future<RoleInfo> ensureCurrentUserRole({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      _cached = RoleInfo.empty();
      notifyListeners();
      return _cached;
    }
    return ensureAndGetRole(user, forceRefresh: forceRefresh);
  }

  void clearCache() {
    _cached = RoleInfo.empty();
    notifyListeners();
  }
}

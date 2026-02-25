// lib/gates/admin_gate.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ AdminGate（後台權限 Gate｜最終完整版｜可編譯）
///
/// 功能：
/// - bindAuth(FirebaseAuth auth)：綁定 FirebaseAuth 並監聽登入狀態
/// - refresh()：重新抓取 Firestore 使用者角色
/// - 欄位：loading / isAdmin / isSuperAdmin
class AdminGate extends ChangeNotifier {
  final FirebaseFirestore _db;

  AdminGate({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  FirebaseAuth? _auth;
  StreamSubscription<User?>? _authSub;

  bool _loading = true;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;

  bool get loading => _loading;
  bool get isAdmin => _isAdmin;
  bool get isSuperAdmin => _isSuperAdmin;

  /// ✅ 供 AdminShell 呼叫：綁定 auth，並在登入狀態變化時 refresh
  void bindAuth(FirebaseAuth auth) {
    if (_auth == auth) return;
    _auth = auth;

    _authSub?.cancel();
    _authSub = auth.authStateChanges().listen((_) => refresh());

    refresh();
  }

  /// ✅ 供 AdminShell 呼叫：手動刷新權限
  Future<void> refresh() async {
    _setLoading(true);

    try {
      final uid = _auth?.currentUser?.uid;
      if (uid == null) {
        _applyRoleNone();
        return;
      }

      final doc = await _db.collection('users').doc(uid).get();
      final role = _roleFromDoc(doc.data());

      final superAdmin = role == 'super_admin' || role == 'superadmin';
      final admin = superAdmin || role == 'admin';

      _isSuperAdmin = superAdmin;
      _isAdmin = admin;

      _setLoading(false);
    } catch (_) {
      // 發生錯誤：保守處理（不放行）
      _applyRoleNone();
    }
  }

  String _roleFromDoc(Map<String, dynamic>? data) {
    if (data == null) return '';
    final v = data['role'];

    if (v is String) return v.trim().toLowerCase();
    // 若你用 bool 欄位也可以在這裡兼容，例如：
    // if (data['isAdmin'] == true) return 'admin';
    return '';
  }

  void _applyRoleNone() {
    _isAdmin = false;
    _isSuperAdmin = false;
    _setLoading(false);
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

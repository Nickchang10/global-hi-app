// lib/gates/vendor_gate.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ VendorGate（廠商後台 Gate｜最終完整版｜可編譯）
///
/// Firestore 預設：users/{uid}.role = vendor / admin / super_admin
/// 你若使用 vendors/{uid} 或欄位不同，改 _loadRole() 即可。
class VendorGate extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  VendorGate({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  StreamSubscription<User?>? _sub;

  bool _loading = true;
  bool _isVendor = false;
  bool _isAdmin = false;

  bool get loading => _loading;
  bool get isVendor => _isVendor;
  bool get isAdmin => _isAdmin;

  User? get currentUser => _auth.currentUser;

  /// ✅ 給 main_vendor.dart 呼叫
  void bindAuth() {
    _sub?.cancel();
    _sub = _auth.authStateChanges().listen((_) => refresh());
    refresh();
  }

  Future<void> refresh() async {
    _setLoading(true);

    final u = _auth.currentUser;
    if (u == null) {
      _applyNone();
      return;
    }

    try {
      final role = await _loadRole(u.uid);

      final superAdmin = role == 'super_admin' || role == 'superadmin';
      final admin = superAdmin || role == 'admin';
      final vendor = admin || role == 'vendor';

      _isAdmin = admin;
      _isVendor = vendor;

      _setLoading(false);
    } catch (_) {
      _applyNone();
    }
  }

  Future<String> _loadRole(String uid) async {
    // ✅ 預設用 users/{uid}
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();

    final v = data?['role'];
    if (v is String) return v.trim().toLowerCase();

    // 兼容：布林欄位
    if (data?['isVendor'] == true) return 'vendor';
    if (data?['isAdmin'] == true) return 'admin';

    return '';
  }

  void _applyNone() {
    _isVendor = false;
    _isAdmin = false;
    _setLoading(false);
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

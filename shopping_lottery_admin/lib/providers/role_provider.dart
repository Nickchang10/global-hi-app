// lib/providers/role_provider.dart
//
// ✅ RoleProvider（完整版｜可編譯｜不依賴 RoleInfo.error）
// ------------------------------------------------------------
// - 透過 AdminGate.ensureAndGetRole(User) 取得 RoleInfo
// - Provider 自行維護：loading / errorMessage / info
// - 避免你目前 RoleInfo 欄位不一致（nullable/non-nullable）造成編譯炸掉：用 dynamic 讀 role/vendorId
//
// 依賴：provider, firebase_auth, services/admin_gate.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/admin_gate.dart';

class RoleProvider extends ChangeNotifier {
  RoleProvider({required AdminGate gate}) : _gate = gate;

  final AdminGate _gate;

  RoleInfo? _info;
  bool _loading = false;
  String? _errorMessage;

  String? _uid;
  StreamSubscription<User?>? _sub;

  // -------------------------
  // Public state
  // -------------------------
  RoleInfo? get info => _info;

  bool get isLoading => _loading;

  bool get hasError => (_errorMessage ?? '').trim().isNotEmpty;

  String get errorMessage => (_errorMessage ?? '').trim();

  bool get isReady => !_loading && _info != null && !hasError;

  // -------------------------
  // Derived role info (safe)
  // -------------------------
  String get role {
    final i = _info;
    if (i == null) return '';
    final v = (i as dynamic).role;
    return (v ?? '').toString().trim();
  }

  String get vendorId {
    final i = _info;
    if (i == null) return '';
    final v = (i as dynamic).vendorId;
    return (v ?? '').toString().trim();
  }

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isVendor => role.toLowerCase() == 'vendor';

  // -------------------------
  // Helpers
  // -------------------------
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _info = null;
    _loading = false;
    _errorMessage = null;
    _uid = null;
    notifyListeners();
  }

  // -------------------------
  // Core: load role once
  // -------------------------
  Future<void> load({required User user, bool forceRefresh = false}) async {
    // 避免重複對同一 uid 連續 load
    if (_loading) return;

    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _uid = user.uid;
      final r = await _gate.ensureAndGetRole(user, forceRefresh: forceRefresh);

      _info = r;
      _errorMessage = null;
    } catch (e) {
      _info = null;
      _errorMessage = '讀取角色失敗：$e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({bool forceRefresh = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      reset();
      return;
    }
    await load(user: user, forceRefresh: forceRefresh);
  }

  // -------------------------
  // Optional: auto bind auth changes
  // -------------------------
  void bindAuthChanges() {
    _sub?.cancel();
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        reset();
        return;
      }
      // uid 變更才 reload，避免每次 token refresh 也觸發
      if (_uid != user.uid) {
        await load(user: user, forceRefresh: false);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

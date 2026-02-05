// lib/providers/role_provider.dart
//
// ✅ RoleProvider（完整版｜可與 AdminGate 整合）
// ------------------------------------------------------------
// 功能：
// - 監聽與快取目前登入者角色資訊（admin/vendor/customer）
// - 提供 refresh() 方法供 UI 主動更新
// - 若使用者登出或角色載入失敗，自動回傳 error 狀態
//
// 相依：
// - services/admin_gate.dart
// - firebase_auth
// - provider

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/admin_gate.dart';

class RoleProvider extends ChangeNotifier {
  final AdminGate gate;
  RoleProvider(this.gate);

  RoleInfo? _info;
  bool _loading = false;

  RoleInfo? get info => _info;
  bool get isLoading => _loading;
  bool get isAdmin => _info?.isAdmin ?? false;
  bool get isVendor => _info?.isVendor ?? false;
  String get role => _info?.role ?? 'customer';
  String get uid => _info?.uid ?? '';
  String? get error => _info?.error;

  /// 初始化或重新讀取角色資訊
  Future<void> refresh({bool forceRefresh = true}) async {
    _loading = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _info = RoleInfo.errorInfo('未登入');
      _loading = false;
      notifyListeners();
      return;
    }

    final r = await gate.ensureAndGetRole(user, forceRefresh: forceRefresh);
    _info = r;
    _loading = false;
    notifyListeners();
  }

  /// 清除角色快取（通常配合登出或切換帳號）
  void clear() {
    gate.clearCache();
    _info = null;
    notifyListeners();
  }
}

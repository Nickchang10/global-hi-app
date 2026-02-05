// lib/services/role_gate.dart
// =====================================================
// ✅ RoleGate（自動角色導向｜Admin / Vendor / User）
// -----------------------------------------------------
// - 登入後自動導向對應系統
// - 無需手動選擇模式
// - 監聽 AuthService 與 Firestore role 欄位
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import '../pages/admin_shell_page.dart';
import '../pages/vendor_shell_page.dart';
import '../main.dart'; // 內含 MainNavigationPage

class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.loggedIn) {
      // 尚未登入 → 回登入頁
      return const _LoginRedirect();
    }

    final role = auth.user?['role'] ?? 'user';

    switch (role) {
      case 'admin':
        return const AdminShellPage();
      case 'vendor':
        return const VendorShellPage();
      default:
        return const MainNavigationPage();
    }
  }
}

class _LoginRedirect extends StatelessWidget {
  const _LoginRedirect();

  @override
  Widget build(BuildContext context) {
    Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// lib/pages/vendor/vendor_gate.dart
//
// ✅ VendorGate（最終完整版｜角色守門｜可編譯）
// ------------------------------------------------------------
// 功能：
// - 監聽 FirebaseAuth 登入狀態
// - 讀取 users/{uid} 取得 role / vendorId / disabled
// - role == vendor -> VendorShellPage
// - role == admin  -> AdminShellPage
// - 未登入 -> LoginPage
// - disabled / 缺 vendorId / user doc 不存在 -> 顯示錯誤 + 可登出
//
// 依賴：firebase_auth, cloud_firestore
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// 依你的專案結構：Login 與 AdminShell 在 pages 根目錄
import '../login_page.dart';
import '../admin_shell_page.dart';

// Vendor Shell 在 vendor 資料夾
import 'vendor_shell_page.dart';

class VendorGate extends StatefulWidget {
  const VendorGate({super.key});

  @override
  State<VendorGate> createState() => _VendorGateState();
}

class _VendorGateState extends State<VendorGate> {
  bool _didNavigate = false; // 防止重複導向（Web/熱重載時常見）

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _GateLoadingPage(text: '正在讀取登入狀態...');
        }

        final user = authSnap.data;
        if (user == null) {
          _didNavigate = false;
          return const LoginPage();
        }

        return FutureBuilder<_RoleInfo>(
          future: _loadRoleInfo(user.uid),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return const _GateLoadingPage(text: '正在讀取角色權限...');
            }

            final info = roleSnap.data!;
            if (info.error != null && info.error!.isNotEmpty) {
              return _GateErrorPage(
                title: '權限讀取失敗',
                message: info.error!,
                onLogout: _logoutAndBackToLogin,
              );
            }

            if (info.disabled == true) {
              return _GateErrorPage(
                title: '帳號已停用',
                message: '此帳號目前被停用，請聯絡管理員。',
                onLogout: _logoutAndBackToLogin,
              );
            }

            // -------------------------
            // ✅ 直接回傳頁面（不依賴 routes）
            // -------------------------
            if (info.role == 'vendor') {
              if ((info.vendorId ?? '').trim().isEmpty) {
                return _GateErrorPage(
                  title: 'Vendor 資料不完整',
                  message: 'users/${user.uid} 缺少 vendorId，無法進入 Vendor 後台。',
                  onLogout: _logoutAndBackToLogin,
                );
              }
              return const VendorShellPage();
            }

            if (info.role == 'admin') {
              return const AdminShellPage();
            }

            // 其他角色：未知
            return _GateErrorPage(
              title: '無法識別的角色',
              message: 'role = "${info.role}"，請確認 users/{uid}.role 設定正確（admin / vendor）。',
              onLogout: _logoutAndBackToLogin,
            );
          },
        );
      },
    );
  }

  Future<_RoleInfo> _loadRoleInfo(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists) {
        return _RoleInfo(
          role: '',
          vendorId: '',
          disabled: false,
          error: '找不到 users/$uid 文件。請先建立使用者文件（至少包含 role 與 vendorId）。',
        );
      }

      final data = doc.data() ?? {};
      final role = (data['role'] ?? '').toString().trim();
      final vendorId = (data['vendorId'] ?? '').toString().trim();
      final disabled = data['disabled'] == true;

      return _RoleInfo(
        role: role,
        vendorId: vendorId,
        disabled: disabled,
        error: null,
      );
    } catch (e) {
      return _RoleInfo(
        role: '',
        vendorId: '',
        disabled: false,
        error: '讀取 users/{uid} 失敗：$e',
      );
    }
  }

  Future<void> _logoutAndBackToLogin() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (!mounted) return;

    // 若你要用 route：可改成 pushNamedAndRemoveUntil('/login', ...)
    // 這裡用直接替換 Widget 的方式即可
    setState(() {
      _didNavigate = false;
    });
  }
}

// ------------------------------------------------------------
// Models
// ------------------------------------------------------------

class _RoleInfo {
  final String role;
  final String? vendorId;
  final bool disabled;
  final String? error;

  const _RoleInfo({
    required this.role,
    required this.vendorId,
    required this.disabled,
    required this.error,
  });
}

// ------------------------------------------------------------
// UI helpers
// ------------------------------------------------------------

class _GateLoadingPage extends StatelessWidget {
  final String text;
  const _GateLoadingPage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Flexible(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GateErrorPage extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onLogout;

  const _GateErrorPage({
    required this.title,
    required this.message,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 10),
                    Text(message),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: onLogout,
                          icon: const Icon(Icons.logout),
                          label: const Text('登出'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

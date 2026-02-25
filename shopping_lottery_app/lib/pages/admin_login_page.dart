// lib/pages/admin_login_page.dart
//
// ✅ AdminLoginPage（修正版｜可編譯｜移除不存在的 lottery_admin_page.dart 依賴）
// ------------------------------------------------------------
// - Email/Password 登入
// - 登入後檢查 Firestore users/{uid}.role
//   - role == 'admin' -> 導到 adminRoute（預設 /admin）
//   - 其他 -> 顯示無權限並登出
//
// 依賴：firebase_auth, cloud_firestore, flutter/material.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({
    super.key,
    this.usersCollection = 'users',
    this.adminRoute = '/admin',
    this.afterDeniedRoute = '/login',
  });

  /// users 集合名稱（預設 users）
  final String usersCollection;

  /// 管理員登入成功後導向的 route（預設 /admin）
  final String adminRoute;

  /// 非管理員/無權限時導回的 route（預設 /login）
  final String afterDeniedRoute;

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  bool _loading = false;
  bool _showPwd = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<void> _signOutSilently() async {
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  Future<String> _fetchRole(String uid) async {
    final doc = await _db.collection(widget.usersCollection).doc(uid).get();
    final data = doc.data() ?? <String, dynamic>{};
    return _s(data['role']).toLowerCase();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text,
      );

      final user = cred.user;
      if (user == null) {
        _snack('登入失敗：找不到使用者');
        return;
      }

      // ✅ 檢查角色
      final role = await _fetchRole(user.uid);
      if (role == 'admin') {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          widget.adminRoute,
          (r) => false,
        );
        return;
      }

      // 非 admin：登出 + 提示
      await _signOutSilently();
      _snack('此帳號不是管理員（role=$role），無法進入後台');

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        widget.afterDeniedRoute,
        (r) => false,
      );
    } on FirebaseAuthException catch (e) {
      _snack(_authErrorMsg(e));
    } catch (e) {
      _snack('登入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authErrorMsg(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email 格式不正確';
      case 'user-disabled':
        return '此帳號已停用';
      case 'user-not-found':
        return '找不到此帳號';
      case 'wrong-password':
        return '密碼錯誤';
      case 'invalid-credential':
        return '帳號或密碼錯誤';
      case 'too-many-requests':
        return '嘗試次數過多，請稍後再試';
      default:
        return '登入失敗：${e.message ?? e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '管理員登入',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Osmile 後台登入',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '登入後會檢查 users/{uid}.role 是否為 admin。',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _emailCtrl,
                        enabled: !_loading,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return '請輸入 Email';
                          final ok = RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(s);
                          if (!ok) return 'Email 格式不正確';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _pwdCtrl,
                        enabled: !_loading,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: '密碼',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: IconButton(
                            tooltip: _showPwd ? '隱藏密碼' : '顯示密碼',
                            onPressed: _loading
                                ? null
                                : () => setState(() => _showPwd = !_showPwd),
                            icon: Icon(
                              _showPwd
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        obscureText: !_showPwd,
                        validator: (v) {
                          final s = (v ?? '');
                          if (s.isEmpty) return '請輸入密碼';
                          if (s.length < 6) return '密碼至少 6 碼';
                          return null;
                        },
                        onFieldSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 14),

                      FilledButton.icon(
                        onPressed: _loading ? null : _login,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_open),
                        label: const Text('登入'),
                      ),

                      const SizedBox(height: 10),
                      Text(
                        '提示：請在 Firestore users/{uid} 設定 role=admin 才能進入後台。',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

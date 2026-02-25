// lib/services/login_page.dart
//
// ✅ LoginPage（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// ✅ 移除 FirestoreMockService.instance（你目前錯誤來源）
// ✅ 使用 FirebaseAuth.instance / FirebaseFirestore.instance
// ✅ 功能：
//   - Email/Password 登入
//   - Email/Password 註冊
//   - 忘記密碼（寄重設信）
//   - 成功後確保 users/{uid} 文件存在（points/role/displayName...）
//
// 需要套件：firebase_auth, cloud_firestore, flutter material
// ----------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();

  bool _isRegister = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  String _clean(String s) => s.trim();

  Future<void> _ensureUserDoc(User u, {String? displayName}) async {
    final ref = _db.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (snap.exists) {
      // 順便補齊欄位（merge）
      await ref.set({
        'uid': u.uid,
        'email': u.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final now = FieldValue.serverTimestamp();
    await ref.set({
      'uid': u.uid,
      'email': u.email,
      'displayName': displayName ?? u.displayName ?? 'Osmile 會員',
      'photoUrl': u.photoURL,
      'role': 'user',
      'points': 0,
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> _submit() async {
    if (_busy) return;

    final email = _clean(_emailCtrl.text);
    final password = _passwordCtrl.text;

    if (email.isEmpty || !email.contains('@')) {
      _toast('請輸入正確 Email');
      return;
    }
    if (password.length < 6) {
      _toast('密碼至少 6 碼');
      return;
    }
    if (_isRegister && _clean(_displayNameCtrl.text).isEmpty) {
      _toast('請輸入暱稱');
      return;
    }

    setState(() => _busy = true);
    try {
      UserCredential cred;

      if (_isRegister) {
        cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final name = _clean(_displayNameCtrl.text);
        if (name.isNotEmpty) {
          await cred.user?.updateDisplayName(name);
        }

        final user = cred.user;
        if (user != null) {
          await _ensureUserDoc(user, displayName: name);
        }

        _toast('註冊成功');
      } else {
        cred = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = cred.user;
        if (user != null) {
          await _ensureUserDoc(user, displayName: user.displayName);
        }

        _toast('登入成功');
      }

      if (!mounted) return;

      // 登入成功：回上一頁或回首頁
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyAuthError(e));
    } catch (e) {
      _toast('操作失敗：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_busy) return;

    final email = _clean(_emailCtrl.text);
    if (email.isEmpty || !email.contains('@')) {
      _toast('請先輸入要重設的 Email');
      return;
    }

    setState(() => _busy = true);
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _toast('已寄出重設密碼信');
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyAuthError(e));
    } catch (e) {
      _toast('寄送失敗：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email 格式不正確';
      case 'user-disabled':
        return '此帳號已停用';
      case 'user-not-found':
        return '找不到此帳號';
      case 'wrong-password':
        return '密碼錯誤';
      case 'email-already-in-use':
        return '此 Email 已被註冊';
      case 'weak-password':
        return '密碼強度不足（至少 6 碼）';
      case 'too-many-requests':
        return '嘗試次數過多，請稍後再試';
      case 'network-request-failed':
        return '網路連線失敗';
      default:
        return '登入/註冊失敗：${e.message ?? e.code}';
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegister ? '註冊' : '登入';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _isRegister = !_isRegister;
                    });
                  },
            child: Text(
              _isRegister ? '我有帳號' : '我要註冊',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_isRegister) ...[
                    TextField(
                      controller: _displayNameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '暱稱',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: '密碼（至少 6 碼）',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(_busy ? '處理中...' : title),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_isRegister)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _resetPassword,
                        child: const Text('忘記密碼？'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '提示：登入/註冊成功後會自動建立 users/{uid} 文件（role/points 等欄位）。',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

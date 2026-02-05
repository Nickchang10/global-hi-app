// lib/pages/login_page.dart
//
// ✅ LoginPage（路線 A：後台不開放註冊｜單檔完整版｜可直接使用｜可編譯）
// ------------------------------------------------------------
// - 移除所有「註冊」入口與 /register 導航
// - 僅提供：Email/Password 登入 + 忘記密碼
// - 登入成功後不手動導航：交給 main.dart 的 AuthRouter 監聽 authStateChanges() 自動進入後台
// ------------------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text,
      );

      // ✅ 不要在這裡 push /dashboard
      // 交給 main.dart 的 AuthRouter（authStateChanges）自動進入後台
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登入成功，正在進入後台...')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final msg = _friendlyAuthError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登入失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先輸入有效 Email，再使用忘記密碼。')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已寄出重設密碼信件，請至信箱查收。')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAuthError(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('寄送失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email 格式不正確。';
      case 'user-disabled':
        return '此帳號已停用，請聯絡管理員。';
      case 'user-not-found':
        return '找不到此帳號，請確認 Email 或聯絡管理員建立帳號。';
      case 'wrong-password':
        return '密碼錯誤，請重新輸入。';
      case 'invalid-credential':
        return '登入資訊不正確，請確認 Email / 密碼。';
      case 'too-many-requests':
        return '嘗試次數過多，請稍後再試。';
      case 'network-request-failed':
        return '網路連線異常，請檢查網路。';
      default:
        return '登入失敗：${e.message ?? e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: cs.primaryContainer,
                              child: Icon(Icons.admin_panel_settings_outlined,
                                  color: cs.onPrimaryContainer),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Osmile 後台管理系統',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '此系統不提供註冊，請由管理員建立帳號。',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),

                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return '請輸入 Email';
                            if (!s.contains('@')) return 'Email 格式不正確';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _pwdCtrl,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: '密碼',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? '顯示密碼' : '隱藏密碼',
                              onPressed:
                                  _loading ? null : () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if ((v ?? '').isEmpty) return '請輸入密碼';
                            return null;
                          },
                          onFieldSubmitted: (_) => _loading ? null : _signIn(),
                        ),

                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _resetPassword,
                            child: const Text('忘記密碼'),
                          ),
                        ),

                        const SizedBox(height: 6),

                        FilledButton.icon(
                          onPressed: _loading ? null : _signIn,
                          icon: _loading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(_loading ? '登入中...' : '登入'),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          '提示：登入後會自動進入後台（由 AuthRouter 控制）。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

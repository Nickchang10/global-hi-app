// lib/pages/auth_page.dart
//
// ✅ AuthPage（完整版｜可編譯）
// - Firebase Email/Password 登入 / 註冊（含 displayName、確認密碼）
// - 可選：註冊後寄送 Email 驗證信
// - ✅ 修正重點：不使用 GoogleFonts.notoSansTc（某些版本不存在）
//              改用 GoogleFonts.getFont('Noto Sans TC')，版本更穩定
//
// 依賴：firebase_auth, flutter/material, google_fonts

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    this.afterSignedInRoute = '/',
    this.sendVerifyEmailOnSignUp = true,
  });

  /// 登入成功後導向
  final String afterSignedInRoute;

  /// 註冊成功後是否寄送 Email 驗證信
  final bool sendVerifyEmailOnSignUp;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _loading = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();

  bool _showPwd = false;
  bool _showPwd2 = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  TextStyle _font(TextStyle base) =>
      GoogleFonts.getFont('Noto Sans TC', textStyle: base);

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _vEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '請輸入 Email';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    if (!ok) return 'Email 格式不正確';
    return null;
  }

  String? _vPwd(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return '請輸入密碼';
    if (s.length < 6) return '密碼至少 6 碼';
    return null;
  }

  String? _vPwd2(String? v) {
    if (_isLogin) return null;
    final s = (v ?? '');
    if (s.isEmpty) return '請再次輸入密碼';
    if (s != _pwdCtrl.text) return '兩次密碼不一致';
    return null;
  }

  String? _vName(String? v) {
    if (_isLogin) return null;
    final s = (v ?? '').trim();
    if (s.isEmpty) return '請輸入姓名/暱稱';
    if (s.length < 2) return '至少 2 個字';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _pwdCtrl.text,
        );
        _snack('登入成功');
      } else {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _pwdCtrl.text,
        );

        final displayName = _nameCtrl.text.trim();
        if (displayName.isNotEmpty) {
          await cred.user?.updateDisplayName(displayName);
        }

        if (widget.sendVerifyEmailOnSignUp) {
          try {
            await cred.user?.sendEmailVerification();
          } catch (_) {
            // 寄送失敗不阻擋註冊
          }
        }

        _snack(widget.sendVerifyEmailOnSignUp ? '註冊成功（已嘗試寄送驗證信）' : '註冊成功');
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, widget.afterSignedInRoute);
    } on FirebaseAuthException catch (e) {
      _snack(_authMessage(e));
    } catch (e) {
      _snack('操作失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email 格式不正確';
      case 'user-disabled':
        return '此帳號已停用';
      case 'user-not-found':
        return '查無此帳號';
      case 'wrong-password':
        return '密碼錯誤';
      case 'email-already-in-use':
        return '此 Email 已註冊';
      case 'weak-password':
        return '密碼強度不足（至少 6 碼）';
      case 'operation-not-allowed':
        return '此登入方式未啟用';
      default:
        return 'Auth 錯誤：${e.message ?? e.code}';
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    _snack('已登出');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              user == null ? (_isLogin ? '登入' : '註冊') : '已登入',
              style: _font(const TextStyle(fontWeight: FontWeight.w900)),
            ),
            actions: [
              if (user != null)
                TextButton.icon(
                  onPressed: _loading ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('登出'),
                ),
            ],
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
                    child: user != null
                        ? _signedInPanel(user, cs)
                        : _formPanel(cs),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _signedInPanel(User user, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '目前已登入',
          style: _font(
            TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'uid：${user.uid}\nemail：${user.email ?? '-'}\nname：${user.displayName ?? '-'}\nverified：${user.emailVerified}',
          style: _font(TextStyle(color: cs.onSurfaceVariant)),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.pushReplacementNamed(
            context,
            widget.afterSignedInRoute,
          ),
          child: const Text('繼續'),
        ),
      ],
    );
  }

  Widget _formPanel(ColorScheme cs) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isLogin ? '登入帳號' : '建立新帳號',
            style: _font(
              TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 14),

          if (!_isLogin) ...[
            TextFormField(
              controller: _nameCtrl,
              enabled: !_loading,
              decoration: const InputDecoration(
                labelText: '姓名 / 暱稱',
                border: OutlineInputBorder(),
              ),
              validator: _vName,
            ),
            const SizedBox(height: 12),
          ],

          TextFormField(
            controller: _emailCtrl,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            validator: _vEmail,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _pwdCtrl,
            enabled: !_loading,
            obscureText: !_showPwd,
            autofillHints: _isLogin
                ? const [AutofillHints.password]
                : const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: '密碼',
              border: const OutlineInputBorder(),
              helperText: '至少 6 碼',
              suffixIcon: IconButton(
                onPressed: _loading
                    ? null
                    : () => setState(() => _showPwd = !_showPwd),
                icon: Icon(_showPwd ? Icons.visibility_off : Icons.visibility),
              ),
            ),
            validator: _vPwd,
          ),

          if (!_isLogin) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _pwd2Ctrl,
              enabled: !_loading,
              obscureText: !_showPwd2,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: '確認密碼',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _showPwd2 = !_showPwd2),
                  icon: Icon(
                    _showPwd2 ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: _vPwd2,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],

          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isLogin ? Icons.login : Icons.person_add_alt_1),
            label: Text(
              _isLogin
                  ? '登入'
                  : (widget.sendVerifyEmailOnSignUp ? '註冊並寄送驗證信' : '註冊'),
            ),
          ),

          const SizedBox(height: 10),

          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                    _isLogin = !_isLogin;
                  }),
            child: Text(_isLogin ? '沒有帳號？去註冊' : '已經有帳號？回登入'),
          ),

          const SizedBox(height: 6),
          Text(
            '字體：GoogleFonts.getFont("Noto Sans TC")（避免 notoSansTc 方法不存在）',
            style: _font(TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

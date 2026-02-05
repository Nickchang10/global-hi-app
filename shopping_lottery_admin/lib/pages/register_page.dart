// lib/pages/register_page.dart
//
// RegisterPage（完整版｜可編譯）
// - Email/Password 註冊 + displayName
// - 確認密碼驗證
// - 註冊後可選：寄送 Email 驗證信
// - 成功後導回 Login 或直接導向 afterRegisterRoute（預設回 /login）
//
// 依賴：
// - services/auth_service.dart (AuthService, AuthException)
// - provider

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    this.afterRegisterRoute = '/login',
    this.sendVerifyEmail = true,
  });

  /// 註冊成功後導向（常見是回登入頁）
  final String afterRegisterRoute;

  /// 是否在註冊後寄送驗證信
  final bool sendVerifyEmail;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();

  bool _loading = false;
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '請輸入姓名或暱稱';
    if (s.length < 2) return '至少 2 個字';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '請輸入 Email';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    if (!ok) return 'Email 格式不正確';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return '請輸入密碼';
    if (s.length < 6) return '密碼至少 6 碼';
    return null;
  }

  String? _validatePassword2(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return '請再次輸入密碼';
    if (s != _pwdCtrl.text) return '兩次密碼不一致';
    return null;
  }

  Future<void> _register() async {
    final auth = context.read<AuthService>();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      await auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text,
        displayName: _nameCtrl.text.trim(),
      );

      if (widget.sendVerifyEmail) {
        try {
          await auth.sendEmailVerification();
        } catch (_) {
          // 驗證信寄送失敗不阻斷註冊流程（避免 UX 卡住）
        }
      }

      if (!mounted) return;

      if (widget.sendVerifyEmail) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('註冊完成'),
            content: const Text('已建立帳號。若你啟用 Email 驗證，請至信箱收取驗證信後再登入或使用完整功能。'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('了解'),
              ),
            ],
          ),
        );
      } else {
        _snack('註冊成功');
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, widget.afterRegisterRoute);
    } catch (e) {
      final msg = (e is AuthException) ? e.message : '註冊失敗：$e';
      _snack(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('註冊')),
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
                        '建立新帳號',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: '姓名 / 暱稱',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateName,
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateEmail,
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _pwdCtrl,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: '密碼',
                          border: const OutlineInputBorder(),
                          helperText: '至少 6 碼',
                          suffixIcon: IconButton(
                            tooltip: _showPwd ? '隱藏密碼' : '顯示密碼',
                            onPressed: _loading ? null : () => setState(() => _showPwd = !_showPwd),
                            icon: Icon(_showPwd ? Icons.visibility_off : Icons.visibility),
                          ),
                        ),
                        obscureText: !_showPwd,
                        validator: _validatePassword,
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _pwd2Ctrl,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: '確認密碼',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _showPwd2 ? '隱藏密碼' : '顯示密碼',
                            onPressed: _loading ? null : () => setState(() => _showPwd2 = !_showPwd2),
                            icon: Icon(_showPwd2 ? Icons.visibility_off : Icons.visibility),
                          ),
                        ),
                        obscureText: !_showPwd2,
                        validator: _validatePassword2,
                        enabled: !_loading,
                        onFieldSubmitted: (_) => _register(),
                      ),
                      const SizedBox(height: 14),

                      FilledButton.icon(
                        onPressed: _loading ? null : _register,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.person_add_alt_1),
                        label: Text(widget.sendVerifyEmail ? '註冊並寄送驗證信' : '註冊'),
                      ),

                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading ? null : () => Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text('已經有帳號？回登入'),
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

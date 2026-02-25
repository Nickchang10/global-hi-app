import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth/auth_service.dart';
import 'forgot_password_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _formKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();
  final _name = TextEditingController();

  final _emailFocus = FocusNode();
  final _pwdFocus = FocusNode();
  final _pwd2Focus = FocusNode();
  final _nameFocus = FocusNode();

  bool _hidePwd = true;
  bool _hidePwd2 = true;
  bool _loading = false;

  String? _inlineError;

  bool get _isRegister => _tab.index == 1;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!mounted) return;
        setState(() {
          _inlineError = null;
          // 切換模式時把第二次密碼清掉，避免誤判
          _pwd2.clear();
        });
      });

    // ✅ Web 保持登入狀態（async）
    unawaited(AuthService.instance.ensureWebPersistence());
  }

  @override
  void dispose() {
    _tab.dispose();
    _email.dispose();
    _pwd.dispose();
    _pwd2.dispose();
    _name.dispose();
    _emailFocus.dispose();
    _pwdFocus.dispose();
    _pwd2Focus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '請輸入 Email';
    if (!s.contains('@') || !s.contains('.')) return 'Email 格式不正確';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return '請輸入密碼';
    if (_isRegister && s.length < 6) return '密碼至少 6 碼';
    return null;
  }

  String? _validatePassword2(String? v) {
    if (!_isRegister) return null;
    final s = (v ?? '');
    if (s.isEmpty) return '請再次輸入密碼';
    if (s != _pwd.text) return '兩次密碼不一致';
    return null;
  }

  Future<void> _submit() async {
    // 關閉鍵盤 / 完成 autofill
    FocusScope.of(context).unfocus();
    TextInput.finishAutofillContext();

    setState(() => _inlineError = null);

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() => _loading = true);
    try {
      if (_isRegister) {
        await AuthService.instance.registerWithEmail(
          email: _email.text,
          password: _pwd.text,
          displayName: _name.text,
          role: 'user',
        );
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('註冊成功並已登入')));
      } else {
        await AuthService.instance.signInWithEmail(
          email: _email.text,
          password: _pwd.text,
        );
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('登入成功')));
      }
    } catch (e) {
      final msg = AuthService.formatAuthError(e);
      if (!mounted) return;
      setState(() => _inlineError = msg);
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goForgot() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ForgotPasswordPage()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('登入'), centerTitle: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        Icon(
                          Icons.lock_outline,
                          size: 56,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),

                        TabBar(
                          controller: _tab,
                          tabs: const [
                            Tab(text: '登入'),
                            Tab(text: '註冊'),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Email
                        TextFormField(
                          controller: _email,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          validator: _validateEmail,
                          onFieldSubmitted: (_) => _isRegister
                              ? _nameFocus.requestFocus()
                              : _pwdFocus.requestFocus(),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // 註冊：顯示名稱（選填）
                        AnimatedBuilder(
                          animation: _tab,
                          builder: (context, _) {
                            if (!_isRegister) return const SizedBox.shrink();
                            return Column(
                              children: [
                                TextFormField(
                                  controller: _name,
                                  focusNode: _nameFocus,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  onFieldSubmitted: (_) =>
                                      _pwdFocus.requestFocus(),
                                  decoration: const InputDecoration(
                                    labelText: '顯示名稱（選填）',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            );
                          },
                        ),

                        // 密碼
                        TextFormField(
                          controller: _pwd,
                          focusNode: _pwdFocus,
                          obscureText: _hidePwd,
                          textInputAction: _isRegister
                              ? TextInputAction.next
                              : TextInputAction.done,
                          autofillHints: _isRegister
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                          validator: _validatePassword,
                          onFieldSubmitted: (_) {
                            if (_isRegister) {
                              _pwd2Focus.requestFocus();
                            } else {
                              unawaited(_submit());
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '密碼',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _hidePwd = !_hidePwd),
                              icon: Icon(
                                _hidePwd
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                        ),

                        // 註冊：再次輸入密碼
                        AnimatedBuilder(
                          animation: _tab,
                          builder: (context, _) {
                            if (!_isRegister) return const SizedBox.shrink();
                            return Column(
                              children: [
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _pwd2,
                                  focusNode: _pwd2Focus,
                                  obscureText: _hidePwd2,
                                  textInputAction: TextInputAction.done,
                                  validator: _validatePassword2,
                                  onFieldSubmitted: (_) => unawaited(_submit()),
                                  decoration: InputDecoration(
                                    labelText: '再次輸入密碼',
                                    prefixIcon: const Icon(Icons.lock_reset),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _hidePwd2 = !_hidePwd2,
                                      ),
                                      icon: Icon(
                                        _hidePwd2
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        if (_inlineError != null) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _inlineError!,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(_isRegister ? '註冊' : '登入'),
                          ),
                        ),

                        const SizedBox(height: 10),

                        if (!_isRegister)
                          TextButton(
                            onPressed: _loading ? null : _goForgot,
                            child: const Text('忘記密碼？'),
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

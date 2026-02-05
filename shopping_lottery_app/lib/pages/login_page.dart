// lib/pages/login_page.dart
// =====================================================
// ✅ LoginPage（登入頁最終完整版｜對應你目前 AuthService）
// -----------------------------------------------------
// - 你的 AuthService.login 回傳 String?
//   ✅ 成功 = null、失敗 = 錯誤字串
// - 你的 AuthService.sendPasswordResetEmail({required email}) 回傳 String?
//   ✅ 成功 = null、失敗 = 錯誤字串
// - 登入成功後：優先導向 /main（主框架=逛商品 Tab0）
//   若 /main 不存在，依序嘗試 /shop、/、/home，最後才回 /member
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color _brand = Color(0xFF3B82F6);

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  AuthService _authOf(BuildContext context) {
    // 優先使用 Provider 注入；沒有就用單例
    try {
      return context.read<AuthService>();
    } catch (_) {
      return AuthService.instance;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
      ),
    );
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

  Future<void> _goAfterLogin() async {
    if (!mounted) return;

    // ✅ 你現在「還是一樣」通常是因為 /main 沒註冊，導頁失敗後回到 /member
    // 這裡做多路由 fallback，確保能真的進到「逛商品」頁
    const candidates = <String>['/main', '/shop', '/', '/home', '/member'];

    for (final route in candidates) {
      try {
        Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
        debugPrint('✅ Login redirect => $route');
        return;
      } catch (e) {
        debugPrint('⚠️ Route not found: $route ($e)');
      }
    }
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = _authOf(context);

    try {
      // 你的 AuthService.login => Future<String?>（成功 null）
      final String? err = await auth.login(
        _email.text.trim(),
        _password.text.trim(),
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (err != null && err.isNotEmpty) {
        _toast(err);
        setState(() => _error = err);
        return;
      }

      _toast('登入成功');
      await _goAfterLogin();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      _toast(msg.isEmpty ? '登入失敗' : msg);
      setState(() => _error = msg.isEmpty ? '登入失敗' : msg);
    }
  }

  Future<void> _showResetPasswordDialog() async {
    final controller = TextEditingController(text: _email.text.trim());
    String? localErr;

    try {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              return AlertDialog(
                title: const Text('重設密碼'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '請輸入註冊 Email，我們將寄送重設密碼信件。',
                      style: TextStyle(height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: '例如：test@osmile.com',
                        errorText: localErr,
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onChanged: (_) => setLocal(() => localErr = null),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final email = controller.text.trim();
                      final vErr = _validateEmail(email);
                      if (vErr != null) {
                        setLocal(() => localErr = vErr);
                        return;
                      }

                      final auth = _authOf(context);

                      try {
                        final String? err =
                            await auth.sendPasswordResetEmail(email: email);

                        if (!ctx.mounted) return;

                        if (err != null && err.isNotEmpty) {
                          setLocal(() => localErr = err);
                        } else {
                          Navigator.pop(ctx, true);
                        }
                      } catch (e) {
                        if (!ctx.mounted) return;
                        final msg =
                            e.toString().replaceFirst('Exception: ', '').trim();
                        setLocal(() => localErr = msg.isEmpty ? '寄送失敗' : msg);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('寄送'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted) return;
      if (ok == true) _toast('已寄送重設密碼信件');
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topPad = media.padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // 背景漸層
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF6F8FF), Color(0xFFF7F8FA)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 裝飾圓
          Positioned(
            top: -120 + topPad,
            right: -80,
            child: _BlurCircle(color: _brand.withOpacity(0.18), size: 240),
          ),
          Positioned(
            bottom: -140,
            left: -90,
            child: _BlurCircle(color: _brand.withOpacity(0.10), size: 260),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      const _BrandHeader(
                        title: '登入 Osmile 帳號',
                        subtitle: '登入後可使用購物、抽獎、健康與 SOS 功能',
                      ),
                      const SizedBox(height: 16),

                      // ===== Login Card =====
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _TextFieldLabel('Email'),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: _inputDecoration(
                                    hintText: '例如：test@osmile.com',
                                    prefixIcon: Icons.mail_outline,
                                  ),
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: 12),

                                _TextFieldLabel('密碼'),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  autofillHints: const [AutofillHints.password],
                                  decoration: _inputDecoration(
                                    hintText: '請輸入密碼',
                                    prefixIcon: Icons.lock_outline,
                                    suffix: IconButton(
                                      tooltip: _obscure ? '顯示密碼' : '隱藏密碼',
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: _validatePassword,
                                ),

                                const SizedBox(height: 10),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _loading
                                        ? null
                                        : _showResetPasswordDialog,
                                    child: const Text(
                                      '忘記密碼？',
                                      style:
                                          TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 4),

                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _brand,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            '登入',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w900),
                                          ),
                                  ),
                                ),

                                if (_error != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('還沒有帳號？',
                              style: TextStyle(color: Colors.grey.shade700)),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.pushNamed(context, '/register'),
                            child: const Text(
                              '註冊',
                              style: TextStyle(
                                color: _brand,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(prefixIcon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _brand, width: 1.2),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _BrandHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.person_outline, color: Color(0xFF3B82F6)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade700, height: 1.25),
            ),
          ]),
        ),
      ],
    );
  }
}

class _TextFieldLabel extends StatelessWidget {
  final String text;
  const _TextFieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _BlurCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

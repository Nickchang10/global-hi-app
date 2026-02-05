// lib/pages/register_page.dart
// =====================================================
// ✅ RegisterPage（註冊頁最終版｜對應新版 AuthService.registerAndLogin）
// -----------------------------------------------------
// - 自動登入 + 導向 /member
// - 具體錯誤提示（整合 FirebaseAuthException）
// - 密碼強度條、漸層 Header、高質感 UI
// - 可編譯、可在 Web/Android/iOS 運行
// =====================================================

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _brand = Color(0xFF3B82F6);

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '請輸入顯示名稱';
    if (s.length < 2) return '顯示名稱至少 2 個字';
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

  double _passwordScore(String s) {
    if (s.isEmpty) return 0;
    double score = 0;
    if (s.length >= 6) score += 0.3;
    if (s.length >= 10) score += 0.2;
    if (RegExp(r'[A-Z]').hasMatch(s)) score += 0.2;
    if (RegExp(r'[0-9]').hasMatch(s)) score += 0.15;
    if (RegExp(r'[^\w]').hasMatch(s)) score += 0.15;
    return score.clamp(0, 1);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final err = await AuthService.instance.registerAndLogin(
      _name.text.trim(),
      _email.text.trim(),
      _password.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (err == null) {
      _toast('註冊成功，已自動登入');
      Navigator.pushNamedAndRemoveUntil(context, '/member', (r) => false);
    } else {
      _toast(err);
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 520;

    final score = _passwordScore(_password.text);
    final strengthText = score >= 0.75
        ? '強'
        : score >= 0.45
            ? '中'
            : '弱';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('註冊', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? 520 : 9999),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              children: [
                // ===== Header Hero =====
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.22)),
                        ),
                        child: const Icon(Icons.person_add_alt_1_outlined,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '建立你的 Osmile 帳號\n註冊後即可享受積分、通知與健康同步功能。',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ===== Form Card =====
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: InputDecoration(
                              labelText: '顯示名稱',
                              hintText: '例如：Osmile 小明',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              filled: true,
                              fillColor: const Color(0xFFF7F8FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            validator: _validateName,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'demo@osmile.com',
                              prefixIcon: const Icon(Icons.mail_outline),
                              filled: true,
                              fillColor: const Color(0xFFF7F8FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 12),

                          // 密碼欄位 + 強度條
                          StatefulBuilder(builder: (context, setLocal) {
                            return Column(
                              children: [
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [
                                    AutofillHints.newPassword
                                  ],
                                  onChanged: (_) => setLocal(() {}),
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: '密碼',
                                    hintText: '至少 6 碼',
                                    prefixIcon:
                                        const Icon(Icons.lock_outline_rounded),
                                    filled: true,
                                    fillColor: const Color(0xFFF7F8FA),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                          () => _obscure = !_obscure),
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        child: LinearProgressIndicator(
                                          value: score,
                                          minHeight: 8,
                                          backgroundColor:
                                              Colors.grey.shade200,
                                          color: score >= 0.75
                                              ? Colors.green
                                              : score >= 0.45
                                                  ? Colors.orange
                                                  : Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '強度：$strengthText',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }),

                          const SizedBox(height: 20),

                          // 註冊按鈕
                          SizedBox(
                            height: 48,
                            width: double.infinity,
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
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('註冊',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900)),
                            ),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!,
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 13)),
                          ],

                          const SizedBox(height: 12),

                          // hint
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('已經有帳號？',
                                  style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => Navigator.of(context).pop(false),
                                child: const Text(
                                  '回到登入',
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

                const SizedBox(height: 14),
                Text(
                  '註冊即代表您同意服務條款與隱私權政策（模板）',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ RegisterPage（註冊頁｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - ✅ control_flow_in_finally：finally 內不使用 return（改成 if (mounted) setState）
///// 功能：
/// - Email/Password 註冊
/// - 顯示名稱 displayName（同時寫入 FirebaseAuth + Firestore）
/// - 可選：寫入 users/{uid} 基本資料（createdAt / email / displayName）
/// - 成功後：
///   - 若能 pop 則 pop(true)
///   - 否則 pushReplacementNamed('/')（可改你的首頁 route）
/// ------------------------------------------------------------
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();

  bool _loading = false;
  bool _showPwd = false;
  bool _showPwd2 = false;
  String? _errorText;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '請輸入名稱';
    if (s.length < 2) return '名稱至少 2 個字';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '請輸入 Email';
    if (!s.contains('@') || !s.contains('.')) return 'Email 格式不正確';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '請輸入密碼';
    if (s.length < 6) return '密碼至少 6 碼';
    return null;
  }

  String? _validatePassword2(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '請再次輸入密碼';
    if (s != _pwdCtrl.text.trim()) return '兩次密碼不一致';
    return null;
  }

  Future<void> _register() async {
    if (_loading) return;

    setState(() {
      _errorText = null;
    });

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pwd = _pwdCtrl.text;

    setState(() => _loading = true);

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pwd,
      );

      final user = cred.user;
      if (user == null) {
        throw Exception('註冊失敗：未取得 user');
      }

      // 1) 更新 Auth displayName（不阻塞流程）
      try {
        await user.updateDisplayName(name);
      } catch (_) {}

      // 2) 寫入 Firestore users/{uid}
      //    若你暫時沒設定 rules / collection，這裡失敗也不影響註冊完成
      try {
        await _fs.collection('users').doc(user.uid).set(<String, dynamic>{
          'uid': user.uid,
          'email': user.email,
          'displayName': name,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      if (!mounted) return;

      // 成功後：回上一頁或回首頁
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = _friendlyAuthError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '註冊失敗：$e');
    } finally {
      // ✅ finally 內不要 return（修正 control_flow_in_finally）
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return '此 Email 已被註冊';
      case 'invalid-email':
        return 'Email 格式不正確';
      case 'operation-not-allowed':
        return '此登入方式尚未啟用（請在 Firebase Console 開啟 Email/Password）';
      case 'weak-password':
        return '密碼強度不足（至少 6 碼）';
      case 'too-many-requests':
        return '嘗試次數過多，請稍後再試';
      default:
        return '註冊失敗（${e.code}）：${e.message ?? ""}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('註冊')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              const Icon(
                Icons.person_add_alt_1,
                size: 64,
                color: Colors.blueGrey,
              ),
              const SizedBox(height: 10),
              const Text(
                '建立 Osmile 帳號',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),

              if (_errorText != null) _errorBar(_errorText!),

              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          enabled: !_loading,
                          decoration: const InputDecoration(
                            labelText: '顯示名稱',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: _validateName,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _emailCtrl,
                          enabled: !_loading,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _pwdCtrl,
                          enabled: !_loading,
                          obscureText: !_showPwd,
                          decoration: InputDecoration(
                            labelText: '密碼',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
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
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _pwd2Ctrl,
                          enabled: !_loading,
                          obscureText: !_showPwd2,
                          decoration: InputDecoration(
                            labelText: '確認密碼',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              onPressed: _loading
                                  ? null
                                  : () =>
                                        setState(() => _showPwd2 = !_showPwd2),
                              icon: Icon(
                                _showPwd2
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: _validatePassword2,
                          onFieldSubmitted: (_) => _register(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading ? null : _register,
                            child: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('註冊'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          child: const Text('已有帳號？回登入'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBar(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.20)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.red.shade800,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

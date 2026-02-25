import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 🔒 更改密碼頁（正式版｜Email/Password 專用）
///
/// ✅ 重新驗證舊密碼（reauthenticate）
/// ✅ 更新新密碼（updatePassword）
/// ✅ 匿名 / 手機登入（無密碼）會提示不可使用
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _busy = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  String _mapAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return '舊密碼錯誤';
        case 'weak-password':
          return '新密碼強度不足（至少 6 碼）';
        case 'requires-recent-login':
          return '此操作需要重新登入，請先登出後再登入一次';
        case 'too-many-requests':
          return '嘗試次數過多，請稍後再試';
        case 'network-request-failed':
          return '網路連線失敗，請檢查網路後重試';
        case 'operation-not-allowed':
          return '此登入方式未啟用（請到 Firebase Console 開啟 Email/Password）';
        default:
          return e.message ?? '操作失敗';
      }
    }
    return '操作失敗：$e';
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('尚未登入');
      return;
    }

    if (user.isAnonymous) {
      _toast('匿名帳號無法更改密碼，請先升級為正式帳號');
      return;
    }

    // 必須是 Email/Password provider
    final providers = user.providerData.map((p) => p.providerId).toList();
    final hasPasswordProvider = providers.contains('password');
    final email = user.email;

    if (email == null || email.isEmpty || !hasPasswordProvider) {
      _toast('此帳號不是 Email/密碼登入，無法在此更改密碼');
      return;
    }

    final oldPw = _oldCtrl.text;
    final newPw = _newCtrl.text;

    if (oldPw == newPw) {
      _toast('新密碼不能與舊密碼相同');
      return;
    }

    setState(() => _busy = true);
    try {
      // ✅ 重新驗證舊密碼
      final cred = EmailAuthProvider.credential(email: email, password: oldPw);
      await user.reauthenticateWithCredential(cred);

      // ✅ 更新新密碼
      await user.updatePassword(newPw);

      if (!mounted) return;
      _toast('密碼修改成功 ✅');
      Navigator.pop(context);
    } catch (e) {
      _toast(_mapAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final loggedIn = user != null;
    final isAnonymous = user?.isAnonymous ?? false;
    final emailText = user?.email ?? '未登入';

    final disabled = _busy || !loggedIn || isAnonymous;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "更改密碼",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text(
                "帳號：$emailText",
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              if (isAnonymous)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '目前為匿名帳號，無法更改密碼（請先升級/登入正式帳號）',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _oldCtrl,
                obscureText: _obscureOld,
                enabled: !disabled,
                decoration: InputDecoration(
                  labelText: "舊密碼",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureOld ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _obscureOld = !_obscureOld),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? "請輸入舊密碼" : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _newCtrl,
                obscureText: _obscureNew,
                enabled: !disabled,
                decoration: InputDecoration(
                  labelText: "新密碼",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "請輸入新密碼";
                  if (v.length < 6) return "密碼需至少 6 碼";
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                enabled: !disabled,
                decoration: InputDecoration(
                  labelText: "確認新密碼",
                  prefixIcon: const Icon(Icons.verified_user),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: _busy
                        ? null
                        : () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "請再次輸入新密碼";
                  if (v != _newCtrl.text) return "兩次輸入的密碼不一致";
                  return null;
                },
              ),
              const SizedBox(height: 34),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: disabled ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(_busy ? "處理中…" : "確認修改"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
}

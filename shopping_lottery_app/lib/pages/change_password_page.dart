import 'package:flutter/material.dart';
import 'package:osmile_shopping_app/services/auth_service.dart';

/// 🔒 更改密碼頁（模擬版）
///
/// 功能：
/// ✅ 驗證舊密碼  
/// ✅ 輸入新密碼、確認新密碼  
/// ✅ 模擬更新成功提示  
/// ✅ UI 風格與 Profile 一致
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

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // 模擬驗證密碼流程
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("密碼修改成功 ✅")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text("更改密碼"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                "帳號：${user?['email'] ?? '未登入'}",
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // 舊密碼
              TextFormField(
                controller: _oldCtrl,
                obscureText: _obscureOld,
                decoration: InputDecoration(
                  labelText: "舊密碼",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureOld ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() {
                      _obscureOld = !_obscureOld;
                    }),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? "請輸入舊密碼" : null,
              ),
              const SizedBox(height: 20),

              // 新密碼
              TextFormField(
                controller: _newCtrl,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: "新密碼",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureNew ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() {
                      _obscureNew = !_obscureNew;
                    }),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length < 6) return "密碼需至少 6 碼";
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 確認新密碼
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: "確認新密碼",
                  prefixIcon: const Icon(Icons.verified_user),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () => setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    }),
                  ),
                ),
                validator: (v) {
                  if (v != _newCtrl.text) return "兩次輸入的密碼不一致";
                  return null;
                },
              ),
              const SizedBox(height: 40),

              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_circle),
                label: const Text("確認修改"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

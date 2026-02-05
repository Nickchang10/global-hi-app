import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lottery_admin_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  static const String adminPassword = "admin1234"; // ✅ 可改為你自己的密碼

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final input = _passwordController.text.trim();
    await Future.delayed(const Duration(milliseconds: 800)); // 模擬驗證時間

    if (input == adminPassword) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdmin', true);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LotteryAdminPage()),
        );
      }
    } else {
      setState(() {
        _errorText = "密碼錯誤，請再試一次。";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text("管理者登入"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  color: Colors.blueAccent, size: 60),
              const SizedBox(height: 16),
              const Text(
                "請輸入管理者密碼",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "密碼",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  errorText: _errorText,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.blueAccent,
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(_isLoading ? "登入中..." : "登入"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

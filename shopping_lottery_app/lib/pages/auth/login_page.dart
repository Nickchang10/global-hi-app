import 'package:flutter/material.dart';
import 'auth_page.dart';

/// ✅ 為了相容舊路由/舊檔名：保留 LoginPage 這個 class
/// 但實際 UI 使用新版 AuthPage（登入/註冊/忘記密碼）。
///
/// 這樣做還能避免：
/// - AuthService 撞名（login_page.dart 不再宣告 AuthService）
/// - unnecessary_cast（整頁沒有任何 cast）
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthPage();
  }
}

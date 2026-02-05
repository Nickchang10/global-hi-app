import 'package:flutter/material.dart';
import 'package:osmile_shopping_app/pages/login_page.dart';
import 'package:osmile_shopping_app/pages/home_page.dart';
import 'package:osmile_shopping_app/services/auth_service.dart';
import 'package:osmile_shopping_app/services/firestore_mock_service.dart';

/// 🚀 啟動畫面（自動登入判斷版）
///
/// 功能：
/// ✅ 啟動時顯示 LOGO 與動畫
/// ✅ 自動檢查是否登入過
/// ✅ 已登入 → 進入首頁
/// ✅ 未登入 → 前往登入頁
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(milliseconds: 800)); // 模擬啟動畫面時間

    final auth = AuthService.instance;
    final firestore = FirestoreMockService.instance;

    await auth.init();
    await firestore.init();

    final loggedIn = auth.isLoggedIn || await firestore.isLoggedIn();

    await Future.delayed(const Duration(milliseconds: 600)); // 美觀過場
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => loggedIn ? const HomePage() : const LoginPage(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.watch, color: Colors.white, size: 100),
              SizedBox(height: 20),
              Text(
                "Osmile 智慧生活",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "Smart • Health • Safe",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

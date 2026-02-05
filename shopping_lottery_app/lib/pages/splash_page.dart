// lib/pages/splash_page.dart
// =====================================================
// ✅ Osmile Shopping App - 啟動畫面 (SplashPage)
// 功能：
// - LOGO 與品牌動畫
// - 初始化 Firestore / AuthService
// - 自動檢查登入狀態 → 導向 LoginPage 或 主頁
// =====================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:osmile_shopping_app/services/auth_service.dart';
import 'package:osmile_shopping_app/services/firestore_mock_service.dart';
import 'package:osmile_shopping_app/pages/auth/login_page.dart';
import 'package:osmile_shopping_app/main.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // LOGO 動畫控制
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    // 啟動初始化流程
    _initializeApp();
  }

  /// ✅ 初始化 Firestore + Auth + 導向邏輯
  Future<void> _initializeApp() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1500));

      final firestore = FirestoreMockService.instance;
      await firestore.init();

      final auth = AuthService.instance;
      await auth.init();

      if (!mounted) return;

      // 🔐 登入狀態檢查
      if (auth.isLoggedIn) {
        // 已登入 → 進入主頁
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainTabPage()),
        );
      } else {
        // 未登入 → 登入頁
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      debugPrint('⚠️ 初始化失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化失敗：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // =====================================================
  // ✅ 畫面 UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景漸層
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // 主體內容
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // LOGO 圓形圖示
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.watch, size: 80, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 30),

                  // 品牌名稱
                  const Text(
                    "Osmile 智慧購物",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 副標語
                  const Text(
                    "連接．健康．生活",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 載入進度
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const SizedBox.shrink(),
                ],
              ),
            ),

            // 底部標語 / 版本資訊
            const Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    "Osmile Health Co., Ltd.",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "版本 1.0.0",
                    style: TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

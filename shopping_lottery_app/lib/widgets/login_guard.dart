// lib/widgets/login_guard.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ LoginGuard（登入守門員｜完整版｜可編譯｜已修 withOpacity deprecated）
/// ------------------------------------------------------------
/// 用法：
/// LoginGuard(
///   child: YourPage(),
/// )
///
/// - 未登入：顯示提示卡片 + 前往登入按鈕
/// - 已登入：顯示 child
class LoginGuard extends StatelessWidget {
  const LoginGuard({
    super.key,
    required this.child,
    this.title = '需要登入',
    this.message = '請先登入後再繼續使用此功能',
    this.loginRoute = '/login',
    this.onLoginTap,
    this.backgroundAlpha = 0.06,
    this.maxWidth = 520,
  });

  final Widget child;

  final String title;
  final String message;

  /// 預設導到 /login（你 main.dart routes 有註冊即可）
  final String loginRoute;

  /// 你也可以自訂登入行為（例如 open modal）
  final VoidCallback? onLoginTap;

  /// 背景淡色透明度（0~1）
  final double backgroundAlpha;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return child;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(
                        alpha: backgroundAlpha,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 36,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          onLoginTap ??
                          () => Navigator.of(
                            context,
                            rootNavigator: true,
                          ).pushNamed(loginRoute),
                      child: const Text('前往登入'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(
                      '稍後再說',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

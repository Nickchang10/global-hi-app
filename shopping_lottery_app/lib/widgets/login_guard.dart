import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

/// ✅ LoginGuard：統一檢查登入狀態
/// - 若已登入：執行 child
/// - 若未登入：顯示灰階禁用按鈕或跳轉提示
class LoginGuard extends StatelessWidget {
  final Widget Function(BuildContext) builder;
  final bool showOverlay;
  final VoidCallback? onRequireLogin;

  const LoginGuard({
    super.key,
    required this.builder,
    this.showOverlay = false,
    this.onRequireLogin,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final loggedIn = auth.loggedIn;

    if (loggedIn) return builder(context);

    // 未登入
    if (showOverlay) {
      return Stack(
        children: [
          builder(context),
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.7),
              child: Center(
                child: ElevatedButton(
                  onPressed: onRequireLogin ??
                      () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  child: const Text('登入以使用此功能'),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return builder(context);
  }
}

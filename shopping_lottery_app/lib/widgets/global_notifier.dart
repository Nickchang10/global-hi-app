// lib/widgets/global_notifier.dart
import 'package:flutter/material.dart';

/// ======================================================
/// ✅ GlobalNotifier（全域 Snackbar/訊息提示）
/// ------------------------------------------------------
/// 用法（建議放在 MaterialApp.builder）
/// MaterialApp(
///   scaffoldMessengerKey: GlobalNotifier.messengerKey, // ✅ 這行也可用
///   builder: (context, child) => GlobalNotifier(child: child ?? const SizedBox.shrink()),
/// )
///
/// 任何地方呼叫：
/// GlobalNotifier.show(message: '已加入購物車');
/// GlobalNotifier.success('付款成功');
/// GlobalNotifier.error('付款失敗');
/// ======================================================
class GlobalNotifier extends StatelessWidget {
  final Widget child;

  const GlobalNotifier({super.key, required this.child});

  /// ✅ 全域 ScaffoldMessengerKey
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    // ✅ 不做任何「非 null 變數」的 null 比較（移除 unnecessary_null_comparison）
    return ScaffoldMessenger(key: messengerKey, child: child);
  }

  // -----------------------
  // Public APIs
  // -----------------------

  static void show({
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: action,
        content: title == null || title.trim().isEmpty
            ? Text(message)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
      ),
    );
  }

  static void success(String message, {String title = '✅ 成功'}) {
    show(title: title, message: message);
  }

  static void warning(String message, {String title = '⚠️ 提醒'}) {
    show(title: title, message: message, duration: const Duration(seconds: 3));
  }

  static void error(String message, {String title = '❌ 錯誤'}) {
    show(title: title, message: message, duration: const Duration(seconds: 4));
  }

  static void clear() {
    messengerKey.currentState?.clearSnackBars();
  }
}

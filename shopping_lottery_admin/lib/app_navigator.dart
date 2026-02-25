// lib/app_navigator.dart
//
// ✅ AppNavigator（完整版｜可編譯｜全域導頁）
// ------------------------------------------------------------
// 用途：讓 services（像 push_service / fcm_service）在沒有 BuildContext 的情況下也能導頁。
// 你只要在 MaterialApp 掛上 navigatorKey: AppNavigator.key 就能用。

import 'package:flutter/material.dart';

class AppNavigator {
  AppNavigator._();

  /// 全域 NavigatorKey
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static NavigatorState? get _nav => key.currentState;
  static BuildContext? get context => key.currentContext;

  static bool get isReady => _nav != null;

  // -------------------------
  // Basic navigation helpers
  // -------------------------

  static Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) async {
    final nav = _nav;
    if (nav == null) return null;
    return nav.pushNamed<T>(routeName, arguments: arguments);
  }

  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    Object? arguments,
    TO? result,
  }) async {
    final nav = _nav;
    if (nav == null) return null;
    return nav.pushReplacementNamed<T, TO>(
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  static Future<T?> push<T extends Object?>(Route<T> route) async {
    final nav = _nav;
    if (nav == null) return null;
    return nav.push<T>(route);
  }

  static void pop<T extends Object?>([T? result]) {
    final nav = _nav;
    if (nav == null) return;
    if (nav.canPop()) nav.pop<T>(result);
  }

  static Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String routeName, {
    Object? arguments,
    bool Function(Route<dynamic>)? predicate,
  }) async {
    final nav = _nav;
    if (nav == null) return null;
    return nav.pushNamedAndRemoveUntil<T>(
      routeName,
      predicate ?? (r) => false,
      arguments: arguments,
    );
  }

  // -------------------------
  // UI helpers
  // -------------------------

  static void snack(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final ctx = context;
    if (ctx == null) return;
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(SnackBar(content: Text(message), duration: duration));
  }

  static Future<bool> confirm(
    String title,
    String message, {
    String okText = '確認',
    String cancelText = '取消',
  }) async {
    final ctx = context;
    if (ctx == null) return false;

    final result = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okText),
          ),
        ],
      ),
    );
    return result == true;
  }
}

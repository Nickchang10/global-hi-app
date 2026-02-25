// lib/services/push_router.dart
//
// ✅ PushRouter（完整版｜可編譯）
// ------------------------------------------------------------
// 用途：
// - 統一處理 FCM 推播點擊後的「導頁」
// - 支援：App 還沒 ready（navigatorKey 尚未掛上）時先排隊，等 ready 再執行
//
// 推播 data 建議格式：
// {
//   "route": "/orders",
//   "args": "{...json...}" 或直接 data 其他欄位都當 arguments
// }
//
// 若沒有 route，會 fallback 到 /notifications（可改）

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

class PushRouter {
  PushRouter({
    GlobalKey<NavigatorState>? navigatorKey,
    this.fallbackRoute = '/notifications',
  }) : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();

  final GlobalKey<NavigatorState> navigatorKey;
  final String fallbackRoute;

  bool _ready = false;
  final List<_PendingNav> _pending = [];

  /// 可選：在 App 首頁 build 後呼叫一次，確保推播點擊導頁不會因 navigator 尚未 ready 而失敗
  void markReady() {
    _ready = true;
    _flushPending();
  }

  /// ✅ 你缺的就是這個：讓 fcm_service.dart 可以呼叫 pushRouter.handle(message)
  void handle(RemoteMessage message) {
    handleData(message.data);
  }

  /// 也可直接丟 data 進來（方便測試）
  void handleData(Map<String, dynamic> data) {
    final route = (data['route'] ?? data['screen'] ?? '').toString().trim();
    final args = _parseArgs(data);

    final goRoute = route.isNotEmpty ? route : fallbackRoute;
    pushNamed(goRoute, arguments: args);
  }

  /// 統一 pushNamed（自動排隊）
  void pushNamed(
    String route, {
    Object? arguments,
    bool replace = false,
    bool clearStack = false,
  }) {
    final nav = navigatorKey.currentState;
    final canNav = _ready && nav != null;

    if (!canNav) {
      _pending.add(
        _PendingNav(
          route: route,
          arguments: arguments,
          replace: replace,
          clearStack: clearStack,
        ),
      );
      return;
    }

    if (clearStack) {
      nav.pushNamedAndRemoveUntil(route, (r) => false, arguments: arguments);
      return;
    }

    if (replace) {
      nav.pushReplacementNamed(route, arguments: arguments);
      return;
    }

    nav.pushNamed(route, arguments: arguments);
  }

  // ------------------------------------------------------------
  // Internal
  // ------------------------------------------------------------

  void _flushPending() {
    final nav = navigatorKey.currentState;
    if (!_ready || nav == null) return;
    if (_pending.isEmpty) return;

    final jobs = List<_PendingNav>.from(_pending);
    _pending.clear();

    for (final j in jobs) {
      pushNamed(
        j.route,
        arguments: j.arguments,
        replace: j.replace,
        clearStack: j.clearStack,
      );
    }
  }

  Object? _parseArgs(Map<String, dynamic> data) {
    // 支援 data['args'] 是 JSON 字串
    final raw = data['args'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        // ignore
      }
    }

    // 否則：把整包 data 當 arguments（最通用）
    return data;
  }
}

class _PendingNav {
  final String route;
  final Object? arguments;
  final bool replace;
  final bool clearStack;

  _PendingNav({
    required this.route,
    required this.arguments,
    required this.replace,
    required this.clearStack,
  });
}

import 'package:flutter/widgets.dart';

typedef MainNavJumpHandler = void Function(int index, Object? args);

class MainNavScope extends InheritedWidget {
  const MainNavScope({
    super.key,
    required this.currentIndex,
    required this.onJump,
    required this.routeToIndex,
    required super.child,
  });

  final int currentIndex;
  final MainNavJumpHandler onJump;

  /// ✅ 由 MainNavigationPage 動態產生（依照後台 footerTabs）
  final Map<String, int> routeToIndex;

  static MainNavScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainNavScope>();
  }

  static MainNavScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'MainNavScope.of() called with no MainNavScope in context.',
    );
    return scope!;
  }

  /// ✅ HomePage 用：優先切 tab，切不到才回 false 讓你走 pushNamed
  bool jumpTo(String route, {Object? args}) {
    final r = _alias[_norm(route)] ?? _norm(route);
    final idx = routeToIndex[r];
    if (idx == null) return false;
    onJump(idx, args);
    return true;
  }

  static String _norm(String raw) {
    var r = raw.trim();
    if (r.isEmpty || r == '/' || r == '/home') return '/home';
    if (!r.startsWith('/')) r = '/$r';
    while (r.endsWith('/') && r.length > 1) {
      r = r.substring(0, r.length - 1);
    }
    return r.toLowerCase();
  }

  /// ✅ 常見 alias（你的 HomePage 也有 normalize，我這裡再補一層保險）
  static const Map<String, String> _alias = {
    '/interaction': '/interact',
    '/member': '/me',
    '/mine': '/me',
  };

  @override
  bool updateShouldNotify(MainNavScope oldWidget) {
    return oldWidget.currentIndex != currentIndex ||
        oldWidget.onJump != onJump ||
        oldWidget.routeToIndex != routeToIndex;
  }
}

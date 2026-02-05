import 'package:flutter/widgets.dart';

typedef JumpToTabFn = bool Function(String route, {Object? args});

class MainNavScope extends InheritedWidget {
  final JumpToTabFn jumpTo;
  final String currentRoute;

  const MainNavScope({
    super.key,
    required super.child,
    required this.jumpTo,
    required this.currentRoute,
  });

  static MainNavScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainNavScope>();
  }

  static MainNavScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'MainNavScope not found in widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(MainNavScope oldWidget) {
    return oldWidget.currentRoute != currentRoute;
  }
}

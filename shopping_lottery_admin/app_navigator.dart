// lib/app_navigator.dart
import 'package:flutter/material.dart';

class AppNavigator {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> pushNamed(String routeName, {Object? arguments}) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    await nav.pushNamed(routeName, arguments: arguments);
  }

  static Future<void> pushReplacementNamed(String routeName, {Object? arguments}) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    await nav.pushReplacementNamed(routeName, arguments: arguments);
  }
}

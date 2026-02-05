// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  ThemeService._internal();
  static final ThemeService instance = ThemeService._internal();

  static const String _kKey = 'osmile_theme_dark';
  bool _isDark = false;
  bool get isDark => _isDark;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_kKey) ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, _isDark);
    notifyListeners();
  }

  Future<void> setDark(bool v) async {
    _isDark = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, _isDark);
    notifyListeners();
  }
}

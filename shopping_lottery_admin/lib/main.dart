// lib/main.dart
import 'package:flutter/material.dart';

// ✅ 用你的 pubspec.yaml 的 name（你 log 顯示是 package:osmile_admin/...）
import 'package:osmile_admin/main_app.dart' as app;

@pragma('vm:entry-point')
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const app.AdminBootstrap());
}

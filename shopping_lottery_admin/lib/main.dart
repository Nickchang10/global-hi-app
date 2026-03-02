// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'package:osmile_admin/main_app.dart' as app;

@pragma('vm:entry-point')
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 先初始化 Firebase（Web/Android/iOS/Windows/Linux 都吃 flutterfire options）
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const app.AdminBootstrap());
}

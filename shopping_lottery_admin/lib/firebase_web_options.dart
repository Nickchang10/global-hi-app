// lib/firebase_web_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'firebase_options.dart';

/// ✅ 相容舊程式：如果專案任何地方還在用 firebaseWebOptions，這裡直接回傳 web options
/// ❌ 不要再用 dart-define + throw 的寫法（會造成你現在看到的錯誤畫面）
final FirebaseOptions firebaseWebOptions = DefaultFirebaseOptions.web;

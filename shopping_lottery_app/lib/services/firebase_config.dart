import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static bool isConnected = false;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      isConnected = true;
      debugPrint("✅ Firebase initialized successfully");
    } catch (e) {
      isConnected = false;
      debugPrint("⚠️ Firebase unavailable, switching to mock mode: $e");
    }
  }
}

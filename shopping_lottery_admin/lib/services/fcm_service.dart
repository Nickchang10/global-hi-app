import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'push_router.dart';

class FCMService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static bool _initialized = false;

  /// 🚀 初始化（登入後呼叫一次即可）
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // ============================
      // 1️⃣ 權限（iOS / Web 必要）
      // ============================
      await _requestPermission();

      // ============================
      // 2️⃣ Token 註冊
      // ============================
      await _registerToken();

      // ============================
      // 3️⃣ Token refresh
      // ============================
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final uid = _auth.currentUser?.uid;
        if (uid == null) return;

        await _saveToken(uid, newToken);
      });

      // ============================
      // 4️⃣ 前景通知（App 開著）
      // ============================
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // 你若之後要做前景 toast / snackbar，可在這裡加
        debugPrint('[FCM] Foreground message: ${message.data}');
      });

      // ============================
      // 5️⃣ 背景 → 點擊
      // ============================
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        PushRouter.handle(message.data);
      });

      // ============================
      // 6️⃣ 關閉狀態 → 點擊啟動
      // ============================
      final initialMsg = await _fcm.getInitialMessage();
      if (initialMsg != null) {
        PushRouter.handle(initialMsg.data);
      }
    } catch (e, st) {
      debugPrint('[FCM] init failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  // ===========================================================
  // Permission
  // ===========================================================

  static Future<void> _requestPermission() async {
    if (kIsWeb) {
      await _fcm.requestPermission();
      return;
    }

    if (Platform.isIOS || Platform.isMacOS) {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // iOS 前景顯示
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  // ===========================================================
  // Token handling
  // ===========================================================

  static Future<void> _registerToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final token = await _fcm.getToken();
    if (token == null) return;

    await _saveToken(uid, token);
  }

  static Future<void> _saveToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).set(
        {
          'fcmTokens': FieldValue.arrayUnion([token]),
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[FCM] saveToken failed: $e');
    }
  }

  // ===========================================================
  // 登出時可選呼叫（乾淨）
  // ===========================================================

  static Future<void> removeCurrentToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final token = await _fcm.getToken();
    if (token == null) return;

    await _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }
}

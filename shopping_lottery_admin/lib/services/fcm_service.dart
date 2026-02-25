// lib/services/fcm_service.dart
//
// ✅ FcmService（完整版｜可編譯｜Web + Android/iOS 安全）
// ------------------------------------------------------------
// 功能：
// - 初始化 FirebaseMessaging
// - 取得/更新 FCM token（登入後寫入 users/{uid}.fcmTokens）
// - 前景訊息 onMessage（可選：寫入通知中心/顯示 SnackBar）
// - 點擊通知 onMessageOpenedApp / getInitialMessage 導頁（透過 PushRouter.handle）
//
// 依賴：
// firebase_core, firebase_messaging, cloud_firestore, firebase_auth, flutter/foundation
//
// 使用建議（main.dart）：
// final pushRouter = PushRouter(navigatorKey: navigatorKey);
// final fcm = FcmService(pushRouter: pushRouter);
// await fcm.init();
// MaterialApp(navigatorKey: pushRouter.navigatorKey, ...);
// 首頁 build 完後呼叫 pushRouter.markReady();

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_router.dart';

/// ✅ 背景訊息 handler（Android/iOS）
///
/// 注意：你需要在 main() 很早期註冊：
/// FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // 若你的專案有多 FirebaseApp/自訂 options，請在此補上 initializeApp options
    await Firebase.initializeApp();
  } catch (_) {
    // ignore
  }
  // 這裡通常只做資料寫入（不要做導航）
}

class FcmService {
  FcmService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    required this.pushRouter,
    this.usersCollection = 'users',
    this.webVapidKey,
  }) : _msg = messaging ?? FirebaseMessaging.instance,
       _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseMessaging _msg;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  final PushRouter pushRouter;
  final String usersCollection;

  /// Web 若你有 VAPID key（Firebase console 產的 Web push certificate key pair）
  /// 沒有也不會炸，只是拿不到 token
  final String? webVapidKey;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenSub;
  StreamSubscription<String>? _tokenRefreshSub;

  bool _inited = false;

  // ------------------------------------------------------------
  // Public
  // ------------------------------------------------------------

  Future<void> init({bool requestPermission = true}) async {
    if (_inited) return;
    _inited = true;

    // ✅ 背景 handler：通常在 main() 註冊更好，但這裡也補一層保險
    if (!kIsWeb) {
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (_) {
        // ignore
      }
    }

    if (requestPermission) {
      await _requestPermissionIfNeeded();
    }

    // iOS/macOS：顯示前景通知（Android 預設就會顯示系統通知，前景則由 app 自行處理）
    try {
      await _msg.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // ignore
    }

    // ✅ token 綁定（登入狀態下）
    await syncTokenToUser();

    // ✅ token refresh
    _tokenRefreshSub = _msg.onTokenRefresh.listen((t) async {
      await _saveTokenToUser(t);
    });

    // ✅ 前景訊息
    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      // 這裡不做導航（通常前景由 UI 決定要不要跳）
      // 你若要寫入 notifications collection，可在此呼叫 NotificationService
    });

    // ✅ 點擊通知（背景/前景點擊）
    _onOpenSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      pushRouter.handle(message);
    });

    // ✅ 冷啟動：從通知點進來
    try {
      final initial = await _msg.getInitialMessage();
      if (initial != null) {
        pushRouter.handle(initial);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onOpenSub?.cancel();
    await _tokenRefreshSub?.cancel();
    _onMessageSub = null;
    _onOpenSub = null;
    _tokenRefreshSub = null;
  }

  /// 手動同步 token（例如：登入成功後呼叫）
  Future<void> syncTokenToUser() async {
    final token = await _getTokenSafe();
    if (token == null || token.trim().isEmpty) return;
    await _saveTokenToUser(token);
  }

  /// 登出時可選：把 token 從 user doc 移除（看你是否要保留裝置 token）
  Future<void> removeTokenFromUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final token = await _getTokenSafe();
    if (token == null || token.trim().isEmpty) return;

    final ref = _db.collection(usersCollection).doc(user.uid);
    await ref.set({
      'fcmTokens': FieldValue.arrayRemove([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ------------------------------------------------------------
  // Internal
  // ------------------------------------------------------------

  Future<void> _requestPermissionIfNeeded() async {
    try {
      // Web 也可呼叫，但有些環境會丟例外，包起來即可
      final settings = await _msg.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 你想 debug 可印出：settings.authorizationStatus
      // 這裡不強制
      // ignore: unused_local_variable
      final _ = settings.authorizationStatus;
    } catch (_) {
      // ignore
    }
  }

  Future<String?> _getTokenSafe() async {
    try {
      if (kIsWeb) {
        // Web 若沒提供 vapidKey 也不會炸，但可能拿不到 token
        return await _msg.getToken(vapidKey: webVapidKey);
      }
      return await _msg.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveTokenToUser(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final t = token.trim();
    if (t.isEmpty) return;

    final ref = _db.collection(usersCollection).doc(user.uid);

    // ✅ 用 arrayUnion 保留多裝置 token
    await ref.set({
      'uid': user.uid,
      'email': user.email,
      'fcmTokens': FieldValue.arrayUnion([t]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

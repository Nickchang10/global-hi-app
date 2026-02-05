// lib/services/push_service.dart
//
// ✅ PushService（最終完整版｜已補齊「公告通知點擊 → 跳公告詳情」）
// ------------------------------------------------------------
// - 申請通知權限（iOS 需要）
// - 取得 FCM token 並寫入：users/{uid}/fcmTokens/{token}
// - 監聽 token refresh 自動更新
// - 前景收到推播：用 flutter_local_notifications 顯示
// - 點擊推播：依 data.route / data.orderId / data.announcementId 自動導頁（Deep Link）
//
// ✅ 新增：
// - route == '/announcement_detail' 時，支援從 data['announcementId'] 或 data['extra']['announcementId'] 取值
// - 導頁 arguments: {'announcementId': xxx}
//
// 依賴：firebase_messaging, flutter_local_notifications, cloud_firestore, firebase_auth

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app_navigator.dart';

class PushService {
  PushService({this.enableDebugLog = false});

  final bool enableDebugLog;

  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _local = FlutterLocalNotificationsPlugin();

  bool _inited = false;

  // ============
  // Public
  // ============

  Future<void> ensureInitialized() async {
    if (_inited) return;
    _inited = true;

    await _initLocalNotifications();
    await _requestPermission();
    await _syncToken();
    _listenTokenRefresh();
    _listenForeground();
    await _handleInitialOpen();
    _listenOpenFromBackground();
  }

  /// 登入後呼叫：確保 token 綁定到當前 uid
  Future<void> onSignedIn() async {
    await ensureInitialized();
    await _syncToken();
  }

  /// 登出前可呼叫：視需求刪 token（通常不強制）
  Future<void> onSignedOut() async {
    // 可選：刪除 token（若要強一致）
    // final token = await _messaging.getToken();
    // if (token != null) await _deleteToken(token);
  }

  // ============
  // Init
  // ============

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();

    const settings = InitializationSettings(android: android, iOS: iOS);

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload;
        if (payload == null || payload.trim().isEmpty) return;
        try {
          final m = jsonDecode(payload) as Map<String, dynamic>;
          await _routeByMap(m);
        } catch (_) {}
      },
    );

    // Android channel（避免前景不顯示）
    const channel = AndroidNotificationChannel(
      'osmile_high',
      'Osmile Notifications',
      description: 'Osmile app notifications',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      sound: true,
      badge: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    _log('permission: ${settings.authorizationStatus}');
  }

  // ============
  // Token sync
  // ============

  Future<void> _syncToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _log('no user, skip token sync');
      return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;

    final ref =
        _db.collection('users').doc(uid).collection('fcmTokens').doc(token);

    await ref.set({
      'token': token,
      'platform': kIsWeb ? 'web' : 'mobile',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _log('token saved: ${token.substring(0, token.length.clamp(0, 12))}...');
  }

  void _listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _log('token refresh');
      await _syncToken();
    });
  }

  // ============
  // Message handling
  // ============

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      _log('onMessage: ${msg.messageId}');
      // 前景顯示本地通知
      await _showLocalNotificationFromMessage(msg);
    });
  }

  Future<void> _handleInitialOpen() async {
    // App 被關閉時，點擊通知開啟
    final msg = await _messaging.getInitialMessage();
    if (msg != null) {
      _log('getInitialMessage');
      await _routeByRemoteMessage(msg);
    }
  }

  void _listenOpenFromBackground() {
    // App 在背景時，點擊通知回到前景
    FirebaseMessaging.onMessageOpenedApp.listen((msg) async {
      _log('onMessageOpenedApp');
      await _routeByRemoteMessage(msg);
    });
  }

  // ============
  // Local notification
  // ============

  Future<void> _showLocalNotificationFromMessage(RemoteMessage msg) async {
    final title =
        msg.notification?.title ?? (msg.data['title']?.toString() ?? '通知');
    final body =
        msg.notification?.body ?? (msg.data['body']?.toString() ?? '');

    final payloadMap = <String, dynamic>{};
    payloadMap.addAll(msg.data);

    // fallback：若沒 route，就不導頁
    final payload = jsonEncode(payloadMap);

    const androidDetails = AndroidNotificationDetails(
      'osmile_high',
      'Osmile Notifications',
      channelDescription: 'Osmile app notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iOSDetails = DarwinNotificationDetails();

    const details =
        NotificationDetails(android: androidDetails, iOS: iOSDetails);

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ============
  // Deep link routing
  // ============

  Future<void> _routeByRemoteMessage(RemoteMessage msg) async {
    // 你 Cloud Function 會把 route/orderId 放在 data
    final data = msg.data;
    await _routeByMap(data);
  }

  Future<void> _routeByMap(Map<String, dynamic> data) async {
    final route = (data['route'] ?? '').toString().trim();
    if (route.isEmpty) return;

    // ===============================
    // ✅ 公告：點通知跳公告詳情
    // route: /announcement_detail
    // data: announcementId 或 extra.announcementId
    // ===============================
    if (route == '/announcement_detail') {
      String _getAnnouncementId() {
        final a = (data['announcementId'] ?? '').toString().trim();
        if (a.isNotEmpty) return a;

        final extra = data['extra'];
        if (extra is Map) {
          final b = (extra['announcementId'] ?? '').toString().trim();
          if (b.isNotEmpty) return b;
        }

        // 容錯：有些人會用 key = id
        final c = (data['id'] ?? '').toString().trim();
        if (c.isNotEmpty) return c;

        return '';
      }

      final announcementId = _getAnnouncementId();
      if (announcementId.isNotEmpty) {
        await AppNavigator.pushNamed(
          '/announcement_detail',
          arguments: {'announcementId': announcementId},
        );
      } else {
        // 若未帶 id：退回公告列表
        await AppNavigator.pushNamed('/announcements');
      }
      return;
    }

    // ===============================
    // ✅ 訂單（Admin/Vendor）
    // ===============================
    final orderId = (data['orderId'] ?? data['oid'] ?? '').toString().trim();

    // ✅ 你目前訂單詳情路由：/admin/orders/detail (arguments: orderId)
    if (route == '/admin/orders/detail' && orderId.isNotEmpty) {
      await AppNavigator.pushNamed('/admin/orders/detail', arguments: orderId);
      return;
    }

    // ✅ Vendor 訂單詳情（如果你有）
    if (route == '/vendor/orders/detail' && orderId.isNotEmpty) {
      await AppNavigator.pushNamed('/vendor/orders/detail', arguments: orderId);
      return;
    }

    // ===============================
    // 其他路由：直接帶 arguments（若你想）
    // ===============================
    final argsRaw = data['args'];
    Object? args;

    // args 可能是 JSON 字串
    if (argsRaw is String && argsRaw.trim().startsWith('{')) {
      try {
        args = jsonDecode(argsRaw);
      } catch (_) {}
    } else {
      args = argsRaw;
    }

    await AppNavigator.pushNamed(route, arguments: args);
  }

  void _log(String msg) {
    if (!enableDebugLog) return;
    // ignore: avoid_print
    print('[PushService] $msg');
  }
}

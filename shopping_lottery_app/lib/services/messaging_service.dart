// lib/services/messaging_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// MessagingService
/// - 申請通知權限
/// - 取得 FCM token（Web 可傳 vapidKey）
/// - 登入/換 token 時自動把 token 寫回 Firestore: users/{uid}/devices/{encodedToken}
/// - 不依賴 BuildContext，不會出現 use_build_context_synchronously
class MessagingService {
  MessagingService._();
  static final MessagingService instance = MessagingService._();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _msg = FirebaseMessaging.instance;

  bool _inited = false;
  String? _cachedToken;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _msgSub;

  /// 初始化（可重複呼叫；只會真的 init 一次）
  Future<void> init({String? vapidKey}) async {
    if (_inited) {
      // 若已 init 過，但現在登入了，補一次寫回
      await _syncTokenToCurrentUser();
      return;
    }
    _inited = true;

    // 1) 權限（iOS/Android 需要；Web 也可呼叫但可能無感）
    try {
      await _msg.requestPermission();
    } catch (_) {}

    // 2) 監聽登入：登入後把 cached token 寫回
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((u) async {
      if (u == null) {
        return;
      }
      final t = _cachedToken;
      if (t != null && t.isNotEmpty) {
        await _saveToken(u.uid, t);
      } else {
        await _syncTokenToCurrentUser(vapidKey: vapidKey);
      }
    });

    // 3) 取得 token（Web 沒 SW / 沒 VAPID 可能會失敗，不要讓 app 爆）
    await _syncTokenToCurrentUser(vapidKey: vapidKey);

    // 4) token refresh
    _tokenSub?.cancel();
    _tokenSub = _msg.onTokenRefresh.listen((t) async {
      _cachedToken = t;
      final uid = _auth.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        await _saveToken(uid, t);
      }
    });

    // 5) 前景訊息（你目前不做彈窗 OK；先留著避免沒監聽）
    _msgSub?.cancel();
    _msgSub = FirebaseMessaging.onMessage.listen((m) async {
      // 開發期先不做 local_notifications
      // 你若要接 NotificationCenter，可在這裡把 m.data 寫入 Firestore notifications
    });
  }

  /// 若你想在登入成功後手動觸發一次寫回 token，也可以呼叫這個
  Future<void> syncNow({String? vapidKey}) async {
    await _syncTokenToCurrentUser(vapidKey: vapidKey);
  }

  /// 釋放監聽（一般不必呼叫；除非你做熱重載/多入口想手動管理）
  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenSub?.cancel();
    await _msgSub?.cancel();
    _authSub = null;
    _tokenSub = null;
    _msgSub = null;
    _inited = false;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _syncTokenToCurrentUser({String? vapidKey}) async {
    try {
      final token = await _msg.getToken(vapidKey: vapidKey);
      if (token == null || token.isEmpty) {
        return;
      }
      _cachedToken = token;

      final uid = _auth.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        await _saveToken(uid, token);
      }
    } catch (_) {
      // Web 沒 SW / 沒 VAPID：會進來這裡，忽略即可
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    // Firestore docId 不允許 '/'，保險起見做 encode（FCM token 通常不含 '/'，但這樣最穩）
    final docId = Uri.encodeComponent(token);

    try {
      await _fs
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(docId)
          .set(<String, dynamic>{
            'token': token,
            'platform': kIsWeb ? 'web' : 'mobile',
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }
}

// lib/services/cloud_push_service.dart
//
// ✅ CloudPushService（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// 修正重點：原本呼叫通知寫入時缺少 required named parameter `type`。
// 這版把 `type` 提供預設值（不再 required），並統一寫入 Firestore 通知中心。
// ----------------------------------------------------
//
// Firestore 結構：
// - users/{uid}/notifications/{autoId}
//
// 需要套件：cloud_firestore, firebase_auth
// ----------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PushNotificationFields {
  static const String title = 'title';
  static const String body = 'body';
  static const String type =
      'type'; // system / order / achievement / marketing / push ...
  static const String read = 'read';
  static const String createdAt = 'createdAt';
  static const String data = 'data';
}

class CloudPushService {
  CloudPushService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static final CloudPushService instance = CloudPushService._();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get currentUid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _notiCol(String uid) =>
      _userRef(uid).collection('notifications');

  /// ✅ 寫通知到指定使用者（通知中心用）
  ///
  /// - type：不再 required，預設 'system'（解決你 missing_required_argument）
  Future<void> addNotification({
    required String uid,
    required String title,
    required String body,
    String type = 'system',
    Map<String, dynamic>? data,
  }) async {
    await _notiCol(uid).add({
      PushNotificationFields.title: title,
      PushNotificationFields.body: body,
      PushNotificationFields.type: type,
      PushNotificationFields.read: false,
      PushNotificationFields.createdAt: FieldValue.serverTimestamp(),
      PushNotificationFields.data: data ?? <String, dynamic>{},
    });
  }

  /// ✅ 寫通知給自己（最常用：前台流程直接呼叫）
  Future<void> notifyMe({
    required String title,
    required String body,
    String type = 'system',
    Map<String, dynamic>? data,
  }) async {
    final uid = currentUid;
    if (uid == null) return;
    await addNotification(
      uid: uid,
      title: title,
      body: body,
      type: type,
      data: data,
    );
  }

  /// ✅ 訂單通知（付款成功/失敗/出貨等）
  Future<void> notifyOrder({
    required String uid,
    required String orderId,
    required String title,
    required String body,
    String type = 'order',
    Map<String, dynamic>? extra,
  }) async {
    await addNotification(
      uid: uid,
      title: title,
      body: body,
      type: type,
      data: {'orderId': orderId, ...?extra},
    );
  }

  /// ✅ 行銷通知（推播/活動/優惠）
  Future<void> notifyMarketing({
    required String uid,
    required String title,
    required String body,
    String type = 'marketing',
    Map<String, dynamic>? data,
  }) async {
    await addNotification(
      uid: uid,
      title: title,
      body: body,
      type: type,
      data: data,
    );
  }

  /// ✅ 成就通知（如果你想統一都走這裡也可以）
  Future<void> notifyAchievement({
    required String uid,
    required String achievementId,
    required String title,
    required String body,
    String type = 'achievement',
    Map<String, dynamic>? extra,
  }) async {
    await addNotification(
      uid: uid,
      title: title,
      body: body,
      type: type,
      data: {'achievementId': achievementId, ...?extra},
    );
  }
}

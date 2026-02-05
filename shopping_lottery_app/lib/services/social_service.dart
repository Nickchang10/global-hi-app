// lib/services/sos_service.dart
// ======================================================
// ✅ SOSService（最終整合版）
// - trigger/cancel 會寫入 Firestore：
//   sos/{userId}  (active, lastTriggeredAt, lastResolvedAt, lastLocation...)
//   sos/{userId}/events/{eventId}
// - 同步通知中心 NotificationService
// - 可選：listenRemote(userId) 監看雲端狀態（家長端/同端顯示）
// ======================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'notification_service.dart';

class SOSService extends ChangeNotifier {
  static final SOSService instance = SOSService._internal();
  factory SOSService() => instance;
  SOSService._internal();

  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  bool active = false;
  DateTime? lastTriggered;
  DateTime? lastResolved;
  String? lastEventId;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  // ======================================================
  // 監看雲端 SOS（可用於同一 App 顯示家長/孩子狀態）
  // ======================================================
  void listenRemote(String userId) {
    _sub?.cancel();
    _sub = _fire.collection('sos').doc(userId).snapshots().listen((doc) {
      if (!doc.exists) return;
      final d = doc.data() ?? {};
      active = d['active'] == true;
      lastTriggered = _parseTime(d['lastTriggeredAt']);
      lastResolved = _parseTime(d['lastResolvedAt']);
      lastEventId = d['lastEventId']?.toString();
      notifyListeners();
    });
  }

  Future<void> disposeListener() async {
    await _sub?.cancel();
    _sub = null;
  }

  // ======================================================
  // 觸發 SOS
  // ======================================================
  Future<void> triggerSOS({
    required String userId,
    Map<String, dynamic>? location, // {'lat':..,'lng':..,'acc':..}
    String source = 'app',
  }) async {
    final now = DateTime.now();
    final eventId = 'sos_${now.millisecondsSinceEpoch}';

    active = true;
    lastTriggered = now;
    lastResolved = null;
    lastEventId = eventId;
    notifyListeners();

    // 雲端主狀態
    await _fire.collection('sos').doc(userId).set({
      'active': true,
      'lastTriggeredAt': Timestamp.fromDate(now),
      'lastResolvedAt': null,
      'lastEventId': eventId,
      'lastLocation': location ?? {},
      'source': source,
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    // 事件紀錄
    await _fire.collection('sos').doc(userId).collection('events').doc(eventId).set({
      'eventId': eventId,
      'type': 'trigger',
      'triggeredAt': Timestamp.fromDate(now),
      'location': location ?? {},
      'source': source,
    }, SetOptions(merge: true));

    // 通知中心
    await NotificationService.instance.addNotification(
      type: 'sos',
      title: 'SOS 求救已啟動',
      message: '系統已記錄求救事件，並可通知緊急聯絡人（需雲端推播流程）。',
      icon: Icons.sos,
      payload: {'userId': userId, 'eventId': eventId},
    );

    // 推播給家長/緊急聯絡人：建議 Cloud Functions 觸發（此處保留）
  }

  // ======================================================
  // 取消 SOS
  // ======================================================
  Future<void> cancelSOS({
    required String userId,
    String source = 'app',
  }) async {
    final now = DateTime.now();
    final eventId = lastEventId ?? 'sos_${now.millisecondsSinceEpoch}';

    active = false;
    lastResolved = now;
    notifyListeners();

    await _fire.collection('sos').doc(userId).set({
      'active': false,
      'lastResolvedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    await _fire
        .collection('sos')
        .doc(userId)
        .collection('events')
        .doc('res_${now.millisecondsSinceEpoch}')
        .set({
      'eventId': eventId,
      'type': 'cancel',
      'resolvedAt': Timestamp.fromDate(now),
      'source': source,
    }, SetOptions(merge: true));

    await NotificationService.instance.addNotification(
      type: 'sos',
      title: 'SOS 已解除',
      message: '求救狀態已解除並同步至雲端。',
      icon: Icons.check_circle_outline,
      payload: {'userId': userId, 'eventId': eventId},
    );
  }

  DateTime? _parseTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

// lib/services/sos_service.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'notification_service.dart';

class SOSService extends ChangeNotifier {
  static final SOSService instance = SOSService._internal();
  SOSService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _initialized = false;

  bool _active = false;
  bool get active => _active;

  bool _sending = false;
  bool get sending => _sending;

  void init() {
    if (_initialized) return;
    _initialized = true;
  }

  /// ✅ 舊版相容：member_page 用 triggerSOS
  Future<void> triggerSOS({required String reason}) async {
    if (_sending) return;
    _sending = true;
    _active = true;
    notifyListeners();

    try {
      final u = _auth.currentUser;

      await NotificationService.instance.addNotification(
        type: 'sos',
        title: 'SOS 求助已啟動',
        message: u == null ? '（未登入）求助原因：$reason' : '使用者 ${u.uid} 求助原因：$reason',
        icon: Icons.sos_rounded,
        data: {'reason': reason, 'uid': u?.uid},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌[SOSService] triggerSOS failed: $e');
      await NotificationService.instance.addNotification(
        type: 'sos',
        title: 'SOS 求助失敗',
        message: '原因：$e',
        icon: Icons.error_outline,
        pushToFirestore: false,
      );
      _active = false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// ✅ 舊版相容：member_page 用 cancelSOS
  Future<void> cancelSOS() async {
    if (!_active) return;
    _active = false;
    notifyListeners();

    try {
      await NotificationService.instance.addNotification(
        type: 'sos',
        title: '已取消 SOS',
        message: '求助狀態已關閉',
        icon: Icons.check_circle_outline,
        pushToFirestore: false,
      );
    } catch (_) {}
  }

  /// ✅ 你自己若要用新命名也可
  Future<void> sendSOS({required String reason}) => triggerSOS(reason: reason);
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_center_config.dart';

class AppCenterConfigService {
  AppCenterConfigService() {
    _start();
  }

  final StreamController<AppCenterConfig> _controller =
      StreamController<AppCenterConfig>.broadcast();

  Stream<AppCenterConfig> get stream => _controller.stream;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  void _start() {
    // ✅ 先送 defaults，UI 不會空
    _safeAdd(AppCenterConfig.defaults());

    final doc =
        FirebaseFirestore.instance.collection('app_config').doc('app_center');

    // ✅ 監聽 snapshots：錯誤吞掉、改送 defaults（避免 web internal assertion）
    _sub = doc.snapshots().listen(
      (snap) {
        final data = snap.data();
        if (data == null) {
          _safeAdd(AppCenterConfig.defaults());
          return;
        }
        try {
          _safeAdd(AppCenterConfig.fromMap(data));
        } catch (e, st) {
          debugPrint('❌[AppCenterConfigService] fromMap error: $e');
          debugPrint('$st');
          _safeAdd(AppCenterConfig.defaults());
        }
      },
      onError: (e, st) {
        debugPrint('❌[AppCenterConfigService] snapshots error: $e');
        debugPrint('$st');
        _safeAdd(AppCenterConfig.defaults());
      },
      cancelOnError: false,
    );
  }

  void _safeAdd(AppCenterConfig cfg) {
    if (_controller.isClosed) return;
    _controller.add(cfg);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}

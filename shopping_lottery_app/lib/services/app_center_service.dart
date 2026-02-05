import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_center_config.dart';

class AppCenterService extends ChangeNotifier {
  AppCenterService._();
  static final AppCenterService instance = AppCenterService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('app_center');

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  bool _initialized = false;
  bool get initialized => _initialized;

  Object? _lastError;
  Object? get lastError => _lastError;

  bool _exists = true;
  bool get exists => _exists;

  AppCenterConfig _config = AppCenterConfig.defaults();
  AppCenterConfig get config => _config;

  // 常用 getter（前台 UI 直接用）
  bool get shopHomeEnabled => _config.shopHomeEnabled;
  bool get bannerEnabled => _config.bannerEnabled;
  bool get bottomNavEnabled => _config.bottomNavEnabled;
  bool get featureToggleEnabled => _config.featureToggleEnabled;
  bool get sosHealthEnabled => _config.sosHealthEnabled;
  bool get deviceMgmtEnabled => _config.deviceMgmtEnabled;

  /// ✅ 呼叫一次即可：開始監聽 Firestore 設定
  void init() {
    if (_sub != null) return; // 避免重複監聽（熱重載常見）
    _sub = _ref.snapshots().listen(
      (doc) {
        _exists = doc.exists;
        final raw = doc.data();
        if (raw == null) {
          _config = AppCenterConfig.defaults();
        } else {
          _config = AppCenterConfig.fromMap(raw);
        }
        _lastError = null;
        _initialized = true;
        notifyListeners();
      },
      onError: (e) {
        _lastError = e;
        _initialized = true; // 讓 UI 能顯示錯誤狀態
        notifyListeners();
      },
    );
  }

  ///（前台通常不必呼叫）停止監聽
  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// ✅ 前台可用：快速拉一次最新設定（不靠 stream 時也能用）
  Future<AppCenterConfig> fetchOnce() async {
    try {
      final doc = await _ref.get();
      _exists = doc.exists;
      final raw = doc.data();
      final cfg =
          raw == null ? AppCenterConfig.defaults() : AppCenterConfig.fromMap(raw);

      _config = cfg;
      _lastError = null;
      _initialized = true;
      notifyListeners();
      return cfg;
    } catch (e) {
      _lastError = e;
      _initialized = true;
      notifyListeners();
      rethrow;
    }
  }

  ///（可選）如果你希望「不存在就建立預設」，可在後台或開發期使用
  Future<void> ensureExists({String updatedBy = ''}) async {
    final doc = await _ref.get();
    if (doc.exists) return;

    await _ref.set({
      ...AppCenterConfig.defaults().toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    }, SetOptions(merge: true));
  }

  ///（可選）提供前台/後台共用 patch 寫入（注意：前台通常不建議寫）
  Future<void> patch(Map<String, dynamic> patch, {String updatedBy = ''}) async {
    await _ref.set({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    }, SetOptions(merge: true));
  }
}

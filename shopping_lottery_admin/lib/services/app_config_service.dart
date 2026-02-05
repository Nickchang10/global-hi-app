// lib/services/app_config_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// 全站 App 設定（後台可調）
/// Firestore 路徑：app_config/global
class AppConfigService {
  final FirebaseFirestore _db;

  AppConfigService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('global');

  /// 即時監聽設定（可能為 null：若 doc 尚未建立）
  Stream<Map<String, dynamic>?> streamConfig() {
    return _ref.snapshots().map((snap) => snap.data());
  }

  /// 讀取一次設定（可能為 null：若 doc 尚未建立）
  Future<Map<String, dynamic>?> getConfig() async {
    final snap = await _ref.get();
    return snap.data();
  }

  /// 更新設定（merge），並自動寫入 lastUpdate
  Future<void> updateConfig(Map<String, dynamic> data) async {
    await _ref.set(
      {
        ...data,
        'lastUpdate': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// 若 app_config/global 不存在，建立預設值
  Future<void> ensureDefaultConfig() async {
    final snap = await _ref.get();
    if (snap.exists) return;

    await _ref.set({
      'version': '1.0.0',
      'updateNote': '初始版本',
      'supportUrl': 'https://osmile.com/support',
      'maintenanceMode': false,
      'bannerText': '',
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }
}

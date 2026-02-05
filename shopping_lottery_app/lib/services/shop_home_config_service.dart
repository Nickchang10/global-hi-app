// lib/services/shop_home_config_service.dart
//
// ✅ ShopHomeConfigService（商城首頁設定讀取｜完整版｜可編譯）
// ------------------------------------------------------------
// Firestore：shop_config/home
// - watchHomeConfig(): 監聽並回傳 ShopHomeConfig
// - doc 不存在：回傳 ShopHomeConfig.empty()，避免前台爆掉
// - 容錯：data 為 null 時也回空
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shop_home_config.dart';

class ShopHomeConfigService {
  ShopHomeConfigService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('shop_config').doc('home');

  /// 監聽商城首頁設定
  Stream<ShopHomeConfig> watchHomeConfig() {
    return _ref.snapshots().map((doc) {
      if (!doc.exists) return ShopHomeConfig.empty();

      final data = doc.data();
      if (data == null) return ShopHomeConfig.empty();

      return ShopHomeConfig.fromDoc(data);
    });
  }

  /// 一次性讀取（有些頁面啟動時想先 await）
  Future<ShopHomeConfig> fetchHomeConfig() async {
    final doc = await _ref.get();
    if (!doc.exists) return ShopHomeConfig.empty();

    final data = doc.data();
    if (data == null) return ShopHomeConfig.empty();

    return ShopHomeConfig.fromDoc(data);
  }
}

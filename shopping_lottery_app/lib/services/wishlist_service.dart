// lib/services/wishlist_service.dart
// ======================================================
// ✅ WishlistService（收藏清單服務 - Provider 版｜完整版）
// ------------------------------------------------------
// 功能：
// - 永續儲存至 SharedPreferences
// - 新增 / 移除 / 切換收藏狀態 (toggle)
// - 提供 safeCopy() 給購物車共用
// - 支援 Provider 監聽（即時刷新 UI）
// - 向後相容舊版 getWishlistIds() / clear()
// ======================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WishlistService extends ChangeNotifier {
  // --------------------------------------------------
  // ✅ Singleton
  // --------------------------------------------------
  static final WishlistService instance = WishlistService._internal();
  factory WishlistService() => instance;
  WishlistService._internal();

  // --------------------------------------------------
  // ✅ SharedPreferences keys
  // --------------------------------------------------
  static const String _keyIds = 'wishlist_items';
  static const String _keyData = 'wishlist_data';

  // --------------------------------------------------
  // ✅ 內部狀態
  // --------------------------------------------------
  final List<String> _ids = [];
  final List<Map<String, String>> _items = [];

  // --------------------------------------------------
  // ✅ 公開 getter（for UI & 兼容舊版頁面）
  // --------------------------------------------------
  List<String> get ids => List.unmodifiable(_ids);
  List<Map<String, String>> get items => List.unmodifiable(_items);

  // 與 wishlist_page.dart 相容
  List<Map<String, String>> get wishlist => items;

  // ======================================================
  // ✅ 初始化（從 SharedPreferences 載入資料）
  // ======================================================
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1️⃣ 載入 id 清單
    _ids
      ..clear()
      ..addAll(prefs.getStringList(_keyIds) ?? []);

    // 2️⃣ 載入商品資料
    final raw = prefs.getStringList(_keyData) ?? [];
    _items
      ..clear()
      ..addAll(raw.map((e) {
        try {
          return Uri.splitQueryString(e);
        } catch (_) {
          return <String, String>{};
        }
      }).where((e) => e.isNotEmpty));

    notifyListeners();
  }

  // ======================================================
  // ✅ 舊版相容方法
  // ======================================================
  Future<List<String>> getWishlistIds() async {
    if (_ids.isEmpty) await init();
    return _ids;
  }

  // ======================================================
  // ✅ 是否已收藏
  // ======================================================
  bool isInWishlist(String id) => _ids.contains(id);

  // ======================================================
  // ✅ 新增收藏
  // ======================================================
  Future<void> addToWishlist(Map<String, dynamic> product) async {
    final prefs = await SharedPreferences.getInstance();
    final id = product['id']?.toString() ?? '';
    if (id.isEmpty) return;

    if (!_ids.contains(id)) _ids.add(id);

    _items.removeWhere((m) => m['id'] == id);
    _items.add({
      'id': id,
      'name': (product['name'] ?? '').toString(),
      'price': (product['price'] ?? '').toString(),
      'image': (product['image'] ?? '').toString(),
      'category': (product['category'] ?? '').toString(),
    });

    await prefs.setStringList(_keyIds, _ids);
    final encoded = _items.map((m) => Uri(queryParameters: m).query).toList();
    await prefs.setStringList(_keyData, encoded);

    notifyListeners();
  }

  // ======================================================
  // ✅ 移除收藏（for UI、舊版 removeItem() 相容）
  // ======================================================
  Future<void> removeFromWishlist(String id) async {
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    _ids.remove(id);
    _items.removeWhere((m) => m['id'] == id);

    await prefs.setStringList(_keyIds, _ids);
    final encoded = _items.map((m) => Uri(queryParameters: m).query).toList();
    await prefs.setStringList(_keyData, encoded);

    notifyListeners();
  }

  // 舊版兼容：removeItem() (非 async 呼叫安全版本)
  void removeItem(String id) {
    removeFromWishlist(id);
  }

  // ======================================================
  // ✅ toggleWishlist（整合 add/remove）
  // ======================================================
  Future<void> toggleWishlist(Map<String, dynamic> product) async {
    final id = product['id']?.toString() ?? '';
    if (id.isEmpty) return;

    if (isInWishlist(id)) {
      await removeFromWishlist(id);
    } else {
      await addToWishlist(product);
    }
  }

  // ======================================================
  // ✅ 清空收藏
  // ======================================================
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIds);
    await prefs.remove(_keyData);
    _ids.clear();
    _items.clear();
    notifyListeners();
  }

  // 舊版別名（for compatibility）
  Future<void> clear() => clearAll();

  // ======================================================
  // ✅ 附加工具
  // ======================================================
  int get count => _ids.length;
  bool get isEmpty => _ids.isEmpty;

  List<Map<String, dynamic>> toProductList() {
    return _items.map((m) {
      return {
        'id': m['id'] ?? '',
        'name': m['name'] ?? '',
        'price': double.tryParse(m['price'] ?? '0') ?? 0,
        'image': m['image'] ?? '',
        'category': m['category'] ?? '',
      };
    }).toList();
  }

  // ======================================================
  // ✅ 與購物車共用的工具方法
  // ======================================================
  Map<String, dynamic> safeCopy(Map<String, dynamic> src,
      {String? id, String? name, double? price}) {
    return {
      ...src,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
    };
  }
}

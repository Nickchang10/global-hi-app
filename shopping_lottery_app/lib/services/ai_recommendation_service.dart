// lib/services/ai_recommendation_service.dart
//
// ✅ AiRecommendationService（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// ✅ 移除 FirestoreMockService.instance（你目前的錯誤來源）
// ✅ 直接使用 FirebaseFirestore.instance / FirebaseAuth.instance
// ✅ 提供：
//    - 取得推薦商品（依使用者行為 + 熱門商品 + 同分類）
//    - 記錄推薦事件（曝光/點擊）
//    - 監聽我的推薦清單（可選）
// ----------------------------------------------------
//
// Firestore 建議結構（可直接用，不會跟你現有衝突）：
// - products/{productId}  （你的商品集合）
// - users/{uid}/events/{eventId}  （使用者事件）
// - users/{uid}/recommendation_logs/{logId} （推薦曝光/點擊記錄）
//
// 需要套件：cloud_firestore, firebase_auth
// ----------------------------------------------------

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductFields {
  static const String name = 'name';
  static const String title = 'title'; // 有些專案用 title
  static const String categoryId = 'categoryId';
  static const String category = 'category'; // 有些專案用 category
  static const String price = 'price';
  static const String currency = 'currency';
  static const String imageUrl = 'imageUrl';
  static const String images = 'images'; // List
  static const String isActive = 'isActive';
  static const String stock = 'stock';
  static const String soldCount = 'soldCount';
  static const String updatedAt = 'updatedAt';
  static const String createdAt = 'createdAt';
}

class RecEventFields {
  static const String type = 'type'; // impression / click
  static const String placement = 'placement'; // home / product / checkout...
  static const String productId = 'productId';
  static const String source = 'source'; // e.g. "ai_reco"
  static const String data = 'data';
  static const String createdAt = 'createdAt';
}

class SimpleProduct {
  final String id;
  final String name;
  final String? category;
  final num? price;
  final String currency;
  final String? imageUrl;
  final bool isActive;
  final int? stock;
  final int? soldCount;

  final Map<String, dynamic> raw;

  const SimpleProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.currency,
    required this.imageUrl,
    required this.isActive,
    required this.stock,
    required this.soldCount,
    required this.raw,
  });

  static num? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String? _pickImage(dynamic data) {
    if (data is String && data.trim().isNotEmpty) return data.trim();
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
    }
    return null;
  }

  factory SimpleProduct.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data() ?? <String, dynamic>{};

    final name = (d[ProductFields.name] ?? d[ProductFields.title] ?? '商品')
        .toString();
    final category = (d[ProductFields.categoryId] ?? d[ProductFields.category])
        ?.toString();
    final price = _toNum(d[ProductFields.price]);
    final currency = (d[ProductFields.currency] ?? 'TWD').toString();

    final image =
        _pickImage(d[ProductFields.imageUrl]) ??
        _pickImage(d[ProductFields.images]);

    final isActive = d[ProductFields.isActive] == null
        ? true
        : (d[ProductFields.isActive] == true);
    final stock = _toInt(d[ProductFields.stock]);
    final soldCount = _toInt(d[ProductFields.soldCount]);

    return SimpleProduct(
      id: snap.id,
      name: name,
      category: category,
      price: price,
      currency: currency,
      imageUrl: image,
      isActive: isActive,
      stock: stock,
      soldCount: soldCount,
      raw: Map<String, dynamic>.from(d),
    );
  }
}

class AiRecommendationService {
  AiRecommendationService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static final AiRecommendationService instance = AiRecommendationService._();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _productsCol =>
      _db.collection('products');

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _eventsCol(String uid) =>
      _userRef(uid).collection('events');

  CollectionReference<Map<String, dynamic>> _recoLogsCol(String uid) =>
      _userRef(uid).collection('recommendation_logs');

  /// ✅ 取得推薦商品（可直接用在首頁「為你推薦」、商品頁「你可能也喜歡」）
  ///
  /// 推薦策略（可跑、可擴充）：
  /// 1) 取使用者最近互動的商品分類（events 裡的 view/click/purchase）
  /// 2) 以該分類抓商品（同分類推薦）
  /// 3) 不足時補熱門（soldCount 高 / updatedAt 新）
  Future<List<SimpleProduct>> getRecommendations({
    int limit = 10,
    String placement = 'home',
    String? seedCategory,
  }) async {
    final uid = _uid;

    // 未登入：直接給熱門商品
    if (uid == null) {
      return _getTrendingProducts(limit: limit);
    }

    // 先試著找出最近互動分類
    final category = seedCategory ?? await _guessTopCategory(uid);

    final results = <SimpleProduct>[];

    if (category != null && category.trim().isNotEmpty) {
      final sameCat = await _getProductsByCategory(
        category: category.trim(),
        limit: limit,
      );
      results.addAll(sameCat);
    }

    // 不夠補熱門
    if (results.length < limit) {
      final more = await _getTrendingProducts(limit: limit - results.length);
      results.addAll(more);
    }

    // 去重（以 id）
    final unique = <String, SimpleProduct>{};
    for (final p in results) {
      unique[p.id] = p;
    }

    final list = unique.values.take(limit).toList(growable: false);

    // ✅ 記錄曝光
    await trackImpression(
      placement: placement,
      productIds: list.map((e) => e.id).toList(),
      source: 'ai_reco',
      data: {'seedCategory': category, 'limit': limit},
    );

    return list;
  }

  /// ✅ 商品頁：你可能也喜歡（同分類 + 熱門補齊，並排除自己）
  Future<List<SimpleProduct>> getSimilarProducts({
    required String productId,
    String? category,
    int limit = 8,
    String placement = 'product',
  }) async {
    final uid = _uid;

    final cat = category ?? await _getProductCategory(productId);

    final results = <SimpleProduct>[];

    if (cat != null && cat.trim().isNotEmpty) {
      final sameCat = await _getProductsByCategory(
        category: cat.trim(),
        limit: limit + 4,
      );
      results.addAll(sameCat.where((p) => p.id != productId));
    }

    if (results.length < limit) {
      final more = await _getTrendingProducts(
        limit: (limit - results.length) + 4,
      );
      results.addAll(more.where((p) => p.id != productId));
    }

    // 去重 + 截斷
    final unique = <String, SimpleProduct>{};
    for (final p in results) {
      unique[p.id] = p;
    }
    final list = unique.values.take(limit).toList(growable: false);

    // 曝光紀錄
    if (uid != null) {
      await trackImpression(
        placement: placement,
        productIds: list.map((e) => e.id).toList(),
        source: 'ai_reco',
        data: {'seedProductId': productId, 'seedCategory': cat, 'limit': limit},
      );
    }

    return list;
  }

  // ---------- Tracking ----------

  /// ✅ 推薦曝光紀錄（一次記一批 ids）
  Future<void> trackImpression({
    required String placement,
    required List<String> productIds,
    String source = 'ai_reco',
    Map<String, dynamic>? data,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    await _recoLogsCol(uid).add({
      RecEventFields.type: 'impression',
      RecEventFields.placement: placement,
      RecEventFields.source: source,
      RecEventFields.data: {'productIds': productIds, ...?data},
      RecEventFields.createdAt: FieldValue.serverTimestamp(),
    });
  }

  /// ✅ 點擊紀錄（使用者點了某推薦商品）
  Future<void> trackClick({
    required String placement,
    required String productId,
    String source = 'ai_reco',
    Map<String, dynamic>? data,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    await _recoLogsCol(uid).add({
      RecEventFields.type: 'click',
      RecEventFields.placement: placement,
      RecEventFields.productId: productId,
      RecEventFields.source: source,
      RecEventFields.data: data ?? <String, dynamic>{},
      RecEventFields.createdAt: FieldValue.serverTimestamp(),
    });
  }

  // ---------- Internals (Queries) ----------

  Future<List<SimpleProduct>> _getProductsByCategory({
    required String category,
    required int limit,
  }) async {
    try {
      // 相容 categoryId / category 兩種欄位
      final snap1 = await _productsCol
          .where(ProductFields.isActive, isEqualTo: true)
          .where(ProductFields.categoryId, isEqualTo: category)
          .limit(limit)
          .get();

      if (snap1.docs.isNotEmpty) {
        return snap1.docs
            .map((d) => SimpleProduct.fromSnap(d))
            .toList(growable: false);
      }

      final snap2 = await _productsCol
          .where(ProductFields.isActive, isEqualTo: true)
          .where(ProductFields.category, isEqualTo: category)
          .limit(limit)
          .get();

      return snap2.docs
          .map((d) => SimpleProduct.fromSnap(d))
          .toList(growable: false);
    } catch (_) {
      // 若索引/欄位不同導致 where 報錯，退而求其次：抓少量熱門再本地過濾
      final fallback = await _getTrendingProducts(limit: max(limit, 20));
      return fallback
          .where((p) => (p.category ?? '') == category)
          .take(limit)
          .toList(growable: false);
    }
  }

  Future<List<SimpleProduct>> _getTrendingProducts({required int limit}) async {
    try {
      // 若你 products 沒 soldCount 欄位，這段可能會出索引錯誤，catch 後會走 updatedAt
      final snap = await _productsCol
          .where(ProductFields.isActive, isEqualTo: true)
          .orderBy(ProductFields.soldCount, descending: true)
          .limit(limit)
          .get();

      return snap.docs
          .map((d) => SimpleProduct.fromSnap(d))
          .toList(growable: false);
    } catch (_) {
      try {
        final snap = await _productsCol
            .where(ProductFields.isActive, isEqualTo: true)
            .orderBy(ProductFields.updatedAt, descending: true)
            .limit(limit)
            .get();

        return snap.docs
            .map((d) => SimpleProduct.fromSnap(d))
            .toList(growable: false);
      } catch (_) {
        // 最後備援：不排序直接抓
        final snap = await _productsCol.limit(limit).get();
        return snap.docs
            .map((d) => SimpleProduct.fromSnap(d))
            .toList(growable: false);
      }
    }
  }

  Future<String?> _guessTopCategory(String uid) async {
    // 你 events 若尚未建立，也沒關係：回 null -> fallback to trending
    try {
      final snap = await _eventsCol(
        uid,
      ).orderBy('createdAt', descending: true).limit(30).get();

      final counts = <String, int>{};

      for (final d in snap.docs) {
        final data = d.data();
        final cat = (data['categoryId'] ?? data['category'])?.toString();
        if (cat == null || cat.trim().isEmpty) continue;
        counts[cat] = (counts[cat] ?? 0) + 1;
      }

      if (counts.isEmpty) return null;

      // 取最高
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.first.key;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getProductCategory(String productId) async {
    try {
      final snap = await _productsCol.doc(productId).get();
      if (!snap.exists) return null;
      final d = snap.data() ?? <String, dynamic>{};
      return (d[ProductFields.categoryId] ?? d[ProductFields.category])
          ?.toString();
    } catch (_) {
      return null;
    }
  }
}

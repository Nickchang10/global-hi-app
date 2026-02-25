import 'dart:math';
import 'package:flutter/foundation.dart';

import 'firestore_mock_service.dart';

/// ✅ RecommendationService（推薦服務｜完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - ❌ 不使用 FirestoreMockService.instance（你的 mock 沒有 singleton）
/// - ✅ 改為可注入 store，預設 FirestoreMockService()
/// - ✅ 自動 fallback：fetchProducts / getMockProducts / products getter / demo data
/// - ✅ 提供多個常用 API，減少其他頁面整合時出錯
/// ------------------------------------------------------------
class RecommendationService extends ChangeNotifier {
  RecommendationService({FirestoreMockService? store})
    : _store = store ?? FirestoreMockService();

  /// 你其他地方若習慣用 RecommendationService.instance 也可以
  static final RecommendationService instance = RecommendationService();

  final FirestoreMockService _store;

  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  // ------------------------------------------------------------
  // Public APIs
  // ------------------------------------------------------------

  /// 取得全部商品（盡量向 mock 拿，拿不到就用 demo）
  Future<List<Map<String, dynamic>>> fetchAllProducts() async {
    _setLoading(true);
    _error = null;
    try {
      final list = await _tryFetchProductsFromMock();
      return list.isNotEmpty ? list : _demoProducts();
    } catch (e) {
      _error = e.toString();
      return _demoProducts();
    } finally {
      _setLoading(false);
    }
  }

  /// ✅ 產生推薦（依 uid 做「可重現」的隨機排序；也可指定 category）
  Future<List<Map<String, dynamic>>> recommend({
    String? uid,
    int limit = 10,
    String? category,
  }) async {
    final products = await fetchAllProducts();

    final filtered = category == null || category.trim().isEmpty
        ? products
        : products.where((p) {
            final c = (p['category'] ?? '').toString().toLowerCase();
            return c == category.trim().toLowerCase();
          }).toList();

    if (filtered.isEmpty) return products.take(limit).toList();

    // 用 uid 決定 seed，確保同一 uid 推薦結果可重現
    final seed = _stableHash(uid ?? 'guest');
    final rng = Random(seed);

    // 分數：rating + sold + 隨機微擾
    final scored = filtered.map((p) {
      final rating = _toDouble(p['rating']);
      final sold = _toDouble(p['soldCount']);
      final price = _toDouble(p['price']);
      final boost = rng.nextDouble() * 0.15; // 小幅隨機
      final score =
          rating * 2.0 +
          log(1 + sold) * 1.2 +
          boost -
          (price > 0 ? log(1 + price) * 0.05 : 0);
      return MapEntry(p, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit.clamp(1, 100)).map((e) => e.key).toList();
  }

  /// ✅ 依關鍵字搜尋（name/title/desc）
  Future<List<Map<String, dynamic>>> search(
    String keyword, {
    int limit = 30,
  }) async {
    final q = keyword.trim().toLowerCase();
    final products = await fetchAllProducts();
    if (q.isEmpty) return products.take(limit).toList();

    final hits = products.where((p) {
      final name = (p['name'] ?? p['title'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final cat = (p['category'] ?? '').toString().toLowerCase();
      return name.contains(q) || desc.contains(q) || cat.contains(q);
    }).toList();

    return hits.take(limit.clamp(1, 200)).toList();
  }

  /// ✅ 依已看過商品 ids 推薦（簡化版：優先同類別）
  Future<List<Map<String, dynamic>>> recommendFromViewed({
    required List<String> viewedProductIds,
    String? uid,
    int limit = 10,
  }) async {
    final products = await fetchAllProducts();
    final viewedSet = viewedProductIds.map((e) => e.toLowerCase()).toSet();

    final viewed = products.where((p) {
      final id = (p['id'] ?? '').toString().toLowerCase();
      return viewedSet.contains(id);
    }).toList();

    // 找出已看過的主要類別
    final cats = <String, int>{};
    for (final p in viewed) {
      final c = (p['category'] ?? '').toString().toLowerCase();
      if (c.isEmpty) continue;
      cats[c] = (cats[c] ?? 0) + 1;
    }

    String? topCat;
    if (cats.isNotEmpty) {
      final sorted = cats.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topCat = sorted.first.key;
    }

    // 先推同類別（排除已看過）
    final candidates = products.where((p) {
      final id = (p['id'] ?? '').toString().toLowerCase();
      if (viewedSet.contains(id)) return false;
      if (topCat == null) return true;
      return (p['category'] ?? '').toString().toLowerCase() == topCat;
    }).toList();

    // 再用 recommend 做排序
    final rec = await recommend(uid: uid, limit: limit, category: topCat);
    if (rec.isNotEmpty) return rec;

    return candidates.take(limit).toList();
  }

  // ------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _tryFetchProductsFromMock() async {
    final d = _store as dynamic;

    // 1) fetchProducts()
    try {
      final r = d.fetchProducts();
      final v = r is Future ? await r : r;
      final list = _normalizeList(v);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    // 2) getMockProducts()
    try {
      final r = d.getMockProducts();
      final v = r is Future ? await r : r;
      final list = _normalizeList(v);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    // 3) products getter
    try {
      final v = d.products;
      final list = _normalizeList(v);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    return const [];
  }

  List<Map<String, dynamic>> _normalizeList(dynamic v) {
    if (v is List<Map<String, dynamic>>) return v;
    if (v is List) {
      return v
          .map((e) {
            if (e is Map<String, dynamic>) return e;
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          })
          .where((m) => m.isNotEmpty)
          .toList();
    }
    return const [];
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  int _stableHash(String s) {
    // 簡單可重現 hash
    var h = 0;
    for (final code in s.codeUnits) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    return h;
  }

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  List<Map<String, dynamic>> _demoProducts() {
    // fallback demo，避免 mock 沒資料時整個 UI 空白
    return [
      {
        'id': 'p_ed1000',
        'name': 'ED1000 智慧手錶',
        'category': 'watch',
        'price': 2990,
        'rating': 4.7,
        'soldCount': 1200,
        'imageUrl': '',
        'description': '主推款：SOS / 健康 / 通話',
      },
      {
        'id': 'p_band_01',
        'name': '健康手環 Pro',
        'category': 'health',
        'price': 1590,
        'rating': 4.5,
        'soldCount': 860,
        'imageUrl': '',
        'description': '心率/血氧/睡眠監測',
      },
      {
        'id': 'p_acc_01',
        'name': '充電底座',
        'category': 'accessory',
        'price': 390,
        'rating': 4.2,
        'soldCount': 520,
        'imageUrl': '',
        'description': '磁吸式快充底座',
      },
      {
        'id': 'p_sim_01',
        'name': '大哥大 SIM 方案',
        'category': 'sim',
        'price': 199,
        'rating': 4.0,
        'soldCount': 430,
        'imageUrl': '',
        'description': '展場常用：需確認是否儲值',
      },
    ];
  }
}

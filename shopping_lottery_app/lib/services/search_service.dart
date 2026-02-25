import 'package:flutter/foundation.dart';

import 'firestore_mock_service.dart';

/// ✅ SearchService（搜尋服務｜完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - ❌ 不使用 FirestoreMockService.instance（你的 mock 沒有 singleton）
/// - ✅ 改為可注入 store，預設 FirestoreMockService()
/// - ✅ 自動 fallback：fetchProducts / getMockProducts / products getter / demo data
/// - ✅ 提供常用搜尋 API：searchProducts、searchAll（同樣回傳 List<Map>）
/// ------------------------------------------------------------
class SearchService extends ChangeNotifier {
  SearchService({FirestoreMockService? store})
    : _store = store ?? FirestoreMockService();

  /// 如果其他頁面習慣用 SearchService.instance，這裡也提供
  static final SearchService instance = SearchService();

  final FirestoreMockService _store;

  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  // ============================================================
  // Public APIs
  // ============================================================

  /// ✅ 商品搜尋（name/title/description/category/id）
  Future<List<Map<String, dynamic>>> searchProducts(
    String keyword, {
    int limit = 50,
  }) async {
    final q = keyword.trim().toLowerCase();
    final products = await _fetchAllProducts();

    if (q.isEmpty) return products.take(limit.clamp(1, 200)).toList();

    final hits = products.where((p) {
      final id = (p['id'] ?? '').toString().toLowerCase();
      final name = (p['name'] ?? p['title'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final cat = (p['category'] ?? '').toString().toLowerCase();
      return id.contains(q) ||
          name.contains(q) ||
          desc.contains(q) ||
          cat.contains(q);
    }).toList();

    // 簡單排序：名稱命中優先、再看 rating / soldCount
    hits.sort((a, b) {
      final aName = (a['name'] ?? a['title'] ?? '').toString().toLowerCase();
      final bName = (b['name'] ?? b['title'] ?? '').toString().toLowerCase();

      final aNameHit = aName.contains(q) ? 1 : 0;
      final bNameHit = bName.contains(q) ? 1 : 0;
      if (aNameHit != bNameHit) return bNameHit.compareTo(aNameHit);

      final ar = _toDouble(a['rating']);
      final br = _toDouble(b['rating']);
      if (ar != br) return br.compareTo(ar);

      final asold = _toDouble(a['soldCount']);
      final bsold = _toDouble(b['soldCount']);
      return bsold.compareTo(asold);
    });

    return hits.take(limit.clamp(1, 200)).toList();
  }

  /// ✅ 全域搜尋（目前先聚焦 products；未來你要擴充 coupons/posts/users 再加）
  /// 為了讓現有頁面先跑起來，回傳格式保持 List<Map>
  Future<List<Map<String, dynamic>>> searchAll(
    String keyword, {
    int limit = 60,
  }) async {
    // 目前：直接回傳 products 搜尋結果（先解編譯/先可用）
    return searchProducts(keyword, limit: limit);
  }

  // ============================================================
  // Internals
  // ============================================================

  Future<List<Map<String, dynamic>>> _fetchAllProducts() async {
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

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
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

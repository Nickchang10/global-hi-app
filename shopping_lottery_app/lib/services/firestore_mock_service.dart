import 'dart:math';
import 'package:flutter/foundation.dart';

/// ✅ FirestoreMockService（最終可用 Mock 版｜含 init / reset｜可編譯）
/// ------------------------------------------------------------
/// 目的：
/// - 先讓整個專案「能編譯」
/// - 提供多頁面常用的 getter / method，避免到處 undefined_method / undefined_getter
///
/// 你可以之後再逐步替換成真 FirestoreService，或讓此 Mock 只在 demo 使用。
class FirestoreMockService extends ChangeNotifier {
  FirestoreMockService._internal();
  static final FirestoreMockService _instance =
      FirestoreMockService._internal();

  factory FirestoreMockService() => _instance;

  bool _inited = false;

  /// 目前登入 uid（mock 用）
  String _currentUid = 'demo_uid';
  String get currentUid => _currentUid;
  set currentUid(String v) {
    _currentUid = v.isEmpty ? 'demo_uid' : v;
    notifyListeners();
  }

  // ---------------------------
  // Mock Data Stores
  // ---------------------------

  final Map<String, int> _pointsByUid = {};
  final Map<String, Map<String, dynamic>> _profileByUid = {};
  final Map<String, List<Map<String, dynamic>>> _couponsByUid = {};
  final Map<String, List<Map<String, dynamic>>> _ordersByUid = {};
  final Map<String, List<Map<String, dynamic>>> _addressesByUid = {};
  final Map<String, List<Map<String, dynamic>>> _notificationsByUid = {};

  final List<Map<String, dynamic>> _products = [];

  // ---------------------------
  // Common Getters (你很多頁面在用)
  // ---------------------------

  /// ✅ 常見錯：getter userPoints 不存在
  int get userPoints => _pointsByUid[_currentUid] ?? 0;

  /// 有些頁面用 points（例如 reward_shop）
  int get points => userPoints;

  /// ✅ 常見錯：getter products 不存在
  List<Map<String, dynamic>> get products => List.unmodifiable(_products);

  /// ✅ 常見錯：getter userCoupons 不存在
  List<Map<String, dynamic>> get userCoupons =>
      List.unmodifiable(_couponsByUid[_currentUid] ?? const []);

  /// ✅ 常見錯：getter orderHistory 不存在
  List<Map<String, dynamic>> get orderHistory =>
      List.unmodifiable(_ordersByUid[_currentUid] ?? const []);

  /// notifications（若你有通知頁會用到）
  List<Map<String, dynamic>> get userNotifications =>
      List.unmodifiable(_notificationsByUid[_currentUid] ?? const []);

  // ---------------------------
  // init / reset
  // ---------------------------

  /// ✅ 你現在 splash_page.dart 卡住的 init()
  Future<void> init({String? uid}) async {
    if (_inited) return;
    _inited = true;

    if (uid != null && uid.isNotEmpty) _currentUid = uid;

    // seed profile
    _profileByUid.putIfAbsent(_currentUid, () {
      return {
        'uid': _currentUid,
        'displayName': 'Demo User',
        'email': 'demo@osmile.com',
        'phone': '09xx-xxx-xxx',
        'role': 'user',
        'createdAt': DateTime.now()
            .subtract(const Duration(days: 30))
            .toIso8601String(),
      };
    });

    // seed points
    _pointsByUid.putIfAbsent(_currentUid, () => 1200);

    // seed products
    if (_products.isEmpty) {
      _products.addAll([
        {
          'id': 'p_watch',
          'name': 'Osmile Watch',
          'price': 2990,
          'imageUrl': '',
          'isActive': true,
          'stock': 99,
        },
        {
          'id': 'p_strap',
          'name': '錶帶配件',
          'price': 390,
          'imageUrl': '',
          'isActive': true,
          'stock': 200,
        },
        {
          'id': 'p_dock',
          'name': '充電底座',
          'price': 490,
          'imageUrl': '',
          'isActive': true,
          'stock': 150,
        },
        {
          'id': 'p_vip',
          'name': '健康服務月費',
          'price': 199,
          'imageUrl': '',
          'isActive': true,
          'stock': 9999,
        },
      ]);
    }

    // seed coupons
    _couponsByUid.putIfAbsent(_currentUid, () {
      return [
        {
          'id': 'c_10off',
          'title': '全館 9 折券',
          'discountType': 'percent',
          'value': 10,
          'isUsed': false,
          'expireAt': DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String(),
        },
      ];
    });

    // seed orders
    _ordersByUid.putIfAbsent(_currentUid, () {
      return [
        {
          'id': 'o_10001',
          'status': 'paid',
          'total': 2990,
          'createdAt': DateTime.now()
              .subtract(const Duration(days: 3))
              .toIso8601String(),
          'items': [
            {'id': 'p_watch', 'name': 'Osmile Watch', 'price': 2990, 'qty': 1},
          ],
        },
      ];
    });

    // seed addresses
    _addressesByUid.putIfAbsent(_currentUid, () {
      return [
        {
          'id': 'a_1',
          'name': '家',
          'receiver': 'Demo User',
          'phone': '09xx-xxx-xxx',
          'zip': '100',
          'city': '台北市',
          'district': '中正區',
          'detail': '忠孝西路一段 1 號',
          'isDefault': true,
        },
      ];
    });

    // seed notifications
    _notificationsByUid.putIfAbsent(_currentUid, () {
      return [
        {
          'id': 'n_welcome',
          'title': '歡迎使用 Osmile',
          'body': '已為你建立示範資料。',
          'type': 'system',
          'createdAt': DateTime.now().toIso8601String(),
          'read': false,
        },
      ];
    });

    notifyListeners();
  }

  /// ✅ 常見錯：settings_page.dart 用 reset()
  Future<void> reset() async {
    _inited = false;
    _pointsByUid.clear();
    _profileByUid.clear();
    _couponsByUid.clear();
    _ordersByUid.clear();
    _addressesByUid.clear();
    _notificationsByUid.clear();
    _products.clear();
    await init(uid: _currentUid);
  }

  // ---------------------------
  // Methods used by many pages
  // ---------------------------

  /// ✅ 常見錯：addPoints 不存在
  Future<void> addPoints(String uid, int delta, {String reason = ''}) async {
    final old = _pointsByUid[uid] ?? 0;
    _pointsByUid[uid] = old + delta;

    await addNotification(uid, {
      'title': '點數變動',
      'body':
          '點數 ${delta >= 0 ? '+' : ''}$delta${reason.isNotEmpty ? '（$reason）' : ''}',
      'type': 'points',
    });

    if (uid == _currentUid) notifyListeners();
  }

  /// ✅ 常見錯：addNotification 不存在
  Future<void> addNotification(String uid, Map<String, dynamic> data) async {
    final list = _notificationsByUid.putIfAbsent(uid, () => []);
    list.insert(0, {
      'id':
          'n_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}',
      'title': (data['title'] ?? '通知').toString(),
      'body': (data['body'] ?? '').toString(),
      'type': (data['type'] ?? 'system').toString(),
      'createdAt': DateTime.now().toIso8601String(),
      'read': false,
      ...data,
    });
    if (uid == _currentUid) notifyListeners();
  }

  /// ✅ 常見錯：getMockProducts 不存在（ai_assistant_page 用）
  List<Map<String, dynamic>> getMockProducts() => products;

  /// ✅ 常見錯：fetchProducts 不存在（products_page 用）
  Future<List<Map<String, dynamic>>> fetchProducts() async => products;

  /// ✅ 常見錯：fetchProductById 不存在（favorites_page 用）
  Future<Map<String, dynamic>?> fetchProductById(String id) async {
    try {
      return _products.firstWhere((p) => (p['id'] ?? '') == id);
    } catch (_) {
      return null;
    }
  }

  /// ✅ 常見錯：addProduct 不存在（admin_product_page 用）
  Future<String> addProduct(Map<String, dynamic> product) async {
    final id = (product['id']?.toString().isNotEmpty == true)
        ? product['id'].toString()
        : 'p_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
    _products.add({
      'id': id,
      'name': product['name'] ?? '商品',
      'price': product['price'] ?? 0,
      'imageUrl': product['imageUrl'] ?? '',
      'isActive': product['isActive'] ?? true,
      'stock': product['stock'] ?? 0,
      ...product,
    });
    notifyListeners();
    return id;
  }

  /// ✅ 常見錯：getUserProfile 不存在（profile_edit_page 用）
  Future<Map<String, dynamic>> getUserProfile(String uid) async {
    return _profileByUid.putIfAbsent(uid, () {
      return {
        'uid': uid,
        'displayName': 'User $uid',
        'email': '',
        'phone': '',
        'role': 'user',
        'createdAt': DateTime.now().toIso8601String(),
      };
    });
  }

  /// ✅ 常見錯：demoAddresses 不存在（address_page 用）
  List<Map<String, dynamic>> demoAddresses({String? uid}) {
    final u = (uid == null || uid.isEmpty) ? _currentUid : uid;
    return List.unmodifiable(_addressesByUid[u] ?? const []);
  }

  /// 建立 mock 訂單（有些 debug page 會用）
  Future<Map<String, dynamic>> createMockOrder({
    String? uid,
    List<Map<String, dynamic>>? items,
    num? total,
  }) async {
    final u = (uid == null || uid.isEmpty) ? _currentUid : uid;
    final orderId =
        'o_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
    final order = {
      'id': orderId,
      'status': 'paid',
      'total': total ?? 0,
      'createdAt': DateTime.now().toIso8601String(),
      'items': items ?? const [],
    };
    final list = _ordersByUid.putIfAbsent(u, () => []);
    list.insert(0, order);
    if (u == _currentUid) notifyListeners();
    return order;
  }
}

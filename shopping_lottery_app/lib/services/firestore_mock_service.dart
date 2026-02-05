// lib/services/firestore_mock_service.dart
// =====================================================
// ✅ FirestoreMockService - 最終完整版（整合 + reset 支援）
// -----------------------------------------------------
// 模擬雲端資料：商品 / 積分 / 抽獎 / 地址 / 付款卡 / 訂單
// - 可與 OrderService、NotificationService、LotteryService 串接
// - 支援 reset() 重置所有假資料（SettingsPage 專用）
// =====================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'order_service.dart';

class FirestoreMockService extends ChangeNotifier {
  // -------------------- Singleton --------------------
  FirestoreMockService._internal();
  static final FirestoreMockService instance = FirestoreMockService._internal();

  bool _initialized = false;

  // -------------------- 模擬資料 --------------------
  final List<Map<String, dynamic>> _products = [];
  int _userPoints = 120;
  int _freeLotteryCount = 0; // 免費抽獎次數
  final List<Map<String, dynamic>> _orders = [];

  // -------------------- Getter --------------------
  List<Map<String, dynamic>> get products => List.unmodifiable(_products);
  int get userPoints => _userPoints;
  int get freeLotteryCount => _freeLotteryCount;
  List<Map<String, dynamic>> get orders => List.unmodifiable(_orders);

  // =====================================================
  // ✅ 初始化
  // =====================================================
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await Future.delayed(const Duration(milliseconds: 200));
    if (_products.isEmpty) _products.addAll(_seedProducts());
    debugPrint('[Mock Firestore] 初始化完成，共 ${_products.length} 筆商品');
    notifyListeners();
  }

  List<Map<String, dynamic>> _seedProducts() {
    return List.generate(8, (i) {
      final id = 'p${i + 1}';
      return {
        'id': id,
        'name': i == 0
            ? 'Osmile S5 健康錶'
            : (i == 1 ? 'Osmile 充電座' : '商品 ${i + 1}'),
        'price': [3990, 490, 199, 1750, 899, 2590, 1200, 450][i % 8],
        'image': 'https://picsum.photos/seed/$id/800/500',
        'description': '示範商品描述：這是 ${i + 1} 號商品。',
        'category': (i % 2 == 0) ? '手錶' : '配件',
        'stock': 20 + i,
      };
    });
  }

  // =====================================================
  // ✅ 相容舊程式：demoProducts()
  // =====================================================
  static List<Map<String, dynamic>> demoProducts() {
    return List.generate(8, (i) {
      final id = 'p${i + 1}';
      return {
        'id': id,
        'name': i == 0
            ? 'Osmile S5 健康錶'
            : (i == 1 ? 'Osmile 充電座' : '商品 ${i + 1}'),
        'price': [3990, 490, 199, 1750, 899, 2590, 1200, 450][i % 8],
        'image': 'https://picsum.photos/seed/$id/800/500',
        'description': '示範商品描述：這是 ${i + 1} 號商品。',
        'category': (i % 2 == 0) ? '手錶' : '配件',
        'stock': 20 + i,
      };
    });
  }

  // =====================================================
  // ✅ 商品查詢
  // =====================================================
  Future<List<Map<String, dynamic>>> fetchProducts({
    int page = 1,
    int limit = 12,
    String? query,
    String? category,
  }) async {
    if (_products.isEmpty) _products.addAll(_seedProducts());
    await Future.delayed(const Duration(milliseconds: 100));

    final filtered = _products.where((p) {
      if (category != null && category.isNotEmpty) {
        final cat = (p['category'] ?? '').toString().toLowerCase();
        if (cat != category.toLowerCase()) return false;
      }
      if (query != null && query.isNotEmpty) {
        final text =
            '${p['name'] ?? ''} ${p['description'] ?? ''}'.toLowerCase();
        if (!text.contains(query.toLowerCase())) return false;
      }
      return true;
    }).toList();

    final start = (page - 1) * limit;
    final end = (start + limit).clamp(0, filtered.length);
    if (start >= filtered.length) return [];

    return filtered
        .sublist(start, end)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic>? fetchProductById(String id) {
    if (_products.isEmpty) _products.addAll(_seedProducts());
    try {
      final p = _products.firstWhere((e) => e['id'] == id);
      return Map<String, dynamic>.from(p);
    } catch (_) {
      try {
        final p = demoProducts().firstWhere((e) => e['id'] == id);
        return Map<String, dynamic>.from(p);
      } catch (_) {
        return null;
      }
    }
  }

  // =====================================================
  // ✅ 積分系統
  // =====================================================
  Future<int> getPoints([String? userId]) async {
    await Future.delayed(const Duration(milliseconds: 80));
    return _userPoints;
  }

  Future<bool> spendPoints(int amount, {String userId = 'demo_user'}) async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (_userPoints >= amount) {
      _userPoints -= amount;
      debugPrint('[Mock Firestore] spendPoints: -$amount => $_userPoints');
      notifyListeners();
      return true;
    }
    debugPrint('[Mock Firestore] spendPoints FAILED: need $amount, has $_userPoints');
    return false;
  }

  Future<void> addPoints(int amount, {String userId = 'demo_user'}) async {
    await Future.delayed(const Duration(milliseconds: 80));
    _userPoints += amount;
    debugPrint('[Mock Firestore] addPoints: +$amount => $_userPoints');
    notifyListeners();
  }

  Future<void> setPoints(String userId, int points) async {
    await Future.delayed(const Duration(milliseconds: 80));
    _userPoints = points.clamp(0, 999999);
    debugPrint('[Mock Firestore] setPoints($userId): $_userPoints');
    notifyListeners();
  }

  Future<void> deductPoints(int amount, {String userId = 'demo_user'}) async {
    await Future.delayed(const Duration(milliseconds: 80));
    _userPoints = (_userPoints - amount).clamp(0, 999999);
    debugPrint('[Mock Firestore] deductPoints($userId): -$amount => $_userPoints');
    notifyListeners();
  }

  // =====================================================
  // ✅ 抽獎邏輯
  // =====================================================
  Future<void> addFreeLotteryChance([int count = 1]) async {
    _freeLotteryCount += count;
    debugPrint('[Mock Firestore] addFreeLotteryChance: +$count => $_freeLotteryCount');
    notifyListeners();
  }

  Future<void> useFreeLotteryChance() async {
    if (_freeLotteryCount > 0) {
      _freeLotteryCount -= 1;
      debugPrint('[Mock Firestore] useFreeLotteryChance => $_freeLotteryCount');
      notifyListeners();
    }
  }

  // =====================================================
  // ✅ 購買整合流程
  // =====================================================
  Future<void> handlePurchase({
    required String userId,
    required double amount,
  }) async {
    final notification = NotificationService.instance;
    final orderService = OrderService.instance;

    // 建立訂單
    await orderService.createOrder(
      items: [
        {'productId': 'auto', 'name': '商城購物', 'qty': 1, 'price': amount}
      ],
      total: amount,
    );

    notification.addNotification(
      type: 'shop',
      title: '訂單已成立',
      message: '成功購買商品 NT\$${amount.toStringAsFixed(0)}',
      icon: Icons.shopping_cart_checkout,
    );

    // 消費回饋
    final rewardPoints = (amount ~/ 100) * 10;
    if (rewardPoints > 0) {
      await addPoints(rewardPoints);
      notification.addNotification(
        type: 'shop',
        title: '購物回饋',
        message: '獲得 $rewardPoints 積分！',
        icon: Icons.card_giftcard,
      );
    }

    // 抽獎機會
    if (amount >= 500) {
      await addFreeLotteryChance(1);
      notification.addNotification(
        type: 'lottery',
        title: '抽獎贈送',
        message: '消費滿 NT\$500，獲得 1 次免費抽獎機會！',
        icon: Icons.casino_outlined,
      );
    }

    notifyListeners();
  }

  // =====================================================
  // ✅ Reset（SettingsPage 用）
  // =====================================================
  /// 重置所有假資料、積分、抽獎次數與商品列表。
  Future<void> reset({bool keepProducts = true}) async {
    await Future.delayed(const Duration(milliseconds: 200));

    _userPoints = 120;
    _freeLotteryCount = 0;
    _orders.clear();

    if (!keepProducts) {
      _products
        ..clear()
        ..addAll(_seedProducts());
    }

    debugPrint('[Mock Firestore] reset() 完成：積分 $_userPoints, 免費抽獎 $_freeLotteryCount');
    notifyListeners();
  }

  // =====================================================
  // ✅ 假資料 - demo
  // =====================================================
  static Map<String, dynamic> demoProduct() => {
        'id': 'demo_p1',
        'name': 'Osmile S5 健康錶',
        'price': 3990,
        'image': 'https://picsum.photos/seed/demo_p1/800/500',
        'description': '示範商品：Osmile S5 健康錶（純前端假資料）。',
        'category': '手錶',
        'stock': 99,
        'reviews': [
          {'user': '小明', 'text': '功能很多，CP 值高！', 'rating': 5, 'when': '1 天前'},
          {'user': '小美', 'text': '外觀好看，戴起來很舒服～', 'rating': 4, 'when': '3 小時前'},
        ],
      };

  static List<Map<String, dynamic>> demoAddresses() => [
        {
          'title': '家',
          'name': '王小明',
          'phone': '0912-345-678',
          'fullAddress': '台北市中正區幸福路 123 號',
          'isDefault': true,
        },
        {
          'title': '公司',
          'name': '王小華',
          'phone': '02-1234-5678',
          'fullAddress': '台北市信義區信義路 45 號',
          'isDefault': false,
        },
      ];

  static List<Map<String, dynamic>> demoCards() => [
        {'brand': 'VISA', 'last4': '4242', 'isDefault': true},
        {'brand': 'MasterCard', 'last4': '8888', 'isDefault': false},
      ];
}

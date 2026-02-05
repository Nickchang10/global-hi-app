// lib/services/cart_service.dart
// ======================================================
// ✅ CartService（購物車服務 - 最終整合穩定版）
// ------------------------------------------------------
// - 支援多型 addItem 呼叫：
//    1) addItem({...})          // Map
//    2) addItem(cartItem)       // CartItem
//    3) addItem(product: {...}) // named
//    4) addItem(productId/name/price/qty...) // named
// - updateQty() / updateItem() 均支援
// - operator [] 相容老版本
// - total / totalPrice / totalAmount 相容舊版
// - qty/quantity 欄位兼容
// - 已在 Flutter Web 編譯通過
// ======================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final int qty;
  final String? image;
  final String? category;

  const CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
    this.image,
    this.category,
  });

  double get total => price * qty;

  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    int? qty,
    String? image,
    String? category,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      image: image ?? this.image,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'qty': qty,
        'quantity': qty,
        'image': image ?? '',
        'category': category ?? '',
      };

  factory CartItem.fromMap(Map<String, dynamic> m) {
    final rawQty = m['qty'] ?? m['quantity'] ?? 1;
    final rawPrice = m['price'] ?? 0;

    return CartItem(
      id: (m['id'] ?? m['productId'] ?? '').toString(),
      name: (m['name'] ?? m['title'] ?? '商品').toString(),
      price: (rawPrice is num)
          ? rawPrice.toDouble()
          : double.tryParse('$rawPrice') ?? 0,
      qty: (rawQty is num)
          ? rawQty.toInt()
          : int.tryParse('$rawQty') ?? 1,
      image: (m['image'] ?? m['imageUrl'] ?? m['img'])?.toString(),
      category: m['category']?.toString(),
    );
  }

  dynamic operator [](String key) {
    switch (key) {
      case 'id':
        return id;
      case 'name':
        return name;
      case 'price':
        return price;
      case 'qty':
      case 'quantity':
        return qty;
      case 'image':
      case 'imageUrl':
        return image;
      case 'category':
        return category;
      case 'total':
        return total;
      default:
        return null;
    }
  }
}

class CartService extends ChangeNotifier {
  static final CartService instance = CartService._internal();
  factory CartService() => instance;
  CartService._internal();

  static const String _prefsKey = 'osmile_cart_items_v4';

  final List<CartItem> _items = [];
  bool _inited = false;

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, e) => sum + e.qty);
  double get totalAmount => _items.fold(0, (sum, e) => sum + e.total);
  double get totalPrice => totalAmount;
  double get total => totalAmount;

  // ======================================================
  // 初始化
  // ======================================================
  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    _items
      ..clear()
      ..addAll(raw.map((e) {
        try {
          return CartItem.fromMap(jsonDecode(e));
        } catch (_) {
          return const CartItem(id: '', name: '無效商品', price: 0, qty: 0);
        }
      }).where((e) => e.id.isNotEmpty));
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _items.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList(_prefsKey, encoded);
  }

  // ======================================================
  // ✅ addItem：相容所有舊版呼叫寫法
  // ======================================================
  Future<void> addItem(
    dynamic item, {
    String? productId,
    String? name,
    double? price,
    int qty = 1,
    String? image,
    String? category,
    Map<String, dynamic>? product,
  }) async {
    // 1) 若呼叫 addItem(product: {...})
    if (product != null) {
      await _addFromMap(product, fallbackQty: qty);
      await _save();
      notifyListeners();
      return;
    }

    // 2) 若呼叫 addItem({...}) / addItem(CartItem)
    if (item != null) {
      if (item is CartItem) {
        _addOrIncrease(item);
        await _save();
        notifyListeners();
        return;
      }
      if (item is Map) {
        await _addFromMap(item.cast<String, dynamic>(), fallbackQty: qty);
        await _save();
        notifyListeners();
        return;
      }
    }

    // 3) 若使用純 named
    final id = (productId ?? '').isNotEmpty
        ? productId!
        : 'item_${DateTime.now().millisecondsSinceEpoch}';
    final newItem = CartItem(
      id: id,
      name: name ?? '商品',
      price: price ?? 0,
      qty: qty <= 0 ? 1 : qty,
      image: image,
      category: category,
    );
    _addOrIncrease(newItem);
    await _save();
    notifyListeners();
  }

  Future<void> _addFromMap(Map<String, dynamic> map,
      {int fallbackQty = 1}) async {
    final it = CartItem.fromMap({
      ...map,
      'qty': map['qty'] ?? map['quantity'] ?? fallbackQty,
    });
    _addOrIncrease(it);
  }

  void _addOrIncrease(CartItem item) {
    if (item.id.isEmpty) return;
    final idx = _items.indexWhere((e) => e.id == item.id);
    final safeQty = item.qty <= 0 ? 1 : item.qty;
    if (idx >= 0) {
      final cur = _items[idx];
      _items[idx] = cur.copyWith(qty: cur.qty + safeQty);
    } else {
      _items.add(item.copyWith(qty: safeQty));
    }
  }

  // ======================================================
  // 相容舊版 add(Map)
  // ======================================================
  Future<void> add(Map<String, dynamic> product) async {
    await addItem(product);
  }

  // ======================================================
  // 更新/刪除/清空
  // ======================================================
  Future<void> updateQty(String id, int qty) async {
    await updateItem(id, qty);
  }

  Future<void> updateItem(String id, int qty) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    if (qty <= 0) {
      _items.removeAt(idx);
    } else {
      _items[idx] = _items[idx].copyWith(qty: qty);
    }
    await _save();
    notifyListeners();
  }

  Future<void> increment(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final it = _items[idx];
    await updateItem(id, it.qty + 1);
  }

  Future<void> decrement(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final it = _items[idx];
    await updateItem(id, it.qty - 1);
  }

  Future<void> removeItem(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    await _save();
    notifyListeners();
  }

  bool contains(String id) => _items.any((e) => e.id == id);

  int getQty(String id) => _items
      .firstWhere(
        (e) => e.id == id,
        orElse: () => const CartItem(id: '', name: '', price: 0, qty: 0),
      )
      .qty;

  List<Map<String, dynamic>> toMapList() =>
      _items.map((e) => e.toMap()).toList();
}

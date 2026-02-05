// lib/services/app_state.dart
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/cart_item.dart';
import 'notification_service.dart';

/// 全域應用狀態管理（購物車、訂單、積分、收藏）
///
/// 管理購物流程：
/// - 商品加入購物車
/// - 收藏 / 取消收藏
/// - 結帳產生訂單
/// - 積分累積
/// - 發送通知
class AppState extends ChangeNotifier {
  /// 商品清單（可選：從伺服器或 FirestoreMockService 取得）
  List<Product> products = [];

  /// 購物車內容
  List<CartItem> cart = [];

  /// 訂單紀錄
  List<Order> orders = [];

  /// 收藏清單
  List<Product> favorites = [];

  /// 使用者積分
  int points = 0;

  /// 加入購物車
  void addToCart(Product p, {int qty = 1}) {
    final exist = cart.where((c) => c.product.id == p.id).toList();
    if (exist.isNotEmpty) {
      exist.first.qty += qty;
    } else {
      cart.add(CartItem(product: p, qty: qty));
    }
    notifyListeners();
  }

  /// 從購物車移除商品
  void removeFromCart(String productId) {
    cart.removeWhere((c) => c.product.id == productId);
    notifyListeners();
  }

  /// 清空購物車
  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  /// 收藏 / 取消收藏
  void toggleFavorite(Product p) {
    final exist = favorites.any((f) => f.id == p.id);
    if (exist) {
      favorites.removeWhere((f) => f.id == p.id);
    } else {
      favorites.add(p);
    }
    notifyListeners();
  }

  /// 是否為收藏商品
  bool isFavorite(String id) => favorites.any((f) => f.id == id);

  /// 模擬結帳流程
  /// - 建立訂單
  /// - 清空購物車
  /// - 加積分
  /// - 發送通知
  void checkout(NotificationService ns) {
    if (cart.isEmpty) return;

    final total = cart.fold<int>(
      0,
      (sum, e) => sum + e.product.price * e.qty,
    );

    final order = Order.generate(cart);
    orders.add(order);
    addPoints(total ~/ 100); // 每消費 100 元給 1 積分

    ns.addNotification(
      type: '訂單',
      title: '付款完成',
      message: '訂單 ${order.id} 已完成付款，共 ${total} 元。',
    );

    clearCart();
  }

  /// 積分：增加
  void addPoints(int p) {
    points += p;
    notifyListeners();
  }

  /// 積分：消耗
  void spendPoints(int p) {
    points = (points - p).clamp(0, 999999);
    notifyListeners();
  }

  /// 訂單數量
  int get orderCount => orders.length;

  /// 購物車內總數量
  int get cartCount => cart.fold<int>(0, (sum, e) => sum + e.qty);

  /// 購物車總金額
  int get cartTotal => cart.fold<int>(0, (sum, e) => sum + e.product.price * e.qty);
}
// lib/services/app_state.dart
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/cart_item.dart';
import 'notification_service.dart';

/// 全域應用狀態管理（購物車、訂單、積分、收藏）
///
/// 管理購物流程：
/// - 商品加入購物車
/// - 收藏 / 取消收藏
/// - 結帳產生訂單
/// - 積分累積
/// - 發送通知
class AppState extends ChangeNotifier {
  /// 商品清單（可選：從伺服器或 FirestoreMockService 取得）
  List<Product> products = [];

  /// 購物車內容
  List<CartItem> cart = [];

  /// 訂單紀錄
  List<Order> orders = [];

  /// 收藏清單
  List<Product> favorites = [];

  /// 使用者積分
  int points = 0;

  /// 加入購物車
  void addToCart(Product p, {int qty = 1}) {
    final exist = cart.where((c) => c.product.id == p.id).toList();
    if (exist.isNotEmpty) {
      exist.first.qty += qty;
    } else {
      cart.add(CartItem(product: p, qty: qty));
    }
    notifyListeners();
  }

  /// 從購物車移除商品
  void removeFromCart(String productId) {
    cart.removeWhere((c) => c.product.id == productId);
    notifyListeners();
  }

  /// 清空購物車
  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  /// 收藏 / 取消收藏
  void toggleFavorite(Product p) {
    final exist = favorites.any((f) => f.id == p.id);
    if (exist) {
      favorites.removeWhere((f) => f.id == p.id);
    } else {
      favorites.add(p);
    }
    notifyListeners();
  }

  /// 是否為收藏商品
  bool isFavorite(String id) => favorites.any((f) => f.id == id);

  /// 模擬結帳流程
  /// - 建立訂單
  /// - 清空購物車
  /// - 加積分
  /// - 發送通知
  void checkout(NotificationService ns) {
    if (cart.isEmpty) return;

    final total = cart.fold<int>(
      0,
      (sum, e) => sum + e.product.price * e.qty,
    );

    final order = Order.generate(cart);
    orders.add(order);
    addPoints(total ~/ 100); // 每消費 100 元給 1 積分

    ns.addNotification(
      type: '訂單',
      title: '付款完成',
      message: '訂單 ${order.id} 已完成付款，共 ${total} 元。',
    );

    clearCart();
  }

  /// 積分：增加
  void addPoints(int p) {
    points += p;
    notifyListeners();
  }

  /// 積分：消耗
  void spendPoints(int p) {
    points = (points - p).clamp(0, 999999);
    notifyListeners();
  }

  /// 訂單數量
  int get orderCount => orders.length;

  /// 購物車內總數量
  int get cartCount => cart.fold<int>(0, (sum, e) => sum + e.qty);

  /// 購物車總金額
  int get cartTotal => cart.fold<int>(0, (sum, e) => sum + e.product.price * e.qty);
}

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/models.dart';

class AppState extends ChangeNotifier {
  final List<CartItem> _cart = [];
  final List<LotteryParticipation> _lotteryParticipations = [];
  final List<Order> _orders = [];
  final List<Review> _userReviews = [];

  List<CartItem> get cart => List.unmodifiable(_cart);
  List<LotteryParticipation> get lotteryParticipations => List.unmodifiable(_lotteryParticipations);
  List<Order> get orders => List.unmodifiable(_orders);
  List<Review> get userReviews => List.unmodifiable(_userReviews);

  void addToCart(Product product) {
    final idx = _cart.indexWhere((e) => e.product.id == product.id);
    if (idx >= 0) {
      final item = _cart[idx];
      final nextQty = min(item.quantity + 1, product.stock);
      _cart[idx] = item.copyWith(quantity: nextQty);
    } else {
      _cart.add(CartItem(product: product, quantity: 1));
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((e) => e.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final idx = _cart.indexWhere((e) => e.product.id == productId);
    if (idx < 0) return;

    final item = _cart[idx];
    final q = quantity.clamp(1, item.product.stock);
    _cart[idx] = item.copyWith(quantity: q);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  int getTotalPrice() {
    int total = 0;
    for (final item in _cart) {
      total += item.product.price * item.quantity;
    }
    return total;
  }

  int getCartItemCount() {
    int count = 0;
    for (final item in _cart) {
      count += item.quantity;
    }
    return count;
  }

  void participateInLottery(LotteryParticipation participation) {
    _lotteryParticipations.add(participation);
    notifyListeners();
  }

  /// Reveal (announce) a pending participation for a given lottery id.
  /// Returns the decided status, or null if no participation found.
  LotteryStatus? revealLottery(String lotteryId, {double winRate = 0.1}) {
    final idx = _lotteryParticipations.indexWhere(
      (p) => p.lottery.id == lotteryId && p.status == LotteryStatus.pending,
    );
    if (idx < 0) return null;

    final won = Random().nextDouble() < winRate;
    final next = _lotteryParticipations[idx].copyWith(
      status: won ? LotteryStatus.won : LotteryStatus.lost,
      announced: true,
    );
    _lotteryParticipations[idx] = next;
    notifyListeners();
    return next.status;
  }

  void createOrder(List<CartItem> items, int total) {
    final id = 'order-${DateTime.now().millisecondsSinceEpoch}';
    _orders.add(
      Order(
        id: id,
        items: List<CartItem>.unmodifiable(items),
        total: total,
        shippingFee: 0, // 預設免運費
        date: DateTime.now(),
        status: OrderStatus.shipping,
      ),
    );
    notifyListeners();
  }

  void addReview(Review review) {
    _userReviews.add(review);
    notifyListeners();
  }

  bool hasReviewed(String productId) {
    return _userReviews.any((r) => r.productId == productId);
  }
}

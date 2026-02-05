// lib/services/mock_api_service.dart
import 'dart:async';

class MockApiService {
  static final Map<String, Map<String, dynamic>> _orders = {};

  static Future<Map<String, dynamic>> createOrder(Map<String, dynamic> body, String idempotencyKey) async {
    await Future.delayed(const Duration(seconds: 1));
    final orderId = 'ord_${DateTime.now().millisecondsSinceEpoch}';
    _orders[orderId] = {
      'order_id': orderId,
      'status': 'PENDING_PAYMENT',
      'body': body,
      'total': _calcBodyTotal(body),
      'created_at': DateTime.now().toIso8601String(),
    };

    // 模擬 8 秒後自動完成（若仍為 PENDING_PAYMENT）
    Timer(const Duration(seconds: 8), () {
      if (_orders.containsKey(orderId) && _orders[orderId]!['status'] == 'PENDING_PAYMENT') {
        _orders[orderId]!['status'] = 'COMPLETED';
      }
    });

    return {
      'order_id': orderId,
      'status': 'PENDING_PAYMENT',
      'payment_url': null,
      'total': _orders[orderId]!['total'],
    };
  }

  static double _calcBodyTotal(Map<String, dynamic> body) {
    final items = (body['items'] as List?) ?? [];
    double total = 0.0;
    for (var it in items) {
      final price = (it['price'] ?? 0) as num;
      final qty = (it['qty'] ?? 1) as num;
      total += price.toDouble() * qty.toDouble();
    }
    return total;
  }

  static Future<Map<String, dynamic>> getOrderStatus(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final order = _orders[orderId];
    if (order == null) return {'order_id': orderId, 'status': 'NOT_FOUND'};
    return {'order_id': orderId, 'status': order['status']};
  }

  static Future<void> simulatePaymentNow(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_orders.containsKey(orderId)) {
      _orders[orderId]!['status'] = 'COMPLETED';
    }
  }

  /// Append single item (Map with product_id, qty, price...) into existing order
  static Future<Map<String, dynamic>> appendItemToOrder(String orderId, Map<String, dynamic> item) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final order = _orders[orderId];
    if (order == null) return {'order_id': orderId, 'status': 'NOT_FOUND'};
    final status = (order['status'] ?? '').toString().toUpperCase();
    if (status == 'COMPLETED' || status == 'PAID' || status == 'CANCELLED') {
      return {'order_id': orderId, 'status': status, 'error': 'CANNOT_APPEND'};
    }

    // append to body.items
    order['body'] ??= {};
    order['body']['items'] ??= [];
    (order['body']['items'] as List).add(item);

    // recalc total
    final currentTotal = (order['total'] ?? 0) as num;
    final add = ((item['price'] ?? 0) as num).toDouble() * ((item['qty'] ?? 1) as num).toDouble();
    order['total'] = (currentTotal.toDouble() + add);

    // return updated info
    return {
      'order_id': orderId,
      'status': order['status'],
      'total': order['total'],
    };
  }

  static Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final order = _orders[orderId];
    if (order == null) return {'order_id': orderId, 'status': 'NOT_FOUND'};
    if ((order['status'] ?? '') == 'COMPLETED' || (order['status'] ?? '') == 'PAID') {
      return {'order_id': orderId, 'status': order['status'], 'error': 'ALREADY_PAID'};
    }
    order['status'] = 'CANCELLED';
    return {'order_id': orderId, 'status': 'CANCELLED'};
  }
}

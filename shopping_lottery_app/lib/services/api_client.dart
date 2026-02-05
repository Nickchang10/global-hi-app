// lib/services/api_client.dart
// Mock API client for local testing. Replace with real HTTP calls in production.
import 'dart:async';
import 'dart:math';

class ApiClient {
  // In-memory orders store
  static final Map<String, Map<String, dynamic>> _orders = {};

  // helper to generate order id
  static String _generateOrderId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(100000);
    return 'ord_${ms}_$rnd';
  }

  // helper to compute total from items (fixed and robust)
  static double _computeTotalFromItems(List items) {
    double sum = 0.0;
    for (final it in items) {
      if (it is Map) {
        final priceVal = it['price'] ?? it['unit_price'] ?? it['amount'] ?? 0;
        final qtyVal = it['qty'] ?? it['quantity'] ?? 1;

        double p;
        if (priceVal is num) {
          p = priceVal.toDouble();
        } else if (priceVal is String) {
          p = double.tryParse(priceVal) ?? 0.0;
        } else {
          p = 0.0;
        }

        double q;
        if (qtyVal is num) {
          q = qtyVal.toDouble();
        } else if (qtyVal is String) {
          q = double.tryParse(qtyVal) ?? 1.0;
        } else {
          q = 1.0;
        }

        sum += p * q;
      }
    }
    return sum;
  }

  /// Create order (mock)
  /// body: should contain items: List<Map>, shipping_method, payment_method, address, etc.
  static Future<Map<String, dynamic>> createOrder(
      Map<String, dynamic> body, String idempotencyKey, String apiBase) async {
    // simulate network delay
    await Future.delayed(const Duration(milliseconds: 400));

    // generate id
    final orderId = _generateOrderId();

    final items = (body['items'] is List) ? List.from(body['items']) : [];
    final paymentMethod = body['payment_method']?.toString() ?? 'redirect';
    final total = _computeTotalFromItems(items);

    // sample payment_url for redirect-like flows
    String? paymentUrl;
    if (['redirect', 'google_pay', 'apple_pay', 'paypal', 'line_pay'].contains(paymentMethod)) {
      paymentUrl = 'https://example.com/pay?order=$orderId';
    }

    // create order record
    final record = <String, dynamic>{
      'order_id': orderId,
      'status': 'PENDING_PAYMENT',
      'items': items,
      'total': total,
      'payment_method': paymentMethod,
      'payment_url': paymentUrl,
      'shipping_method': body['shipping_method'],
      'address': body['address'],
      'created_at': DateTime.now().toIso8601String(),
      'message': '訂單已建立，等待付款',
      // store extra metadata if any
      'metadata': body['metadata'] ?? {},
    };

    _orders[orderId] = record;

    return {
      'order_id': orderId,
      'status': record['status'],
      'payment_url': paymentUrl,
      'order': record,
    };
  }

  /// Append item to existing order (mock)
  static Future<Map<String, dynamic>> appendToOrder(
      String orderId, Map<String, dynamic> item, String apiBase) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final rec = _orders[orderId];
    if (rec == null) return {'error': 'order_not_found'};
    final items = (rec['items'] as List<dynamic>? ?? []);
    items.add(item);
    rec['items'] = items;
    rec['total'] = _computeTotalFromItems(items);
    rec['message'] = '已加入加購商品';
    rec['status'] = 'PENDING_PAYMENT';
    _orders[orderId] = rec;
    return {'ok': true, 'order_id': orderId, 'status': rec['status']};
  }

  /// Get order status / details (mock)
  static Future<Map<String, dynamic>?> getOrderStatus(String orderId, String apiBase) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final rec = _orders[orderId];
    if (rec == null) {
      // return a NOT_FOUND like structure
      return {
        'order_id': orderId,
        'status': 'NOT_FOUND',
        'message': '找不到訂單',
      };
    }
    // return a shallow copy to avoid external mutation
    return Map<String, dynamic>.from(rec);
  }

  /// Simulate payment immediately (mock)
  static Future<Map<String, dynamic>> simulatePaymentNow(String orderId, String apiBase) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final rec = _orders[orderId];
    if (rec == null) return {'error': 'order_not_found'};
    rec['status'] = 'PAID';
    rec['message'] = '付款完成（模擬）';
    rec['paid_at'] = DateTime.now().toIso8601String();
    _orders[orderId] = rec;
    return {'ok': true, 'order_id': orderId, 'status': 'PAID'};
  }

  /// Cancel order (mock)
  static Future<Map<String, dynamic>> cancelOrder(String orderId, String apiBase) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final rec = _orders[orderId];
    if (rec == null) return {'error': 'order_not_found'};
    rec['status'] = 'CANCELLED';
    rec['message'] = '訂單已取消（模擬）';
    rec['cancelled_at'] = DateTime.now().toIso8601String();
    _orders[orderId] = rec;
    return {'ok': true, 'order_id': orderId, 'status': 'CANCELLED', 'message': '訂單已取消'};
  }
}

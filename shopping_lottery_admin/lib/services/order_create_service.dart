// lib/services/order_create_service.dart
//
// ✅ OrderCreateService（最終可編譯完整版｜已修正 avoid_types_as_parameter_names + 補齊 if 大括號）
// ------------------------------------------------------------
// 用途：建立訂單 + 扣庫存 + 付款狀態寫入 + 取消回補庫存
//
// 依賴：cloud_firestore
// ------------------------------------------------------------

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderCreateResult {
  final String orderId;
  final String orderNo;
  final double total;
  final Map<String, dynamic> orderData;

  const OrderCreateResult({
    required this.orderId,
    required this.orderNo,
    required this.total,
    required this.orderData,
  });
}

class OrderCreateService {
  final FirebaseFirestore _db;

  /// collection 命名
  final String ordersCol;
  final String productsCol;
  final String couponsCol;

  /// 商品庫存欄位
  final String stockField;

  OrderCreateService({
    FirebaseFirestore? db,
    this.ordersCol = 'orders',
    this.productsCol = 'products',
    this.couponsCol = 'coupons',
    this.stockField = 'stock',
  }) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection(ordersCol);
  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection(productsCol);
  CollectionReference<Map<String, dynamic>> get _coupons =>
      _db.collection(couponsCol);

  // ===========================================================
  // Public APIs
  // ===========================================================

  Future<OrderCreateResult> createOrder({
    required String userId,
    required List<Map<String, dynamic>> items,
    Map<String, dynamic>? shipping,
    Map<String, dynamic>? buyer,
    String? vendorId,
    String? couponCode,
    String? couponId,
    double shippingFee = 0,
    double discount = 0,
    String currency = 'TWD',
    String paymentProvider = 'manual',
    String paymentMethod = 'card',
    bool isCod = false,
    bool decrementStock = true,
    bool writeCouponUsage = true,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) {
      throw ArgumentError('userId 不可為空');
    }
    if (items.isEmpty) {
      throw ArgumentError('items 不可為空');
    }

    final normalizedItems = items.map(_normalizeItem).toList(growable: false);

    // ✅ 修正：sum 參數名撞到可見 type（avoid_types_as_parameter_names）
    final subtotal = normalizedItems.fold<double>(
      0.0,
      (acc, it) =>
          acc + (_asDouble(it['price']) * _asInt(it['qty']).toDouble()),
    );

    // ✅ 關鍵：max 回傳 num，這裡強制轉 double
    final total = max<double>(0.0, subtotal + shippingFee - discount);

    final orderNo = _genOrderNo();
    final orderDoc = _orders.doc(); // auto id
    final orderId = orderDoc.id;

    final orderData = <String, dynamic>{
      'orderNo': orderNo,
      'userId': uid,
      if ((vendorId ?? '').trim().isNotEmpty) 'vendorId': vendorId!.trim(),
      'items': normalizedItems,
      'totals': <String, dynamic>{
        'subtotal': subtotal,
        'shippingFee': shippingFee,
        'discount': discount,
        'total': total,
        'currency': currency,
      },
      'status': 'pending',
      'payment': <String, dynamic>{
        'status': isCod ? 'cod' : 'pending',
        'provider': paymentProvider,
        'method': paymentMethod,
      },
      'shipping': _asMap(shipping),
      'buyer': _asMap(buyer),
      if ((couponCode ?? '').trim().isNotEmpty)
        'couponCode': couponCode!.trim(),
      if ((couponId ?? '').trim().isNotEmpty) 'couponId': couponId!.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _db.runTransaction((tx) async {
      // 1) create order
      tx.set(orderDoc, orderData);

      // 2) decrement stock (optional)
      if (decrementStock) {
        for (final it in normalizedItems) {
          final pid = (it['productId'] ?? '').toString().trim();
          if (pid.isEmpty) {
            continue;
          }

          final qty = _asInt(it['qty']);
          if (qty <= 0) {
            continue;
          }

          final pRef = _products.doc(pid);
          final pSnap = await tx.get(pRef);
          final p = pSnap.data() ?? <String, dynamic>{};

          final currentStock = _asInt(p[stockField]);
          final newStock = currentStock - qty;

          // 若不允許負庫存
          if (currentStock >= 0 && newStock < 0) {
            throw StateError('商品庫存不足：$pid（stock=$currentStock, need=$qty）');
          }

          tx.update(pRef, {
            stockField: newStock,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // 3) coupon usage (optional)
      if (writeCouponUsage) {
        final cid = (couponId ?? '').trim();
        if (cid.isNotEmpty) {
          final cRef = _coupons.doc(cid);
          final cSnap = await tx.get(cRef);
          if (cSnap.exists) {
            tx.update(cRef, {
              'usedCount': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    });

    return OrderCreateResult(
      orderId: orderId,
      orderNo: orderNo,
      total: total, // ✅ 這裡現在是 double
      orderData: orderData,
    );
  }

  Future<void> setPaymentPending(
    String orderId, {
    required String provider,
    required String method,
    String? transactionId,
    Map<String, dynamic>? raw,
  }) async {
    final ref = _orders.doc(orderId.trim());
    await ref.update({
      'payment.status': 'pending',
      'payment.provider': provider.trim(),
      'payment.method': method.trim(),
      if ((transactionId ?? '').trim().isNotEmpty)
        'payment.transactionId': transactionId!.trim(),
      if (raw != null) 'payment.raw': raw,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markPaid(
    String orderId, {
    String? transactionId,
    Map<String, dynamic>? raw,
  }) async {
    final ref = _orders.doc(orderId.trim());
    await ref.update({
      'status': 'paid',
      'payment.status': 'paid',
      if ((transactionId ?? '').trim().isNotEmpty)
        'payment.transactionId': transactionId!.trim(),
      if (raw != null) 'payment.raw': raw,
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markPaymentFailed(
    String orderId, {
    String? reason,
    Map<String, dynamic>? raw,
  }) async {
    final ref = _orders.doc(orderId.trim());
    await ref.update({
      'payment.status': 'failed',
      if ((reason ?? '').trim().isNotEmpty)
        'payment.failReason': reason!.trim(),
      if (raw != null) 'payment.raw': raw,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markCod(
    String orderId, {
    String provider = 'cod',
    String method = 'cash',
  }) async {
    final ref = _orders.doc(orderId.trim());
    await ref.update({
      'payment.status': 'cod',
      'payment.provider': provider.trim(),
      'payment.method': method.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelOrder(
    String orderId, {
    String reason = '',
    bool restoreStock = true,
  }) async {
    final id = orderId.trim();
    if (id.isEmpty) {
      return;
    }

    final oRef = _orders.doc(id);

    await _db.runTransaction((tx) async {
      final oSnap = await tx.get(oRef);
      final o = oSnap.data() ?? <String, dynamic>{};
      final status = (o['status'] ?? '').toString().toLowerCase();

      if (status == 'completed' || status == 'shipped') {
        throw StateError('訂單已$status，不允許取消');
      }

      if (restoreStock) {
        final items = _safeList(o['items']);
        for (final raw in items) {
          final it = _asMap(raw);
          final pid = (it['productId'] ?? '').toString().trim();
          final qty = _asInt(it['qty']);
          if (pid.isEmpty || qty <= 0) {
            continue;
          }

          final pRef = _products.doc(pid);
          final pSnap = await tx.get(pRef);
          final p = pSnap.data() ?? <String, dynamic>{};
          final currentStock = _asInt(p[stockField]);

          tx.update(pRef, {
            stockField: currentStock + qty,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      tx.update(oRef, {
        'status': 'cancelled',
        'cancelReason': reason.trim(),
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setShippingInfo(
    String orderId, {
    String? status, // packing/shipped/delivered
    String? carrier,
    String? trackingNo,
    DateTime? shippedAt,
  }) async {
    final ref = _orders.doc(orderId.trim());
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};

    if ((status ?? '').trim().isNotEmpty) {
      data['shipping.status'] = status!.trim();
    }
    if ((carrier ?? '').trim().isNotEmpty) {
      data['shipping.carrier'] = carrier!.trim();
    }
    if ((trackingNo ?? '').trim().isNotEmpty) {
      data['shipping.trackingNo'] = trackingNo!.trim();
    }
    if (shippedAt != null) {
      data['shipping.shippedAt'] = Timestamp.fromDate(shippedAt);
    }

    await ref.update(data);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamOrder(String orderId) {
    return _orders.doc(orderId.trim()).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getOrder(String orderId) {
    return _orders.doc(orderId.trim()).get();
  }

  // ===========================================================
  // normalize / helpers
  // ===========================================================

  Map<String, dynamic> _normalizeItem(Map<String, dynamic> raw) {
    final pid = (raw['productId'] ?? raw['id'] ?? '').toString().trim();
    final qtyRaw = _asInt(raw['qty'] ?? raw['quantity']);
    final priceRaw = _asDouble(raw['price'] ?? raw['unitPrice']);
    final title = (raw['title'] ?? raw['name'] ?? '').toString().trim();
    final vendorId = (raw['vendorId'] ?? raw['vendor_id'] ?? '')
        .toString()
        .trim();

    // ✅ 關鍵：max 回傳 num，這裡強制轉 int/double
    final safeQty = max<int>(1, qtyRaw);
    final safePrice = max<double>(0.0, priceRaw);

    return <String, dynamic>{
      'productId': pid,
      'title': title,
      'qty': safeQty,
      'price': safePrice,
      if (vendorId.isNotEmpty) 'vendorId': vendorId,
      if (raw['sku'] != null) 'sku': (raw['sku'] ?? '').toString(),
      if (raw['imageUrl'] != null)
        'imageUrl': (raw['imageUrl'] ?? '').toString(),
      if (raw['image'] != null) 'image': (raw['image'] ?? '').toString(),
      if (raw['options'] is Map) 'options': _asMap(raw['options']),
    };
  }

  String _genOrderNo() {
    final now = DateTime.now();
    final rand = Random().nextInt(9000) + 1000;
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return 'O${now.year}$mm$dd-$hh$mi$ss-$rand';
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v == null) return <String, dynamic>{};
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<dynamic> _safeList(dynamic v) {
    if (v is List) return v;
    return const <dynamic>[];
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = (v ?? '').toString().trim();
    return int.tryParse(s) ?? 0;
  }

  double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    final s = (v ?? '').toString().trim();
    return double.tryParse(s) ?? 0.0;
  }
}

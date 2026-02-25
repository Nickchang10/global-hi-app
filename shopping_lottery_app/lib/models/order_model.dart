// lib/models/order_model.dart
//
// ✅ OrderModel / OrderItemModel（最終完整版｜可直接使用｜修正 avoid_types_as_parameter_names）
// ------------------------------------------------------------
// 金額一律用 int（元）避免 double 精度與 fold 型別錯誤。
// 百分比折扣請用整數：amount * rate ~/ 100

import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item.dart';

enum OrderStatus {
  pending, // 已建立待付款
  paid, // 已付款
  shipped, // 已出貨
  completed, // 已完成
  cancelled, // 已取消
  refunded, // 已退款
}

OrderStatus _statusFromString(String s) {
  switch (s) {
    case 'paid':
      return OrderStatus.paid;
    case 'shipped':
      return OrderStatus.shipped;
    case 'completed':
      return OrderStatus.completed;
    case 'cancelled':
      return OrderStatus.cancelled;
    case 'refunded':
      return OrderStatus.refunded;
    case 'pending':
    default:
      return OrderStatus.pending;
  }
}

String _statusToString(OrderStatus s) => s.name;

class OrderItemModel {
  final String productId;
  final String title;
  final String image;

  /// 單價（元）
  final int unitPrice;

  final int qty;
  final String currency;

  final String vendorId;
  final String vendorName;

  const OrderItemModel({
    required this.productId,
    required this.title,
    required this.image,
    required this.unitPrice,
    required this.qty,
    required this.currency,
    required this.vendorId,
    required this.vendorName,
  });

  int get lineTotal => unitPrice * qty;

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'title': title,
    'image': image,
    'unitPrice': unitPrice,
    'qty': qty,
    'currency': currency,
    'vendorId': vendorId,
    'vendorName': vendorName,
  };

  static OrderItemModel fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      productId: (map['productId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      image: (map['image'] ?? '').toString(),
      unitPrice: _toInt(map['unitPrice'], fallback: 0),
      qty: _toInt(map['qty'], fallback: 1).clamp(1, 999999),
      currency: (map['currency'] ?? 'TWD').toString(),
      vendorId: (map['vendorId'] ?? '').toString(),
      vendorName: (map['vendorName'] ?? '').toString(),
    );
  }
}

class OrderModel {
  final String id;
  final String userId;

  final List<OrderItemModel> items;

  final String currency;

  /// 小計（元）
  final int subtotal;

  /// 運費（元）
  final int shippingFee;

  /// 折扣（元）
  final int discountAmount;

  /// 點數折抵（元）
  final int pointsDiscount;

  /// 應付總額（元）
  final int total;

  final OrderStatus status;

  // 支付資訊（可選）
  final String paymentMethod;
  final String transactionId;

  // 收件資訊（可選）
  final String receiverName;
  final String receiverPhone;
  final String shippingAddress;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.currency,
    required this.subtotal,
    required this.shippingFee,
    required this.discountAmount,
    required this.pointsDiscount,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.transactionId,
    required this.receiverName,
    required this.receiverPhone,
    required this.shippingAddress,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderModel.fromCart({
    required String id,
    required String userId,
    required List<CartItem> cartItems,
    int shippingFee = 0,
    int discountAmount = 0,
    int pointsDiscount = 0,
    String currency = 'TWD',
    OrderStatus status = OrderStatus.pending,
    String paymentMethod = '',
    String transactionId = '',
    String receiverName = '',
    String receiverPhone = '',
    String shippingAddress = '',
  }) {
    final items = cartItems
        .map(
          (c) => OrderItemModel(
            productId: c.productId,
            title: c.title,
            image: c.image,
            unitPrice: c.unitPrice,
            qty: c.qty,
            currency: c.currency,
            vendorId: c.vendorId,
            vendorName: c.vendorName,
          ),
        )
        .toList();

    // ✅ FIX: sum -> acc
    final subtotalCalc = items.fold<int>(0, (acc, e) => acc + e.lineTotal);

    final totalCalc = _calcTotalInt(
      subtotal: subtotalCalc,
      shippingFee: shippingFee,
      discountAmount: discountAmount,
      pointsDiscount: pointsDiscount,
    );

    final now = DateTime.now();
    return OrderModel(
      id: id,
      userId: userId,
      items: items,
      currency: currency,
      subtotal: subtotalCalc,
      shippingFee: shippingFee,
      discountAmount: discountAmount,
      pointsDiscount: pointsDiscount,
      total: totalCalc,
      status: status,
      paymentMethod: paymentMethod,
      transactionId: transactionId,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      shippingAddress: shippingAddress,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 百分比折扣（整數）
  static int percentDiscountAmount({
    required int amount,
    required int percentOff,
  }) {
    if (amount <= 0) return 0;
    final p = percentOff.clamp(0, 100);
    return amount * p ~/ 100;
  }

  static int _calcTotalInt({
    required int subtotal,
    required int shippingFee,
    required int discountAmount,
    required int pointsDiscount,
  }) {
    final raw = subtotal + shippingFee - discountAmount - pointsDiscount;
    return raw < 0 ? 0 : raw;
  }

  OrderModel copyWith({
    String? id,
    String? userId,
    List<OrderItemModel>? items,
    String? currency,
    int? subtotal,
    int? shippingFee,
    int? discountAmount,
    int? pointsDiscount,
    int? total,
    OrderStatus? status,
    String? paymentMethod,
    String? transactionId,
    String? receiverName,
    String? receiverPhone,
    String? shippingAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      currency: currency ?? this.currency,
      subtotal: subtotal ?? this.subtotal,
      shippingFee: shippingFee ?? this.shippingFee,
      discountAmount: discountAmount ?? this.discountAmount,
      pointsDiscount: pointsDiscount ?? this.pointsDiscount,
      total: total ?? this.total,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'items': items.map((e) => e.toMap()).toList(),
    'currency': currency,
    'subtotal': subtotal,
    'shippingFee': shippingFee,
    'discountAmount': discountAmount,
    'pointsDiscount': pointsDiscount,
    'total': total,
    'status': _statusToString(status),
    'paymentMethod': paymentMethod,
    'transactionId': transactionId,
    'receiverName': receiverName,
    'receiverPhone': receiverPhone,
    'shippingAddress': shippingAddress,
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
  };

  static OrderModel fromMap(String id, Map<String, dynamic> map) {
    final itemsRaw = map['items'];
    final items = (itemsRaw is List)
        ? itemsRaw
              .whereType<Map>()
              .map((e) => OrderItemModel.fromMap(Map<String, dynamic>.from(e)))
              .toList()
        : <OrderItemModel>[];

    // ✅ FIX: sum -> acc
    final subtotalCalc = items.fold<int>(0, (acc, e) => acc + e.lineTotal);

    final shippingFee = _toInt(map['shippingFee'], fallback: 0);
    final discountAmount = _toInt(map['discountAmount'], fallback: 0);
    final pointsDiscount = _toInt(map['pointsDiscount'], fallback: 0);

    final subtotal = _toInt(map['subtotal'], fallback: subtotalCalc);
    final total = _toInt(
      map['total'],
      fallback: _calcTotalInt(
        subtotal: subtotal,
        shippingFee: shippingFee,
        discountAmount: discountAmount,
        pointsDiscount: pointsDiscount,
      ),
    );

    return OrderModel(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      items: items,
      currency: (map['currency'] ?? 'TWD').toString(),
      subtotal: subtotal,
      shippingFee: shippingFee,
      discountAmount: discountAmount,
      pointsDiscount: pointsDiscount,
      total: total,
      status: _statusFromString((map['status'] ?? 'pending').toString()),
      paymentMethod: (map['paymentMethod'] ?? '').toString(),
      transactionId: (map['transactionId'] ?? '').toString(),
      receiverName: (map['receiverName'] ?? '').toString(),
      receiverPhone: (map['receiverPhone'] ?? '').toString(),
      shippingAddress: (map['shippingAddress'] ?? '').toString(),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  static OrderModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return fromMap(doc.id, data);
  }
}

int _toInt(dynamic v, {required int fallback}) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

// lib/models/order.dart
import 'dart:math';
import 'cart_item.dart';

/// 訂單模型：
/// - 對應購物車的 CartItem 清單
/// - total 會依照商品單價 * 數量自動計算
/// - status：pending / shipped / delivered / cancelled / refund
/// - 額外欄位：物流追蹤、支付方式、時間軸等
class Order {
  /// 訂單編號，例如：ORD-000123
  final String id;

  /// 購物車項目
  final List<CartItem> items;

  /// 訂單總金額（所有商品 price * qty 加總）
  final int total;

  /// 下單時間
  final DateTime createdAt;

  /// 訂單狀態：pending / shipped / delivered / cancelled / refund
  final String status;

  /// 收件 / 配送地址（顯示用）
  final String? shippingAddress;

  /// 付款方式（例如：信用卡 VISA **** 4242）
  final String? paymentMethod;

  /// 物流追蹤號碼（有物流時才有）
  final String? trackingNumber;

  /// 物流商名稱（如：黑貓 / 宅配通）
  final String? carrier;

  /// 發票連結（實務中可放雲端發票網址）
  final String? invoiceUrl;

  /// 是否可以取消（例如 pending 時為 true，其餘為 false）
  final bool canCancel;

  /// 訂單時間軸（給 UI 用）：
  /// 每個節點包含：{ 'label': String, 'time': DateTime?, 'done': bool }
  final List<Map<String, dynamic>> timeline;

  Order({
    required this.id,
    required this.items,
    required this.total,
    required this.createdAt,
    this.status = 'pending',
    this.shippingAddress,
    this.paymentMethod,
    this.trackingNumber,
    this.carrier,
    this.invoiceUrl,
    this.canCancel = true,
    this.timeline = const [],
  });

  /// 依照購物車 items 自動產生一筆訂單：
  /// - 自動計算 total
  /// - 自動產生隨機訂單編號
  /// - 預設狀態為 pending
  /// - 自動帶出一組簡單時間軸（下單 / 付款 / 出貨 / 送達）
  factory Order.generate(
    List<CartItem> items, {
    String status = 'pending',
    String? shippingAddress,
    String? paymentMethod,
    String? trackingNumber,
    String? carrier,
    String? invoiceUrl,
    bool? canCancel,
  }) {
    final total = items.fold<int>(
      0,
      (sum, e) => sum + e.product.price * e.qty,
    );

    final now = DateTime.now();
    final createdAt = now;

    // 建立簡單的時間軸，之後可以在 OrdersPage / OrderDetailPage 直接使用
    final List<Map<String, dynamic>> timeline = [
      {
        'label': '下單',
        'time': createdAt,
        'done': true,
      },
      {
        'label': '付款',
        'time': createdAt.add(const Duration(minutes: 5)),
        'done': status != 'pending',
      },
      {
        'label': '出貨',
        'time': null,
        'done': status == 'shipped' || status == 'delivered',
      },
      {
        'label': '送達',
        'time': null,
        'done': status == 'delivered',
      },
    ];

    if (status == 'cancelled') {
      timeline.add({
        'label': '已取消',
        'time': createdAt.add(const Duration(minutes: 10)),
        'done': true,
      });
    } else if (status == 'refund') {
      timeline.add({
        'label': '退款/退貨',
        'time': createdAt.add(const Duration(days: 1)),
        'done': true,
      });
    }

    return Order(
      id: 'ORD-${Random().nextInt(999999).toString().padLeft(6, '0')}',
      items: List<CartItem>.from(items),
      total: total,
      createdAt: createdAt,
      status: status,
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      trackingNumber: trackingNumber,
      carrier: carrier,
      invoiceUrl: invoiceUrl,
      canCancel: canCancel ?? (status == 'pending'),
      timeline: timeline,
    );
  }

  /// 建立一個新的 Order（例如更新狀態/物流資訊）
  Order copyWith({
    String? id,
    List<CartItem>? items,
    int? total,
    DateTime? createdAt,
    String? status,
    String? shippingAddress,
    String? paymentMethod,
    String? trackingNumber,
    String? carrier,
    String? invoiceUrl,
    bool? canCancel,
    List<Map<String, dynamic>>? timeline,
  }) {
    return Order(
      id: id ?? this.id,
      items: items ?? this.items,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      carrier: carrier ?? this.carrier,
      invoiceUrl: invoiceUrl ?? this.invoiceUrl,
      canCancel: canCancel ?? this.canCancel,
      timeline: timeline ?? this.timeline,
    );
  }

  @override
  String toString() {
    return 'Order(id: $id, total: $total, status: $status, items: ${items.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Order && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

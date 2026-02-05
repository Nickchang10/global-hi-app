// lib/models/order_model.dart
import 'dart:math';

import 'cart_item.dart';

/// 訂單狀態（可搭配 UI 顯示）
/// 你也可以只用 String，不用 enum；這裡同時保留 status 字串欄位做兼容。
enum OrderStatus {
  pending,   // 待處理
  shipped,   // 已出貨
  delivered, // 已送達
  cancelled, // 已取消
  refund,    // 退款/退貨
}

extension OrderStatusExt on OrderStatus {
  String get code {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.shipped:
        return 'shipped';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.refund:
        return 'refund';
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return '待處理';
      case OrderStatus.shipped:
        return '已出貨';
      case OrderStatus.delivered:
        return '已送達';
      case OrderStatus.cancelled:
        return '已取消';
      case OrderStatus.refund:
        return '退款/退貨';
    }
  }
}

/// 訂單時間軸節點（搭配訂單詳情頁上的 timeline 使用）
class OrderTimelineStep {
  final String label;
  final DateTime? time;
  final bool done;

  const OrderTimelineStep({
    required this.label,
    this.time,
    this.done = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'time': time,
      'done': done,
    };
  }

  factory OrderTimelineStep.fromMap(Map<String, dynamic> map) {
    return OrderTimelineStep(
      label: map['label'] as String? ?? '',
      time: map['time'] is DateTime ? map['time'] as DateTime : null,
      done: map['done'] == true,
    );
  }
}

/// 訂單資料模型
///
/// - [id]           訂單編號（例：ORD-123456）
/// - [items]        購物車項目列表
/// - [total]        總金額
/// - [createdAt]    建立時間
/// - [status]       當前狀態（搭配 [statusCode] / [statusLabel] 使用）
/// - [shippingAddress] 配送地址
/// - [paymentMethod]   付款方式描述（例：信用卡 VISA **** 4242）
/// - [trackingNumber]  物流單號
/// - [carrier]         配送業者
/// - [invoiceUrl]      發票連結（示範用）
/// - [canCancel]       是否可以取消
/// - [timeline]        時間軸節點（配合 UI 顯示）
class OrderModel {
  final String id;
  final List<CartItem> items;
  final int total;
  final DateTime createdAt;

  final OrderStatus status;
  final String? shippingAddress;
  final String? paymentMethod;
  final String? trackingNumber;
  final String? carrier;
  final String? invoiceUrl;
  final bool canCancel;
  final List<OrderTimelineStep> timeline;

  OrderModel({
    required this.id,
    required this.items,
    required this.total,
    required this.createdAt,
    this.status = OrderStatus.pending,
    this.shippingAddress,
    this.paymentMethod,
    this.trackingNumber,
    this.carrier,
    this.invoiceUrl,
    this.canCancel = true,
    this.timeline = const [],
  });

  /// 產生一筆訂單（從購物車項目轉成訂單）
  factory OrderModel.fromCartItems(
    List<CartItem> items, {
    OrderStatus status = OrderStatus.pending,
    String? shippingAddress,
    String? paymentMethod,
    String? trackingNumber,
    String? carrier,
    String? invoiceUrl,
  }) {
    final total = items.fold<int>(
      0,
      (sum, e) => sum + e.product.price * e.qty,
    );

    final now = DateTime.now();
    final baseTimeline = _buildDefaultTimeline(now, status);

    return OrderModel(
      id: 'ORD-${Random().nextInt(999999).toString().padLeft(6, '0')}',
      items: List<CartItem>.from(items),
      total: total,
      createdAt: now,
      status: status,
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      trackingNumber: trackingNumber,
      carrier: carrier,
      invoiceUrl: invoiceUrl,
      canCancel: status == OrderStatus.pending,
      timeline: baseTimeline,
    );
  }

  /// 內部使用：根據狀態建立一組預設時間軸
  static List<OrderTimelineStep> _buildDefaultTimeline(
    DateTime now,
    OrderStatus status,
  ) {
    final created = now;
    final paid = created.add(const Duration(hours: 1));
    final shipped = paid.add(const Duration(days: 1));
    final delivered = shipped.add(const Duration(days: 2));

    final steps = <OrderTimelineStep>[
      OrderTimelineStep(label: '下單', time: created, done: true),
      OrderTimelineStep(label: '付款', time: paid, done: true),
      OrderTimelineStep(
        label: '出貨',
        time: shipped,
        done: status == OrderStatus.shipped ||
            status == OrderStatus.delivered ||
            status == OrderStatus.cancelled ||
            status == OrderStatus.refund,
      ),
      OrderTimelineStep(
        label: '送達',
        time: delivered,
        done: status == OrderStatus.delivered,
      ),
    ];

    if (status == OrderStatus.cancelled) {
      steps.add(OrderTimelineStep(
        label: '已取消',
        time: now,
        done: true,
      ));
    } else if (status == OrderStatus.refund) {
      steps.add(OrderTimelineStep(
        label: '退款/退貨',
        time: now,
        done: true,
      ));
    }

    return steps;
  }

  /// 狀態字串（提供給舊版需要使用 String 的地方）
  String get statusCode => status.code;

  /// 狀態中文（UI 顯示）
  String get statusLabel => status.label;

  /// 方便在 Provider 裡 immutable 更新
  OrderModel copyWith({
    String? id,
    List<CartItem>? items,
    int? total,
    DateTime? createdAt,
    OrderStatus? status,
    String? shippingAddress,
    String? paymentMethod,
    String? trackingNumber,
    String? carrier,
    String? invoiceUrl,
    bool? canCancel,
    List<OrderTimelineStep>? timeline,
  }) {
    return OrderModel(
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

  /// 給現在的 OrdersPage 用的 map 格式
  ///
  /// 你可以這樣用：
  /// final list = orders.map((o) => o.toMapForOrdersPage()).toList();
  /// Navigator.push(context, MaterialPageRoute(
  ///   builder: (_) => OrdersPage(initialOrders: list),
  /// ));
  Map<String, dynamic> toMapForOrdersPage() {
    return {
      'id': id,
      'date': createdAt,
      'status': statusCode,
      'items': items
          .map((c) => {
                'name': c.product.title,
                'qty': c.qty,
                'price': c.product.price,
                'image': c.product.image,
              })
          .toList(),
      'total': total,
      'shippingAddress': shippingAddress ?? '',
      'paymentMethod': paymentMethod ?? '',
      'trackingNumber': trackingNumber,
      'carrier': carrier,
      'invoiceUrl': invoiceUrl,
      'canCancel': canCancel,
      'timeline': timeline.map((t) => t.toMap()).toList(),
    };
  }

  /// 如果之後你有把 Map 存到本機 / 雲端，也可以用這個還原
  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final statusCode = map['status'] as String? ?? 'pending';
    final status = OrderStatus.values.firstWhere(
      (e) => e.code == statusCode,
      orElse: () => OrderStatus.pending,
    );

    return OrderModel(
      id: map['id'] as String? ?? '',
      items: (map['items'] as List<dynamic>? ?? [])
          .map((e) => e as CartItem)
          .toList(),
      total: map['total'] as int? ?? 0,
      createdAt: map['date'] as DateTime? ?? DateTime.now(),
      status: status,
      shippingAddress: map['shippingAddress'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
      trackingNumber: map['trackingNumber'] as String?,
      carrier: map['carrier'] as String?,
      invoiceUrl: map['invoiceUrl'] as String?,
      canCancel: map['canCancel'] as bool? ?? false,
      timeline: (map['timeline'] as List<dynamic>? ?? [])
          .map((e) => OrderTimelineStep.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

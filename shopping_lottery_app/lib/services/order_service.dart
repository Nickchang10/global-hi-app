// lib/services/order_service.dart
// =======================================================
// ✅ OrderService - 完整最終版（相容 shipping / extra / paymentMethod）
// - CheckoutPage: createOrder(... shipping/extra/paymentMethod 可帶)
// - PaymentStatusPage: updateStatus(orderId,'paid') / markPaid(orderId)
// - OrdersPage: 讀 orders / myOrders / statusLabel / timeline
// =======================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'cart_service.dart';
import 'notification_service.dart';

/// =======================================================
/// ✅ 訂單狀態常數（全專案請用同一套）
/// =======================================================
class OrderStatus {
  static const String placed = 'placed'; // 已下單（待付款/處理）
  static const String paid = 'paid'; // 已付款
  static const String shipped = 'shipped'; // 已出貨
  static const String delivered = 'delivered'; // 已送達
  static const String cancelled = 'cancelled'; // 已取消
  static const String refunded = 'refunded'; // 已退款
}

/// =======================================================
/// ✅ OrderTimelineEvent（追蹤時間軸）
/// =======================================================
class OrderTimelineEvent {
  final String key;
  final String label;
  final int timeMs;
  final bool done;

  const OrderTimelineEvent({
    required this.key,
    required this.label,
    required this.timeMs,
    required this.done,
  });

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'timeMs': timeMs,
        'done': done,
      };

  factory OrderTimelineEvent.fromMap(Map<String, dynamic> m) {
    return OrderTimelineEvent(
      key: (m['key'] ?? '').toString(),
      label: (m['label'] ?? '').toString(),
      timeMs: (m['timeMs'] is int)
          ? (m['timeMs'] as int)
          : int.tryParse('${m['timeMs']}') ??
              DateTime.now().millisecondsSinceEpoch,
      done: m['done'] == true,
    );
  }
}

/// =======================================================
/// ✅ OrderItem - 單一訂單品項模型
/// =======================================================
class OrderItem {
  final String productId;
  final String name;
  final int qty;
  final double price;
  final String? image;

  OrderItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.price,
    this.image,
  });

  double get subtotal => qty * price;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'qty': qty,
        'price': price,
        'image': image,
      };

  factory OrderItem.fromMap(Map<String, dynamic> m) {
    final rawPrice = m['price'];
    final double price = (rawPrice is num)
        ? rawPrice.toDouble()
        : double.tryParse('${m['price']}') ?? 0.0;

    final rawQty = m['qty'];
    final int qty =
        (rawQty is int) ? rawQty : int.tryParse('${m['qty']}') ?? 1;

    final img = (m['image'] ?? m['imageUrl'] ?? '').toString().trim();

    return OrderItem(
      productId: (m['productId'] ?? m['id'] ?? m['sku'] ?? '').toString(),
      name: (m['name'] ?? m['title'] ?? '商品').toString(),
      qty: qty <= 0 ? 1 : qty,
      price: price < 0 ? 0 : price,
      image: img.isEmpty ? null : img,
    );
  }
}

/// =======================================================
/// ✅ Order - 訂單資料模型
/// - shipping：出貨/地址/物流資訊
/// - extra：支付方式、備註、折扣等延伸欄位
/// - paymentMethod：付款方式（方便 UI 直接顯示）
/// - timeline：狀態時間軸（固定輸出順序）
/// =======================================================
class Order {
  final String id;
  final String userId;
  final DateTime createdAt;
  DateTime? updatedAt;

  final double totalAmount;
  String status;

  final List<OrderItem> items;

  Map<String, dynamic>? shipping;
  Map<String, dynamic>? extra;
  String? paymentMethod;

  List<OrderTimelineEvent> timeline;

  Order({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.totalAmount,
    required this.status,
    required this.items,
    this.shipping,
    this.extra,
    this.paymentMethod,
    List<OrderTimelineEvent>? timeline,
    this.updatedAt,
  }) : timeline = timeline ?? <OrderTimelineEvent>[];

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
        'totalAmount': totalAmount,
        'status': status,
        'items': items.map((i) => i.toMap()).toList(),
        'shipping': shipping,
        'extra': extra,
        'paymentMethod': paymentMethod,
        'timeline': timeline.map((e) => e.toMap()).toList(),
      };

  factory Order.fromMap(Map<String, dynamic> m) {
    final items = <OrderItem>[];
    if (m['items'] is List) {
      for (final e in (m['items'] as List)) {
        if (e is Map) {
          items.add(OrderItem.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }

    final timeline = <OrderTimelineEvent>[];
    if (m['timeline'] is List) {
      for (final e in (m['timeline'] as List)) {
        if (e is Map) {
          timeline.add(OrderTimelineEvent.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }

    final createdAtMs = (m['createdAt'] is int)
        ? (m['createdAt'] as int)
        : int.tryParse('${m['createdAt']}') ??
            DateTime.now().millisecondsSinceEpoch;

    final updatedAtMs = (m['updatedAt'] is int)
        ? (m['updatedAt'] as int)
        : int.tryParse('${m['updatedAt']}');

    final rawTotal = m['totalAmount'];
    final double totalAmount = (rawTotal is num)
        ? rawTotal.toDouble()
        : double.tryParse('${m['totalAmount']}') ?? 0.0;

    final pm = (m['paymentMethod'] ?? '').toString().trim();

    return Order(
      id: (m['id'] ?? '').toString(),
      userId: (m['userId'] ?? '').toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      updatedAt: updatedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      totalAmount: totalAmount < 0 ? 0 : totalAmount,
      status: (m['status'] ?? OrderStatus.placed).toString(),
      items: items,
      shipping: (m['shipping'] is Map)
          ? Map<String, dynamic>.from(m['shipping'])
          : null,
      extra: (m['extra'] is Map) ? Map<String, dynamic>.from(m['extra']) : null,
      paymentMethod: pm.isEmpty ? null : pm,
      timeline: timeline,
    );
  }
}

/// =======================================================
/// ✅ OrderService - 訂單服務（相容版）
/// =======================================================
class OrderService extends ChangeNotifier {
  OrderService._internal();
  static final OrderService instance = OrderService._internal();
  factory OrderService() => instance;

  static const String _kKey = 'osmile_orders_v2';
  final List<Order> _orders = [];

  List<Order> get orders => List.unmodifiable(_orders);

  /// ✅ ProfilePage / OrdersPage 常用
  List<Order> get allOrders => List.unmodifiable(_orders);

  /// 依使用者篩選（AuthService.userId）
  List<Order> get myOrders {
    final uid = AuthService.instance.userId;
    return _orders.where((o) => o.userId == uid).toList();
  }

  /// 初始化（App 啟動時呼叫一次）
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);

    _orders.clear();

    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final e in list) {
            if (e is Map) {
              final o = Order.fromMap(Map<String, dynamic>.from(e));
              o.timeline = _ensureTimeline(o.timeline, o.createdAt, o.status);
              _orders.add(o);
            }
          }
        }
        _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (e) {
        debugPrint('[OrderService] init error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> reload() async => init();

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _orders.map((o) => o.toMap()).toList();
    await prefs.setString(_kKey, jsonEncode(list));
  }

  // =======================================================
  // ✅ 建立訂單（支援 shipping / paymentMethod / extra）
  // - items 可為 List<Map> / List<OrderItem> / List<CartItem(物件)
  // =======================================================
  Future<Order> createOrder({
    required List items,
    required double total,
    Map<String, dynamic>? shipping,
    String? paymentMethod,
    Map<String, dynamic>? extra,
  }) async {
    final uid = (AuthService.instance.userId.toString().trim().isEmpty)
        ? 'demo_user'
        : AuthService.instance.userId;

    final orderId = 'ord_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final orderItems = <OrderItem>[];

    for (final it in items) {
      if (it is OrderItem) {
        orderItems.add(it);
        continue;
      }

      if (it is Map) {
        orderItems.add(OrderItem.fromMap(Map<String, dynamic>.from(it)));
        continue;
      }

      // ✅ 兼容 CartItem / 其他物件型 item（用 dynamic 取欄位）
      try {
        final dynamic any = it;

        final String pid = (() {
          try {
            final v = any.productId;
            if (v != null && v.toString().trim().isNotEmpty) return v.toString();
          } catch (_) {}
          try {
            final v = any.id;
            if (v != null && v.toString().trim().isNotEmpty) return v.toString();
          } catch (_) {}
          return '';
        })();

        final String name = (() {
          try {
            final v = any.name;
            if (v != null && v.toString().trim().isNotEmpty) return v.toString();
          } catch (_) {}
          try {
            final v = any.title;
            if (v != null && v.toString().trim().isNotEmpty) return v.toString();
          } catch (_) {}
          return '商品';
        })();

        final int qty = (() {
          try {
            final v = any.qty;
            if (v is int) return v;
            return int.tryParse('$v') ?? 1;
          } catch (_) {
            return 1;
          }
        })();

        final double price = (() {
          try {
            final v = any.price;
            if (v is num) return v.toDouble();
            return double.tryParse('$v') ?? 0.0;
          } catch (_) {
            return 0.0;
          }
        })();

        final String? image = (() {
          try {
            final v = any.image;
            if (v != null && v.toString().trim().isNotEmpty) return v.toString();
          } catch (_) {}
          try {
            final v = any.imageUrl;
            if (v != null && v.toString().trim().isNotEmpty) return v.toString();
          } catch (_) {}
          return null;
        })();

        if (pid.trim().isNotEmpty) {
          orderItems.add(
            OrderItem(
              productId: pid,
              name: name,
              qty: qty <= 0 ? 1 : qty,
              price: price < 0 ? 0 : price,
              image: image,
            ),
          );
        }
      } catch (_) {
        // ignore
      }
    }

    final pm = (paymentMethod ?? '').toString().trim();

    // ✅ 若 extra 內有 paymentMethod，同步到欄位（讓 UI 一致）
    final mergedExtra = <String, dynamic>{...(extra ?? {})};
    if (pm.isNotEmpty) mergedExtra['paymentMethod'] = pm;

    final order = Order(
      id: orderId,
      userId: uid,
      createdAt: now,
      totalAmount: total < 0 ? 0 : total,
      status: OrderStatus.placed,
      items: orderItems,
      shipping: shipping,
      paymentMethod: pm.isEmpty ? null : pm,
      extra: mergedExtra.isEmpty ? null : mergedExtra,
      timeline: _ensureTimeline(const [], now, OrderStatus.placed),
    );

    _orders.insert(0, order);
    await _save();

    // 通知：訂單建立
    try {
      NotificationService.instance.addNotification(
        type: 'shop',
        title: '訂單建立成功',
        message: '訂單 $orderId 已建立，等待付款。',
        icon: Icons.shopping_bag_outlined,
      );
    } catch (_) {}

    // 清空購物車（相容不同 CartService 寫法）
    try {
      await CartService.instance.clear();
    } catch (_) {
      try {
        final dynamic any = CartService.instance;
        final r = any.clearAll();
        if (r is Future) await r;
      } catch (_) {}
    }

    notifyListeners();
    return order;
  }

  // =======================================================
  // ✅ 從購物車建立訂單（避免 CartItem → Map 型別錯誤）
  // =======================================================
  Future<Order> placeOrder({
    Map<String, dynamic>? shipping,
    Map<String, dynamic>? extra,
    String? paymentMethod,
  }) async {
    final cart = CartService.instance;
    final cartItems = cart.items;

    if (cartItems.isEmpty) {
      throw Exception('購物車是空的');
    }

    final total = cart.total;
    return createOrder(
      items: cartItems,
      total: total,
      shipping: shipping,
      extra: extra,
      paymentMethod: paymentMethod,
    );
  }

  // =======================================================
  // ✅ 更新出貨資訊（物流單號/承運商/地址…）
  // =======================================================
  Future<void> updateShipping(
    String orderId, {
    String? trackingNumber,
    String? carrier,
    String? address,
    Map<String, dynamic>? extra,
  }) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;

    final o = _orders[idx];
    final s = <String, dynamic>{...(o.shipping ?? {})};

    if (trackingNumber != null) s['trackingNumber'] = trackingNumber;
    if (carrier != null) s['carrier'] = carrier;
    if (address != null) s['address'] = address;
    if (extra != null) s.addAll(extra);

    o.shipping = s;
    o.updatedAt = DateTime.now();

    await _save();
    notifyListeners();

    try {
      NotificationService.instance.addNotification(
        type: 'shop',
        title: '出貨資訊已更新',
        message: '訂單 $orderId 的出貨資訊已更新。',
        icon: Icons.local_shipping_outlined,
      );
    } catch (_) {}
  }

  // =======================================================
  // ✅ 更新訂單狀態（核心：支援 extra）
  // - PaymentStatusPage 建議用：updateStatus(orderId, OrderStatus.paid)
  // =======================================================
  Future<void> updateStatus(
    String orderId,
    String newStatus, {
    Map<String, dynamic>? extra,
    bool silentNotification = false,
  }) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;

    final now = DateTime.now();
    final o = _orders[idx];

    o.status = newStatus;
    o.updatedAt = now;

    if (extra != null && extra.isNotEmpty) {
      o.extra = <String, dynamic>{...(o.extra ?? {}), ...extra};

      // 若 extra 帶 paymentMethod，也同步到欄位
      final pm = (extra['paymentMethod'] ?? '').toString().trim();
      if (pm.isNotEmpty) o.paymentMethod = pm;
    }

    o.timeline = _applyStatusToTimeline(o.timeline, o.createdAt, newStatus, now);

    await _save();
    notifyListeners();

    if (!silentNotification) {
      try {
        NotificationService.instance.addNotification(
          type: 'shop',
          title: '訂單狀態更新',
          message: '訂單 $orderId：${statusLabel(newStatus)}',
          icon: Icons.update_rounded,
        );
      } catch (_) {}
    }
  }

  /// ✅ 舊程式相容：PaymentPage / 舊版頁面常用
  Future<void> updateOrderStatus(String id, String status) async =>
      updateStatus(id, status);

  /// ✅ 舊程式相容：有些頁會呼叫 setPaid
  Future<void> setPaid(String orderId, {String? paymentMethod}) async =>
      markPaid(orderId, paymentMethod: paymentMethod);

  // =======================================================
  // ✅ 付款成功（支援 paymentMethod）
  // =======================================================
  Future<void> markPaid(String orderId, {String? paymentMethod}) async {
    final pm = (paymentMethod ?? '').toString().trim();

    await updateStatus(
      orderId,
      OrderStatus.paid,
      extra: pm.isEmpty ? null : {'paymentMethod': pm},
      silentNotification: true, // 付款成功你通常會另外發通知（PaymentStatusPage）
    );

    // 再次保險：同步存入欄位（方便訂單頁顯示）
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1 && pm.isNotEmpty) {
      _orders[idx].paymentMethod = pm;
      await _save();
      notifyListeners();
    }
  }

  Future<void> cancelOrder(String orderId) async =>
      updateStatus(orderId, OrderStatus.cancelled);

  Future<void> refundOrder(String orderId) async =>
      updateStatus(orderId, OrderStatus.refunded);

  Future<Order?> getById(String id) async {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    _orders.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
    notifyListeners();
  }

  // =======================================================
  // ✅ UI Helper
  // =======================================================
  static String statusLabel(String s) {
    switch (s) {
      case OrderStatus.placed:
        return '已下單';
      case OrderStatus.paid:
        return '已付款';
      case OrderStatus.shipped:
        return '已出貨';
      case OrderStatus.delivered:
        return '已送達';
      case OrderStatus.cancelled:
        return '已取消';
      case OrderStatus.refunded:
        return '已退款';
      default:
        return s;
    }
  }

  static Color statusColor(String s) {
    switch (s) {
      case OrderStatus.placed:
        return Colors.orange;
      case OrderStatus.paid:
        return Colors.blueAccent;
      case OrderStatus.shipped:
        return Colors.indigo;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.grey;
      case OrderStatus.refunded:
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  // =======================================================
  // ✅ timeline helpers（固定順序輸出，避免 map.values 亂序）
  // - 重要：已完成節點不會每次 updateStatus 就改成 now（避免時間跳動）
  // =======================================================
  List<OrderTimelineEvent> _ensureTimeline(
    List<OrderTimelineEvent> timeline,
    DateTime createdAt,
    String status,
  ) {
    if (timeline.isNotEmpty) {
      return _applyStatusToTimeline(timeline, createdAt, status, DateTime.now());
    }

    final base = <OrderTimelineEvent>[
      OrderTimelineEvent(
        key: OrderStatus.placed,
        label: '下單',
        timeMs: createdAt.millisecondsSinceEpoch,
        done: true,
      ),
      OrderTimelineEvent(
        key: OrderStatus.paid,
        label: '付款',
        timeMs: createdAt.millisecondsSinceEpoch,
        done: false,
      ),
      OrderTimelineEvent(
        key: OrderStatus.shipped,
        label: '出貨',
        timeMs: createdAt.millisecondsSinceEpoch,
        done: false,
      ),
      OrderTimelineEvent(
        key: OrderStatus.delivered,
        label: '送達',
        timeMs: createdAt.millisecondsSinceEpoch,
        done: false,
      ),
    ];

    return _applyStatusToTimeline(base, createdAt, status, DateTime.now());
  }

  List<OrderTimelineEvent> _applyStatusToTimeline(
    List<OrderTimelineEvent> timeline,
    DateTime createdAt,
    String status,
    DateTime now,
  ) {
    final map = <String, OrderTimelineEvent>{};
    for (final e in timeline) {
      map[e.key] = e;
    }

    OrderTimelineEvent ensure(String key, String label) {
      return map[key] ??
          OrderTimelineEvent(
            key: key,
            label: label,
            timeMs: createdAt.millisecondsSinceEpoch,
            done: false,
          );
    }

    map[OrderStatus.placed] = ensure(OrderStatus.placed, '下單');
    map[OrderStatus.paid] = ensure(OrderStatus.paid, '付款');
    map[OrderStatus.shipped] = ensure(OrderStatus.shipped, '出貨');
    map[OrderStatus.delivered] = ensure(OrderStatus.delivered, '送達');

    final donePaid = status == OrderStatus.paid ||
        status == OrderStatus.shipped ||
        status == OrderStatus.delivered;
    final doneShipped =
        status == OrderStatus.shipped || status == OrderStatus.delivered;
    final doneDelivered = status == OrderStatus.delivered;

    // placed 永遠 done
    map[OrderStatus.placed] = OrderTimelineEvent(
      key: OrderStatus.placed,
      label: '下單',
      timeMs: map[OrderStatus.placed]!.timeMs,
      done: true,
    );

    map[OrderStatus.paid] = OrderTimelineEvent(
      key: OrderStatus.paid,
      label: '付款',
      timeMs: donePaid
          ? _keepOrNow(map[OrderStatus.paid]!.timeMs, createdAt, now)
          : map[OrderStatus.paid]!.timeMs,
      done: donePaid,
    );

    map[OrderStatus.shipped] = OrderTimelineEvent(
      key: OrderStatus.shipped,
      label: '出貨',
      timeMs: doneShipped
          ? _keepOrNow(map[OrderStatus.shipped]!.timeMs, createdAt, now)
          : map[OrderStatus.shipped]!.timeMs,
      done: doneShipped,
    );

    map[OrderStatus.delivered] = OrderTimelineEvent(
      key: OrderStatus.delivered,
      label: '送達',
      timeMs: doneDelivered
          ? _keepOrNow(map[OrderStatus.delivered]!.timeMs, createdAt, now)
          : map[OrderStatus.delivered]!.timeMs,
      done: doneDelivered,
    );

    // cancelled / refunded 節點
    if (status == OrderStatus.cancelled) {
      map[OrderStatus.cancelled] = OrderTimelineEvent(
        key: OrderStatus.cancelled,
        label: '已取消',
        timeMs: now.millisecondsSinceEpoch,
        done: true,
      );
    } else {
      map.remove(OrderStatus.cancelled);
    }

    if (status == OrderStatus.refunded) {
      map[OrderStatus.refunded] = OrderTimelineEvent(
        key: OrderStatus.refunded,
        label: '退款/退貨',
        timeMs: now.millisecondsSinceEpoch,
        done: true,
      );
    } else {
      map.remove(OrderStatus.refunded);
    }

    // 固定輸出順序
    final keys = <String>[
      OrderStatus.placed,
      OrderStatus.paid,
      OrderStatus.shipped,
      OrderStatus.delivered,
      if (map.containsKey(OrderStatus.cancelled)) OrderStatus.cancelled,
      if (map.containsKey(OrderStatus.refunded)) OrderStatus.refunded,
    ];

    return keys.map((k) => map[k]!).toList();
  }

  int _keepOrNow(int oldMs, DateTime createdAt, DateTime now) {
    // 若仍是 createdAt（預設值），第一次完成狀態就寫入 now
    if (oldMs == createdAt.millisecondsSinceEpoch) {
      return now.millisecondsSinceEpoch;
    }
    // 已有完成時間就保留，不要每次更新狀態都跳動
    return oldMs;
  }
}

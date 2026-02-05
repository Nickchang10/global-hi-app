// lib/models/order_enums.dart
//
// ✅ Osmile 共用狀態列舉（完整版・最終版）
// ------------------------------------------------------------
// 用途：統一管理 Order / Payment / Shipping 各狀態與方法
// 建議 Firestore 存法：一律用 enum.name (小寫/駝峰) 存字串
//
// 可供以下檔案直接 import：
//   - services/order_create_service.dart
//   - services/payment_service.dart
//   - pages/admin_orders_page.dart
//
// 特色：
// - 提供 label（中文顯示）
// - 提供 toFirestore() / fromAny() 解析（相容舊資料：大小寫、底線、短寫、以及 int index）
// - 提供 isFinal / isPending 等常用判斷
// ------------------------------------------------------------

/// 支付提供者（通道）
enum PaymentProvider {
  stripe,
  linepay,
  cod, // Cash on Delivery
}

/// 使用者選擇的支付方式（UI/訂單層級）
enum PaymentMethod {
  creditCard,
  linePay,
  cash,
}

/// 支付狀態（支付層級）
enum PaymentStatus {
  init,
  pending,
  paid,
  failed,
  cancelled,
  cod,
}

/// 訂單狀態（訂單主狀態）
enum OrderStatus {
  draft,
  pendingPayment,
  codPending,
  paid,
  failed,
  cancelled,
  shipped,
  completed,
}

/// 物流狀態（出貨層級）
enum ShippingStatus {
  pending,
  preparing,
  shipped,
  delivered,
  failed,
  returned,
}

// ------------------------------------------------------------
// Labels (UI)
// ------------------------------------------------------------

extension PaymentProviderExt on PaymentProvider {
  String get label {
    switch (this) {
      case PaymentProvider.stripe:
        return '信用卡（Stripe）';
      case PaymentProvider.linepay:
        return 'LINE Pay';
      case PaymentProvider.cod:
        return '貨到付款';
    }
  }

  /// Firestore 建議：存 name
  String toFirestore() => name;
}

extension PaymentMethodExt on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.creditCard:
        return '信用卡';
      case PaymentMethod.linePay:
        return 'LINE Pay';
      case PaymentMethod.cash:
        return '現金 / 貨到付款';
    }
  }

  String toFirestore() => name;
}

extension PaymentStatusExt on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.init:
        return '初始化';
      case PaymentStatus.pending:
        return '待付款';
      case PaymentStatus.paid:
        return '已付款';
      case PaymentStatus.failed:
        return '付款失敗';
      case PaymentStatus.cancelled:
        return '已取消';
      case PaymentStatus.cod:
        return '貨到付款';
    }
  }

  String toFirestore() => name;

  bool get isFinal =>
      this == PaymentStatus.paid ||
      this == PaymentStatus.failed ||
      this == PaymentStatus.cancelled;

  bool get isPending =>
      this == PaymentStatus.init || this == PaymentStatus.pending;
}

extension OrderStatusExt on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.draft:
        return '草稿';
      case OrderStatus.pendingPayment:
        return '待付款';
      case OrderStatus.codPending:
        return '待收貨（貨到付款）';
      case OrderStatus.paid:
        return '已付款';
      case OrderStatus.failed:
        return '失敗';
      case OrderStatus.cancelled:
        return '取消';
      case OrderStatus.shipped:
        return '已出貨';
      case OrderStatus.completed:
        return '已完成';
    }
  }

  String toFirestore() => name;

  bool get isFinal =>
      this == OrderStatus.completed ||
      this == OrderStatus.cancelled ||
      this == OrderStatus.failed;

  bool get isPayRelated =>
      this == OrderStatus.pendingPayment ||
      this == OrderStatus.codPending ||
      this == OrderStatus.paid;
}

extension ShippingStatusExt on ShippingStatus {
  String get label {
    switch (this) {
      case ShippingStatus.pending:
        return '待出貨';
      case ShippingStatus.preparing:
        return '準備中';
      case ShippingStatus.shipped:
        return '已出貨';
      case ShippingStatus.delivered:
        return '已送達';
      case ShippingStatus.failed:
        return '配送失敗';
      case ShippingStatus.returned:
        return '已退貨';
    }
  }

  String toFirestore() => name;

  bool get isFinal =>
      this == ShippingStatus.delivered ||
      this == ShippingStatus.failed ||
      this == ShippingStatus.returned;
}

// ------------------------------------------------------------
// Safe Parsing (Firestore / old data compatibility)
// ------------------------------------------------------------

String _normEnum(dynamic v) {
  if (v == null) return '';

  // ✅ 直接傳入 enum（例如 PaymentStatus.paid）
  if (v is Enum) {
    return v.name
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '');
  }

  final s = v.toString().trim();
  if (s.isEmpty) return '';

  // 轉成統一形式：小寫、去空白、底線與中線全部拿掉
  return s.toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');
}

/// ✅ PaymentProvider 解析（相容：line_pay / linePay / LINEPAY / int index）
PaymentProvider paymentProviderFromAny(
  dynamic v, {
  PaymentProvider fallback = PaymentProvider.stripe,
}) {
  if (v is int) {
    if (v >= 0 && v < PaymentProvider.values.length) return PaymentProvider.values[v];
    return fallback;
  }

  final s = _normEnum(v);
  if (s.isEmpty) return fallback;

  if (s == 'stripe') return PaymentProvider.stripe;
  if (s == 'linepay' || s == 'line') return PaymentProvider.linepay;
  if (s == 'cod' || s == 'cashondelivery' || s == 'cash') return PaymentProvider.cod;

  return fallback;
}

/// ✅ PaymentMethod 解析（相容：credit_card / creditcard / linepay / cash / int index）
PaymentMethod paymentMethodFromAny(
  dynamic v, {
  PaymentMethod fallback = PaymentMethod.cash,
}) {
  if (v is int) {
    if (v >= 0 && v < PaymentMethod.values.length) return PaymentMethod.values[v];
    return fallback;
  }

  final s = _normEnum(v);
  if (s.isEmpty) return fallback;

  if (s == 'creditcard' || s == 'credit' || s == 'card' || s == 'cc') return PaymentMethod.creditCard;
  if (s == 'linepay' || s == 'line') return PaymentMethod.linePay;
  if (s == 'cash' || s == 'cod') return PaymentMethod.cash;

  return fallback;
}

/// ✅ PaymentStatus 解析（相容：PENDING / pending_payment / init / paid / success / int index）
PaymentStatus paymentStatusFromAny(
  dynamic v, {
  PaymentStatus fallback = PaymentStatus.pending,
}) {
  if (v is int) {
    if (v >= 0 && v < PaymentStatus.values.length) return PaymentStatus.values[v];
    return fallback;
  }

  final s = _normEnum(v);
  if (s.isEmpty) return fallback;

  if (s == 'init' || s == 'initialized') return PaymentStatus.init;
  if (s == 'pending' || s == 'pendingpayment' || s == 'unpaid' || s == 'waiting') return PaymentStatus.pending;
  if (s == 'paid' || s == 'success' || s == 'succeeded') return PaymentStatus.paid;
  if (s == 'failed' || s == 'fail' || s == 'error') return PaymentStatus.failed;
  if (s == 'cancelled' || s == 'canceled' || s == 'cancel') return PaymentStatus.cancelled;
  if (s == 'cod' || s == 'cashondelivery') return PaymentStatus.cod;

  return fallback;
}

/// ✅ OrderStatus 解析（相容：pending_payment / cod_pending / shipped / complete / int index）
OrderStatus orderStatusFromAny(
  dynamic v, {
  OrderStatus fallback = OrderStatus.pendingPayment,
}) {
  if (v is int) {
    if (v >= 0 && v < OrderStatus.values.length) return OrderStatus.values[v];
    return fallback;
  }

  final s = _normEnum(v);
  if (s.isEmpty) return fallback;

  if (s == 'draft') return OrderStatus.draft;
  if (s == 'pendingpayment' || s == 'pending' || s == 'unpaid') return OrderStatus.pendingPayment;
  if (s == 'codpending' || s == 'cashondeliverypending') return OrderStatus.codPending;
  if (s == 'paid') return OrderStatus.paid;
  if (s == 'failed' || s == 'fail') return OrderStatus.failed;
  if (s == 'cancelled' || s == 'canceled' || s == 'cancel') return OrderStatus.cancelled;
  if (s == 'shipped' || s == 'shipping') return OrderStatus.shipped;
  if (s == 'completed' || s == 'complete' || s == 'done') return OrderStatus.completed;

  return fallback;
}

/// ✅ ShippingStatus 解析（相容：preparing / in_transit / delivered / returned / int index）
ShippingStatus shippingStatusFromAny(
  dynamic v, {
  ShippingStatus fallback = ShippingStatus.pending,
}) {
  if (v is int) {
    if (v >= 0 && v < ShippingStatus.values.length) return ShippingStatus.values[v];
    return fallback;
  }

  final s = _normEnum(v);
  if (s.isEmpty) return fallback;

  if (s == 'pending') return ShippingStatus.pending;
  if (s == 'preparing' || s == 'packing' || s == 'processing') return ShippingStatus.preparing;
  if (s == 'shipped' || s == 'intransit' || s == 'shipping') return ShippingStatus.shipped;
  if (s == 'delivered' || s == 'arrived') return ShippingStatus.delivered;
  if (s == 'failed' || s == 'fail') return ShippingStatus.failed;
  if (s == 'returned' || s == 'return') return ShippingStatus.returned;

  return fallback;
}

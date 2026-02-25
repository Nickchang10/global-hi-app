// lib/providers/order_provider.dart
//
// ✅ Osmile（前台）OrderProvider｜完整版（可直接貼上編譯）
// ----------------------------------------------------
// ✅ 不依賴 UI（不使用 Icons / material.dart），避免 provider 層混入 Widget 物件
// ✅ 監聽 Firestore orders（僅監聽目前登入者 uid 的訂單）
// ✅ 提供：refresh / createOrder / updateStatus / attachPayment / cancelListening
//
// 需要套件：cloud_firestore, firebase_auth, flutter (foundation)
// ----------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firestore collection
const String kOrdersCollection = 'orders';

/// 常見欄位 keys（你後台若不同，可在這裡統一調整）
class OrderFields {
  static const String uid = 'uid';
  static const String orderNo = 'orderNo';
  static const String items = 'items'; // List<Map>
  static const String currency = 'currency'; // 'TWD'
  static const String subtotal = 'subtotal';
  static const String discount = 'discount';
  static const String shippingFee = 'shippingFee';
  static const String total = 'total';
  static const String status = 'status'; // string
  static const String note = 'note';

  // coupon
  static const String couponId = 'couponId';
  static const String couponCode = 'couponCode';

  // payment
  static const String paymentProvider = 'paymentProvider';
  static const String paymentMethod = 'paymentMethod';
  static const String paymentTxId = 'paymentTxId';
  static const String paymentSuccess = 'paymentSuccess';
  static const String paymentRaw = 'paymentRaw';

  // timestamps
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
}

enum OrderStatus {
  pending,
  unpaid,
  paid,
  preparing,
  shipping,
  delivered,
  completed,
  cancelled,
  failed,
}

String orderStatusToKey(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return 'pending';
    case OrderStatus.unpaid:
      return 'unpaid';
    case OrderStatus.paid:
      return 'paid';
    case OrderStatus.preparing:
      return 'preparing';
    case OrderStatus.shipping:
      return 'shipping';
    case OrderStatus.delivered:
      return 'delivered';
    case OrderStatus.completed:
      return 'completed';
    case OrderStatus.cancelled:
      return 'cancelled';
    case OrderStatus.failed:
      return 'failed';
  }
}

OrderStatus orderStatusFromKey(String? key) {
  switch ((key ?? '').toLowerCase().trim()) {
    case 'pending':
      return OrderStatus.pending;
    case 'unpaid':
      return OrderStatus.unpaid;
    case 'paid':
      return OrderStatus.paid;
    case 'preparing':
      return OrderStatus.preparing;
    case 'shipping':
      return OrderStatus.shipping;
    case 'delivered':
      return OrderStatus.delivered;
    case 'completed':
      return OrderStatus.completed;
    case 'cancelled':
      return OrderStatus.cancelled;
    case 'failed':
      return OrderStatus.failed;
    default:
      return OrderStatus.pending;
  }
}

/// 前台訂單簡易模型（不綁你專案其他 model，也能直接編譯）
@immutable
class OrderDoc {
  final String id;
  final String uid;
  final String orderNo;
  final OrderStatus status;

  final num subtotal;
  final num discount;
  final num shippingFee;
  final num total;

  final String currency;
  final List<Map<String, dynamic>> items;

  final String? couponId;
  final String? couponCode;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 保留整包 raw，方便你 UI/Debug/相容舊欄位
  final Map<String, dynamic> raw;

  const OrderDoc({
    required this.id,
    required this.uid,
    required this.orderNo,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.shippingFee,
    required this.total,
    required this.currency,
    required this.items,
    required this.couponId,
    required this.couponCode,
    required this.createdAt,
    required this.updatedAt,
    required this.raw,
  });

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  static List<Map<String, dynamic>> _toItems(dynamic v) {
    if (v is List) {
      // ✅ prefer_iterable_wheretype: where((e) => e is Map) -> whereType<Map>()
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  factory OrderDoc.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};

    final uid = (data[OrderFields.uid] ?? '').toString();
    final orderNo = (data[OrderFields.orderNo] ?? '').toString();
    final status = orderStatusFromKey(data[OrderFields.status]?.toString());

    final subtotal = _toNum(data[OrderFields.subtotal]);
    final discount = _toNum(data[OrderFields.discount]);
    final shippingFee = _toNum(data[OrderFields.shippingFee]);
    final total = _toNum(data[OrderFields.total]);

    final currency = (data[OrderFields.currency] ?? 'TWD').toString();
    final items = _toItems(data[OrderFields.items]);

    final couponId = data[OrderFields.couponId]?.toString();
    final couponCode = data[OrderFields.couponCode]?.toString();

    final createdAt = _toDate(data[OrderFields.createdAt]);
    final updatedAt = _toDate(data[OrderFields.updatedAt]);

    return OrderDoc(
      id: snap.id,
      uid: uid,
      orderNo: orderNo,
      status: status,
      subtotal: subtotal,
      discount: discount,
      shippingFee: shippingFee,
      total: total,
      currency: currency,
      items: items,
      couponId: couponId,
      couponCode: couponCode,
      createdAt: createdAt,
      updatedAt: updatedAt,
      raw: Map<String, dynamic>.from(data),
    );
  }
}

class OrderProvider extends ChangeNotifier {
  OrderProvider({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  bool _loading = false;
  String? _error;

  List<OrderDoc> _orders = const [];

  bool get loading => _loading;
  String? get error => _error;
  List<OrderDoc> get orders => _orders;

  OrderDoc? byId(String id) {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 你可以在 App 啟動後呼叫一次（例如登入後、或進到訂單頁時）
  void startListeningMyOrders() {
    final user = _auth.currentUser;
    if (user == null) {
      _orders = const [];
      _error = null;
      _loading = false;
      _cancelSub();
      notifyListeners();
      return;
    }

    // 避免重複訂閱
    _cancelSub();

    _loading = true;
    _error = null;
    notifyListeners();

    final q = _db
        .collection(kOrdersCollection)
        .where(OrderFields.uid, isEqualTo: user.uid)
        .orderBy(OrderFields.createdAt, descending: true);

    _sub = q.snapshots().listen(
      (snap) {
        _orders = snap.docs.map((d) => OrderDoc.fromSnapshot(d)).toList();
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _loading = false;
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  /// 手動刷新一次（不開監聽也可以用）
  Future<void> refreshMyOrdersOnce() async {
    final user = _auth.currentUser;
    if (user == null) {
      _orders = const [];
      _error = null;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final snap = await _db
          .collection(kOrdersCollection)
          .where(OrderFields.uid, isEqualTo: user.uid)
          .orderBy(OrderFields.createdAt, descending: true)
          .get();

      _orders = snap.docs.map((d) => OrderDoc.fromSnapshot(d)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// ✅ 前台建立訂單（Checkout 送出用）
  /// - items: 每個 item 建議包含 productId, name, price, qty, image 等（你可自由擴充）
  /// - 回傳：orderDocId
  Future<String> createOrder({
    required List<Map<String, dynamic>> items,
    String currency = 'TWD',
    num subtotal = 0,
    num discount = 0,
    num shippingFee = 0,
    num total = 0,
    String? note,
    String? couponId,
    String? couponCode,
    OrderStatus initialStatus = OrderStatus.pending,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not logged in');
    }

    final now = FieldValue.serverTimestamp();

    // 你也可以把 orderNo 改成更漂亮的規則（例如年月日+流水號）
    final orderNo = 'OD-${DateTime.now().millisecondsSinceEpoch}';

    final payload = <String, dynamic>{
      OrderFields.uid: user.uid,
      OrderFields.orderNo: orderNo,
      OrderFields.items: items,
      OrderFields.currency: currency,
      OrderFields.subtotal: subtotal,
      OrderFields.discount: discount,
      OrderFields.shippingFee: shippingFee,
      OrderFields.total: total,
      OrderFields.status: orderStatusToKey(initialStatus),
      if (note != null && note.trim().isNotEmpty) OrderFields.note: note.trim(),
      if (couponId != null && couponId.trim().isNotEmpty)
        OrderFields.couponId: couponId.trim(),
      if (couponCode != null && couponCode.trim().isNotEmpty)
        OrderFields.couponCode: couponCode.trim(),
      OrderFields.createdAt: now,
      OrderFields.updatedAt: now,
    };

    final ref = await _db.collection(kOrdersCollection).add(payload);
    return ref.id;
  }

  /// ✅ 更新狀態（前台常用：付款成功 -> paid；或取消 -> cancelled）
  Future<void> updateOrderStatus({
    required String orderDocId,
    required OrderStatus status,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _db.collection(kOrdersCollection).doc(orderDocId).update({
      OrderFields.status: orderStatusToKey(status),
      OrderFields.updatedAt: now,
    });
  }

  /// ✅ 綁定付款結果（PaymentPage / PaymentStatusPage 常用）
  Future<void> attachPaymentResult({
    required String orderDocId,
    required bool success,
    String? provider,
    String? method,
    String? transactionId,
    Map<String, dynamic>? raw,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _db.collection(kOrdersCollection).doc(orderDocId).set({
      OrderFields.paymentSuccess: success,
      if (provider != null) OrderFields.paymentProvider: provider,
      if (method != null) OrderFields.paymentMethod: method,
      if (transactionId != null) OrderFields.paymentTxId: transactionId,
      if (raw != null) OrderFields.paymentRaw: raw,
      OrderFields.updatedAt: now,
      // success 時順便把狀態推到 paid（你要改成其它狀態也可以）
      if (success) OrderFields.status: orderStatusToKey(OrderStatus.paid),
      if (!success) OrderFields.status: orderStatusToKey(OrderStatus.failed),
    }, SetOptions(merge: true));
  }

  void cancelListening() {
    _cancelSub();
  }

  void _cancelSub() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    _cancelSub();
    super.dispose();
  }
}

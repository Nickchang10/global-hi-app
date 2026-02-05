// lib/services/order_create_service.dart
//
// ✅ OrderCreateService（完整版・強化可編譯最終版）
//
// 功能重點
// - Transaction 建立「待付款」訂單（status=pendingPayment + payment.status=pending）
// - 交易內讀取 products/{productId}：鎖定價格/標題/圖片/vendorId（避免前端被竄改）
// - 支援 coupon（percent / fixed）驗證與折抵（可選）
// - 支援運費（固定/滿額免運/依 method）
// - 支援 idempotencyKey：避免重複按下付款造成重複訂單
// - 支援 vendorId 推導（同 vendor 才能自動推導）
// - 產出一致欄位：items/subtotal/discount/shippingFee/total/payment/shipping/timeline
//
// 依賴：cloud_firestore, firebase_auth
//
// ⚠️ 重要：本檔已改為 Firestore 存 enum.name（字串）
// - order.status: OrderStatus.xxx.name
// - payment.status: PaymentStatus.xxx.name
// - shipping.status: ShippingStatus.xxx.name

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/order_enums.dart';

class OrderCreateException implements Exception {
  final String code;
  final String message;
  OrderCreateException(this.code, this.message);

  @override
  String toString() => 'OrderCreateException($code): $message';
}

class OrderItemInput {
  /// 必填：商品 id（對應 products/{id}）
  final String productId;

  /// 必填：數量
  final num qty;

  /// 可選：若 allowMissingProducts=true 且商品不存在，用 fallback 建單
  final String? fallbackTitle;
  final num? fallbackPrice;
  final String? fallbackImage;

  const OrderItemInput({
    required this.productId,
    required this.qty,
    this.fallbackTitle,
    this.fallbackPrice,
    this.fallbackImage,
  });
}

class OrderShippingInput {
  final String? method; // home_delivery / cvs / ...
  final String? name;
  final String? phone;
  final String? address;
  final String? note;
  final Map<String, dynamic>? extra;

  const OrderShippingInput({
    this.method,
    this.name,
    this.phone,
    this.address,
    this.note,
    this.extra,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        if ((method ?? '').trim().isNotEmpty) 'method': method!.trim(),
        if ((name ?? '').trim().isNotEmpty) 'name': name!.trim(),
        if ((phone ?? '').trim().isNotEmpty) 'phone': phone!.trim(),
        if ((address ?? '').trim().isNotEmpty) 'address': address!.trim(),
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        if (extra != null) 'extra': extra,

        // ✅ 存字串（enum.name）
        'status': ShippingStatus.pending.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class CouponResult {
  final String code;
  final String type; // percent/fixed
  final num value;
  final num discount;
  final Map<String, dynamic> raw;

  const CouponResult({
    required this.code,
    required this.type,
    required this.value,
    required this.discount,
    required this.raw,
  });

  Map<String, dynamic> toOrderMap() => <String, dynamic>{
        'code': code,
        'type': type,
        'value': value,
        'discount': discount,
      };
}

class ShippingFeePolicy {
  /// 固定運費（預設 0）
  final num flatFee;

  /// 滿額免運門檻（<=0 表示不啟用）
  final num freeOver;

  /// 依照 method 不同運費（例如 {"cvs": 60, "home_delivery": 100}）
  final Map<String, num> feeByMethod;

  const ShippingFeePolicy({
    this.flatFee = 0,
    this.freeOver = 0,
    this.feeByMethod = const {},
  });

  num resolve({
    required num subtotalAfterDiscount,
    required String shippingMethod,
  }) {
    final m = shippingMethod.trim().toLowerCase();
    final byMethod = feeByMethod[m];
    final base = byMethod ?? flatFee;

    if (freeOver > 0 && subtotalAfterDiscount >= freeOver) return 0;
    return base < 0 ? 0 : base;
  }
}

class CreateOrderRequest {
  final List<OrderItemInput> items;

  /// buyer
  final String? buyerUid;
  final String? buyerEmail;
  final String? buyerName;

  /// 由商品 vendorId 推導；或由呼叫端指定
  final String? vendorId;

  /// coupon
  final String? couponCode;

  /// shipping
  final OrderShippingInput? shipping;

  /// payment method（僅寫入 order.payment.method）
  final String? paymentMethod;

  /// 幣別
  final String currency;

  /// idempotency：避免重複訂單（建議：用付款單號 / checkout session id）
  final String? idempotencyKey;

  /// 若 true：商品不存在仍允許建立（會用 fallback 欄位）
  final bool allowMissingProducts;

  /// 若 false：商品 isActive != true 則拒絕建立
  final bool allowInactiveProducts;

  /// 額外資料（會寫入 order.extra）
  final Map<String, dynamic>? extra;

  /// 備註
  final String? note;

  const CreateOrderRequest({
    required this.items,
    this.buyerUid,
    this.buyerEmail,
    this.buyerName,
    this.vendorId,
    this.couponCode,
    this.shipping,
    this.paymentMethod,
    this.currency = 'TWD',
    this.idempotencyKey,
    this.allowMissingProducts = false,
    this.allowInactiveProducts = true,
    this.extra,
    this.note,
  });
}

class CreateOrderResult {
  final String orderId;
  final num subtotal;
  final num discount;
  final num shippingFee;
  final num total;
  final String currency;

  /// ✅ 回傳 enum.name（字串）
  final String status;
  final String paymentStatus;

  final String? vendorId;
  final CouponResult? coupon;

  const CreateOrderResult({
    required this.orderId,
    required this.subtotal,
    required this.discount,
    required this.shippingFee,
    required this.total,
    required this.currency,
    required this.status,
    required this.paymentStatus,
    required this.vendorId,
    required this.coupon,
  });

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'subtotal': subtotal,
        'discount': discount,
        'shippingFee': shippingFee,
        'total': total,
        'currency': currency,
        'status': status,
        'paymentStatus': paymentStatus,
        'vendorId': vendorId,
        'coupon': coupon?.toOrderMap(),
      };
}

class OrderCreateService {
  OrderCreateService({
    FirebaseFirestore? firestore,
    this.shippingFeePolicy = const ShippingFeePolicy(),
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final ShippingFeePolicy shippingFeePolicy;

  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');
  CollectionReference<Map<String, dynamic>> get _products => _db.collection('products');
  CollectionReference<Map<String, dynamic>> get _coupons => _db.collection('coupons');
  CollectionReference<Map<String, dynamic>> get _idem => _db.collection('order_idempotency');

  String _s(dynamic v) => (v ?? '').toString().trim();

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(_s(v)) ?? 0;
  }

  String _safeDocId(String raw, {required String fieldName}) {
    final s = _s(raw);
    if (s.isEmpty) return '';
    if (s.contains('/')) {
      throw OrderCreateException('invalid_$fieldName', '$fieldName 不可包含 "/"');
    }
    return s;
  }

  // ------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------

  /// ✅ 兼容 checkout_page.dart 呼叫：createOrder(...) -> 回傳 orderId
  Future<String> createOrder({
    required List<OrderItemInput> items,
    String? buyerUid,
    String? buyerEmail,
    String? buyerName,
    String? vendorId,
    String? couponCode,
    OrderShippingInput? shipping,
    String? paymentMethod,
    String currency = 'TWD',
    String? idempotencyKey,
    bool allowMissingProducts = false,
    bool allowInactiveProducts = true,
    Map<String, dynamic>? extra,
    String? note,
  }) async {
    final res = await createPendingPaymentOrder(
      CreateOrderRequest(
        items: items,
        buyerUid: buyerUid,
        buyerEmail: buyerEmail,
        buyerName: buyerName,
        vendorId: vendorId,
        couponCode: couponCode,
        shipping: shipping,
        paymentMethod: paymentMethod,
        currency: currency,
        idempotencyKey: idempotencyKey,
        allowMissingProducts: allowMissingProducts,
        allowInactiveProducts: allowInactiveProducts,
        extra: extra,
        note: note,
      ),
    );
    return res.orderId;
  }

  /// 以目前登入 user 建立訂單（快捷）
  Future<CreateOrderResult> createPendingPaymentOrderForCurrentUser({
    required List<OrderItemInput> items,
    String? couponCode,
    OrderShippingInput? shipping,
    String? paymentMethod,
    String currency = 'TWD',
    String? idempotencyKey,
    String? vendorId,
    bool allowMissingProducts = false,
    bool allowInactiveProducts = true,
    Map<String, dynamic>? extra,
    String? note,
  }) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      throw OrderCreateException('no_user', '目前沒有登入使用者');
    }

    return createPendingPaymentOrder(
      CreateOrderRequest(
        items: items,
        buyerUid: u.uid,
        buyerEmail: u.email,
        buyerName: u.displayName,
        couponCode: couponCode,
        shipping: shipping,
        paymentMethod: paymentMethod,
        currency: currency,
        idempotencyKey: idempotencyKey,
        vendorId: vendorId,
        allowMissingProducts: allowMissingProducts,
        allowInactiveProducts: allowInactiveProducts,
        extra: extra,
        note: note,
      ),
    );
  }

  /// 建立 pendingPayment 訂單（Transaction）
  Future<CreateOrderResult> createPendingPaymentOrder(CreateOrderRequest req) async {
    if (req.items.isEmpty) {
      throw OrderCreateException('empty_items', '購物車沒有任何商品');
    }

    // qty sanity + productId docId safety
    for (final it in req.items) {
      final pid = _safeDocId(_s(it.productId), fieldName: 'productId');
      if (pid.isEmpty) {
        throw OrderCreateException('invalid_item', '商品 productId 不可為空');
      }
      final q = _toNum(it.qty);
      if (q <= 0) {
        throw OrderCreateException('invalid_qty', '商品數量必須大於 0（$pid）');
      }
    }

    final idemKey = _safeDocId(_s(req.idempotencyKey), fieldName: 'idempotencyKey');
    final couponCode = _s(req.couponCode);
    final paymentMethod = _s(req.paymentMethod);
    final currency = _s(req.currency).isEmpty ? 'TWD' : _s(req.currency);

    final result = await _db.runTransaction<CreateOrderResult>((tx) async {
      // 1) idempotency check
      if (idemKey.isNotEmpty) {
        final idemRef = _idem.doc(idemKey);
        final idemSnap = await tx.get(idemRef);
        if (idemSnap.exists) {
          final m = idemSnap.data() ?? <String, dynamic>{};
          final existing = _s(m['orderId']);
          if (existing.isNotEmpty) {
            final orderSnap = await tx.get(_orders.doc(existing));
            if (orderSnap.exists) {
              final od = orderSnap.data() ?? <String, dynamic>{};
              return _resultFromOrder(existing, od);
            }
            // mapping 存在但 order 不在：容錯 -> 繼續建單
          }
        }
      }

      // 2) 讀取 products，建立 items（鎖定價格/名稱/vendorId）
      final builtItems = <Map<String, dynamic>>[];
      final vendorIds = <String>{};

      num subtotal = 0;

      for (final input in req.items) {
        final pid = _safeDocId(_s(input.productId), fieldName: 'productId');
        final qty = _toNum(input.qty);
        final qtySafe = qty <= 0 ? 1 : qty;

        final prodRef = _products.doc(pid);
        final prodSnap = await tx.get(prodRef);

        if (!prodSnap.exists) {
          if (!req.allowMissingProducts) {
            throw OrderCreateException('product_not_found', '找不到商品：$pid');
          }
          final title = _s(input.fallbackTitle);
          final price = _toNum(input.fallbackPrice);
          if (title.isEmpty || price <= 0) {
            throw OrderCreateException('product_missing_fallback', '商品不存在且 fallback 資料不足：$pid');
          }

          final subtotalLine = price * qtySafe;
          subtotal += subtotalLine;

          builtItems.add({
            'productId': pid,
            'title': title,
            'qty': qtySafe,
            'price': price,
            'subtotal': subtotalLine,
            if (_s(input.fallbackImage).isNotEmpty) 'image': _s(input.fallbackImage),
            'source': 'fallback',
          });
          continue;
        }

        final m = prodSnap.data() ?? <String, dynamic>{};

        final isActive = m['isActive'] == true;
        if (!req.allowInactiveProducts && !isActive) {
          throw OrderCreateException('product_inactive', '商品未上架：$pid');
        }

        final title = _s(m['title']).isEmpty ? pid : _s(m['title']);
        final price = _toNum(m['price']);
        if (price < 0) {
          throw OrderCreateException('invalid_price', '商品價格異常：$pid');
        }

        // images 可能混雜型別，做安全轉字串
        final rawImages = (m['images'] is List) ? (m['images'] as List) : const [];
        final imgs = rawImages.map((e) => _s(e)).where((e) => e.isNotEmpty).toList();
        final image = imgs.isNotEmpty ? imgs.first : _s(m['imageUrl']);

        final vId = _s(m['vendorId']);
        if (vId.isNotEmpty) vendorIds.add(vId);

        final subtotalLine = price * qtySafe;
        subtotal += subtotalLine;

        builtItems.add({
          'productId': pid,
          'title': title,
          'qty': qtySafe,
          'price': price,
          'subtotal': subtotalLine,
          if (image.isNotEmpty) 'image': image,
          if (vId.isNotEmpty) 'vendorId': vId,
          'source': 'products',
        });
      }

      // 3) vendorId 推導（若 req.vendorId 未指定）
      String vendorId = _s(req.vendorId);
      if (vendorId.isEmpty) {
        if (vendorIds.length == 1) {
          vendorId = vendorIds.first;
        } else if (vendorIds.isEmpty) {
          vendorId = '';
        } else {
          throw OrderCreateException('multi_vendor', '同一筆訂單包含多個 vendorId，請先拆單');
        }
      }

      // 4) coupon 驗證與折抵
      CouponResult? coupon;
      num discount = 0;

      if (couponCode.isNotEmpty) {
        final safeCouponDocId = _safeDocId(couponCode.toUpperCase(), fieldName: 'couponCode');
        coupon = await _validateAndComputeCoupon(
          tx,
          code: safeCouponDocId,
          buyerUid: _s(req.buyerUid),
          subtotal: subtotal,
        );
        discount = coupon.discount;
      }

      // 5) 運費
      final shippingMethod = _s(req.shipping?.method);
      final subtotalAfterDiscount = (subtotal - discount) < 0 ? 0 : (subtotal - discount);
      final shippingFee = shippingFeePolicy.resolve(
        subtotalAfterDiscount: subtotalAfterDiscount,
        shippingMethod: shippingMethod,
      );

      // 6) total
      final total = (subtotalAfterDiscount + shippingFee) < 0 ? 0 : (subtotalAfterDiscount + shippingFee);

      // 7) 建立 orders doc
      final orderRef = _orders.doc(); // auto id
      final orderId = orderRef.id;

      final orderData = <String, dynamic>{
        'id': orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // ✅ 存字串（enum.name）
        'status': OrderStatus.pendingPayment.name,

        'currency': currency,
        'vendorId': vendorId.isEmpty ? null : vendorId,
        'buyerUid': _s(req.buyerUid).isEmpty ? null : _s(req.buyerUid),
        'buyerEmail': _s(req.buyerEmail).isEmpty ? null : _s(req.buyerEmail),
        'buyerName': _s(req.buyerName).isEmpty ? null : _s(req.buyerName),

        'items': builtItems,
        'subtotal': subtotal,
        'discount': discount,
        'shippingFee': shippingFee,
        'total': total,

        // 舊欄位相容
        'amount': total,

        if (_s(req.note).isNotEmpty) 'note': _s(req.note),
        if (req.extra != null) 'extra': req.extra,

        'payment': {
          // ✅ 存字串（enum.name）
          'status': PaymentStatus.pending.name,
          if (paymentMethod.isNotEmpty) 'method': paymentMethod,
          'updatedAt': FieldValue.serverTimestamp(),
        },

        if (req.shipping != null) 'shipping': req.shipping!.toMap(),
        if (coupon != null) 'coupon': coupon.toOrderMap(),

        'timeline': [
          {
            'type': 'created',
            'at': FieldValue.serverTimestamp(),
            'msg': 'order created (pending payment)',
            if (idemKey.isNotEmpty) 'idempotencyKey': idemKey,
          }
        ],
      };

      tx.set(orderRef, orderData, SetOptions(merge: true));

      // 8) idempotency mapping
      if (idemKey.isNotEmpty) {
        tx.set(
          _idem.doc(idemKey),
          {
            'orderId': orderId,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // 9) coupon usage（可選）
      if (coupon != null) {
        _commitCouponRedemption(tx, coupon: coupon, buyerUid: _s(req.buyerUid), orderId: orderId);
      }

      return CreateOrderResult(
        orderId: orderId,
        subtotal: subtotal,
        discount: discount,
        shippingFee: shippingFee,
        total: total,
        currency: currency,
        status: OrderStatus.pendingPayment.name,
        paymentStatus: PaymentStatus.pending.name,
        vendorId: vendorId.isEmpty ? null : vendorId,
        coupon: coupon,
      );
    });

    return result;
  }

  // ------------------------------------------------------------
  // Coupon（交易內）
  // ------------------------------------------------------------

  Future<CouponResult> _validateAndComputeCoupon(
    Transaction tx, {
    required String code,
    required String buyerUid,
    required num subtotal,
  }) async {
    final c = _safeDocId(_s(code).toUpperCase(), fieldName: 'couponCode');
    if (c.isEmpty) {
      throw OrderCreateException('invalid_coupon', '優惠碼不可為空');
    }

    final ref = _coupons.doc(c);
    final snap = await tx.get(ref);

    if (!snap.exists) {
      throw OrderCreateException('coupon_not_found', '找不到優惠碼：$c');
    }

    final m = snap.data() ?? <String, dynamic>{};

    final isActive = m['isActive'] == true;
    if (!isActive) throw OrderCreateException('coupon_inactive', '優惠碼未啟用：$c');

    final type = _s(m['type']).toLowerCase();
    final value = _toNum(m['value']);

    if (type != 'percent' && type != 'fixed') {
      throw OrderCreateException('coupon_type_invalid', '優惠碼設定錯誤（type）：$c');
    }
    if (value <= 0) {
      throw OrderCreateException('coupon_value_invalid', '優惠碼設定錯誤（value）：$c');
    }

    // 時間窗（可選）
    final startsAt = m['startsAt'];
    final endsAt = m['endsAt'];
    final now = DateTime.now();

    DateTime? sAt;
    DateTime? eAt;
    if (startsAt is Timestamp) sAt = startsAt.toDate();
    if (endsAt is Timestamp) eAt = endsAt.toDate();

    if (sAt != null && now.isBefore(sAt)) {
      throw OrderCreateException('coupon_not_started', '優惠碼尚未開始：$c');
    }
    if (eAt != null && now.isAfter(eAt)) {
      throw OrderCreateException('coupon_expired', '優惠碼已過期：$c');
    }

    // 最低消費（可選）
    final minSpend = _toNum(m['minSpend']);
    if (minSpend > 0 && subtotal < minSpend) {
      throw OrderCreateException('coupon_min_spend', '未達最低消費（$minSpend）');
    }

    // usage limit（可選）
    final usageLimit = (m['usageLimit'] is num) ? (m['usageLimit'] as num).toInt() : 0;
    final usedCount = (m['usedCount'] is num) ? (m['usedCount'] as num).toInt() : 0;
    if (usageLimit > 0 && usedCount >= usageLimit) {
      throw OrderCreateException('coupon_usage_limit', '優惠碼已達使用上限');
    }

    // per-user limit（可選）
    final perUserLimit = (m['perUserLimit'] is num) ? (m['perUserLimit'] as num).toInt() : 0;
    if (perUserLimit > 0 && buyerUid.trim().isNotEmpty) {
      final userRedRef = _coupons.doc(c).collection('redemptions').doc(buyerUid.trim());
      final userRedSnap = await tx.get(userRedRef);
      final userRed = userRedSnap.data() ?? <String, dynamic>{};
      final userUsed = (userRed['count'] is num) ? (userRed['count'] as num).toInt() : 0;
      if (userUsed >= perUserLimit) {
        throw OrderCreateException('coupon_user_limit', '此帳號已達該優惠碼使用上限');
      }
    }

    // discount calc
    num discount;
    if (type == 'percent') {
      // value = 10 表示 10%
      final rate = value / 100;
      discount = subtotal * rate;
    } else {
      discount = value;
    }

    // max discount（可選）
    final maxDiscount = _toNum(m['maxDiscount']);
    if (maxDiscount > 0 && discount > maxDiscount) discount = maxDiscount;

    // 不可超過 subtotal
    if (discount > subtotal) discount = subtotal;
    if (discount < 0) discount = 0;

    return CouponResult(
      code: c,
      type: type,
      value: value,
      discount: discount,
      raw: m,
    );
  }

  void _commitCouponRedemption(
    Transaction tx, {
    required CouponResult coupon,
    required String buyerUid,
    required String orderId,
  }) {
    final code = coupon.code.toUpperCase();

    // usedCount++
    final couponRef = _coupons.doc(code);
    tx.set(
      couponRef,
      {
        'usedCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // per-user redemption count
    if (buyerUid.trim().isNotEmpty) {
      final userRef = couponRef.collection('redemptions').doc(buyerUid.trim());
      tx.set(
        userRef,
        {
          'uid': buyerUid.trim(),
          'lastOrderId': orderId,
          'count': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------

  CreateOrderResult _resultFromOrder(String orderId, Map<String, dynamic> od) {
    final subtotal = _toNum(od['subtotal']);
    final discount = _toNum(od['discount']);
    final shippingFee = _toNum(od['shippingFee']);
    final total = _toNum(od['total'] ?? od['amount']);

    final status = orderStatusFromAny(od['status'], fallback: OrderStatus.pendingPayment).name;

    final payAny = od['payment'];
    final pay = (payAny is Map) ? Map<String, dynamic>.from(payAny as Map) : <String, dynamic>{};
    final paymentStatus = paymentStatusFromAny(pay['status'], fallback: PaymentStatus.pending).name;

    CouponResult? coupon;
    final cAny = od['coupon'];
    if (cAny is Map) {
      final c = Map<String, dynamic>.from(cAny as Map);
      final code = _s(c['code']).toUpperCase();
      final type = _s(c['type']).toLowerCase();
      final value = _toNum(c['value']);
      final disc = _toNum(c['discount']);
      if (code.isNotEmpty) {
        coupon = CouponResult(code: code, type: type, value: value, discount: disc, raw: c);
      }
    }

    final currency = _s(od['currency']).isEmpty ? 'TWD' : _s(od['currency']);
    final vendorId = _s(od['vendorId']).isEmpty ? null : _s(od['vendorId']);

    return CreateOrderResult(
      orderId: orderId,
      subtotal: subtotal,
      discount: discount,
      shippingFee: shippingFee,
      total: total,
      currency: currency,
      status: status,
      paymentStatus: paymentStatus,
      vendorId: vendorId,
      coupon: coupon,
    );
  }
}

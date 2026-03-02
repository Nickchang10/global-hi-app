// lib/services/checkout/checkout_submit_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CheckoutSubmitResult {
  final String orderId;
  CheckoutSubmitResult({required this.orderId});
}

class CheckoutSubmitService {
  CheckoutSubmitService._();
  static final CheckoutSubmitService instance = CheckoutSubmitService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _s(dynamic v) => (v ?? '').toString().trim();

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    final s = v.toString().replaceAll(',', '').trim();
    return int.tryParse(s) ?? (double.tryParse(s)?.round() ?? 0);
  }

  int _qtyOf(Map<String, dynamic> it) {
    final q = _toInt(it['qty'] ?? it['quantity'] ?? 1);
    return q <= 0 ? 1 : q;
  }

  int _unitPriceOf(Map<String, dynamic> it) {
    return _toInt(
      it['unitPriceSnapshot'] ??
          it['priceSnapshot'] ??
          it['unitPrice'] ??
          it['price'] ??
          it['amount'] ??
          0,
    );
  }

  int _lineTotalOf(Map<String, dynamic> it) {
    final lt = _toInt(it['lineTotalSnapshot'] ?? it['lineTotal']);
    if (lt > 0) return lt;
    return _unitPriceOf(it) * _qtyOf(it);
  }

  int _calcSubtotal(List<Map<String, dynamic>> items) {
    int sum = 0;
    for (final it in items) {
      sum += _lineTotalOf(it);
    }
    return sum;
  }

  int _shippingFee(String shippingMethod, int subtotal) {
    if (shippingMethod != 'standard') return 0;
    return subtotal >= 999 ? 0 : 80;
  }

  List<Map<String, dynamic>> _normalizeItems(List<Map<String, dynamic>> raw) {
    final out = <Map<String, dynamic>>[];

    for (final it in raw) {
      final productId = _s(it['productId'] ?? it['id'] ?? it['pid']);
      final title = _s(
        it['title'] ?? it['name'] ?? it['productTitle'] ?? '未命名商品',
      );
      final imageUrl = _s(it['imageUrl'] ?? it['image'] ?? it['img'] ?? '');

      final qty = _qtyOf(it);
      final unitPrice = _unitPriceOf(it);
      final lineTotal = _lineTotalOf(it);

      out.add({
        'productId': productId,
        'nameSnapshot': title,
        'imageUrlSnapshot': imageUrl,
        'qty': qty,
        'unitPriceSnapshot': unitPrice < 0 ? 0 : unitPrice,
        'priceSnapshot': unitPrice < 0 ? 0 : unitPrice, // 保留舊欄位
        'lineTotalSnapshot': lineTotal < 0 ? 0 : lineTotal,
      });
    }

    return out;
  }

  Future<List<Map<String, dynamic>>> _loadCartItems(String uid) async {
    // 1) users/{uid}/cart_items
    try {
      final a = await _db
          .collection('users')
          .doc(uid)
          .collection('cart_items')
          .get();
      if (a.docs.isNotEmpty) {
        return a.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
      }
    } catch (_) {}

    // 2) carts/{uid}/items
    try {
      final b = await _db
          .collection('carts')
          .doc(uid)
          .collection('items')
          .get();
      return b.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _clearCart(String uid) async {
    // users/{uid}/cart_items
    try {
      final a = await _db
          .collection('users')
          .doc(uid)
          .collection('cart_items')
          .get();
      final batch = _db.batch();
      for (final d in a.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (_) {}

    // carts/{uid}/items
    try {
      final b = await _db
          .collection('carts')
          .doc(uid)
          .collection('items')
          .get();
      final batch = _db.batch();
      for (final d in b.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<CheckoutSubmitResult> placeOrderDirect({
    required String receiverName,
    required String receiverPhone,
    required String receiverAddress,
    required String shippingMethod,
    required String paymentMethod,
    String? couponCode,
    required List<Map<String, dynamic>> directItems,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('請先登入');
    if (directItems.isEmpty) throw Exception('沒有商品');

    final normalized = _normalizeItems(directItems);

    return _createOrder(
      uid: uid,
      items: normalized,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      receiverAddress: receiverAddress,
      shippingMethod: shippingMethod,
      paymentMethod: paymentMethod,
      couponCode: couponCode,
      clearCartAfter: false,
      source: 'direct',
    );
  }

  Future<CheckoutSubmitResult> placeOrderFromCart({
    required String receiverName,
    required String receiverPhone,
    required String receiverAddress,
    required String shippingMethod,
    required String paymentMethod,
    String? couponCode,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('請先登入');

    final cartRaw = await _loadCartItems(uid);
    if (cartRaw.isEmpty) throw Exception('購物車是空的');

    final normalized = _normalizeItems(cartRaw);

    return _createOrder(
      uid: uid,
      items: normalized,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      receiverAddress: receiverAddress,
      shippingMethod: shippingMethod,
      paymentMethod: paymentMethod,
      couponCode: couponCode,
      clearCartAfter: true,
      source: 'cart',
    );
  }

  Future<CheckoutSubmitResult> _createOrder({
    required String uid,
    required List<Map<String, dynamic>> items,
    required String receiverName,
    required String receiverPhone,
    required String receiverAddress,
    required String shippingMethod,
    required String paymentMethod,
    String? couponCode,
    required bool clearCartAfter,
    required String source,
  }) async {
    if (items.isEmpty) throw Exception('沒有商品');

    final subtotal = _calcSubtotal(items);
    final shippingFee = _shippingFee(shippingMethod, subtotal);

    // 先不做折扣，符合你目前 UI 折扣=0
    final discount = 0;

    final total = subtotal + shippingFee - discount;
    if (total < 0) throw Exception('金額異常（total < 0）');

    final ref = _db.collection('orders').doc();

    final normalizedCoupon = (couponCode ?? '').trim();
    final couponOut = normalizedCoupon.isEmpty
        ? null
        : normalizedCoupon.toUpperCase();

    final payload = <String, dynamic>{
      'uid': uid,
      'buyerUid': uid,
      'userId': uid,

      'status': 'created',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),

      'source': source,

      'items': items,

      // 舊欄位（你原本就有）
      'subtotal': subtotal,
      'shippingFee': shippingFee,
      'discount': discount,
      'total': total,

      // ✅ 新增 pricing 快照（不破壞舊欄位）
      'pricing': {
        'subTotal': subtotal,
        'shippingFee': shippingFee,
        'discount': discount,
        'total': total,
        'currency': 'TWD',
        if (couponOut != null) 'couponCode': couponOut,
      },

      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'receiverAddress': receiverAddress,

      'shippingMethod': shippingMethod,
      'paymentMethod': paymentMethod,

      if (couponOut != null) 'couponCode': couponOut,
    };

    await ref.set(payload);

    if (clearCartAfter) {
      await _clearCart(uid);
    }

    return CheckoutSubmitResult(orderId: ref.id);
  }
}

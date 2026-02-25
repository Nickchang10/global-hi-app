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

  int _calcSubtotal(List<Map<String, dynamic>> items) {
    int sum = 0;
    for (final it in items) {
      final price = _toInt(
        it['priceSnapshot'] ?? it['price'] ?? it['unitPrice'],
      );
      final qty = _toInt(it['qty'] ?? it['quantity'] ?? 1);
      sum += price * (qty <= 0 ? 1 : qty);
    }
    return sum;
  }

  int _shippingFee(String shippingMethod, int subtotal) {
    if (shippingMethod != 'standard') return 0;
    return subtotal >= 999 ? 0 : 80;
  }

  /// 將 direct/cart items 統一成 order items 結構
  List<Map<String, dynamic>> _normalizeItems(List<Map<String, dynamic>> raw) {
    final out = <Map<String, dynamic>>[];

    for (final it in raw) {
      final productId = _s(it['productId'] ?? it['id'] ?? it['pid']);
      final title = _s(
        it['title'] ?? it['name'] ?? it['productTitle'] ?? '未命名商品',
      );
      final qty = _toInt(it['qty'] ?? it['quantity'] ?? 1);
      final price = _toInt(
        it['price'] ?? it['unitPrice'] ?? it['priceSnapshot'],
      );

      out.add({
        'productId': productId,
        'nameSnapshot': title,
        'qty': qty <= 0 ? 1 : qty,
        'priceSnapshot': price < 0 ? 0 : price,
      });
    }

    return out;
  }

  /// 讀取購物車（支援 users/{uid}/cart_items、carts/{uid}/items）
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
    } catch (_) {
      // ignore
    }

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
  }) async {
    if (items.isEmpty) throw Exception('沒有商品');

    final subtotal = _calcSubtotal(items);
    final shippingFee = _shippingFee(shippingMethod, subtotal);

    // 先不做折扣，留接口（符合你 UI 現在折扣=0）
    final discount = 0;

    final total = subtotal + shippingFee - discount;

    final ref = _db.collection('orders').doc();

    // ✅ 這份 payload 對齊你 rules：
    // - owner: uid/buyerUid/userId 任一需等於自己（我三個都寫）
    // - items: list > 0
    // - paymentMethod: string
    // - total: number
    // - status: created (允許)
    final payload = <String, dynamic>{
      'uid': uid,
      'buyerUid': uid,
      'userId': uid,

      'status': 'created',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),

      'items': items,

      'subtotal': subtotal,
      'shippingFee': shippingFee,
      'discount': discount,
      'total': total,

      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'receiverAddress': receiverAddress,

      'shippingMethod': shippingMethod,
      'paymentMethod': paymentMethod,

      if (couponCode != null && couponCode.trim().isNotEmpty)
        'couponCode': couponCode.trim(),
    };

    await ref.set(payload);

    if (clearCartAfter) {
      await _clearCart(uid);
    }

    return CheckoutSubmitResult(orderId: ref.id);
  }
}

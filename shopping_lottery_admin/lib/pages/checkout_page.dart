// lib/pages/checkout_page.dart
//
// ✅ CheckoutPage（可編譯完整版｜修正 signNT bug｜修正 Radio groupValue deprecated｜修正 use_build_context_synchronously）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CheckoutPage extends StatefulWidget {
  static const String routeName = '/checkout';
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _db = FirebaseFirestore.instance;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _couponCtrl = TextEditingController();

  bool _loading = true;
  bool _placing = false;
  bool _applyingCoupon = false;

  List<_CartItem> _items = [];

  Map<String, dynamic>? _couponDoc;
  String _couponCodeApplied = '';
  num _discount = 0;

  String _shippingMethod = 'home_delivery';
  String _paymentMethod = 'online';

  String _s(dynamic v) => (v ?? '').toString().trim();

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '0').toString()) ?? 0;
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  User? get _user => FirebaseAuth.instance.currentUser;

  num get _subtotal {
    num sum = 0;
    for (final it in _items) {
      sum += (it.price * it.qty);
    }
    return sum;
  }

  num get _shippingFee {
    if (_shippingMethod == 'store_pickup') return 0;
    return _subtotal >= 1500 ? 0 : 60;
  }

  num get _total {
    final t = _subtotal + _shippingFee - _discount;
    return t < 0 ? 0 : t;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      await _loadCartOrBuyNow();
    } catch (e) {
      _snack('載入購物車失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCartOrBuyNow() async {
    final user = _user;
    if (user == null) {
      _items = [];
      return;
    }

    // ✅ 先取 arguments（避免 async gap 後再碰 context）
    final args = ModalRoute.of(context)?.settings.arguments;
    final buyNow = (args is Map) ? args['buyNow'] : null;

    if (buyNow is Map) {
      final it = _CartItem.fromMap(
        id: 'buyNow',
        m: Map<String, dynamic>.from(buyNow),
      );
      _items = [it];
      return;
    }

    final itemsA = await _readCartFromSubcollection(user.uid, 'cart_items');
    if (itemsA.isNotEmpty) {
      _items = itemsA;
      return;
    }

    final itemsB = await _readCartFromSubcollection(user.uid, 'cart');
    _items = itemsB;
  }

  Future<List<_CartItem>> _readCartFromSubcollection(
    String uid,
    String subcol,
  ) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection(subcol)
        .get();
    if (snap.docs.isEmpty) return [];
    return snap.docs
        .map((d) => _CartItem.fromMap(id: d.id, m: d.data()))
        .toList();
  }

  Future<void> _applyCoupon() async {
    if (_applyingCoupon) return;

    final user = _user;
    if (user == null) {
      _snack('請先登入');
      return;
    }

    final code = _couponCtrl.text.trim();
    if (code.isEmpty) {
      _snack('請輸入優惠碼');
      return;
    }

    setState(() => _applyingCoupon = true);

    try {
      final q = await _db
          .collection('coupons')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        _clearCoupon();
        _snack('找不到此優惠碼');
        return;
      }

      final data = q.docs.first.data();
      if (data['isActive'] != true) {
        _clearCoupon();
        _snack('此優惠碼已停用');
        return;
      }

      final now = DateTime.now();
      final startsAt = _toDate(data['startsAt']);
      final endsAt = _toDate(data['endsAt']);
      if (startsAt != null && now.isBefore(startsAt)) {
        _clearCoupon();
        _snack('此優惠碼尚未開始');
        return;
      }
      if (endsAt != null && now.isAfter(endsAt)) {
        _clearCoupon();
        _snack('此優惠碼已過期');
        return;
      }

      final minSubtotal = _toNum(data['minSubtotal']);
      if (_subtotal < minSubtotal) {
        _clearCoupon();
        _snack('未達最低門檻（$minSubtotal）');
        return;
      }

      final type = _s(data['type']).toLowerCase();
      final value = _toNum(data['value']);
      num discount = 0;

      if (type == 'percent') {
        discount = _subtotal * (value / 100.0);
      } else {
        discount = value;
      }

      final maxDiscount = _toNum(data['maxDiscount']);
      if (maxDiscount > 0 && discount > maxDiscount) {
        discount = maxDiscount;
      }
      if (discount < 0) discount = 0;

      if (discount > _subtotal + _shippingFee) {
        discount = _subtotal + _shippingFee;
      }

      setState(() {
        _couponDoc = data;
        _couponCodeApplied = code;
        _discount = discount;
      });

      _snack('✅ 已套用優惠碼：$code（折抵 ${discount.toStringAsFixed(0)}）');
    } catch (e) {
      _clearCoupon();
      _snack('套用失敗：$e');
    } finally {
      if (mounted) setState(() => _applyingCoupon = false);
    }
  }

  void _clearCoupon() {
    setState(() {
      _couponDoc = null;
      _couponCodeApplied = '';
      _discount = 0;
    });
  }

  bool _validateForm() {
    if (_items.isEmpty) {
      _snack('購物車是空的');
      return false;
    }

    if (_shippingMethod != 'store_pickup') {
      if (_nameCtrl.text.trim().isEmpty) {
        _snack('請填寫收件人');
        return false;
      }
      if (_phoneCtrl.text.trim().isEmpty) {
        _snack('請填寫電話');
        return false;
      }
      if (_addressCtrl.text.trim().isEmpty) {
        _snack('請填寫地址');
        return false;
      }
    }
    return true;
  }

  Future<void> _placeOrder() async {
    if (_placing) return;

    final user = _user;
    if (user == null) {
      _snack('請先登入');
      return;
    }

    if (!_validateForm()) return;

    // ✅ 修正 use_build_context_synchronously：async 前先取完會用到的 context 相關物件
    final NavigatorState nav = Navigator.of(context);
    final args = ModalRoute.of(context)?.settings.arguments;
    final buyNow = (args is Map) ? args['buyNow'] : null;

    setState(() => _placing = true);

    try {
      final vendorIds = <String>{
        for (final it in _items)
          if (it.vendorId.trim().isNotEmpty) it.vendorId.trim(),
      }.toList();

      final orderRef = _db.collection('orders').doc();

      final orderData = <String, dynamic>{
        'userId': user.uid,
        'status': 'pending_payment',
        'shippingMethod': _shippingMethod,
        'paymentMethod': _paymentMethod,
        'receiver': {
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
        },
        'note': _noteCtrl.text.trim(),
        'items': _items.map((e) => e.toJson()).toList(),
        'vendorIds': vendorIds,
        'subtotal': _subtotal,
        'shippingFee': _shippingFee,
        'discount': _discount,
        'total': _total,
        'coupon': _couponDoc == null
            ? null
            : {
                'code': _couponCodeApplied,
                'type': _s(_couponDoc?['type']),
                'value': _toNum(_couponDoc?['value']),
              },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await orderRef.set(orderData);

      // ✅ buyNow：不清空購物車
      if (buyNow == null) {
        await _clearUserCart(user.uid);
      }

      if (!mounted) return;

      nav.pushNamed(
        '/payment',
        arguments: {
          'orderId': orderRef.id,
          'amount': _total,
          'currency': 'TWD',
        },
      );
    } catch (e) {
      _snack('建立訂單失敗：$e');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _clearUserCart(String uid) async {
    await _clearSubcollection(uid, 'cart_items');
    await _clearSubcollection(uid, 'cart');
  }

  Future<void> _clearSubcollection(String uid, String subcol) async {
    final col = _db.collection('users').doc(uid).collection(subcol);
    final snap = await col.get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final cs = Theme.of(context).colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('結帳')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 44,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    const Text('請先登入才能結帳'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      child: const Text('前往登入'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('結帳'),
        actions: [
          IconButton(
            tooltip: '重新載入',
            onPressed: _loading ? null : _bootstrap,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('購物車是空的'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _sectionCard(
                  title: '商品明細',
                  child: Column(
                    children: [for (final it in _items) _itemTile(it)],
                  ),
                ),
                const SizedBox(height: 10),

                _sectionCard(
                  title: '配送方式',
                  child: RadioGroup<String>(
                    groupValue: _shippingMethod,
                    onChanged: (v) =>
                        setState(() => _shippingMethod = v ?? 'home_delivery'),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'home_delivery',
                          title: const Text('宅配'),
                          subtitle: Text(
                            _shippingFee == 0
                                ? '免運'
                                : '運費 NT\$${_shippingFee.toStringAsFixed(0)}',
                          ),
                        ),
                        const RadioListTile<String>(
                          value: 'store_pickup',
                          title: Text('到店取貨'),
                          subtitle: Text('免運'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                _sectionCard(
                  title: '付款方式',
                  child: RadioGroup<String>(
                    groupValue: _paymentMethod,
                    onChanged: (v) =>
                        setState(() => _paymentMethod = v ?? 'online'),
                    child: Column(
                      children: const [
                        RadioListTile<String>(
                          value: 'online',
                          title: Text('線上付款'),
                        ),
                        RadioListTile<String>(
                          value: 'cod',
                          title: Text('貨到付款'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                _sectionCard(
                  title: '收件資訊',
                  child: Column(
                    children: [
                      if (_shippingMethod == 'store_pickup')
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '到店取貨可不填地址（你可依需求改成必填）',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        ),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: '收件人',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: '電話',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(
                          labelText: '地址',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: '備註（可選）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                _sectionCard(
                  title: '優惠碼',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _couponCtrl,
                              decoration: const InputDecoration(
                                labelText: '輸入優惠碼',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _applyingCoupon ? null : _applyCoupon,
                            child: _applyingCoupon
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('套用'),
                          ),
                        ],
                      ),
                      if (_couponCodeApplied.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '已套用：$_couponCodeApplied（折抵 NT\$${_discount.toStringAsFixed(0)}）',
                                style: TextStyle(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _clearCoupon,
                              child: const Text('取消'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                _sectionCard(
                  title: '金額結算',
                  child: Column(
                    children: [
                      _moneyRow('小計', _subtotal),
                      _moneyRow('運費', _shippingFee),
                      _moneyRow('折扣', -_discount),
                      const Divider(),
                      _moneyRow('總計', _total, emphasize: true),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _placing ? null : _placeOrder,
                  icon: _placing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payments_outlined),
                  label: Text(_placing ? '建立訂單中...' : '確認下單'),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _itemTile(_CartItem it) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(it.qty.toString())),
      title: Text(
        it.title.isEmpty ? it.productId : it.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text('NT\$${it.price.toStringAsFixed(0)}  ×  ${it.qty}'),
      trailing: Text(
        'NT\$${(it.price * it.qty).toStringAsFixed(0)}',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _moneyRow(String label, num value, {bool emphasize = false}) {
    final v = value;
    final sign = v < 0 ? '-' : '';
    final abs = v.abs();

    final style = TextStyle(
      fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
      fontSize: emphasize ? 18 : 14,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('${sign}NT\$${abs.toStringAsFixed(0)}', style: style),
        ],
      ),
    );
  }
}

class _CartItem {
  final String id;
  final String productId;
  final String title;
  final String imageUrl;
  final String vendorId;
  final num price;
  final int qty;

  const _CartItem({
    required this.id,
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.vendorId,
    required this.price,
    required this.qty,
  });

  factory _CartItem.fromMap({
    required String id,
    required Map<String, dynamic> m,
  }) {
    final productId = (m['productId'] ?? m['pid'] ?? '').toString();
    final title = (m['title'] ?? m['name'] ?? '').toString();
    final imageUrl = (m['imageUrl'] ?? m['image'] ?? '').toString();
    final vendorId = (m['vendorId'] ?? '').toString();

    final dynamic p = m['price'] ?? m['unitPrice'] ?? 0;
    final num price = p is num ? p : (num.tryParse(p.toString()) ?? 0);

    final dynamic q = m['qty'] ?? m['quantity'] ?? 1;
    final int qty = q is int ? q : (int.tryParse(q.toString()) ?? 1);

    return _CartItem(
      id: id,
      productId: productId,
      title: title,
      imageUrl: imageUrl,
      vendorId: vendorId,
      price: price,
      qty: qty < 1 ? 1 : qty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'title': title,
      'imageUrl': imageUrl,
      'vendorId': vendorId,
      'price': price,
      'qty': qty,
    };
  }
}

// lib/pages/checkout/checkout_full_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CheckoutFullPage extends StatefulWidget {
  const CheckoutFullPage({super.key});

  @override
  State<CheckoutFullPage> createState() => _CheckoutFullPageState();
}

class _CheckoutFullPageState extends State<CheckoutFullPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);

  // Address
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  // Coupon
  final TextEditingController _couponCtrl = TextEditingController();
  CouponInfo? _coupon;
  String? _couponError;

  // Shipping / Payment
  String _shippingMethod = 'standard'; // standard / express
  String _paymentMethod = 'card'; // card / cod / transfer

  // ✅ prefer_final_fields
  final num _shippingFee = 80;
  final num _shippingFeeExpress = 120;
  final num _freeShippingThreshold = 999;

  User? get _user => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> _cartRef(String uid) =>
      _fs.collection('users').doc(uid).collection('cart_items');

  @override
  void dispose() {
    _busy.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  String _money(num v) {
    final n = v.round();
    final s = n.toString();
    final rev = s.split('').reversed.toList();
    final buf = StringBuffer();
    for (int i = 0; i < rev.length; i++) {
      if (i != 0 && i % 3 == 0) {
        buf.write(',');
      }
      buf.write(rev[i]);
    }
    final out = buf.toString().split('').reversed.join();
    return 'NT\$ $out';
  }

  num _calcShippingFee(num subtotal) {
    if (_shippingMethod == 'express') {
      return _shippingFeeExpress;
    }
    if (subtotal >= _freeShippingThreshold) {
      return 0;
    }
    return _shippingFee;
  }

  num _calcDiscount(num subtotal) {
    final c = _coupon;
    if (c == null) return 0;
    if (c.minSpend > 0 && subtotal < c.minSpend) return 0;

    if (c.type == 'percent') {
      final d = subtotal * (c.value / 100);
      return d.clamp(0, subtotal);
    }
    return c.value.clamp(0, subtotal);
  }

  Future<void> _applyCoupon() async {
    if (_busy.value) return;

    final code = _couponCtrl.text.trim();
    if (code.isEmpty) {
      setState(() {
        _coupon = null;
        _couponError = null;
      });
      return;
    }

    _busy.value = true;
    setState(() => _couponError = null);

    try {
      // ✅ 單欄位 where，不需要 composite index
      final snap = await _fs
          .collection('coupons')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        setState(() {
          _coupon = null;
          _couponError = '找不到此優惠碼';
        });
        return;
      }

      final doc = snap.docs.first;
      final d = doc.data();

      final isActive = (d['isActive'] ?? false) == true;
      if (!isActive) {
        setState(() {
          _coupon = null;
          _couponError = '此優惠碼未啟用';
        });
        return;
      }

      final info = CouponInfo(
        id: doc.id,
        code: (d['code'] ?? '').toString(),
        type: (d['type'] ?? 'amount').toString(), // percent / amount
        value: _asNum(d['value'], fallback: 0),
        minSpend: _asNum(d['minSpend'], fallback: 0),
      );

      setState(() {
        _coupon = info;
        _couponError = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已套用優惠碼：${info.code}')));
    } catch (e) {
      setState(() {
        _coupon = null;
        _couponError = '套用失敗：$e';
      });
    } finally {
      _busy.value = false;
    }
  }

  Future<void> _placeOrder(List<CartItem> items) async {
    if (_busy.value) return;

    final user = _user;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先登入')));
      return;
    }

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || address.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請完整填寫收件資訊（姓名/電話/地址）')));
      return;
    }

    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('購物車是空的')));
      return;
    }

    final subtotal = items.fold<num>(0, (s, e) => s + e.price * e.qty);
    final shippingFee = _calcShippingFee(subtotal);
    final discount = _calcDiscount(subtotal);
    final total = (subtotal + shippingFee - discount).clamp(0, 999999999);

    _busy.value = true;

    try {
      final orderData = <String, dynamic>{
        'uid': user.uid,
        'items': [
          for (final it in items)
            <String, dynamic>{
              'productId': it.productId,
              'name': it.name,
              'price': it.price,
              'qty': it.qty,
              'imageUrl': it.imageUrl,
            },
        ],
        'subtotal': subtotal,
        'shippingFee': shippingFee,
        'discount': discount,
        'total': total,
        'couponCode': _coupon?.code ?? '',
        'couponId': _coupon?.id ?? '',
        'paymentMethod': _paymentMethod,
        'shippingMethod': _shippingMethod,
        'address': <String, dynamic>{
          'receiverName': name,
          'receiverPhone': phone,
          'fullAddress': address,
        },
        'status': 'created',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // orders/{id}
      final orderDoc = await _fs.collection('orders').add(orderData);

      // users/{uid}/orders/{id}
      try {
        await _fs
            .collection('users')
            .doc(user.uid)
            .collection('orders')
            .doc(orderDoc.id)
            .set({
              ...orderData,
              'orderId': orderDoc.id,
            }, SetOptions(merge: true));
      } catch (_) {}

      // clear cart
      final cartSnap = await _cartRef(user.uid).limit(500).get();
      final batch = _fs.batch();
      for (final d in cartSnap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('已建立訂單'),
            content: Text('訂單編號：${orderDoc.id}\n總計：${_money(total)}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('關閉'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushNamed(
                    '/store_payment',
                    arguments: <String, dynamic>{'orderId': orderDoc.id},
                  );
                },
                child: const Text('前往付款'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('建立訂單失敗：$e')));
    } finally {
      _busy.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('結帳'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _busy,
            builder: (_, busy, __) {
              return IconButton(
                tooltip: '重新整理',
                onPressed: busy
                    ? null
                    : () {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('已重新整理')));
                      },
                icon: const Icon(Icons.refresh),
              );
            },
          ),
        ],
      ),
      body: user == null ? _needLogin(context) : _content(uid: user.uid),
      bottomNavigationBar: user == null ? null : _bottomBar(uid: user.uid),
    );
  }

  Widget _needLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能結帳',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/login'),
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

  Widget _content({required String uid}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cartRef(uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('讀取購物車失敗：${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data!.docs
            .map((d) => CartItem.fromDoc(d, asNum: _asNum, asInt: _asInt))
            .toList();

        final subtotal = items.fold<num>(0, (s, e) => s + e.price * e.qty);
        final shippingFee = _calcShippingFee(subtotal);
        final discount = _calcDiscount(subtotal);
        final total = (subtotal + shippingFee - discount).clamp(0, 999999999);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('購物車商品'),
            const SizedBox(height: 8),
            if (items.isEmpty) _emptyCart() else ...items.map(_cartItemTile),
            const SizedBox(height: 16),
            _sectionTitle('收件資訊'),
            const SizedBox(height: 8),
            _addressForm(),
            const SizedBox(height: 16),
            _sectionTitle('配送 / 付款'),
            const SizedBox(height: 8),
            _shippingPayment(),
            const SizedBox(height: 16),
            _sectionTitle('優惠碼'),
            const SizedBox(height: 8),
            _couponBox(),
            const SizedBox(height: 16),
            _sectionTitle('金額摘要'),
            const SizedBox(height: 8),
            _summaryCard(
              subtotal: subtotal,
              shippingFee: shippingFee,
              discount: discount,
              total: total,
            ),
            const SizedBox(height: 110),
          ],
        );
      },
    );
  }

  Widget _bottomBar({required String uid}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cartRef(uid).snapshots(),
      builder: (context, snap) {
        final items = (snap.data?.docs ?? [])
            .map((d) => CartItem.fromDoc(d, asNum: _asNum, asInt: _asInt))
            .toList();

        final subtotal = items.fold<num>(0, (s, e) => s + e.price * e.qty);
        final shippingFee = _calcShippingFee(subtotal);
        final discount = _calcDiscount(subtotal);
        final total = (subtotal + shippingFee - discount).clamp(0, 999999999);

        final cs = Theme.of(context).colorScheme;

        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: _busy,
              builder: (_, busy, __) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '總計：${_money(total)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: busy || items.isEmpty
                          ? null
                          : () => _placeOrder(items),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('下單'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }

  Widget _emptyCart() {
    return const Card(
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('購物車是空的', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('請先加入商品後再結帳', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _cartItemTile(CartItem it) {
    return Card(
      elevation: 1,
      child: ListTile(
        leading: it.imageUrl.trim().isEmpty
            ? const CircleAvatar(child: Icon(Icons.inventory_2_outlined))
            : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  it.imageUrl,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const CircleAvatar(
                    child: Icon(Icons.image_not_supported),
                  ),
                ),
              ),
        title: Text(
          it.name.isEmpty ? '(未命名商品)' : it.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${_money(it.price)}  •  數量 ${it.qty}'),
      ),
    );
  }

  Widget _addressForm() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '收件人姓名',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '收件人電話',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '收件地址',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shippingPayment() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ValueListenableBuilder<bool>(
          valueListenable: _busy,
          builder: (_, busy, __) {
            return Column(
              children: [
                _decoratedDropdown<String>(
                  labelText: '配送方式',
                  value: _shippingMethod,
                  enabled: !busy,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: 'standard',
                      child: Text('標準配送（滿 999 免運）'),
                    ),
                    DropdownMenuItem(
                      value: 'express',
                      child: Text('快速配送（固定 120）'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _shippingMethod = v);
                  },
                ),
                const SizedBox(height: 10),
                _decoratedDropdown<String>(
                  labelText: '付款方式',
                  value: _paymentMethod,
                  enabled: !busy,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'card', child: Text('信用卡 / 行動支付')),
                    DropdownMenuItem(value: 'cod', child: Text('貨到付款')),
                    DropdownMenuItem(value: 'transfer', child: Text('銀行轉帳')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _paymentMethod = v);
                  },
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _shippingMethod == 'express'
                        ? '快速配送運費：${_money(_shippingFeeExpress)}'
                        : '標準配送未滿 $_freeShippingThreshold 需運費：${_money(_shippingFee)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _decoratedDropdown<T>({
    required String labelText,
    required T value,
    required bool enabled,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        isDense: true,
        enabled: enabled,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _couponBox() {
    final c = _coupon;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ValueListenableBuilder<bool>(
          valueListenable: _busy,
          builder: (_, busy, __) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _couponCtrl,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: '輸入優惠碼（例如：WELCOME100）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonal(
                      onPressed: busy ? null : _applyCoupon,
                      child: const Text('套用'),
                    ),
                  ],
                ),
                if (_couponError != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _couponError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (c != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _couponHintText(c),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _couponHintText(CouponInfo c) {
    final off = c.type == 'percent'
        ? '${c.value}% OFF'
        : '${_money(c.value)} OFF';
    final ms = c.minSpend > 0 ? '，低消 ${_money(c.minSpend)}' : '';
    return '已套用：${c.code}（$off$ms）';
  }

  Widget _summaryCard({
    required num subtotal,
    required num shippingFee,
    required num discount,
    required num total,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _row('小計', _money(subtotal)),
            const SizedBox(height: 6),
            _row('運費', _money(shippingFee)),
            const SizedBox(height: 6),
            _row('折扣', discount > 0 ? '- ${_money(discount)}' : _money(0)),
            const Divider(height: 16),
            _row(
              '總計',
              _money(total),
              valueStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Text(
          value,
          style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class CartItem {
  final String id;
  final String productId;
  final String name;
  final num price;
  final int qty;
  final String imageUrl;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    required this.imageUrl,
  });

  factory CartItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required num Function(dynamic v, {num fallback}) asNum,
    required int Function(dynamic v, {int fallback}) asInt,
  }) {
    final d = doc.data();
    return CartItem(
      id: doc.id,
      productId: (d['productId'] ?? d['pid'] ?? '').toString(),
      name: (d['name'] ?? d['title'] ?? '').toString(),
      price: asNum(d['price'], fallback: 0),
      qty: asInt(d['qty'], fallback: 1),
      imageUrl: (d['imageUrl'] ?? d['coverUrl'] ?? '').toString(),
    );
  }
}

class CouponInfo {
  final String id;
  final String code;
  final String type; // percent / amount
  final num value;
  final num minSpend;

  CouponInfo({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.minSpend,
  });
}

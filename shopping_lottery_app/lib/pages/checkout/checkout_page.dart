import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/checkout/checkout_submit_service.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, this.args});
  final Object? args;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();
  final _receiverAddress = TextEditingController();
  final _coupon = TextEditingController();

  bool _submitting = false;
  bool _loadingItems = true;

  String _shippingMethod = 'standard';
  String _paymentMethod = 'card';

  // direct buy
  List<Map<String, dynamic>> _directItems = const [];
  bool _useDirect = false;

  // cart fallback
  List<Map<String, dynamic>> _cartItems = const [];

  @override
  void initState() {
    super.initState();
    _parseArgs(widget.args);
    _loadItems();
  }

  @override
  void dispose() {
    _receiverName.dispose();
    _receiverPhone.dispose();
    _receiverAddress.dispose();
    _coupon.dispose();
    super.dispose();
  }

  void _parseArgs(Object? args) {
    if (args is Map) {
      final di = args['directItems'];
      if (di is List) {
        _directItems = di
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _useDirect = _directItems.isNotEmpty;
      }
    } else if (args is List) {
      _directItems = args
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      _useDirect = _directItems.isNotEmpty;
    }
  }

  Future<void> _loadItems() async {
    setState(() => _loadingItems = true);
    try {
      if (_useDirect) {
        // 直接購買已帶入
        return;
      }

      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // 先試 users/{uid}/cart_items
      final a = await _db
          .collection('users')
          .doc(uid)
          .collection('cart_items')
          .get();
      if (a.docs.isNotEmpty) {
        _cartItems = a.docs
            .map((d) => (d.data()))
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        return;
      }

      // 再試 carts/{uid}/items
      final b = await _db
          .collection('carts')
          .doc(uid)
          .collection('items')
          .get();
      _cartItems = b.docs
          .map((d) => (d.data()))
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } finally {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) {
      final s = v.replaceAll(',', '').trim();
      return int.tryParse(s) ?? (double.tryParse(s)?.round() ?? 0);
    }
    return 0;
  }

  int _calcSubtotal(List<Map<String, dynamic>> items) {
    int sum = 0;
    for (final it in items) {
      final price = _toInt(it['price']);
      final qty = _toInt(it['qty'] ?? it['quantity'] ?? 1);
      sum += price * (qty <= 0 ? 1 : qty);
    }
    return sum;
  }

  int _shippingFee(int subtotal) {
    if (_shippingMethod != 'standard') return 0;
    return subtotal >= 999 ? 0 : 80;
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);

    final name = _receiverName.text.trim();
    final phone = _receiverPhone.text.trim();
    final addr = _receiverAddress.text.trim();

    if (name.isEmpty || phone.isEmpty || addr.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('請填寫完整收件資訊')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final couponCode = _coupon.text.trim().isEmpty
          ? null
          : _coupon.text.trim();

      if (_useDirect) {
        final r = await CheckoutSubmitService.instance.placeOrderDirect(
          receiverName: name,
          receiverPhone: phone,
          receiverAddress: addr,
          shippingMethod: _shippingMethod,
          paymentMethod: _paymentMethod,
          couponCode: couponCode,
          directItems: _directItems,
        );
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('下單成功：${r.orderId}')));
      } else {
        final r = await CheckoutSubmitService.instance.placeOrderFromCart(
          receiverName: name,
          receiverPhone: phone,
          receiverAddress: addr,
          shippingMethod: _shippingMethod,
          paymentMethod: _paymentMethod,
          couponCode: couponCode,
        );
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('下單成功：${r.orderId}')));
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('建立訂單失敗：$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _useDirect ? _directItems : _cartItems;

    final subtotal = _calcSubtotal(items);
    final ship = _shippingFee(subtotal);
    final total = subtotal + ship;

    return Scaffold(
      appBar: AppBar(title: const Text('結帳')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('購物車商品', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),

          if (_loadingItems)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('載入商品中…'),
                  ],
                ),
              ),
            )
          else if (items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _useDirect
                      ? '未帶入 directItems（請從「立即購買」pushNamed 時帶 arguments）'
                      : '購物車是空的',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: items.map((it) {
                  final title = (it['title'] ?? it['name'] ?? '未命名商品')
                      .toString();
                  final price = _toInt(it['price']);
                  final qty = _toInt(it['qty'] ?? it['quantity'] ?? 1);
                  return ListTile(
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('NT\$ $price ・ 數量 $qty'),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 16),

          const Text('收件資訊', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _receiverName,
                    decoration: const InputDecoration(labelText: '收件人姓名'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _receiverPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: '收件人電話'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _receiverAddress,
                    decoration: const InputDecoration(labelText: '收件地址'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text('配送 / 付款', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _shippingMethod,
                    items: const [
                      DropdownMenuItem(
                        value: 'standard',
                        child: Text('標準配送（滿 999 免運）'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _shippingMethod = v ?? 'standard'),
                    decoration: const InputDecoration(labelText: '配送方式'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    items: const [
                      DropdownMenuItem(
                        value: 'card',
                        child: Text('信用卡 / 行動支付'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _paymentMethod = v ?? 'card'),
                    decoration: const InputDecoration(labelText: '付款方式'),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '標準配送未滿 999 需運費：NT\$ 80',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text('優惠碼', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _coupon,
                      decoration: const InputDecoration(
                        hintText: '輸入優惠碼（例如：WELCOME100）',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('優惠碼將於下單時一併寫入 coupon_redemptions'),
                      ),
                    ),
                    child: const Text('套用'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text('金額摘要', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _moneyRow('小計', subtotal),
                  _moneyRow('運費', ship),
                  _moneyRow('折扣', 0),
                  const Divider(),
                  _moneyRow('總計', total, bold: true),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_submitting || items.isEmpty) ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('下單'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, int value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('NT\$ $value', style: style),
        ],
      ),
    );
  }
}

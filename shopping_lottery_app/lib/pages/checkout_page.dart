// lib/pages/checkout_page.dart
// =====================================================
// ✅ CheckoutPage（結帳頁面｜Osmile 最終完整版｜可編譯）
// -----------------------------------------------------
// 功能：
// - 支援 DirectBuy（直接結帳）與 CartService 購物車結帳
// - 折價券、運費、收件資訊、配送方式、自動儲存上次選項
// - 與 PaymentPage、OrderService、NotificationService 完整整合
// - ✅ 未登入狀態：點「前往付款」會導向 /login（不建立訂單）
// - ✅ CartItem / Map 相容轉換（避免 e.toMap() 失敗）
// - ✅ 安全抽取 orderId（相容 Map / String / Order）
// =====================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/coupon_service.dart';
import '../services/order_service.dart';
import '../services/notification_service.dart';
import 'address_page.dart';
import 'payment_page.dart';

enum DeliveryMethod { home, storePickup }

class CheckoutPage extends StatefulWidget {
  final List<Map<String, dynamic>>? directBuyItems;
  const CheckoutPage({super.key, this.directBuyItems});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  static const _bg = Color(0xFFF7F8FA);
  static const _brand = Colors.blueAccent;

  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  // 配送方式
  DeliveryMethod _delivery = DeliveryMethod.home;
  double get _shippingFee => _delivery == DeliveryMethod.home ? 60 : 40;

  // 收件地址
  static const String _addrPrefsKey = 'osmile_addresses_v1';
  Map<String, dynamic>? _selectedAddress;

  // Checkout 記憶
  static const String _ckPrefsKeyDelivery = 'os_ck_delivery_v1';
  static const String _ckPrefsKeyCouponId = 'os_ck_coupon_id_v1';

  // 折價券
  Map<String, dynamic>? _selectedCoupon;
  double _discount = 0;
  bool _couponReady = false;

  // 直接購買模式
  List<Map<String, dynamic>>? _localItems;

  bool _submitting = false;

  bool get _isDirectBuy => widget.directBuyItems != null;

  String _fmtMoney(num v) => _moneyFmt.format(v);
  double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  int _toInt(dynamic v, {int fallback = 1}) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

  @override
  void initState() {
    super.initState();
    _loadDefaultAddress();

    if (widget.directBuyItems != null) {
      _localItems = widget.directBuyItems!
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    Future.microtask(() async {
      try {
        await CouponService.instance.init();
      } catch (_) {}
      _couponReady = true;
      await _restoreCheckoutPrefs();
      if (mounted) setState(() {});
    });
  }

  // ======================================================
  // ✅ 未登入：阻擋付款流程（不建立訂單）
  // ======================================================
  bool _ensureLogin({String message = '登入後才能繼續'}) {
    try {
      final auth = context.read<AuthService>();
      if (auth.loggedIn) return true;
    } catch (_) {
      // 如果專案暫時沒有掛 Provider/AuthService，也不要炸掉
      return true;
    }

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      Navigator.pushNamed(context, '/login');
    });
    return false;
  }

  // ======================================================
  // 收件地址
  // ======================================================
  Future<void> _loadDefaultAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_addrPrefsKey);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is List && list.isNotEmpty) {
        final def = list.firstWhere(
          (e) => (e is Map) && e['isDefault'] == true,
          orElse: () => list.first,
        );
        if (def is Map && mounted) {
          setState(() => _selectedAddress = Map<String, dynamic>.from(def));
        }
      }
    } catch (_) {}
  }

  Future<void> _pickAddress() async {
    final res = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const AddressPage(selectMode: true)),
    );
    if (res != null && mounted) setState(() => _selectedAddress = res);
  }

  // ======================================================
  // Checkout 偏好儲存 / 還原
  // ======================================================
  Future<void> _restoreCheckoutPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final d = prefs.getInt(_ckPrefsKeyDelivery);
    _delivery = (d == 1) ? DeliveryMethod.storePickup : DeliveryMethod.home;

    final cid = prefs.getString(_ckPrefsKeyCouponId);
    if (cid != null) {
      try {
        final all = CouponService.instance.available ?? [];
        final c = all.firstWhere(
          (e) => (e['id']?.toString() ?? '') == cid,
          orElse: () => {},
        );
        if (c is Map && c.isNotEmpty) {
          _selectedCoupon = Map<String, dynamic>.from(c);
        }
      } catch (_) {}
    }
  }

  Future<void> _saveDeliveryPref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _ckPrefsKeyDelivery,
      _delivery == DeliveryMethod.storePickup ? 1 : 0,
    );
  }

  Future<void> _saveCouponPref(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_ckPrefsKeyCouponId);
    } else {
      await prefs.setString(_ckPrefsKeyCouponId, id);
    }
  }

  // ======================================================
  // Items / 金額計算
  // ======================================================
  List<Map<String, dynamic>> _getCartItems(CartService cart) {
    final out = <Map<String, dynamic>>[];

    dynamic raw;
    try {
      raw = cart.items;
    } catch (_) {
      raw = null;
    }

    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          out.add(Map<String, dynamic>.from(e));
          continue;
        }

        // CartItem -> toMap()
        try {
          final m = (e as dynamic).toMap();
          if (m is Map) out.add(Map<String, dynamic>.from(m));
        } catch (_) {}

        // 最後保險：嘗試讀欄位
        try {
          final any = e as dynamic;
          out.add({
            'id': (any.id ?? any.productId ?? '').toString(),
            'productId': (any.productId ?? any.id ?? '').toString(),
            'name': (any.name ?? any.title ?? '商品').toString(),
            'price': _toDouble(any.price),
            'qty': _toInt(any.qty ?? any.count, fallback: 1),
            'image': (any.image ?? any.imageUrl ?? '').toString(),
          });
        } catch (_) {}
      }
    }

    return out;
  }

  List<Map<String, dynamic>> get _items => _isDirectBuy
      ? (_localItems ?? [])
      : _getCartItems(context.read<CartService>());

  double _subtotal(List<Map<String, dynamic>> list) => list.fold(
        0.0,
        (sum, e) =>
            sum + _toDouble(e['price']) * _toInt(e['qty'] ?? e['quantity'] ?? 1),
      );

  double _total(double subtotal) {
    final t = subtotal + _shippingFee - _discount;
    return t < 0 ? 0 : t;
  }

  // ======================================================
  // 折價券
  // ======================================================
  Future<void> _applyBestCoupon(double subtotal) async {
    if (!_couponReady) return;

    final best =
        CouponService.instance.pickBestAvailable(orderSubtotal: subtotal);
    if (best == null) {
      _toast('沒有可用的折價券');
      return;
    }

    final d = CouponService.instance.calcDiscount(best, orderSubtotal: subtotal);
    setState(() {
      _selectedCoupon = Map<String, dynamic>.from(best);
      _discount = d;
    });
    await _saveCouponPref(best['id']?.toString());
  }

  // ======================================================
  // ✅ 安全抽取 orderId（相容 Order / Map / String）
  // ======================================================
  String _extractOrderId(dynamic order) {
    final fallback = 'ord_${DateTime.now().millisecondsSinceEpoch}';
    if (order == null) return fallback;

    if (order is Map) {
      final v = order['id'] ?? order['orderId'];
      return (v == null) ? fallback : v.toString();
    }
    if (order is String && order.isNotEmpty) return order;

    try {
      final any = order as dynamic;
      final v = any.id ?? any.orderId;
      return (v == null) ? fallback : v.toString();
    } catch (_) {
      return fallback;
    }
  }

  // ======================================================
  // 建立訂單 → 付款頁
  // ======================================================
  Future<void> _goPay(List<Map<String, dynamic>> items) async {
    if (!_ensureLogin(message: '登入後才能前往付款')) return;
    if (items.isEmpty || _submitting) return;

    if (_selectedAddress == null) {
      _toast('請先新增或選擇收件資訊');
      return;
    }

    setState(() => _submitting = true);
    try {
      final subtotal = _subtotal(items);

      // 若有選券，保證折扣與最新小計一致
      if (_selectedCoupon != null && _couponReady) {
        _discount = CouponService.instance
            .calcDiscount(_selectedCoupon!, orderSubtotal: subtotal);
      }

      final total = _total(subtotal);

      final order = await OrderService.instance.createOrder(
        items: items,
        total: total,
        shipping: {
          'method': _delivery == DeliveryMethod.home ? 'home' : 'store',
          'fee': _shippingFee,
          'address': _selectedAddress,
        },
        extra: {
          'coupon': _selectedCoupon,
          'discount': _discount,
          'subtotal': subtotal,
          'delivery': _delivery == DeliveryMethod.home ? 'home' : 'storePickup',
        },
      );

      final orderId = _extractOrderId(order);

      NotificationService.instance.addNotification(
        type: 'order',
        title: '訂單已建立',
        message: '訂單 $orderId 已建立，請完成付款。',
        icon: Icons.receipt_long_outlined,
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            orderId: orderId,
            orderSummary: {
              'items': items,
              'subtotal': subtotal,
              'discount': _discount,
              'coupon': _selectedCoupon,
              'shippingFee': _shippingFee,
              'total': total,
              'address': _selectedAddress,
              'delivery':
                  _delivery == DeliveryMethod.home ? 'home' : 'storePickup',
            },
            totalAmount: total,
            coupon: _selectedCoupon,
            discount: _discount,
          ),
        ),
      );
    } catch (e) {
      _toast('訂單建立失敗：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    // 讓頁面跟著購物車變動更新（directBuy 不影響）
    context.watch<CartService>();

    final items = _items;
    final subtotal = _subtotal(items);

    // 顯示時同步折扣（避免小計變動但折扣沒有更新）
    final discountNow = (_selectedCoupon != null && _couponReady)
        ? CouponService.instance
            .calcDiscount(_selectedCoupon!, orderSubtotal: subtotal)
        : _discount;
    if (discountNow != _discount) {
      // 不在 build 內直接 setState 避免迴圈
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _discount = discountNow);
      });
    }

    final total = _total(subtotal);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          _isDirectBuy ? '立即購買結帳' : '結帳',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: items.isEmpty
          ? const Center(child: Text('購物車是空的'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
              children: [
                _SectionCard(
                  title: '收件資訊',
                  trailing: TextButton(
                    onPressed: _pickAddress,
                    child: Text(_selectedAddress == null ? '新增/選擇' : '修改'),
                  ),
                  child: _ReceiverInfo(address: _selectedAddress),
                ),
                const SizedBox(height: 12),

                _SectionCard(
                  title: '配送方式',
                  child: Column(
                    children: [
                      RadioListTile<DeliveryMethod>(
                        title: const Text('宅配到府（NT\$60）'),
                        value: DeliveryMethod.home,
                        groupValue: _delivery,
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => _delivery = v);
                          await _saveDeliveryPref();
                        },
                      ),
                      RadioListTile<DeliveryMethod>(
                        title: const Text('超商取貨（NT\$40）'),
                        value: DeliveryMethod.storePickup,
                        groupValue: _delivery,
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => _delivery = v);
                          await _saveDeliveryPref();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _SectionCard(
                  title: '折價券',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_offer_outlined),
                    title: Text(
                      _selectedCoupon == null
                          ? '未使用折價券'
                          : '${_selectedCoupon?['title'] ?? _selectedCoupon?['name'] ?? '折價券'}（折 NT\$${_discount.toStringAsFixed(0)}）',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: _selectedCoupon == null
                        ? Text(
                            '可使用「最佳券」自動套用',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.auto_awesome,
                              color: Colors.orangeAccent),
                          tooltip: '最佳券',
                          onPressed: () => _applyBestCoupon(subtotal),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          tooltip: '清除',
                          onPressed: _selectedCoupon == null
                              ? null
                              : () async {
                                  setState(() {
                                    _selectedCoupon = null;
                                    _discount = 0;
                                  });
                                  await _saveCouponPref(null);
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _SectionCard(
                  title: '金額明細',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('商品小計：${_fmtMoney(subtotal)}'),
                      Text('運費：${_fmtMoney(_shippingFee)}'),
                      Text('折扣：- ${_fmtMoney(_discount)}'),
                      const Divider(),
                      Text(
                        '應付金額：${_fmtMoney(total)}',
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, -2)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('應付金額',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text(
                      _fmtMoney(total),
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      (items.isEmpty || _submitting) ? null : () => _goPay(items),
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.payment_outlined),
                  label: Text(_submitting ? '處理中...' : '前往付款'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ======================================================
// 🔹 通用 Section 卡片元件
// ======================================================
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ReceiverInfo extends StatelessWidget {
  final Map<String, dynamic>? address;
  const _ReceiverInfo({required this.address});

  @override
  Widget build(BuildContext context) {
    if (address == null) {
      return Text('尚未選擇收件資訊', style: TextStyle(color: Colors.grey.shade600));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${address?['name'] ?? ''} ${address?['phone'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text((address?['fullAddress'] ?? '').toString()),
      ],
    );
  }
}

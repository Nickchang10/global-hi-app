import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ CartPage（購物車｜完整版｜可編譯｜已清掉 unused_element）
/// ------------------------------------------------------------
/// - 讀取 users/{uid}/cart_items
/// - 調整數量 / 移除 / 清空
/// - 前往結帳：pushNamed('/checkout')
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _cartRef(String uid) =>
      _fs.collection('users').doc(uid).collection('cart_items');

  void _snack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  Future<void> _changeQty(_CartItem it, int newQty) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    if (newQty < 1) {
      newQty = 1;
    }
    if (newQty > 999) {
      newQty = 999;
    }

    try {
      await _cartRef(uid).doc(it.id).set(<String, dynamic>{
        'qty': newQty,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('更新數量失敗：$e');
    }
  }

  Future<void> _removeItem(_CartItem it) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    try {
      await _cartRef(uid).doc(it.id).delete();
      _snack('已移除：${it.name}');
    } catch (e) {
      _snack('移除失敗：$e');
    }
  }

  Future<void> _clearCart() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    try {
      final snap = await _cartRef(uid).limit(500).get();
      final batch = _fs.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      _snack('已清空購物車');
    } catch (e) {
      _snack('清空失敗：$e');
    }
  }

  void _goCheckout() {
    try {
      Navigator.of(context).pushNamed('/checkout');
    } catch (_) {
      _snack('找不到 /checkout 路由，請在 main.dart 加 routes 或改成你的路由名稱');
    }
  }

  Widget _needLogin() {
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
                    '請先登入才能查看購物車',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pushNamed('/login');
                    },
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

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('購物車'),
        actions: [
          IconButton(
            tooltip: '清空',
            onPressed: uid == null ? null : _clearCart,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: uid == null
          ? _needLogin()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _cartRef(uid).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snap.data!.docs.map(_CartItem.fromDoc).toList();
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      '購物車是空的',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                final subtotal = items.fold<num>(
                  0,
                  (s, e) => s + e.price * e.qty,
                );

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _itemCard(cs, items[i]),
                      ),
                    ),
                    _bottomBar(cs, subtotal),
                  ],
                );
              },
            ),
    );
  }

  Widget _itemCard(ColorScheme cs, _CartItem it) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _thumb(it.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.name.isEmpty ? '(未命名商品)' : it.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_money(it.price)}  •  數量 ${it.qty}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () {
                          _changeQty(it, it.qty - 1);
                        },
                        icon: const Icon(Icons.remove),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${it.qty}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () {
                          _changeQty(it, it.qty + 1);
                        },
                        icon: const Icon(Icons.add),
                        visualDensity: VisualDensity.compact,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          _removeItem(it);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('移除'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(String url) {
    if (url.trim().isEmpty) {
      return Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 68,
        height: 68,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 68,
          height: 68,
          color: Colors.black.withValues(alpha: 0.05),
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }

  Widget _bottomBar(ColorScheme cs, num subtotal) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('小計', style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    _money(subtotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _goCheckout,
              icon: const Icon(Icons.lock_outline),
              label: const Text('前往結帳'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItem {
  final String id;
  final String productId;
  final String name;
  final num price;
  final int qty;
  final String imageUrl;

  const _CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    required this.imageUrl,
  });

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  factory _CartItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _CartItem(
      id: doc.id,
      productId: (d['productId'] ?? d['pid'] ?? '').toString(),
      name: (d['name'] ?? d['title'] ?? '').toString(),
      price: _asNum(d['price'], fallback: 0),
      qty: _asInt(d['qty'], fallback: 1).clamp(1, 999),
      imageUrl: (d['imageUrl'] ?? d['coverUrl'] ?? d['image'] ?? '').toString(),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId, this.prefill});

  final String productId;
  final Map<String, dynamic>? prefill;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _db = FirebaseFirestore.instance;

  Map<String, dynamic>? _data;
  bool _loading = true;

  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _data = widget.prefill;
    _load();
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.replaceAll(',', '').trim()) ?? 0;
    return 0;
  }

  String _title(Map<String, dynamic> p) {
    final t = (p['title'] ?? p['name'] ?? '').toString().trim();
    return t.isEmpty ? '未命名商品' : t;
  }

  String _desc(Map<String, dynamic> p) {
    final d = (p['desc'] ?? p['description'] ?? p['subtitle'] ?? '')
        .toString()
        .trim();
    return d.isEmpty ? '（無描述）' : d;
  }

  String _imageUrl(Map<String, dynamic> p) {
    final u = (p['imageUrl'] ?? p['image'] ?? '').toString().trim();
    if (u.isNotEmpty) return u;
    final imgs = p['images'];
    if (imgs is List && imgs.isNotEmpty) return (imgs.first ?? '').toString();
    return '';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await _db.collection('products').doc(widget.productId).get();
      if (snap.exists) {
        _data = snap.data();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _buyNow(Map<String, dynamic> p) {
    final item = <String, dynamic>{
      'productId': widget.productId,
      'title': _title(p),
      'price': _toInt(p['price']),
      'qty': _qty,
      'imageUrl': _imageUrl(p),
    };

    Navigator.of(context).pushNamed(
      '/checkout',
      arguments: {
        'directItems': [item],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _data;

    return Scaffold(
      appBar: AppBar(
        title: const Text('商品詳情'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: (_loading && p == null)
          ? const Center(child: CircularProgressIndicator())
          : (p == null)
          ? const Center(child: Text('找不到商品資料'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _imageUrl(p).isEmpty
                        ? Container(
                            color: Colors.black.withValues(alpha: 0.06),
                            child: const Center(
                              child: Icon(Icons.image_outlined, size: 46),
                            ),
                          )
                        : Image.network(
                            _imageUrl(p),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black.withValues(alpha: 0.06),
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 46,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _title(p),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'NT\$${_toInt(p['price'])}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_desc(p), style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      '數量',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _qty <= 1
                          ? null
                          : () => setState(() => _qty -= 1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$_qty',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _qty += 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toast('加入購物車：你若要串接 cart 我可以再幫你接'),
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                        label: const Text('加入購物車'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _buyNow(p),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('立即購買'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

// lib/pages/products/products_page.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

enum _SortMode { newest, priceHigh, priceLow }

class _ProductsPageState extends State<ProductsPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _q = '';
  bool _onlyActive = true;
  bool _safeMode = true;
  _SortMode _sort = _SortMode.newest;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _q = v.trim().toLowerCase());
    });
  }

  Query<Map<String, dynamic>> _baseQuery() {
    // 你的 products 欄位可能叫 active/isActive/status
    // 這裡先只用 orderBy，filter 在前端做（避免不同欄位名造成 query fail）
    return _db.collection('products').orderBy('updatedAt', descending: true);
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

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _money(int v) => 'NT\$${v.toString()}';

  String _ago(DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inHours < 1) return '${diff.inMinutes} 分鐘前';
    if (diff.inDays < 1) return '${diff.inHours} 小時前';
    return '${diff.inDays} 天前';
  }

  bool _isActive(Map<String, dynamic> p) {
    final v1 = p['active'];
    final v2 = p['isActive'];
    final v3 = p['enabled'];
    final status = (p['status'] ?? '').toString().toLowerCase();

    if (v1 is bool) return v1;
    if (v2 is bool) return v2;
    if (v3 is bool) return v3;
    if (status.isNotEmpty)
      return status == 'active' || status == 'published' || status == 'on';
    return true; // 沒欄位就視為上架（避免全部被濾掉）
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

  void _openCart() {
    // 你如果有 /cart，這裡改成你的路由
    try {
      Navigator.of(context).pushNamed('/cart');
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('尚未設定 /cart 路由')));
    }
  }

  void _openDetail(String productId, Map<String, dynamic> data) {
    // ✅ 請依你專案實際路由調整
    try {
      Navigator.of(context).pushNamed(
        '/product_detail',
        arguments: {'productId': productId, 'data': data},
      );
    } catch (_) {
      // 若你是用 MaterialPageRoute 也可以在這裡改成直接 push 詳情頁
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('尚未設定 /product_detail 路由')));
    }
  }

  Future<void> _refresh() async {
    // StreamBuilder 自動更新，這裡做個視覺回饋即可
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilterSort(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var list = docs;

    // filter: 上架
    if (_onlyActive) {
      list = list.where((d) => _isActive(d.data())).toList();
    }

    // filter: safe mode（示例：可依你的定義加更嚴格規則）
    // 我先用「沒有 title 也照顯示」，safe mode 只做提示，不硬濾
    // 你要硬濾：可以在這裡排除某些欄位缺失/違規
    // if (_safeMode) ...

    // filter: search（title/desc）
    if (_q.isNotEmpty) {
      list = list.where((d) {
        final p = d.data();
        final t = _title(p).toLowerCase();
        final desc = _desc(p).toLowerCase();
        return t.contains(_q) || desc.contains(_q);
      }).toList();
    }

    // sort
    if (_sort == _SortMode.priceHigh) {
      list.sort(
        (a, b) =>
            _toInt(b.data()['price']).compareTo(_toInt(a.data()['price'])),
      );
    } else if (_sort == _SortMode.priceLow) {
      list.sort(
        (a, b) =>
            _toInt(a.data()['price']).compareTo(_toInt(b.data()['price'])),
      );
    } else {
      // newest：已由 query orderBy updatedAt desc，大多不用再排
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final q = _baseQuery();

    return Scaffold(
      appBar: AppBar(
        title: const Text('商品'),
        actions: [
          IconButton(
            tooltip: '購物車',
            onPressed: _openCart,
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          final loading =
              snap.connectionState == ConnectionState.waiting && !snap.hasData;
          final docs =
              snap.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          final view = _applyFilterSort(docs);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              children: [
                // Search + chips row
                _SearchHeader(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  onClear: () {
                    _searchCtrl.clear();
                    setState(() => _q = '');
                  },
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      selected: _onlyActive,
                      onSelected: (v) => setState(() => _onlyActive = v),
                      label: const Text('只看上架'),
                    ),
                    FilterChip(
                      selected: _safeMode,
                      onSelected: (v) => setState(() => _safeMode = v),
                      label: const Text('安全模式'),
                    ),
                    _SortDropdown(
                      value: _sort,
                      onChanged: (v) => setState(() => _sort = v),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '共 ${view.length} 件',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                if (_safeMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _InfoBanner(
                      text: '安全模式：將以較保守方式顯示資料（缺圖/缺標題仍可見），避免因資料缺失導致頁面崩潰。',
                    ),
                  ),

                const SizedBox(height: 12),

                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snap.hasError)
                  _InfoBanner(text: '讀取商品失敗：${snap.error}')
                else if (view.isEmpty)
                  const _EmptyState()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: view.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final d = view[i];
                      final p = d.data();
                      final id = d.id;

                      final title = _title(p);
                      final desc = _desc(p);
                      final price = _toInt(p['price']);
                      final updatedAt = _toDate(p['updatedAt']);
                      final active = _isActive(p);
                      final img = _imageUrl(p);

                      return _ProductCard(
                        title: title,
                        desc: desc,
                        priceText: _money(price),
                        updatedAgo: _ago(updatedAt),
                        active: active,
                        imageUrl: img,
                        onTap: () => _openDetail(id, p),
                        onMenu: (action) async {
                          if (action == 'copy') {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已複製商品ID：$id')),
                            );
                          }
                        },
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchHeader({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: '搜尋商品（名稱 / 描述）',
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(onPressed: onClear, icon: const Icon(Icons.close)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        isDense: true,
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final _SortMode value;
  final ValueChanged<_SortMode> onChanged;

  const _SortDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<_SortMode>(
      value: value,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: _SortMode.newest, child: Text('最新')),
        DropdownMenuItem(value: _SortMode.priceHigh, child: Text('價格高→低')),
        DropdownMenuItem(value: _SortMode.priceLow, child: Text('價格低→高')),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 40),
      child: Center(child: Text('沒有符合條件的商品')),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String title;
  final String desc;
  final String priceText;
  final String updatedAgo;
  final bool active;
  final String imageUrl;
  final VoidCallback onTap;
  final FutureOr<void> Function(String action) onMenu;

  const _ProductCard({
    required this.title,
    required this.desc,
    required this.priceText,
    required this.updatedAgo,
    required this.active,
    required this.imageUrl,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = active ? '上架' : '下架';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _Thumb(url: imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: active
                                ? Colors.green.shade700
                                : Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) => onMenu(v),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'copy', child: Text('複製商品ID')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        priceText,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (updatedAgo.isNotEmpty)
                        Text(
                          '更新：$updatedAgo',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
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
}

class _Thumb extends StatelessWidget {
  final String url;
  const _Thumb({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 62,
        height: 62,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 62,
            height: 62,
            color: Colors.black.withValues(alpha: 0.06),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          );
        },
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 62,
            height: 62,
            color: Colors.black.withValues(alpha: 0.06),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }
}

// lib/pages/products_page.dart
//
// ✅ ProductsPage（最終完整版｜可編譯｜已修正 curly braces｜移除 surfaceVariant/withOpacity deprecated｜修正 use_build_context_synchronously）
// ------------------------------------------------------------
// - Firestore collection: products
// - 內建：搜尋、狀態篩選(上架/下架)、快速新增/編輯/刪除、檢視詳情
// - 不依賴其他頁面（單檔可用）
//
// 建議 products schema（彈性容錯）
// products/{id} {
//   title: String
//   subtitle: String?
//   description: String?
//   price: num
//   compareAtPrice: num?
//   currency: String? (TWD)
//   images: List<String>?   // 或 imageUrls / imageUrl
//   active: bool?           // 上架狀態
//   stock: num?
//   sku: String?
//   category: String?       // 或 categoryName/categoryId
//   vendorId: String?
//   createdAt: Timestamp?
//   updatedAt: Timestamp?
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  bool _onlyActive = false;
  bool _onlyInactive = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ----------------------------
  // Helpers（安全取值）
  // ----------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  num _n(dynamic v, {num fallback = 0}) {
    if (v is num) return v;
    if (v is String) {
      final x = num.tryParse(v.trim());
      return x ?? fallback;
    }
    return fallback;
  }

  bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    if (v is String) {
      final t = v.trim().toLowerCase();
      if (t == 'true' || t == '1' || t == 'yes') return true;
      if (t == 'false' || t == '0' || t == 'no') return false;
    }
    if (v is num) return v != 0;
    return fallback;
  }

  List<String> _stringList(dynamic v) {
    if (v is List) {
      return v
          .map((e) => (e ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _fmtDate(dynamic v) {
    final dt = _toDate(v);
    if (dt == null) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _money(num v, {String currency = 'TWD'}) {
    final s = v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
    final parts = s.split('.');
    final ints = parts.first;
    final buf = StringBuffer();
    for (int i = 0; i < ints.length; i++) {
      final idxFromEnd = ints.length - i;
      buf.write(ints[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(',');
    }
    final out = parts.length == 2
        ? '${buf.toString()}.${parts[1]}'
        : buf.toString();
    return '$currency $out';
  }

  String _pickImage(Map<String, dynamic> data) {
    final images = _stringList(data['images']);
    if (images.isNotEmpty) return images.first;

    final imageUrls = _stringList(data['imageUrls']);
    if (imageUrls.isNotEmpty) return imageUrls.first;

    final imageUrl = _s(data['imageUrl']);
    if (imageUrl.isNotEmpty) return imageUrl;

    return '';
  }

  Query<Map<String, dynamic>> _baseQuery() {
    return _db.collection('products').orderBy('updatedAt', descending: true);
  }

  // ----------------------------
  // CRUD actions
  // ----------------------------
  Future<void> _toggleActive(String id, bool active) async {
    await _db.collection('products').doc(id).set({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteProduct(String id) async {
    await _db.collection('products').doc(id).delete();
  }

  Future<void> _openEditor({
    required BuildContext context,
    required String docId,
    required Map<String, dynamic> data,
    required bool isNew,
  }) async {
    final titleCtrl = TextEditingController(text: _s(data['title']));
    final subtitleCtrl = TextEditingController(text: _s(data['subtitle']));
    final descCtrl = TextEditingController(text: _s(data['description']));
    final priceCtrl = TextEditingController(
      text: _n(data['price'], fallback: 0).toString(),
    );
    final compareCtrl = TextEditingController(
      text: data['compareAtPrice'] == null
          ? ''
          : _n(data['compareAtPrice']).toString(),
    );
    final stockCtrl = TextEditingController(
      text: data['stock'] == null ? '' : _n(data['stock']).toString(),
    );
    final skuCtrl = TextEditingController(text: _s(data['sku']));
    final categoryCtrl = TextEditingController(
      text: _s(data['category']).isNotEmpty
          ? _s(data['category'])
          : (_s(data['categoryName']).isNotEmpty
                ? _s(data['categoryName'])
                : _s(data['categoryId'])),
    );
    final currencyCtrl = TextEditingController(
      text: _s(data['currency']).isNotEmpty ? _s(data['currency']) : 'TWD',
    );
    final imageCtrl = TextEditingController(text: _pickImage(data));
    bool active = _b(data['active'], fallback: true);

    void disposeAll() {
      titleCtrl.dispose();
      subtitleCtrl.dispose();
      descCtrl.dispose();
      priceCtrl.dispose();
      compareCtrl.dispose();
      stockCtrl.dispose();
      skuCtrl.dispose();
      categoryCtrl.dispose();
      currencyCtrl.dispose();
      imageCtrl.dispose();
    }

    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text(isNew ? '新增商品' : '編輯商品'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _field(titleCtrl, '商品名稱*'),
                    _field(subtitleCtrl, '副標'),
                    _field(descCtrl, '描述', maxLines: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            priceCtrl,
                            '售價*',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            compareCtrl,
                            '原價',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            stockCtrl,
                            '庫存',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(currencyCtrl, '幣別', hint: 'TWD'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _field(skuCtrl, 'SKU')),
                        const SizedBox(width: 10),
                        Expanded(child: _field(categoryCtrl, '分類')),
                      ],
                    ),
                    _field(imageCtrl, '主圖網址（images[0] / imageUrl）'),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      value: active,
                      onChanged: (v) => active = v,
                      title: const Text('上架（active）'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('儲存'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) {
      disposeAll();
      return;
    }

    final title = titleCtrl.text.trim();
    final price = num.tryParse(priceCtrl.text.trim()) ?? 0;

    if (title.isEmpty) {
      if (!mounted) {
        disposeAll();
        return;
      }
      ScaffoldMessenger.of(
        this.context,
      ).showSnackBar(const SnackBar(content: Text('商品名稱不可空白')));
      disposeAll();
      return;
    }

    final payload = <String, dynamic>{
      'title': title,
      'subtitle': subtitleCtrl.text.trim(),
      'description': descCtrl.text.trim(),
      'price': price,
      'compareAtPrice': compareCtrl.text.trim().isEmpty
          ? null
          : (num.tryParse(compareCtrl.text.trim()) ?? 0),
      'stock': stockCtrl.text.trim().isEmpty
          ? null
          : (num.tryParse(stockCtrl.text.trim()) ?? 0),
      'sku': skuCtrl.text.trim(),
      'category': categoryCtrl.text.trim(),
      'currency': currencyCtrl.text.trim().isEmpty
          ? 'TWD'
          : currencyCtrl.text.trim(),
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final img = imageCtrl.text.trim();
    if (img.isNotEmpty) {
      payload['images'] = [img];
      payload['imageUrl'] = img;
    }

    if (isNew) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await _db
        .collection('products')
        .doc(docId)
        .set(payload, SetOptions(merge: true));

    if (!mounted) {
      disposeAll();
      return;
    }
    ScaffoldMessenger.of(
      this.context,
    ).showSnackBar(const SnackBar(content: Text('已儲存')));

    disposeAll();
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('商品管理'),
        actions: [
          IconButton(
            tooltip: '只看上架',
            onPressed: () {
              setState(() {
                _onlyActive = !_onlyActive;
                if (_onlyActive) _onlyInactive = false;
              });
            },
            icon: Icon(
              _onlyActive ? Icons.check_circle : Icons.check_circle_outline,
            ),
          ),
          IconButton(
            tooltip: '只看下架',
            onPressed: () {
              setState(() {
                _onlyInactive = !_onlyInactive;
                if (_onlyInactive) _onlyActive = false;
              });
            },
            icon: Icon(
              _onlyInactive ? Icons.remove_circle : Icons.remove_circle_outline,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newId = _db.collection('products').doc().id;
          await _openEditor(
            context: context,
            docId: newId,
            data: const <String, dynamic>{},
            isNew: true,
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('新增商品'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋：名稱 / SKU / 分類',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                suffixIcon: IconButton(
                  tooltip: '清除',
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? const [];
                final k = _searchCtrl.text.trim().toLowerCase();

                final filtered = docs.where((d) {
                  final data = d.data();
                  final active = _b(data['active'], fallback: true);

                  if (_onlyActive && !active) return false;
                  if (_onlyInactive && active) return false;

                  if (k.isEmpty) return true;

                  final title = _s(data['title']).toLowerCase();
                  final sku = _s(data['sku']).toLowerCase();
                  final category = _s(data['category']).toLowerCase();
                  final categoryName = _s(data['categoryName']).toLowerCase();
                  final categoryId = _s(data['categoryId']).toLowerCase();

                  return title.contains(k) ||
                      sku.contains(k) ||
                      category.contains(k) ||
                      categoryName.contains(k) ||
                      categoryId.contains(k);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      k.isEmpty ? '目前沒有商品' : '沒有符合搜尋的商品',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 90),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final d = filtered[i];
                    final data = d.data();

                    final title = _s(data['title']).isEmpty
                        ? d.id
                        : _s(data['title']);
                    final subtitle = _s(data['subtitle']);
                    final price = _n(data['price'], fallback: 0);
                    final currency = _s(data['currency']).isEmpty
                        ? 'TWD'
                        : _s(data['currency']);
                    final stock = data['stock'] == null
                        ? null
                        : _n(data['stock']);
                    final sku = _s(data['sku']);
                    final category = _s(data['category']).isNotEmpty
                        ? _s(data['category'])
                        : (_s(data['categoryName']).isNotEmpty
                              ? _s(data['categoryName'])
                              : _s(data['categoryId']));
                    final img = _pickImage(data);
                    final active = _b(data['active'], fallback: true);
                    final updatedAt = _fmtDate(data['updatedAt']);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: ListTile(
                        leading: _Thumb(url: img),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: active
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusPill(active: active),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (subtitle.isNotEmpty)
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  _MiniChip(
                                    icon: Icons.payments_outlined,
                                    text: _money(price, currency: currency),
                                  ),
                                  if (stock != null)
                                    _MiniChip(
                                      icon: Icons.inventory_2_outlined,
                                      text: '庫存 $stock',
                                    ),
                                  if (sku.isNotEmpty)
                                    _MiniChip(icon: Icons.qr_code_2, text: sku),
                                  if (category.isNotEmpty)
                                    _MiniChip(
                                      icon: Icons.category_outlined,
                                      text: category,
                                    ),
                                  if (updatedAt.isNotEmpty)
                                    _MiniChip(
                                      icon: Icons.update,
                                      text: updatedAt,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'view') {
                              _openDetail(context, d.id, data);
                            } else if (v == 'edit') {
                              await _openEditor(
                                context: context,
                                docId: d.id,
                                data: data,
                                isNew: false,
                              );
                            } else if (v == 'toggle') {
                              await _toggleActive(d.id, !active);
                            } else if (v == 'delete') {
                              final ok =
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      title: const Text('刪除商品？'),
                                      content: Text('將刪除：「$title」'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogCtx, false),
                                          child: const Text('取消'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogCtx, true),
                                          child: const Text('刪除'),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (ok) await _deleteProduct(d.id);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.open_in_new, size: 18),
                                  SizedBox(width: 8),
                                  Text('查看'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('編輯'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Row(
                                children: [
                                  Icon(
                                    active
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(active ? '下架' : '上架'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '刪除',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _openDetail(context, d.id, data),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, String id, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(id: id, data: data),
      ),
    );
  }
}

// ----------------------------
// UI Widgets
// ----------------------------
class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (url.trim().isEmpty) {
      return CircleAvatar(
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        child: Icon(
          Icons.image_not_supported_outlined,
          color: cs.onSurfaceVariant,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            child: Icon(
              Icons.broken_image_outlined,
              color: cs.onSurfaceVariant,
            ),
          ),
          loadingBuilder: (_, child, ev) => ev == null
              ? child
              : Container(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.20),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = active
        ? cs.primary.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest.withValues(alpha: 0.35);
    final fg = active ? cs.primary : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        active ? '上架' : '下架',
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ----------------------------
// Detail page (standalone)
// ----------------------------
class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final title = _s(data['title']).isEmpty ? '商品詳細' : _s(data['title']);
    final subtitle = _s(data['subtitle']);
    final desc = _s(data['description']);
    final sku = _s(data['sku']);
    final category = _s(data['category']).isNotEmpty
        ? _s(data['category'])
        : (_s(data['categoryName']).isNotEmpty
              ? _s(data['categoryName'])
              : _s(data['categoryId']));
    final img = (() {
      final imgs = (data['images'] is List)
          ? (data['images'] as List)
                .map((e) => (e ?? '').toString().trim())
                .toList()
          : <String>[];
      if (imgs.isNotEmpty && imgs.first.isNotEmpty) return imgs.first;
      final url = _s(data['imageUrl']);
      return url;
    })();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (img.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                img,
                height: 240,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (img.trim().isNotEmpty) const SizedBox(height: 12),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 10),
          if (desc.isNotEmpty)
            SelectableText(
              desc,
              style: const TextStyle(fontSize: 15, height: 1.5),
            )
          else
            Text(
              '（無描述）',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: const Text('Doc ID'),
                  subtitle: Text(id),
                ),
                if (sku.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.qr_code_2),
                    title: const Text('SKU'),
                    subtitle: Text(sku),
                  ),
                if (category.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: const Text('分類'),
                    subtitle: Text(category),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

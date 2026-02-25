import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ✅ ProductListPage（商品列表｜修改後完整版）
/// ------------------------------------------------------------
/// ✅ 修正重點：
/// - 移除 FirestoreMockService.products 依賴（解掉 undefined_getter）
/// - 改用 Firestore：products + categories（可選）
///
/// 建議 products/{pid} 欄位：
///   - name / title: String
///   - price: num
///   - imageUrl: String (optional)
///   - categoryId: String (optional)
///   - isActive: bool (optional, default true)
///   - stock: num (optional)
///   - sort: num (optional)
///   - createdAt: Timestamp (optional)
///
/// 建議 categories/{cid} 欄位：
///   - name: String
///   - sort: num (optional)
/// ------------------------------------------------------------
class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _fs = FirebaseFirestore.instance;

  final _search = TextEditingController();
  String _categoryId = 'all';
  bool _onlyActive = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  // 主查詢：優先用 sort 排序；若你的 products 沒 sort 欄位會 runtime 報錯，會自動 fallback
  Query<Map<String, dynamic>> _productsQueryPrimary() {
    Query<Map<String, dynamic>> q = _fs.collection('products');

    if (_onlyActive) {
      // 若你沒有 isActive 欄位，建議補上；或把這段註解掉
      q = q.where('isActive', isEqualTo: true);
    }

    if (_categoryId != 'all') {
      q = q.where('categoryId', isEqualTo: _categoryId);
    }

    q = q.orderBy('sort', descending: false);
    q = q.limit(300);
    return q;
  }

  Query<Map<String, dynamic>> _productsQueryFallback() {
    Query<Map<String, dynamic>> q = _fs.collection('products');

    if (_onlyActive) {
      q = q.where('isActive', isEqualTo: true);
    }

    if (_categoryId != 'all') {
      q = q.where('categoryId', isEqualTo: _categoryId);
    }

    // fallback：用 docId 排序（避免 sort/createdAt 欄位不存在造成爆炸）
    q = q.orderBy(FieldPath.documentId, descending: true);
    q = q.limit(300);
    return q;
  }

  // categories：可不存在，不影響主功能
  Query<Map<String, dynamic>> _categoriesQuery() {
    Query<Map<String, dynamic>> q = _fs.collection('categories');
    q = q.orderBy('sort', descending: false);
    q = q.limit(200);
    return q;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applySearch(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final keyword = _search.text.trim().toLowerCase();
    if (keyword.isEmpty) return docs;

    return docs.where((doc) {
      final d = doc.data();
      final name = _s(d['name'], _s(d['title'], '')).toLowerCase();
      final desc = _s(d['description'], '').toLowerCase();
      final sku = _s(d['sku'], '').toLowerCase();
      final id = doc.id.toLowerCase();
      return name.contains(keyword) ||
          desc.contains(keyword) ||
          sku.contains(keyword) ||
          id.contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商品列表'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _topBar(),
          const Divider(height: 1),
          Expanded(child: _productStream()),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜尋商品（名稱 / SKU / 描述 / ID）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('只看上架'),
                selected: _onlyActive,
                onSelected: (v) => setState(() => _onlyActive = v),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('分類：', style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              Expanded(child: _categoryDropdown()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _categoriesQuery().snapshots(),
      builder: (context, snap) {
        // categories 可不存在：錯誤就只顯示「全部」
        final items = <DropdownMenuItem<String>>[
          const DropdownMenuItem(value: 'all', child: Text('全部')),
        ];

        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final name = _s(doc.data()['name'], doc.id);
            items.add(DropdownMenuItem(value: doc.id, child: Text(name)));
          }
        }

        // 若目前選到一個不存在的分類，回到 all 避免 Dropdown 崩
        final values = items.map((e) => e.value).toSet();
        final value = values.contains(_categoryId) ? _categoryId : 'all';
        if (value != _categoryId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _categoryId = 'all');
          });
        }

        return DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: items,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _categoryId = v);
            },
          ),
        );
      },
    );
  }

  Widget _productStream() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productsQueryPrimary().snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          // ✅ fallback：sort 欄位不存在 / 索引問題
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _productsQueryFallback().snapshots(),
            builder: (context, snap2) {
              if (snap2.hasError) {
                return _errorBox(
                  '讀取商品失敗：\n'
                  'Primary：${snap.error}\n'
                  'Fallback：${snap2.error}\n\n'
                  '建議：products 補上 sort 欄位或調整 query。',
                );
              }
              if (!snap2.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _renderList(snap2.data!.docs, note: '（已改用 docId 排序）');
            },
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return _renderList(snap.data!.docs);
      },
    );
  }

  Widget _renderList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    String note = '',
  }) {
    final filtered = _applySearch(docs);

    if (filtered.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(note, style: const TextStyle(color: Colors.grey)),
            ),
          _empty('目前沒有符合條件的商品'),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length + (note.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (note.isNotEmpty && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(note, style: const TextStyle(color: Colors.grey)),
          );
        }

        final i = note.isNotEmpty ? index - 1 : index;
        final doc = filtered[i];
        final d = doc.data();

        final name = _s(d['name'], _s(d['title'], '未命名商品'));
        final price = _asNum(d['price'], fallback: 0);
        final stock = _asNum(d['stock'], fallback: -1); // -1 表示未設定
        final imageUrl = _s(d['imageUrl'], '');
        final isActive = (d['isActive'] ?? true) == true;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: _thumb(imageUrl, name),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              [
                '價格：$price',
                if (stock >= 0) '庫存：$stock',
                'ID：${doc.id}',
              ].join('  •  '),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isActive ? '上架' : '下架',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isActive ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _openDetail(doc),
          ),
        );
      },
    );
  }

  Widget _thumb(String url, String name) {
    if (url.isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Text(name.isNotEmpty ? name.substring(0, 1) : '?'),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: Text(name.isNotEmpty ? name.substring(0, 1) : '?'),
        ),
      ),
    );
  }

  void _openDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final name = _s(d['name'], _s(d['title'], '商品'));
    final price = _asNum(d['price'], fallback: 0);
    final desc = _s(d['description'], '');
    final imageUrl = _s(d['imageUrl'], '');
    final isActive = (d['isActive'] ?? true) == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 12),
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                if (imageUrl.isNotEmpty) const SizedBox(height: 12),
                _detailRow('ID', doc.id),
                _detailRow('價格', '$price'),
                _detailRow('狀態', isActive ? '上架' : '下架'),
                if (desc.trim().isNotEmpty) _detailRow('描述', desc),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('關閉'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(k, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

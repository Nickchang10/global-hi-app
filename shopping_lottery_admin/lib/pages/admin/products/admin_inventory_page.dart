// lib/pages/admin/products/admin_inventory_page.dart
//
// ✅ AdminInventoryPage（完整版｜已修正 math 未定義）
// ------------------------------------------------------------
// - 顯示商品庫存狀態（整合 Firestore 'products' 集合）
// - 入庫 / 出庫
// - 搜尋、分類篩選
// - 更新 Firestore quantity 欄位
// ------------------------------------------------------------

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminInventoryPage extends StatefulWidget {
  const AdminInventoryPage({super.key});

  @override
  State<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends State<AdminInventoryPage> {
  final _db = FirebaseFirestore.instance;
  final _search = TextEditingController();
  String _filterCategory = '全部';
  bool _loading = true;
  List<DocumentSnapshot> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await _db.collection('products').orderBy('name').get();
      if (!mounted) return;
      setState(() {
        _products = snap.docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('載入失敗：$e')));
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '0').toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _search.text.trim().toLowerCase();

    final filtered = _products.where((doc) {
      final d = (doc.data() as Map<String, dynamic>? ?? {});
      final name = (d['name'] ?? '').toString().toLowerCase();
      final matchSearch = q.isEmpty || name.contains(q);
      final matchCat =
          _filterCategory == '全部' || (d['category'] ?? '') == _filterCategory;
      return matchSearch && matchCat;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '商品庫存管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: '搜尋商品名稱',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _filterCategory,
                        items: const [
                          DropdownMenuItem(value: '全部', child: Text('全部')),
                          DropdownMenuItem(value: '手錶', child: Text('手錶')),
                          DropdownMenuItem(value: '配件', child: Text('配件')),
                          DropdownMenuItem(value: '服務', child: Text('服務')),
                        ],
                        onChanged: (v) =>
                            setState(() => _filterCategory = v ?? '全部'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final d =
                          (filtered[i].data() as Map<String, dynamic>? ?? {});
                      final qty = _toInt(d['quantity']);

                      final images = (d['images'] is List)
                          ? (d['images'] as List)
                          : const [];
                      final img0 = images.isNotEmpty
                          ? images.first.toString()
                          : '';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: img0.isNotEmpty
                                ? Image.network(
                                    img0,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  )
                                : const SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: Center(
                                      child: Icon(
                                        Icons.inventory_2_outlined,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                          ),
                          title: Text((d['name'] ?? '').toString()),
                          subtitle: Text(
                            '分類：${(d['category'] ?? '未分類').toString()}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '庫存：$qty',
                                style: TextStyle(
                                  color: qty > 5
                                      ? cs.primary
                                      : qty > 0
                                      ? Colors.orange
                                      : cs.error,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_box_outlined),
                                onPressed: () =>
                                    _adjustStock(filtered[i], true),
                              ),
                              IconButton(
                                icon: const Icon(Icons.indeterminate_check_box),
                                onPressed: () =>
                                    _adjustStock(filtered[i], false),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _adjustStock(DocumentSnapshot doc, bool isAdd) async {
    final d = (doc.data() as Map<String, dynamic>? ?? {});
    final name = (d['name'] ?? '').toString();
    final qty = _toInt(d['quantity']);

    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${isAdd ? "入庫" : "出庫"}：$name'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '數量', hintText: '請輸入數量'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final delta = int.tryParse(ctrl.text.trim()) ?? 0;
    if (delta <= 0) return;

    final newQty = isAdd ? (qty + delta) : math.max(0, qty - delta);

    await _db.collection('products').doc(doc.id).update({
      'quantity': newQty,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已${isAdd ? "入庫" : "出庫"} $delta 件（新庫存：$newQty）')),
    );

    await _load();
  }
}

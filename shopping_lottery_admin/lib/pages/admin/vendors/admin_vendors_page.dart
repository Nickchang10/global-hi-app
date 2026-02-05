// lib/pages/admin/vendors/admin_vendors_page.dart
//
// ✅ AdminVendorsPage（最終修正版｜支援手機版｜修正 vendorId arguments）
// ------------------------------------------------------------
// - Firestore 即時同步廠商清單
// - 支援搜尋 / 多選刪除 / 排序
// - ✅ 修復：Row Overflow（Expanded + Wrap）
// - ✅ 修復：進入詳情頁必帶 vendorId（避免「缺少參數」）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminVendorsPage extends StatefulWidget {
  const AdminVendorsPage({super.key});

  @override
  State<AdminVendorsPage> createState() => _AdminVendorsPageState();
}

class _AdminVendorsPageState extends State<AdminVendorsPage> {
  final _db = FirebaseFirestore.instance;
  final TextEditingController _search = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selected = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query =
        _db.collection('vendors').orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('廠商管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_selectionMode)
            IconButton(
              tooltip: '刪除選取項目',
              icon: const Icon(Icons.delete),
              onPressed: _selected.isEmpty ? null : _confirmBatchDelete,
            ),
          IconButton(
            tooltip: _selectionMode ? '取消多選' : '多選模式',
            icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
            onPressed: () => setState(() {
              _selectionMode = !_selectionMode;
              if (!_selectionMode) _selected.clear();
            }),
          ),
          IconButton(
            tooltip: '新增廠商',
            icon: const Icon(Icons.add_business),
            onPressed: () => Navigator.pushNamed(context, '/admin_vendors/edit'),
          ),
        ],
      ),
      body: Column(
        children: [
          _searchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('載入失敗：${snap.error}'));
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(child: Text('目前沒有廠商資料'));
                }

                final searchText = _search.text.trim().toLowerCase();

                final vendors = snap.data!.docs.where((d) {
                  final data = d.data();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  final region = (data['region'] ?? '').toString().toLowerCase();
                  return searchText.isEmpty ||
                      name.contains(searchText) ||
                      email.contains(searchText) ||
                      phone.contains(searchText) ||
                      region.contains(searchText);
                }).toList();

                if (vendors.isEmpty) {
                  return const Center(child: Text('找不到符合的廠商'));
                }

                return ListView.builder(
                  itemCount: vendors.length,
                  itemBuilder: (context, i) {
                    final doc = vendors[i];
                    return _vendorTile(doc, cs);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 搜尋欄
  // ============================================================
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: '搜尋廠商名稱 / Email / 電話 / 區域',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // ============================================================
  // 廠商卡片
  // ============================================================
  Widget _vendorTile(DocumentSnapshot<Map<String, dynamic>> doc, ColorScheme cs) {
    final data = doc.data() ?? {};
    final name = (data['name'] ?? '未命名').toString();
    final email = (data['email'] ?? '未設定').toString();
    final phone = (data['phone'] ?? '').toString();
    final region = (data['region'] ?? '未指定').toString();
    final status = (data['status'] ?? 'active').toString();

    final selected = _selected.contains(doc.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _selectionMode
            ? () {
                setState(() {
                  if (selected) {
                    _selected.remove(doc.id);
                  } else {
                    _selected.add(doc.id);
                  }
                });
              }
            : () {
                // ✅ 重點：詳情頁需要 vendorId
                Navigator.pushNamed(
                  context,
                  '/admin_vendors/detail',
                  arguments: {
                    'vendorId': doc.id, // ✅ 正式 key
                    'id': doc.id, // ✅ 向下相容（如果你舊版還在用 id）
                  },
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.store, size: 36, color: Colors.blue),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        '電話：$phone',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Chip(
                          label: Text(region),
                          backgroundColor: Colors.grey.shade200,
                        ),
                        Chip(
                          label: Text(status == 'active' ? '啟用' : '停用'),
                          backgroundColor: status == 'active'
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_selectionMode)
                Checkbox(
                  value: selected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(doc.id);
                      } else {
                        _selected.remove(doc.id);
                      }
                    });
                  },
                )
              else
                IconButton(
                  tooltip: '編輯廠商',
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () {
                    // ✅ 建議：同時帶 vendorId + data，避免 edit 頁缺 id
                    Navigator.pushNamed(
                      context,
                      '/admin_vendors/edit',
                      arguments: {
                        'vendorId': doc.id,
                        'data': data,
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 批次刪除
  // ============================================================
  Future<void> _confirmBatchDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除選取廠商？'),
        content: Text('共選取 ${_selected.length} 筆，刪除後無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.delete(_db.collection('vendors').doc(id));
    }
    await batch.commit();

    setState(() => _selected.clear());

    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已刪除選取廠商')));
    }
  }
}

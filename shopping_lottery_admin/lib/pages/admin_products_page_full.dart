// lib/pages/admin_products_page_full.dart
//
// ✅ AdminProductsPageFull（修正版｜可編譯｜Lint 友善）
// ------------------------------------------------------------
// 修正：
// - AppBar UserInfoBadge 缺少必填 title
// - 避免 curly_braces_in_flow_control_structures：所有單行 if/for return 都改成 {}
// ------------------------------------------------------------

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/product_service.dart';
import '../services/auth_service.dart';
import '../services/admin_gate.dart';
import '../widgets/user_info_badge.dart';
import '../utils/csv_download.dart';

class AdminProductsPageFull extends StatefulWidget {
  const AdminProductsPageFull({super.key});

  @override
  State<AdminProductsPageFull> createState() => _AdminProductsPageFullState();
}

class _AdminProductsPageFullState extends State<AdminProductsPageFull> {
  static const String kAll = '__all__';

  final _db = FirebaseFirestore.instance;

  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = <String>{};

  String _q = '';
  String _cat = kAll;
  String _status = kAll; // kAll / active / inactive
  String _vendor = kAll;

  int _page = 1;
  int _pageSize = 20;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  Future<RoleInfo>? _roleFuture;
  String? _roleUid;

  void _snack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  bool _isActive(Map<String, dynamic> p) => (p['isActive'] ?? true) == true;

  String _fmtPrice(dynamic v) {
    final n = num.tryParse('$v');
    return n == null ? '-' : 'NT\$${n.toStringAsFixed(0)}';
  }

  Map<String, dynamic> _normalizeProduct(dynamic raw) {
    final m = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
    final id = _s(m['id']);
    if (id.isNotEmpty) {
      return m;
    }
    final docId = _s(m['docId'] ?? m['documentId'] ?? m['_id']);
    if (docId.isNotEmpty) {
      return <String, dynamic>{'id': docId, ...m};
    }
    return m;
  }

  Stream<List<Map<String, dynamic>>> _productsStream(ProductService svc) {
    try {
      final dynamic s = (svc as dynamic).streamProductMaps?.call();
      if (s is Stream<List<Map<String, dynamic>>>) {
        return s;
      }
      if (s is Stream<List>) {
        return s.map((list) => list.map((e) => _normalizeProduct(e)).toList());
      }
    } catch (_) {}

    try {
      final dynamic s = (svc as dynamic).streamProducts?.call();
      if (s is Stream<List<Map<String, dynamic>>>) {
        return s;
      }
      if (s is Stream<List>) {
        return s.map((list) => list.map((e) => _normalizeProduct(e)).toList());
      }
      if (s is Stream<QuerySnapshot<Map<String, dynamic>>>) {
        return s.map((snap) {
          return snap.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList();
        });
      }
      if (s is Stream<QuerySnapshot>) {
        return s.map((snap) {
          return snap.docs.map((doc) {
            final data = (doc.data() as Map?) ?? {};
            return <String, dynamic>{
              'id': doc.id,
              ...Map<String, dynamic>.from(data),
            };
          }).toList();
        });
      }
    } catch (_) {}

    return _db.collection('products').snapshots().map((snap) {
      return snap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList();
    });
  }

  Future<void> _toggleActive(ProductService svc, String id, bool v) async {
    try {
      await (svc as dynamic).toggleActive(id, v);
      return;
    } catch (_) {}

    await _db.collection('products').doc(id).set(<String, dynamic>{
      'isActive': v,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteProduct(ProductService svc, String id) async {
    try {
      await (svc as dynamic).deleteProductWithImages(id);
      return;
    } catch (_) {}

    await _db.collection('products').doc(id).delete();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all) {
    final q = _q.trim().toLowerCase();

    return all.map(_normalizeProduct).where((p) {
      final vendorId = _s(p['vendorId']);
      final catId = _s(p['categoryId']);
      final active = _isActive(p);

      if (_vendor != kAll && vendorId != _vendor) {
        return false;
      }
      if (_cat != kAll && catId != _cat) {
        return false;
      }

      if (_status == 'active' && !active) {
        return false;
      }
      if (_status == 'inactive' && active) {
        return false;
      }

      if (q.isEmpty) {
        return true;
      }
      final id = _s(p['id']).toLowerCase();
      final title = _s(p['title']).toLowerCase();
      return id.contains(q) || title.contains(q);
    }).toList();
  }

  int _cmp(dynamic a, dynamic b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return -1;
    }
    if (b == null) {
      return 1;
    }

    final na = (a is num) ? a : num.tryParse('$a');
    final nb = (b is num) ? b : num.tryParse('$b');
    if (na != null && nb != null) {
      return na.compareTo(nb);
    }

    if (a is bool && b is bool) {
      return a == b ? 0 : (a ? 1 : -1);
    }

    return '$a'.compareTo('$b');
  }

  List<Map<String, dynamic>> _sort(List<Map<String, dynamic>> list) {
    final idx = _sortColumnIndex;
    if (idx == null) {
      return list;
    }

    String keyOf(int column) {
      switch (column) {
        case 1:
          return 'id';
        case 2:
          return 'title';
        case 3:
          return 'price';
        case 4:
          return 'isActive';
        default:
          return 'id';
      }
    }

    final key = keyOf(idx);
    final copy = <Map<String, dynamic>>[...list];
    copy.sort((a, b) {
      final va = a[key];
      final vb = b[key];
      final c = _cmp(va, vb);
      return _sortAscending ? c : -c;
    });
    return copy;
  }

  Widget _thumb(String? url, {double size = 46}) {
    final u = (url ?? '').trim();
    final cs = Theme.of(context).colorScheme;

    if (u.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.image_not_supported_outlined, size: 18),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        u,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: size,
            height: size,
            color: cs.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined, size: 18),
          );
        },
      ),
    );
  }

  Future<void> _exportCsv(List<Map<String, dynamic>> list) async {
    final headers = <String>[
      'id',
      'title',
      'vendorId',
      'categoryId',
      'price',
      'rating',
      'isActive',
      'imageUrl',
    ];

    final rows = <List<String>>[headers];

    for (final p in list) {
      rows.add(<String>[
        _s(p['id']),
        _s(p['title']),
        _s(p['vendorId']),
        _s(p['categoryId']),
        _s(p['price']),
        _s(p['rating']),
        _isActive(p).toString(),
        _s(p['imageUrl']),
      ]);
    }

    final csv = rows
        .map((r) => r.map((e) => '"${e.replaceAll('"', '""')}"').join(','))
        .join('\n');

    await downloadCsv('products_export.csv', csv);
    _snack('已匯出 CSV');
  }

  Future<bool> _confirm(String title, String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _setSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _page = 1;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prodSvc = context.read<ProductService>();
    final gate = context.read<AdminGate>();
    final auth = context.read<AuthService>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        if (_roleFuture == null || _roleUid != user.uid) {
          _roleUid = user.uid;
          _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);
        }

        return FutureBuilder<RoleInfo>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (_s(roleSnap.data!.role) != 'admin') {
              return const Scaffold(body: Center(child: Text('需要 Admin 權限')));
            }

            final badgeTitle = (user.displayName ?? '').trim().isNotEmpty
                ? user.displayName!.trim()
                : ((user.email ?? '').trim().isNotEmpty
                      ? user.email!.trim()
                      : user.uid);

            return Scaffold(
              appBar: AppBar(
                title: const Text('商品管理（進階版）'),
                actions: [
                  // ✅ FIX: title 必填
                  UserInfoBadge(
                    title: badgeTitle,
                    subtitle: (user.email ?? '').trim(),
                    role: _s(roleSnap.data!.role),
                    uid: user.uid,
                  ),
                  IconButton(
                    tooltip: '登出',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await auth.signOut();
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _productsStream(prodSvc),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final all = (snap.data ?? <Map<String, dynamic>>[])
                        .map(_normalizeProduct)
                        .toList();

                    final vendors =
                        all
                            .map((p) => _s(p['vendorId']))
                            .where((e) => e.isNotEmpty)
                            .toSet()
                            .toList()
                          ..sort();

                    final cats =
                        all
                            .map((p) => _s(p['categoryId']))
                            .where((e) => e.isNotEmpty)
                            .toSet()
                            .toList()
                          ..sort();

                    final filtered = _filter(all);
                    final sorted = _sort(filtered);

                    final total = sorted.length;
                    final totalPages = max(1, (total / _pageSize).ceil());
                    final page = _page.clamp(1, totalPages);

                    if (page != _page) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _page = page;
                          });
                        }
                      });
                    }

                    final start = (page - 1) * _pageSize;
                    final end = min(start + _pageSize, total);
                    final pageList = (start < end)
                        ? sorted.sublist(start, end)
                        : <Map<String, dynamic>>[];

                    final isWide = MediaQuery.sizeOf(context).width > 960;

                    bool allSelectedOnPage() {
                      if (pageList.isEmpty) {
                        return false;
                      }
                      for (final p in pageList) {
                        final id = _s(p['id']);
                        if (id.isEmpty) {
                          continue;
                        }
                        if (!_selectedIds.contains(id)) {
                          return false;
                        }
                      }
                      return true;
                    }

                    void toggleSelectAllOnPage() {
                      setState(() {
                        final allSel = allSelectedOnPage();
                        for (final p in pageList) {
                          final id = _s(p['id']);
                          if (id.isEmpty) {
                            continue;
                          }
                          if (allSel) {
                            _selectedIds.remove(id);
                          } else {
                            _selectedIds.add(id);
                          }
                        }
                      });
                    }

                    Future<void> batchSetActive(bool v) async {
                      final ids = _selectedIds.toList();
                      if (ids.isEmpty) {
                        _snack('請先勾選商品');
                        return;
                      }
                      final ok = await _confirm(
                        '批次更新',
                        '確定要將 ${ids.length} 筆商品設為「${v ? '上架' : '下架'}」？',
                      );
                      if (!ok) {
                        return;
                      }

                      int done = 0;
                      for (final id in ids) {
                        await _toggleActive(prodSvc, id, v);
                        done++;
                      }
                      _snack('已更新 $done 筆');
                    }

                    Future<void> batchDelete() async {
                      final ids = _selectedIds.toList();
                      if (ids.isEmpty) {
                        _snack('請先勾選商品');
                        return;
                      }
                      final ok = await _confirm(
                        '批次刪除',
                        '⚠️ 確定要刪除 ${ids.length} 筆商品？（此動作不可回復）',
                      );
                      if (!ok) {
                        return;
                      }

                      int done = 0;
                      for (final id in ids) {
                        await _deleteProduct(prodSvc, id);
                        done++;
                      }
                      _clearSelection();
                      _snack('已刪除 $done 筆');
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (v) {
                                  setState(() {
                                    _q = v;
                                    _page = 1;
                                  });
                                },
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: '搜尋商品 ID 或標題',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () => _exportCsv(sorted),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('匯出 CSV'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 240,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('vendor_$_vendor'),
                                initialValue: _vendor,
                                decoration: const InputDecoration(
                                  labelText: 'Vendor',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: kAll,
                                    child: Text('全部'),
                                  ),
                                  ...vendors.map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _vendor = v ?? kAll;
                                    _page = 1;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 240,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('cat_$_cat'),
                                initialValue: _cat,
                                decoration: const InputDecoration(
                                  labelText: '分類',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: kAll,
                                    child: Text('全部'),
                                  ),
                                  ...cats.map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _cat = v ?? kAll;
                                    _page = 1;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 200,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('status_$_status'),
                                initialValue: _status,
                                decoration: const InputDecoration(
                                  labelText: '狀態',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: kAll,
                                    child: Text('全部'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'active',
                                    child: Text('上架'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'inactive',
                                    child: Text('下架'),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _status = v ?? kAll;
                                    _page = 1;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 160,
                              child: DropdownButtonFormField<int>(
                                key: ValueKey('pageSize_$_pageSize'),
                                initialValue: _pageSize,
                                decoration: const InputDecoration(
                                  labelText: '每頁',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 10,
                                    child: Text('10'),
                                  ),
                                  DropdownMenuItem(
                                    value: 20,
                                    child: Text('20'),
                                  ),
                                  DropdownMenuItem(
                                    value: 50,
                                    child: Text('50'),
                                  ),
                                  DropdownMenuItem(
                                    value: 100,
                                    child: Text('100'),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _pageSize = v ?? 20;
                                    _page = 1;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Checkbox(
                              value: allSelectedOnPage(),
                              onChanged: (_) => toggleSelectAllOnPage(),
                            ),
                            const Text('全選本頁'),
                            const SizedBox(width: 10),
                            TextButton.icon(
                              onPressed: _selectedIds.isEmpty
                                  ? null
                                  : _clearSelection,
                              icon: const Icon(Icons.clear),
                              label: Text('清除勾選（${_selectedIds.length}）'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              onPressed: _selectedIds.isEmpty
                                  ? null
                                  : () => batchSetActive(true),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('批次上架'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              onPressed: _selectedIds.isEmpty
                                  ? null
                                  : () => batchSetActive(false),
                              icon: const Icon(Icons.remove_circle_outline),
                              label: const Text('批次下架'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              onPressed: _selectedIds.isEmpty
                                  ? null
                                  : batchDelete,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('批次刪除'),
                            ),
                            const Spacer(),
                            Text('共 $total 筆'),
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: '上一頁',
                              onPressed: page <= 1
                                  ? null
                                  : () {
                                      setState(() {
                                        _page = page - 1;
                                      });
                                    },
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('$page / $totalPages'),
                            IconButton(
                              tooltip: '下一頁',
                              onPressed: page >= totalPages
                                  ? null
                                  : () {
                                      setState(() {
                                        _page = page + 1;
                                      });
                                    },
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Expanded(
                          child: isWide
                              ? SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    showCheckboxColumn: true,
                                    sortColumnIndex: _sortColumnIndex,
                                    sortAscending: _sortAscending,
                                    columns: [
                                      const DataColumn(label: Text('圖片')),
                                      DataColumn(
                                        label: const Text('ID'),
                                        onSort: (i, asc) => _setSort(i, asc),
                                      ),
                                      DataColumn(
                                        label: const Text('標題'),
                                        onSort: (i, asc) => _setSort(i, asc),
                                      ),
                                      DataColumn(
                                        numeric: true,
                                        label: const Text('價格'),
                                        onSort: (i, asc) => _setSort(i, asc),
                                      ),
                                      DataColumn(
                                        label: const Text('上架'),
                                        onSort: (i, asc) => _setSort(i, asc),
                                      ),
                                      const DataColumn(label: Text('操作')),
                                    ],
                                    rows: pageList.map((p) {
                                      final id = _s(p['id']);
                                      return DataRow(
                                        selected: _selectedIds.contains(id),
                                        onSelectChanged: (v) {
                                          setState(() {
                                            if (v == true) {
                                              _selectedIds.add(id);
                                            } else {
                                              _selectedIds.remove(id);
                                            }
                                          });
                                        },
                                        cells: [
                                          DataCell(_thumb(_s(p['imageUrl']))),
                                          DataCell(Text(id)),
                                          DataCell(Text(_s(p['title']))),
                                          DataCell(Text(_fmtPrice(p['price']))),
                                          DataCell(
                                            Switch(
                                              value: _isActive(p),
                                              onChanged: (v) async {
                                                await _toggleActive(
                                                  prodSvc,
                                                  id,
                                                  v,
                                                );
                                                _snack('已更新商品上架狀態');
                                              },
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                IconButton(
                                                  tooltip: '預覽',
                                                  icon: const Icon(
                                                    Icons
                                                        .remove_red_eye_outlined,
                                                  ),
                                                  onPressed: () => showDialog(
                                                    context: context,
                                                    builder: (dialogCtx) => AlertDialog(
                                                      title: Text(
                                                        _s(p['title']),
                                                      ),
                                                      content: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          _thumb(
                                                            _s(p['imageUrl']),
                                                            size: 140,
                                                          ),
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                          Align(
                                                            alignment: Alignment
                                                                .centerLeft,
                                                            child: SelectableText(
                                                              'ID: ${_s(p['id'])}',
                                                            ),
                                                          ),
                                                          Align(
                                                            alignment: Alignment
                                                                .centerLeft,
                                                            child: SelectableText(
                                                              '價格: ${_fmtPrice(p['price'])}',
                                                            ),
                                                          ),
                                                          Align(
                                                            alignment: Alignment
                                                                .centerLeft,
                                                            child: SelectableText(
                                                              '廠商: ${_s(p['vendorId'])}',
                                                            ),
                                                          ),
                                                          Align(
                                                            alignment: Alignment
                                                                .centerLeft,
                                                            child: SelectableText(
                                                              '分類: ${_s(p['categoryId'])}',
                                                            ),
                                                          ),
                                                          Align(
                                                            alignment: Alignment
                                                                .centerLeft,
                                                            child: SelectableText(
                                                              '上架: ${_isActive(p) ? '是' : '否'}',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                dialogCtx,
                                                              ),
                                                          child: const Text(
                                                            '關閉',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: '刪除',
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                  ),
                                                  onPressed: () async {
                                                    final ok = await _confirm(
                                                      '刪除商品',
                                                      '確定要刪除 $id？',
                                                    );
                                                    if (!ok) {
                                                      return;
                                                    }
                                                    await _deleteProduct(
                                                      prodSvc,
                                                      id,
                                                    );
                                                    _selectedIds.remove(id);
                                                    _snack('已刪除 $id');
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: pageList.length,
                                  itemBuilder: (context, i) {
                                    final p = pageList[i];
                                    final id = _s(p['id']);
                                    final checked = _selectedIds.contains(id);

                                    return Card(
                                      child: ListTile(
                                        leading: _thumb(_s(p['imageUrl'])),
                                        title: Text(_s(p['title'])),
                                        subtitle: Text(
                                          '${_fmtPrice(p['price'])} | ID: $id',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Checkbox(
                                              value: checked,
                                              onChanged: (v) {
                                                setState(() {
                                                  if (v == true) {
                                                    _selectedIds.add(id);
                                                  } else {
                                                    _selectedIds.remove(id);
                                                  }
                                                });
                                              },
                                            ),
                                            Switch(
                                              value: _isActive(p),
                                              onChanged: (v) async {
                                                await _toggleActive(
                                                  prodSvc,
                                                  id,
                                                  v,
                                                );
                                                _snack('已更新商品上架狀態');
                                              },
                                            ),
                                          ],
                                        ),
                                        onTap: () => showDialog(
                                          context: context,
                                          builder: (dialogCtx) => AlertDialog(
                                            title: Text(_s(p['title'])),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _thumb(
                                                  _s(p['imageUrl']),
                                                  size: 140,
                                                ),
                                                const SizedBox(height: 10),
                                                Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: SelectableText(
                                                    'ID: ${_s(p['id'])}',
                                                  ),
                                                ),
                                                Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: SelectableText(
                                                    '價格: ${_fmtPrice(p['price'])}',
                                                  ),
                                                ),
                                                Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: SelectableText(
                                                    '上架: ${_isActive(p) ? '是' : '否'}',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(dialogCtx),
                                                child: const Text('關閉'),
                                              ),
                                              FilledButton.tonalIcon(
                                                onPressed: () async {
                                                  final ok = await _confirm(
                                                    '刪除商品',
                                                    '確定要刪除 $id？',
                                                  );
                                                  if (!ok) {
                                                    return;
                                                  }
                                                  await _deleteProduct(
                                                    prodSvc,
                                                    id,
                                                  );
                                                  _selectedIds.remove(id);
                                                  if (context.mounted) {
                                                    Navigator.pop(dialogCtx);
                                                  }
                                                  _snack('已刪除 $id');
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                label: const Text('刪除'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

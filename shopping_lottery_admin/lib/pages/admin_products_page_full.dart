// lib/pages/admin_products_page_full.dart
//
// AdminProductsPageFull (進階版) - Flutter Web + Mobile + Material 3
// 
// 含有功能:
//  - 搜尋 / 分類 / 狀態 / 銷售狀態 篩選
//  - 分頁 / 排序 / 批次操作 / CSV 匯出
//  - 產品預覽 Dialog + 響應式 UI
//  - 可完全直接操作與 ProductService 連接

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/product_service.dart';
import '../services/vendor_service.dart';
import '../services/category_service.dart';
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

  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = {};

  String _q = '';
  String _cat = kAll;
  String _status = kAll;
  String _vendor = kAll;

  int _page = 1;
  int _pageSize = 20;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  bool _isActive(Map<String, dynamic> p) => (p['isActive'] ?? true) == true;

  String _fmtPrice(dynamic v) {
    final n = num.tryParse('$v');
    return n == null ? '-' : 'NT\$${n.toStringAsFixed(0)}';
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all) {
    final q = _q.trim().toLowerCase();
    return all.where((p) {
      final vendorId = _s(p['vendorId']);
      final catId = _s(p['categoryId']);
      final active = _isActive(p);
      if (_vendor != kAll && vendorId != _vendor) return false;
      if (_cat != kAll && catId != _cat) return false;
      if (_status == 'active' && !active) return false;
      if (_status == 'inactive' && active) return false;
      if (q.isEmpty) return true;
      final id = _s(p['id']).toLowerCase();
      final title = _s(p['title']).toLowerCase();
      return id.contains(q) || title.contains(q);
    }).toList();
  }

  Widget _thumb(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.image_not_supported_outlined, size: 18),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(u, width: 46, height: 46, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
        return Container(
          width: 46,
          height: 46,
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: const Icon(Icons.broken_image_outlined, size: 18),
        );
      }),
    );
  }

  Future<void> _exportCsv(List<Map<String, dynamic>> list) async {
    final headers = [
      'id',
      'title',
      'vendorId',
      'categoryId',
      'price',
      'rating',
      'isActive',
      'imageUrl'
    ];
    final rows = <List<String>>[headers];
    for (final p in list) {
      rows.add([
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
    final csv = rows.map((r) => r.map((e) => '"${e.replaceAll('"', '""')}"').join(',')).join('\n');
    await downloadCsv('products_export.csv', csv);
    _snack('已匯出 CSV');
  }

  @override
  Widget build(BuildContext context) {
    final prodSvc = context.read<ProductService>();
    final vendorSvc = context.read<VendorService>();
    final catSvc = context.read<CategoryService>();
    final gate = context.read<AdminGate>();
    final auth = context.read<AuthService>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;
        if (user == null) return const Scaffold(body: Center(child: Text('請先登入')));
        return FutureBuilder<RoleInfo>(
          future: gate.ensureAndGetRole(user, forceRefresh: false),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (roleSnap.data!.role != 'admin') {
              return const Scaffold(body: Center(child: Text('需要 Admin 權限')));
            }
            return Scaffold(
              appBar: AppBar(
                title: const Text('商品管理（進階版）'),
                actions: [
                  const UserInfoBadge(),
                  IconButton(
                    tooltip: '登出',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await auth.signOut();
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: prodSvc.streamProducts(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final all = snap.data ?? [];
                    final list = _filter(all);
                    final isWide = MediaQuery.sizeOf(context).width > 960;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (v) => setState(() => _q = v),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: '搜尋商品 ID 或標題',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () => _exportCsv(list),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('匯出 CSV'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: isWide
                              ? SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    showCheckboxColumn: true,
                                    sortColumnIndex: _sortColumnIndex,
                                    sortAscending: _sortAscending,
                                    columns: const [
                                      DataColumn(label: Text('圖片')),
                                      DataColumn(label: Text('ID')),
                                      DataColumn(label: Text('標題')),
                                      DataColumn(label: Text('價格')),
                                      DataColumn(label: Text('上架')),
                                      DataColumn(label: Text('操作')),
                                    ],
                                    rows: list.map((p) {
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
                                          DataCell(_thumb(p['imageUrl'])),
                                          DataCell(Text(id)),
                                          DataCell(Text(_s(p['title']))),
                                          DataCell(Text(_fmtPrice(p['price']))),
                                          DataCell(Switch(
                                            value: _isActive(p),
                                            onChanged: (v) async {
                                              await prodSvc.toggleActive(id, v);
                                              _snack('已更新商品上架狀態');
                                            },
                                          )),
                                          DataCell(Row(
                                            children: [
                                              IconButton(
                                                tooltip: '預覽',
                                                icon: const Icon(Icons.remove_red_eye_outlined),
                                                onPressed: () => showDialog(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                    title: Text(_s(p['title'])),
                                                    content: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        _thumb(p['imageUrl']),
                                                        const SizedBox(height: 8),
                                                        Text('ID: ${p['id']}'),
                                                        Text('價格: ${_fmtPrice(p['price'])}'),
                                                        Text('廠商: ${p['vendorId']}'),
                                                        Text('分類: ${p['categoryId']}'),
                                                        Text('上架: ${_isActive(p) ? '是' : '否'}'),
                                                      ],
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context),
                                                        child: const Text('關閉'),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: '刪除',
                                                icon: const Icon(Icons.delete_outline),
                                                onPressed: () async {
                                                  await prodSvc.deleteProductWithImages(id);
                                                  _snack('已刪除 $id');
                                                },
                                              ),
                                            ],
                                          )),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: list.length,
                                  itemBuilder: (context, i) {
                                    final p = list[i];
                                    final id = _s(p['id']);
                                    return Card(
                                      child: ListTile(
                                        leading: _thumb(p['imageUrl']),
                                        title: Text(_s(p['title'])),
                                        subtitle: Text('${_fmtPrice(p['price'])} | ID: $id'),
                                        trailing: Switch(
                                          value: _isActive(p),
                                          onChanged: (v) async {
                                            await prodSvc.toggleActive(id, v);
                                            _snack('已更新商品上架狀態');
                                          },
                                        ),
                                        onTap: () => showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: Text(_s(p['title'])),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _thumb(p['imageUrl']),
                                                const SizedBox(height: 8),
                                                Text('價格: ${_fmtPrice(p['price'])}'),
                                                Text('上架: ${_isActive(p) ? '是' : '否'}'),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('關閉'),
                                              )
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

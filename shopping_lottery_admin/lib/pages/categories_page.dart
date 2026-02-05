// lib/pages/categories_page.dart
//
// ✅ CategoriesPage（最終完整版｜可編譯｜Admin Only｜CRUD｜可拖曳排序｜匯出 CSV）
//
// Firestore：categories/{categoryId}
//   - name: String
//   - slug: String
//   - sort: num (建議 int)
//   - isActive: bool
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//
// 依賴：cloud_firestore, firebase_auth, provider（可選）, ../services/admin_gate.dart, ../utils/csv_download.dart
// ------------------------------------------------------------

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../utils/csv_download.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _db = FirebaseFirestore.instance;

  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  final _searchCtrl = TextEditingController();
  String _q = '';
  bool? _isActive; // null=全部, true=啟用, false=停用

  bool _busy = false;
  String _busyLabel = '';

  // reordering local buffer（避免 reorder 時被 stream 立刻重排）
  List<_CatRow> _buffer = <_CatRow>[];
  bool _bufferPrimed = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------- utils ----------
  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _isTrue(dynamic v) => v == true;

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString()) ?? 0;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      try {
        if (v < 10000000000) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {}
    }
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  AdminGate _gate(BuildContext c) {
    try {
      return Provider.of<AdminGate>(c, listen: false);
    } catch (_) {
      return AdminGate();
    }
  }

  Future<void> _setBusy(bool v, {String label = ''}) async {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  // ---------- stream ----------
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamCategories() {
    // 盡量保持簡單的 query：sort asc
    Query<Map<String, dynamic>> q = _db.collection('categories').orderBy('sort').limit(800);

    // 需要篩選時用 where + orderBy(sort)（可能需要複合索引，console 會提示）
    if (_isActive != null) {
      q = _db
          .collection('categories')
          .where('isActive', isEqualTo: _isActive)
          .orderBy('sort')
          .limit(800);
    }
    return q.snapshots();
  }

  bool _match(_CatRow r) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    final id = r.id.toLowerCase();
    final name = _s(r.data['name']).toLowerCase();
    final slug = _s(r.data['slug']).toLowerCase();
    return id.contains(q) || name.contains(q) || slug.contains(q);
  }

  // ---------- CRUD ----------
  Future<void> _toggleActive(String id, bool active) async {
    final cid = id.trim();
    if (cid.isEmpty) return;

    await _setBusy(true, label: active ? '啟用中...' : '停用中...');
    try {
      await _db.collection('categories').doc(cid).set(
        <String, dynamic>{
          'isActive': active,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _snack(active ? '已啟用' : '已停用');
    } catch (e) {
      _snack('操作失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _deleteCategory(String id) async {
    final cid = id.trim();
    if (cid.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除分類'),
        content: Text('確定要刪除分類：$cid 嗎？（不可復原）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (ok != true) return;

    await _setBusy(true, label: '刪除中...');
    try {
      await _db.collection('categories').doc(cid).delete();
      _snack('已刪除：$cid');
    } catch (e) {
      _snack('刪除失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  String _autoSlug(String name) {
    final t = name.trim().toLowerCase();
    // 只允許 a-z 0-9 - _
    final slug = t
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\-_]'), '');
    return slug;
  }

  Future<void> _openEditDialog({String? id, Map<String, dynamic>? data}) async {
    final isCreate = (id == null || id.trim().isEmpty);

    final nameCtrl = TextEditingController(text: _s(data?['name']));
    final slugCtrl = TextEditingController(text: _s(data?['slug']));
    final sortCtrl = TextEditingController(
      text: data == null ? '' : '${_toNum(data['sort']).toInt()}',
    );
    bool isActive = data == null ? true : _isTrue(data['isActive']);

    bool autoSlug = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isCreate ? '新增分類' : '編輯分類'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '分類名稱 name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    if (!autoSlug) return;
                    final auto = _autoSlug(v);
                    if (auto.isNotEmpty) slugCtrl.text = auto;
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: slugCtrl,
                  decoration: const InputDecoration(
                    labelText: 'slug（路徑/識別）',
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: '例如：health / kids / accessories',
                  ),
                  onChanged: (_) => autoSlug = false,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sortCtrl,
                  decoration: const InputDecoration(
                    labelText: '排序 sort（數字，越小越前）',
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: '留空=自動',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('啟用 isActive'),
                  value: isActive,
                  onChanged: (v) => isActive = v,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '提示：拖曳列表可批次更新 sort；若你手動填 sort，仍會依 sort 排序。',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('儲存')),
        ],
      ),
    );

    if (ok == true) {
      final name = nameCtrl.text.trim();
      final slug = slugCtrl.text.trim();
      final sortInput = sortCtrl.text.trim();

      if (name.isEmpty) {
        _snack('分類名稱不可為空');
        nameCtrl.dispose();
        slugCtrl.dispose();
        sortCtrl.dispose();
        return;
      }

      int? sort;
      if (sortInput.isNotEmpty) {
        sort = int.tryParse(sortInput);
        if (sort == null) {
          _snack('sort 必須是數字');
          nameCtrl.dispose();
          slugCtrl.dispose();
          sortCtrl.dispose();
          return;
        }
      }

      await _setBusy(true, label: '儲存中...');
      try {
        if (isCreate) {
          // 自動 sort：找目前最大 sort + 10（避免頻繁重排）
          int autoSort = 10;
          try {
            final maxSnap = await _db
                .collection('categories')
                .orderBy('sort', descending: true)
                .limit(1)
                .get();
            if (maxSnap.docs.isNotEmpty) {
              final v = _toNum(maxSnap.docs.first.data()['sort']).toInt();
              autoSort = (v <= 0 ? 10 : v + 10);
            }
          } catch (_) {}

          final ref = _db.collection('categories').doc();
          await ref.set(<String, dynamic>{
            'name': name,
            'slug': slug,
            'sort': sort ?? autoSort,
            'isActive': isActive,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          _snack('已新增分類：${ref.id}');
          // 讓 buffer 重新 primed
          _bufferPrimed = false;
        } else {
          final cid = id!.trim();
          await _db.collection('categories').doc(cid).set(<String, dynamic>{
            'name': name,
            'slug': slug,
            if (sort != null) 'sort': sort,
            'isActive': isActive,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          _snack('已更新：$cid');
          _bufferPrimed = false;
        }
      } catch (e) {
        _snack('儲存失敗：$e');
      } finally {
        await _setBusy(false);
      }
    }

    nameCtrl.dispose();
    slugCtrl.dispose();
    sortCtrl.dispose();
  }

  // ---------- reorder ----------
  Future<void> _commitSortOrder(List<_CatRow> list) async {
    // batch 一次最多 500，這裡保守 450
    const page = 450;

    await _setBusy(true, label: '排序寫入中...');
    try {
      int i = 0;
      while (i < list.length) {
        final chunk = list.skip(i).take(page).toList();
        final batch = _db.batch();

        // 重新配 sort：10,20,30...
        for (int idx = 0; idx < chunk.length; idx++) {
          final sort = (i + idx + 1) * 10;
          final ref = _db.collection('categories').doc(chunk[idx].id);
          batch.set(
            ref,
            <String, dynamic>{
              'sort': sort,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();
        i += chunk.length;
      }

      _snack('排序已更新');
      _bufferPrimed = false; // 讓下一次以 stream 的最新結果重建
    } catch (e) {
      _snack('排序更新失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _exportCsv(List<_CatRow> list) async {
    if (list.isEmpty) return;

    final headers = <String>['categoryId', 'name', 'slug', 'sort', 'isActive', 'createdAt', 'updatedAt'];
    final sb = StringBuffer()..writeln(headers.join(','));

    for (final r in list) {
      final d = r.data;
      final row = <String>[
        r.id,
        _s(d['name']),
        _s(d['slug']),
        '${_toNum(d['sort']).toInt()}',
        _isTrue(d['isActive']).toString(),
        (_toDate(d['createdAt'])?.toIso8601String() ?? ''),
        (_toDate(d['updatedAt'])?.toIso8601String() ?? ''),
      ].map((e) => e.replaceAll(',', '，')).toList();

      sb.writeln(row.join(','));
    }

    await downloadCsv('categories_export.csv', sb.toString());
    _snack('已匯出 categories_export.csv');
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final gate = _gate(context);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        if (_roleFuture == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);

          _buffer = <_CatRow>[];
          _bufferPrimed = false;

          _q = '';
          _isActive = null;
          _searchCtrl.clear();
        }

        return FutureBuilder<RoleInfo>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (roleSnap.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('分類管理')),
                body: Center(child: Text('讀取角色失敗：${roleSnap.error}')),
              );
            }

            final info = roleSnap.data;
            final isAdmin = _s(info?.role).toLowerCase() == 'admin';
            if (!isAdmin) {
              return Scaffold(
                appBar: AppBar(title: const Text('分類管理')),
                body: const Center(child: Text('此頁僅限 Admin 使用')),
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('分類管理', style: TextStyle(fontWeight: FontWeight.w900)),
                actions: [
                  IconButton(
                    tooltip: '新增分類',
                    onPressed: _busy ? null : () => _openEditDialog(),
                    icon: const Icon(Icons.add_box_outlined),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: Stack(
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _streamCategories(),
                    builder: (context, snap) {
                      if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                      final rows = snap.data!.docs
                          .map((d) => _CatRow(id: d.id, data: d.data()))
                          .toList();

                      // prime buffer once per snapshot refresh
                      if (!_bufferPrimed) {
                        _buffer = rows;
                        _bufferPrimed = true;
                      }

                      // search filter（只在 UI 層）
                      final filtered = _buffer.where(_match).toList();

                      return Column(
                        children: [
                          _CategoryFilters(
                            searchCtrl: _searchCtrl,
                            isActive: _isActive,
                            countLabel: '${filtered.length} 筆',
                            onQueryChanged: (v) => setState(() => _q = v),
                            onClearQuery: () {
                              _searchCtrl.clear();
                              setState(() => _q = '');
                            },
                            onActiveChanged: (v) {
                              setState(() {
                                _isActive = v;
                                _bufferPrimed = false; // query 變了，讓 buffer 重新取 stream
                              });
                            },
                            onAdd: () => _openEditDialog(),
                            onExport: filtered.isEmpty ? null : () => _exportCsv(filtered),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ReorderableListView.builder(
                              padding: const EdgeInsets.only(bottom: 90),
                              buildDefaultDragHandles: false,
                              itemCount: filtered.length,
                              onReorder: (oldIndex, newIndex) {
                                // 注意：filtered 只是視圖；我們要改的是 _buffer
                                setState(() {
                                  // 找到 filtered 對應到 buffer 的索引
                                  if (newIndex > oldIndex) newIndex -= 1;

                                  final moving = filtered[oldIndex];
                                  final target = filtered[newIndex];

                                  final from = _buffer.indexWhere((e) => e.id == moving.id);
                                  final to = _buffer.indexWhere((e) => e.id == target.id);

                                  if (from == -1 || to == -1) return;

                                  final item = _buffer.removeAt(from);
                                  _buffer.insert(to, item);
                                });
                              },
                              itemBuilder: (context, i) {
                                final r = filtered[i];
                                final d = r.data;

                                final name = _s(d['name']).isEmpty ? '（未命名分類）' : _s(d['name']);
                                final slug = _s(d['slug']);
                                final sort = _toNum(d['sort']).toInt();
                                final active = _isTrue(d['isActive']);
                                final updatedAt = _toDate(d['updatedAt'] ?? d['createdAt']);

                                return ListTile(
                                  key: ValueKey(r.id),
                                  leading: ReorderableDragStartListener(
                                    index: i,
                                    child: const Icon(Icons.drag_handle),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(fontWeight: FontWeight.w900),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _Pill(
                                        label: active ? '啟用' : '停用',
                                        color: active
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.error,
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Wrap(
                                      spacing: 10,
                                      runSpacing: 4,
                                      children: [
                                        Text('ID：${r.id}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        if (slug.isNotEmpty)
                                          Text('slug：$slug', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        Text('sort：$sort', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        Text('更新：${_fmt(updatedAt)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    tooltip: '更多',
                                    onSelected: _busy
                                        ? null
                                        : (v) async {
                                            if (v == 'copy_id') {
                                              await _copy(r.id, done: '已複製 categoryId');
                                            } else if (v == 'copy_json') {
                                              await _copy(jsonEncode(d), done: '已複製 JSON');
                                            } else if (v == 'edit') {
                                              await _openEditDialog(id: r.id, data: d);
                                            } else if (v == 'active') {
                                              await _toggleActive(r.id, !active);
                                            } else if (v == 'delete') {
                                              await _deleteCategory(r.id);
                                            }
                                          },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'copy_id', child: Text('複製 categoryId')),
                                      const PopupMenuItem(value: 'copy_json', child: Text('複製 JSON')),
                                      const PopupMenuItem(value: 'edit', child: Text('編輯')),
                                      PopupMenuItem(value: 'active', child: Text(active ? '停用' : '啟用')),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(value: 'delete', child: Text('刪除')),
                                    ],
                                  ),
                                  onTap: () => _openEditDialog(id: r.id, data: d),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // 底部固定：排序提交
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomCommitBar(
                      busy: _busy,
                      busyLabel: _busyLabel,
                      onCommit: () async {
                        // 提交的是整個 buffer（而不是 filtered）
                        await _commitSortOrder(_buffer);
                      },
                      onReset: () {
                        setState(() => _bufferPrimed = false);
                        _snack('已重整（依 Firestore sort 重新載入）');
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------
// Models
// ------------------------------------------------------------
class _CatRow {
  final String id;
  final Map<String, dynamic> data;
  _CatRow({required this.id, required this.data});
}

// ------------------------------------------------------------
// UI Widgets
// ------------------------------------------------------------
class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({
    required this.searchCtrl,
    required this.isActive,
    required this.countLabel,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onActiveChanged,
    required this.onAdd,
    required this.onExport,
  });

  final TextEditingController searchCtrl;
  final bool? isActive;
  final String countLabel;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<bool?> onActiveChanged;

  final VoidCallback onAdd;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final search = TextField(
      controller: searchCtrl,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        hintText: '搜尋：categoryId / name / slug',
        suffixIcon: searchCtrl.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: '清除',
                onPressed: onClearQuery,
                icon: const Icon(Icons.clear),
              ),
      ),
      onChanged: onQueryChanged,
    );

    final dd = DropdownButtonFormField<bool?>(
      value: isActive,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        labelText: '狀態',
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('全部')),
        DropdownMenuItem(value: true, child: Text('啟用')),
        DropdownMenuItem(value: false, child: Text('停用')),
      ],
      onChanged: onActiveChanged,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 980;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: dd),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('新增'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('匯出 CSV'),
                    ),
                    const SizedBox(width: 10),
                    Text('共 $countLabel', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              SizedBox(width: 220, child: dd),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined),
                label: const Text('匯出 CSV'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('新增分類'),
              ),
              const SizedBox(width: 10),
              Text('共 $countLabel', style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _BottomCommitBar extends StatelessWidget {
  const _BottomCommitBar({
    required this.busy,
    required this.busyLabel,
    required this.onCommit,
    required this.onReset,
  });

  final bool busy;
  final String busyLabel;

  final Future<void> Function() onCommit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      elevation: 10,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (busy) ...[
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  busyLabel.isEmpty ? '處理中...' : busyLabel,
                  style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
                ),
              ),
            ] else ...[
              Expanded(
                child: Text(
                  '拖曳可排序；按「提交排序」會批次更新 sort。',
                  style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : onReset,
              icon: const Icon(Icons.refresh),
              label: const Text('重整'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: busy ? null : () async => onCommit(),
              icon: const Icon(Icons.save_outlined),
              label: const Text('提交排序'),
            ),
          ],
        ),
      ),
    );
  }
}

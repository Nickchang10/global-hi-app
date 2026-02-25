// lib/pages/admin/categories/admin_categories_page.dart
//
// ✅ AdminCategoriesPage（專業完整版｜可編譯）
// ------------------------------------------------------------
// - Firestore categories 集合管理
// - 搜尋（名稱）
// - 上下架（active）
// - 拖曳排序（sortOrder）
//   ✅ 只有在「未搜尋」時允許拖曳，避免排序混亂
// - 新增 / 編輯 Dialog（名稱、描述、圖示、上架）
// - 批次刪除
//
// 建議資料結構：categories/{id}
// {
//   name: "手錶",
//   description: "...",
//   icon: "watch",              // 可選：字串代碼
//   active: true,
//   sortOrder: 0,
//   createdAt: Timestamp,
//   updatedAt: Timestamp
// }
//
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  final _db = FirebaseFirestore.instance;
  final _search = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selected = {};

  Query<Map<String, dynamic>> _baseQuery() {
    return _db.collection('categories').orderBy('sortOrder', descending: false);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _isFiltering => _search.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '分類管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: '刪除選取分類',
              icon: const Icon(Icons.delete_outline),
              onPressed: _selected.isEmpty ? null : _confirmBatchDelete,
            ),
          ],
          IconButton(
            tooltip: _selectionMode ? '取消多選' : '多選模式',
            icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
            onPressed: () {
              setState(() {
                _selectionMode = !_selectionMode;
                if (!_selectionMode) _selected.clear();
              });
            },
          ),
          IconButton(
            tooltip: '新增分類',
            icon: const Icon(Icons.add),
            onPressed: _openCreate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('新增分類'),
      ),
      body: Column(
        children: [
          _filterBar(cs),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    title: '載入失敗',
                    message: snap.error.toString(),
                    hint:
                        '請確認 Firestore rules、categories 集合、以及 sortOrder 欄位存在或可排序。',
                    onRetry: () => setState(() {}),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _emptyState(
                    title: '目前沒有分類',
                    subtitle: '點右下角「新增分類」開始建立分類。',
                  );
                }

                final q = _search.text.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? docs
                    : docs.where((d) {
                        final data = d.data();
                        final name = (data['name'] ?? '')
                            .toString()
                            .toLowerCase();
                        return name.contains(q) ||
                            d.id.toLowerCase().contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return _emptyState(
                    title: '沒有符合條件的分類',
                    subtitle: '請調整搜尋條件後再試一次。',
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(
                        children: [
                          Text(
                            '共 ${filtered.length} 筆',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (_isFiltering)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                // ✅ withOpacity deprecated → withValues(alpha: ...)
                                color: cs.secondaryContainer.withValues(
                                  alpha: 0.55,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '搜尋中：拖曳排序停用',
                                style: TextStyle(
                                  color: cs.onSecondaryContainer,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _isFiltering
                                ? () => setState(() => _search.clear())
                                : null,
                            icon: const Icon(Icons.clear),
                            label: const Text('清除搜尋'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _isFiltering
                          ? _buildNormalList(filtered)
                          : _buildReorderableList(filtered),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Filter Bar
  // ============================================================
  Widget _filterBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: '搜尋分類（名稱 / id）',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ============================================================
  // Lists
  // ============================================================
  Widget _buildReorderableList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      buildDefaultDragHandles: false,
      itemCount: docs.length,
      onReorder: (oldIndex, newIndex) => _onReorder(docs, oldIndex, newIndex),
      itemBuilder: (context, i) {
        final doc = docs[i];
        return _tile(
          doc,
          index: i,
          key: ValueKey(doc.id),
          allowReorder: !_selectionMode,
        );
      },
    );
  }

  Widget _buildNormalList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        return _tile(doc, index: i, key: ValueKey(doc.id), allowReorder: false);
      },
    );
  }

  Widget _tile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required int index,
    required Key key,
    required bool allowReorder,
  }) {
    final cs = Theme.of(context).colorScheme;
    final d = doc.data();

    final name = (d['name'] ?? '').toString().trim();
    final desc = (d['description'] ?? '').toString().trim();
    final icon = (d['icon'] ?? '').toString().trim();
    final active = (d['active'] is bool) ? (d['active'] as bool) : true;

    final selected = _selected.contains(doc.id);

    return ListTile(
      key: key,
      // ✅ withOpacity deprecated → withValues(alpha: ...)
      tileColor: selected ? cs.primaryContainer.withValues(alpha: 0.35) : null,
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Text(
          (name.isEmpty ? '?' : name.characters.first).toUpperCase(),
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      title: Text(
        name.isEmpty ? '(未命名分類)' : name,
        style: const TextStyle(fontWeight: FontWeight.w900),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (desc.isNotEmpty) desc,
          if (icon.isNotEmpty) 'icon: $icon',
          'id: ${doc.id}',
        ].join('  •  '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _selectionMode
          ? Checkbox(
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
          : SizedBox(
              width: 170,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Switch(value: active, onChanged: (v) => _setActive(doc, v)),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: '編輯',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openEdit(doc),
                  ),
                  if (allowReorder)
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    )
                  else
                    const Icon(Icons.drag_handle, color: Colors.black26),
                ],
              ),
            ),
      onLongPress: () {
        setState(() {
          _selectionMode = true;
          _selected.add(doc.id);
        });
      },
      onTap: () {
        if (_selectionMode) {
          setState(() {
            if (selected) {
              _selected.remove(doc.id);
            } else {
              _selected.add(doc.id);
            }
          });
          return;
        }
        _openEdit(doc);
      },
    );
  }

  // ============================================================
  // Actions
  // ============================================================
  Future<void> _openCreate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryEditDialog(title: '新增分類', initial: const {}),
    );
    if (ok != true) return;

    final payload = (_CategoryEditDialog.result ?? <String, dynamic>{});
    final name = (payload['name'] ?? '').toString().trim();
    if (name.isEmpty) return;

    final snap = await _db
        .collection('categories')
        .orderBy('sortOrder', descending: true)
        .limit(1)
        .get();
    final maxOrder = snap.docs.isEmpty
        ? -1
        : ((snap.docs.first.data()['sortOrder'] ?? -1) as num).toInt();
    final nextOrder = maxOrder + 1;

    await _db.collection('categories').add({
      'name': name,
      'description': (payload['description'] ?? '').toString(),
      'icon': (payload['icon'] ?? '').toString(),
      'active': payload['active'] == true,
      'sortOrder': nextOrder,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('分類已新增')));
  }

  Future<void> _openEdit(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final initial = doc.data();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryEditDialog(title: '編輯分類', initial: initial),
    );
    if (ok != true) return;

    final payload = (_CategoryEditDialog.result ?? <String, dynamic>{});
    final name = (payload['name'] ?? '').toString().trim();
    if (name.isEmpty) return;

    await doc.reference.update({
      'name': name,
      'description': (payload['description'] ?? '').toString(),
      'icon': (payload['icon'] ?? '').toString(),
      'active': payload['active'] == true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('分類已更新')));
  }

  Future<void> _setActive(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool active,
  ) async {
    try {
      await doc.reference.update({
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(active ? '已上架分類' : '已下架分類')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _confirmBatchDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '確認刪除選取分類？',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
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
      batch.delete(_db.collection('categories').doc(id));
    }
    await batch.commit();

    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已刪除選取分類')));
  }

  // ============================================================
  // Reorder (write sortOrder back)
  // ============================================================
  Future<void> _onReorder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int oldIndex,
    int newIndex,
  ) async {
    if (_isFiltering) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('搜尋中不允許排序，請先清除搜尋後再拖曳。')));
      return;
    }

    if (newIndex > oldIndex) newIndex--;

    final moved = docs.removeAt(oldIndex);
    docs.insert(newIndex, moved);

    final batch = _db.batch();
    for (int i = 0; i < docs.length; i++) {
      batch.update(docs[i].reference, {
        'sortOrder': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('分類排序已更新')));
  }

  // ============================================================
  // UI helpers
  // ============================================================
  Widget _emptyState({required String title, required String subtitle}) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category_outlined, size: 44, color: cs.primary),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Category Edit Dialog
// ============================================================================
class _CategoryEditDialog extends StatefulWidget {
  final String title;
  final Map<String, dynamic> initial;

  static Map<String, dynamic>? result;

  const _CategoryEditDialog({required this.title, required this.initial});

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _icon;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _CategoryEditDialog.result = null;

    _name = TextEditingController(
      text: (widget.initial['name'] ?? '').toString(),
    );
    _desc = TextEditingController(
      text: (widget.initial['description'] ?? '').toString(),
    );
    _icon = TextEditingController(
      text: (widget.initial['icon'] ?? '').toString(),
    );

    final a = widget.initial['active'];
    _active = a is bool ? a : true;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _icon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '分類名稱 *',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '描述（可選）',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _icon,
                decoration: const InputDecoration(
                  labelText: 'Icon 代碼（可選）',
                  prefixIcon: Icon(Icons.emoji_emotions_outlined),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: const Text(
                  '上架（active）',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('關閉代表分類下架（App 可不顯示）'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.primary),
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;

            _CategoryEditDialog.result = {
              'name': name,
              'description': _desc.text.trim(),
              'icon': _icon.text.trim(),
              'active': _active,
            };
            Navigator.pop(context, true);
          },
          child: const Text('儲存'),
        ),
      ],
    );
  }
}

// ============================================================================
// Error View
// ============================================================================
class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

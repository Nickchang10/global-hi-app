import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// AdminSidebarBlocksPage（正式版｜完整版｜可直接編譯）
///
/// ✅ 修正：移除未使用的 dart:typed_data import
///
/// Firestore 建議：
/// - admin_ui/sidebar_blocks/blocks/{blockId}
///   - title: String
///   - icon: String            // icon name（例如 "dashboard"）
///   - route: String           // 導頁路徑（例如 "/admin/orders"）
///   - group: String           // 分組（例如 "商城" / "系統"）
///   - enabled: bool
///   - sort: int
///   - roles: `List<String>`   // 可見角色（空=全部），例如 ["admin","super_admin"]
///   - createdAt, updatedAt: Timestamp
class AdminSidebarBlocksPage extends StatefulWidget {
  const AdminSidebarBlocksPage({super.key});

  @override
  State<AdminSidebarBlocksPage> createState() => _AdminSidebarBlocksPageState();
}

class _AdminSidebarBlocksPageState extends State<AdminSidebarBlocksPage> {
  final _searchCtrl = TextEditingController();
  bool _busy = false;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('admin_ui')
      .doc('sidebar_blocks')
      .collection('blocks');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Query<Map<String, dynamic>> _query() =>
      _col.orderBy('sort').orderBy('createdAt', descending: true).limit(500);

  Future<void> _toggleEnabled(String id, bool enabled) async {
    try {
      await _col.doc(id).set({
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('更新失敗：$e', error: true);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除側欄區塊'),
        content: Text('確定要刪除 block=$id 嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _col.doc(id).delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor({String? id, Map<String, dynamic>? initial}) async {
    final res = await showModalBottomSheet<_BlockEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SidebarBlockEditorSheet(blockId: id, initial: initial),
    );
    if (res == null) return;

    setState(() => _busy = true);
    try {
      final payload = {
        ...res.payload,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (id == null) {
        // 新增：給一個 sort（放到最後）
        final snap = await _col
            .orderBy('sort', descending: true)
            .limit(1)
            .get();
        final lastSort = snap.docs.isEmpty
            ? 0
            : _toInt(snap.docs.first.data()['sort'], fallback: 0);
        payload['sort'] = lastSort + 10;

        await _col.add({...payload, 'createdAt': FieldValue.serverTimestamp()});
        _snack('已新增');
      } else {
        await _col.doc(id).set(payload, SetOptions(merge: true));
        _snack('已更新');
      }
    } catch (e) {
      _snack('保存失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = [...docs];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);

    // 重新編 sort（10,20,30...）
    setState(() => _busy = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (int i = 0; i < list.length; i++) {
        batch.set(list[i].reference, {
          'sort': i * 10,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      _snack('已更新排序');
    } catch (e) {
      _snack('排序更新失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _match(Map<String, dynamic> m, String id, String keyword) {
    if (keyword.isEmpty) return true;
    final k = keyword.toLowerCase();
    final title = (m['title'] ?? '').toString().toLowerCase();
    final route = (m['route'] ?? '').toString().toLowerCase();
    final group = (m['group'] ?? '').toString().toLowerCase();
    final icon = (m['icon'] ?? '').toString().toLowerCase();
    return id.toLowerCase().contains(k) ||
        title.contains(k) ||
        route.contains(k) ||
        group.contains(k) ||
        icon.contains(k);
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('側欄區塊管理'),
        actions: [
          IconButton(
            tooltip: '新增區塊',
            onPressed: _busy ? null : () => _openEditor(),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋：title / group / route / icon / id',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  tooltip: '清除',
                  onPressed: () {
                    _searchCtrl.clear();
                    FocusScope.of(context).unfocus();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      '讀取失敗：${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs
                    .where((d) => _match(d.data(), d.id, keyword))
                    .toList(growable: false);

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      '尚無側欄區塊',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  );
                }

                // 用 ReorderableListView（搜尋時也允許拖曳，但排序以目前顯示清單為準）
                return ReorderableListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  onReorder: _busy
                      ? (_, __) {}
                      : (a, b) => _reorder(docs, a, b),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final m = d.data();

                    final title = (m['title'] ?? '').toString().trim();
                    final group = (m['group'] ?? '').toString().trim();
                    final route = (m['route'] ?? '').toString().trim();
                    final iconName = (m['icon'] ?? 'menu').toString().trim();
                    final enabled = m['enabled'] != false;

                    final roles = (m['roles'] is List)
                        ? List<String>.from(m['roles'])
                        : <String>[];
                    final sort = _toInt(m['sort'], fallback: 0);

                    return Card(
                      key: ValueKey(d.id),
                      elevation: 0.7,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: CircleAvatar(
                            child: Icon(_iconFromName(iconName)),
                          ),
                        ),
                        title: Text(
                          title.isEmpty ? '(未命名區塊)' : title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.folder, size: 16),
                                  label: Text(group.isEmpty ? '未分組' : group),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.route, size: 16),
                                  label: Text(
                                    route.isEmpty ? '(未設定 route)' : route,
                                  ),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.sort, size: 16),
                                  label: Text('sort $sort'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.badge, size: 16),
                                  label: Text(
                                    roles.isEmpty
                                        ? 'roles: ALL'
                                        : 'roles: ${roles.join(",")}',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Switch(
                                value: enabled,
                                onChanged: _busy
                                    ? null
                                    : (v) => _toggleEnabled(d.id, v),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                children: [
                                  IconButton(
                                    tooltip: '編輯',
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                              _openEditor(id: d.id, initial: m),
                                    icon: const Icon(Icons.edit),
                                  ),
                                  IconButton(
                                    tooltip: '刪除',
                                    onPressed: _busy
                                        ? null
                                        : () => _delete(d.id),
                                    icon: const Icon(Icons.delete),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        onTap: _busy
                            ? null
                            : () => _openEditor(id: d.id, initial: m),
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
}

// --------------------
// Editor
// --------------------

class _BlockEditResult {
  const _BlockEditResult(this.payload);
  final Map<String, dynamic> payload;
}

class _SidebarBlockEditorSheet extends StatefulWidget {
  const _SidebarBlockEditorSheet({
    required this.blockId,
    required this.initial,
  });

  final String? blockId;
  final Map<String, dynamic>? initial;

  @override
  State<_SidebarBlockEditorSheet> createState() =>
      _SidebarBlockEditorSheetState();
}

class _SidebarBlockEditorSheetState extends State<_SidebarBlockEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _group;
  late final TextEditingController _route;
  late final TextEditingController _icon;
  late final TextEditingController _roles; // comma separated

  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? <String, dynamic>{};

    _title = TextEditingController(text: (m['title'] ?? '').toString());
    _group = TextEditingController(text: (m['group'] ?? '').toString());
    _route = TextEditingController(text: (m['route'] ?? '').toString());
    _icon = TextEditingController(text: (m['icon'] ?? 'menu').toString());

    final roles = (m['roles'] is List)
        ? List<String>.from(m['roles'])
        : <String>[];
    _roles = TextEditingController(text: roles.join(','));

    _enabled = m['enabled'] != false;
  }

  @override
  void dispose() {
    _title.dispose();
    _group.dispose();
    _route.dispose();
    _icon.dispose();
    _roles.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final roles = _roles.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'group': _group.text.trim(),
      'route': _route.text.trim(),
      'icon': _icon.text.trim().isEmpty ? 'menu' : _icon.text.trim(),
      'enabled': _enabled,
      'roles': roles,
    };

    Navigator.pop(context, _BlockEditResult(payload));
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.blockId == null;
    final pad = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: pad.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCreate ? '新增側欄區塊' : '編輯側欄區塊',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!isCreate) ...[
                  const SizedBox(height: 6),
                  Text(
                    'ID: ${widget.blockId}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(height: 14),

                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: '標題（必填）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? '必填' : null,
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _group,
                        decoration: const InputDecoration(
                          labelText: '分組 group',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _icon,
                        decoration: const InputDecoration(
                          labelText: 'icon（例如 dashboard / orders）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _route,
                  decoration: const InputDecoration(
                    labelText: 'route（例如 /admin/orders）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _roles,
                  decoration: const InputDecoration(
                    labelText: '可見角色 roles（逗號分隔；留空=全部）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('啟用 enabled'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------
// Utils
// --------------------

int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

IconData _iconFromName(String name) {
  switch (name.trim().toLowerCase()) {
    case 'dashboard':
      return Icons.dashboard;
    case 'shop':
    case 'store':
      return Icons.storefront;
    case 'products':
    case 'inventory':
      return Icons.inventory_2;
    case 'orders':
    case 'receipt':
      return Icons.receipt_long;
    case 'members':
    case 'users':
      return Icons.group;
    case 'marketing':
    case 'campaign':
      return Icons.campaign;
    case 'content':
    case 'news':
      return Icons.article;
    case 'system':
    case 'settings':
      return Icons.settings;
    case 'analytics':
      return Icons.query_stats;
    case 'roles':
    case 'admin':
      return Icons.admin_panel_settings;
    case 'shipping':
      return Icons.local_shipping;
    case 'support':
    case 'ticket':
      return Icons.support_agent;
    default:
      return Icons.menu;
  }
}

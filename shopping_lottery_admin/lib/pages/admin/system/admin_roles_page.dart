// lib/pages/admin/system/admin_roles_page.dart
//
// ✅ AdminRolesPage（最終完整版｜角色 / 權限矩陣｜可直接使用｜可編譯）
// ------------------------------------------------------------
// Firestore：roles/{id}
//
// {
//   name: "Admin",
//   description: "系統管理員",
//   permissions: {
//     shop: true,
//     members: true,
//     campaigns: false,
//     marketing: false,
//     app_center: true,
//     system: true,
//   },
//   createdAt: Timestamp,
//   updatedAt: Timestamp,
// }
//
// 功能：
// - 角色列表 + 權限矩陣（Role × Feature）
// - 搜尋角色名稱/描述
// - 新增 / 編輯 / 刪除角色
// - 權限採 bool map（permissions）
// - 容錯：permissions 欄位缺失也不會炸
//
// 依賴：cloud_firestore, flutter/material
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminRolesPage extends StatefulWidget {
  const AdminRolesPage({super.key});

  @override
  State<AdminRolesPage> createState() => _AdminRolesPageState();
}

class _AdminRolesPageState extends State<AdminRolesPage> {
  final _db = FirebaseFirestore.instance;
  final _search = TextEditingController();

  // 顯示用（中文）
  final List<String> _scopes = const [
    '商城管理',
    '會員管理',
    '活動中心',
    '行銷中心',
    'App 控制中心',
    '系統設定',
  ];

  // Firestore permissions keys
  final List<String> _keys = const [
    'shop',
    'members',
    'campaigns',
    'marketing',
    'app_center',
    'system',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '角色 / 權限矩陣',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '新增角色',
            icon: const Icon(Icons.add),
            onPressed: _openCreateDialog,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(cs),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('roles').orderBy('name').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    title: '載入失敗',
                    message: snap.error.toString(),
                    hint:
                        '若看到 permission-denied：請確認 Firestore rules 允許 isAdmin() 讀寫 roles。\n'
                        '若 roles 文件缺 name 欄位，orderBy(name) 可能導致查詢問題；請補齊 name。',
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _EmptyView(
                    onCreate: _openCreateDialog,
                  );
                }

                final keyword = _search.text.trim().toLowerCase();
                final filtered = docs.where((doc) {
                  if (keyword.isEmpty) return true;
                  final d = doc.data();
                  final name = (d['name'] ?? '').toString().toLowerCase();
                  final desc = (d['description'] ?? '').toString().toLowerCase();
                  return name.contains(keyword) || desc.contains(keyword);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('沒有符合條件的角色'));
                }

                // ✅ 矩陣表格
                return _buildMatrixTable(filtered, cs);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  Widget _buildSearchBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋（角色名稱 / 描述）',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add),
            label: const Text('新增'),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixTable(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ColorScheme cs,
  ) {
    // DataTable 需要水平捲動
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 980),
        child: Card(
          elevation: 0,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: DataTable(
              headingRowHeight: 46,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 68,
              columns: [
                const DataColumn(
                  label: Text('角色', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
                const DataColumn(
                  label: Text('描述', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
                for (final s in _scopes)
                  DataColumn(
                    label: Text(s, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                const DataColumn(
                  label: Text('操作', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
              rows: docs.map((doc) {
                final d = doc.data();
                final id = doc.id;

                final name = (d['name'] ?? id).toString();
                final desc = (d['description'] ?? '').toString();
                final permissions = _normalizePermissions(d['permissions']);

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onTap: () => _openEditDialog(id, d),
                    ),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          desc.isEmpty ? '—' : desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                      onTap: () => _openEditDialog(id, d),
                    ),
                    for (int i = 0; i < _keys.length; i++)
                      DataCell(
                        _permIcon(permissions[_keys[i]] == true),
                        onTap: () => _showPermissionsDialog(name, permissions),
                      ),
                    DataCell(
                      PopupMenuButton<String>(
                        tooltip: '操作',
                        onSelected: (v) {
                          if (v == 'view') _showPermissionsDialog(name, permissions);
                          if (v == 'edit') _openEditDialog(id, d);
                          if (v == 'delete') _deleteRole(id, name);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'view', child: Text('檢視')),
                          PopupMenuItem(value: 'edit', child: Text('編輯')),
                          PopupMenuItem(value: 'delete', child: Text('刪除')),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.more_vert),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _permIcon(bool enabled) {
    return Icon(
      enabled ? Icons.check_circle : Icons.cancel_outlined,
      color: enabled ? Colors.green : Colors.grey,
      size: 22,
    );
  }

  // ============================================================
  // Create / Edit
  // ============================================================

  Future<void> _openCreateDialog() async {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    final permissions = {for (final k in _keys) k: false};

    final ok = await _openEditorDialog(
      title: '新增角色',
      nameCtl: nameCtl,
      descCtl: descCtl,
      permissions: permissions,
    );

    if (ok != true) return;

    final name = nameCtl.text.trim();
    if (name.isEmpty) {
      _toast('角色名稱不可為空');
      return;
    }

    try {
      await _db.collection('roles').add({
        'name': name,
        'description': descCtl.text.trim(),
        'permissions': permissions,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _toast('角色已新增');
    } catch (e) {
      _toast('新增失敗：$e');
    }
  }

  Future<void> _openEditDialog(String id, Map<String, dynamic> data) async {
    final nameCtl = TextEditingController(text: (data['name'] ?? '').toString());
    final descCtl =
        TextEditingController(text: (data['description'] ?? '').toString());
    final permissions = _normalizePermissions(data['permissions']);

    final ok = await _openEditorDialog(
      title: '編輯角色',
      nameCtl: nameCtl,
      descCtl: descCtl,
      permissions: permissions,
    );

    if (ok != true) return;

    final name = nameCtl.text.trim();
    if (name.isEmpty) {
      _toast('角色名稱不可為空');
      return;
    }

    try {
      await _db.collection('roles').doc(id).update({
        'name': name,
        'description': descCtl.text.trim(),
        'permissions': permissions,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _toast('角色已更新');
    } catch (e) {
      _toast('更新失敗：$e');
    }
  }

  Future<bool?> _openEditorDialog({
    required String title,
    required TextEditingController nameCtl,
    required TextEditingController descCtl,
    required Map<String, bool> permissions,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(
                      labelText: '角色名稱',
                      hintText: '例如：Admin / Vendor / CustomerService',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtl,
                    decoration: const InputDecoration(
                      labelText: '描述',
                      hintText: '例如：可管理全站 / 只管理商品 / 只看報表',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '權限設定',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (int i = 0; i < _scopes.length; i++)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_scopes[i]),
                      value: permissions[_keys[i]] == true,
                      onChanged: (v) => setDialogState(
                        () => permissions[_keys[i]] = v ?? false,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // View / Delete
  // ============================================================

  void _showPermissionsDialog(String name, Map<String, bool> permissions) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('角色權限：$name', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < _scopes.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    permissions[_keys[i]] == true
                        ? Icons.check_circle
                        : Icons.cancel_outlined,
                    color: permissions[_keys[i]] == true ? Colors.green : Colors.grey,
                  ),
                  title: Text(_scopes[i]),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRole(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除角色', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('確定要刪除「$name」嗎？刪除後無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _db.collection('roles').doc(id).delete();
      _toast('角色已刪除');
    } catch (e) {
      _toast('刪除失敗：$e');
    }
  }

  // ============================================================
  // Helpers
  // ============================================================

  Map<String, bool> _normalizePermissions(dynamic raw) {
    final map = <String, bool>{for (final k in _keys) k: false};
    if (raw is Map) {
      for (final k in _keys) {
        map[k] = raw[k] == true;
      }
    }
    return map;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ============================================================
// Empty / Error Views
// ============================================================

class _EmptyView extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyView({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security_outlined, size: 44),
                  const SizedBox(height: 10),
                  const Text(
                    '尚無角色資料',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text('請先新增至少一個角色，並設定權限。'),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('新增角色'),
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

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;

  const _ErrorView({
    required this.title,
    required this.message,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ✅ AdminRolesPermissionsPage（角色權限管理｜可編譯完整版）
/// ------------------------------------------------------------
/// Firestore（預設）:
/// system/roles_permissions {
///   roles: {
///     admin: { permKey: true/false, ... },
///     vendor:{ ... },
///     user:  { ... }
///   },
///   updatedAt: Timestamp
/// }
class AdminRolesPermissionsPage extends StatefulWidget {
  const AdminRolesPermissionsPage({super.key});

  @override
  State<AdminRolesPermissionsPage> createState() =>
      _AdminRolesPermissionsPageState();
}

class _AdminRolesPermissionsPageState extends State<AdminRolesPermissionsPage> {
  final _db = FirebaseFirestore.instance;

  // ✅ 如果你原本路徑不同，只要改這行
  DocumentReference<Map<String, dynamic>> get _docRef =>
      _db.collection('system').doc('roles_permissions');

  final _search = TextEditingController();

  bool _loading = true;
  String? _error;

  String _role = 'admin'; // admin/vendor/user
  Map<String, Map<String, bool>> _roles = {
    'admin': <String, bool>{},
    'vendor': <String, bool>{},
    'user': <String, bool>{},
  };

  // 你可以依專案調整這份「權限清單」
  final Map<String, List<String>> _permissionGroups = const {
    'Orders / Fulfillment': [
      'orders.read',
      'orders.update',
      'orders.refund',
      'shipping.update',
      'shipping.view',
    ],
    'Products / Inventory': [
      'products.read',
      'products.create',
      'products.update',
      'products.delete',
      'inventory.adjust',
    ],
    'Members / Points': ['members.read', 'members.update', 'points.manage'],
    'Marketing / Coupons': [
      'coupons.read',
      'coupons.create',
      'coupons.update',
      'coupons.delete',
      'campaigns.read',
      'campaigns.manage',
    ],
    'System / Admin': [
      'system.roleAssign',
      'system.permissionsManage',
      'system.announcements',
      'system.reports',
    ],
    'SOS': ['sos.read', 'sos.update', 'sos.export'],
  };

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

  // -----------------------------
  // Safe converters (核心：避免 not_map_spread)
  // -----------------------------
  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  Map<String, bool> _asBoolMap(dynamic v) {
    final m = _asMap(v);
    return m.map((k, val) => MapEntry(k, val == true));
  }

  // -----------------------------
  // Load
  // -----------------------------
  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final doc = await _docRef.get();
      final data = doc.data() ?? <String, dynamic>{};

      final rolesRaw = _asMap(data['roles']);

      final admin = _asBoolMap(rolesRaw['admin']);
      final vendor = _asBoolMap(rolesRaw['vendor']);
      final user = _asBoolMap(rolesRaw['user']);

      // 確保所有 permission 都有預設值（避免 UI 找不到）
      final allPerms = _allPermissions();
      for (final p in allPerms) {
        admin.putIfAbsent(p, () => false);
        vendor.putIfAbsent(p, () => false);
        user.putIfAbsent(p, () => false);
      }

      if (!mounted) return;
      setState(() {
        _roles = {'admin': admin, 'vendor': vendor, 'user': user};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<String> _allPermissions() {
    final set = <String>{};
    for (final g in _permissionGroups.values) {
      set.addAll(g);
    }
    return set.toList()..sort();
  }

  // -----------------------------
  // Save (重點：不使用錯誤的 spread)
  // -----------------------------
  Future<void> _save() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '確認儲存',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text('即將更新角色權限設定。\n\n目前編輯角色：$_role'),
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

    if (ok != true) return;

    setState(() => _loading = true);

    try {
      // ✅ 把 Map<String,bool> 轉成 Map<String,dynamic>，完全避免型別問題
      Map<String, dynamic> toDyn(Map<String, bool> m) =>
          m.map((k, v) => MapEntry(k, v));

      final payload = <String, dynamic>{
        'roles': <String, dynamic>{
          'admin': toDyn(_roles['admin'] ?? <String, bool>{}),
          'vendor': toDyn(_roles['vendor'] ?? <String, bool>{}),
          'user': toDyn(_roles['user'] ?? <String, bool>{}),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _docRef.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存權限設定')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    // ✅ 修正：if 必須加大括號（curly_braces_in_flow_control_structures）
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '角色權限管理',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Center(child: Text('載入失敗：$_error')),
      );
    }

    final roleMap = _roles[_role] ?? <String, bool>{};
    final kw = _search.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '角色權限管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新載入',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '儲存',
            onPressed: _save,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '選擇角色與搜尋',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: _role,
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('admin'),
                          ),
                          DropdownMenuItem(
                            value: 'vendor',
                            child: Text('vendor'),
                          ),
                          DropdownMenuItem(value: 'user', child: Text('user')),
                        ],
                        onChanged: (v) => setState(() => _role = v ?? 'admin'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText:
                                '搜尋 permission key（例如 orders., products., sos.）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () {
                          final all = Map<String, bool>.from(roleMap);
                          for (final k in all.keys) {
                            all[k] = true;
                          }
                          setState(() => _roles[_role] = all);
                        },
                        icon: const Icon(Icons.done_all),
                        label: const Text('全開'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          final all = Map<String, bool>.from(roleMap);
                          for (final k in all.keys) {
                            all[k] = false;
                          }
                          setState(() => _roles[_role] = all);
                        },
                        icon: const Icon(Icons.clear_all),
                        label: const Text('全關'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          ..._permissionGroups.entries.map((entry) {
            final group = entry.key;
            final perms = entry.value
                .where((p) => kw.isEmpty || p.toLowerCase().contains(kw))
                .toList();

            // ✅ 修正：這個 if 也要加大括號（在 map 內同樣會觸發 lint）
            if (perms.isEmpty) {
              return const SizedBox.shrink();
            }

            final enabledCount = perms.where((p) => roleMap[p] == true).length;

            return Card(
              child: ExpansionTile(
                title: Text(
                  '$group  ($enabledCount/${perms.length})',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: () {
                                final m = Map<String, bool>.from(roleMap);
                                for (final p in perms) {
                                  m[p] = true;
                                }
                                setState(() => _roles[_role] = m);
                              },
                              child: const Text('此群組全開'),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.tonal(
                              onPressed: () {
                                final m = Map<String, bool>.from(roleMap);
                                for (final p in perms) {
                                  m[p] = false;
                                }
                                setState(() => _roles[_role] = m);
                              },
                              child: const Text('此群組全關'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...perms.map((p) {
                          final v = roleMap[p] == true;
                          return SwitchListTile(
                            value: v,
                            title: Text(
                              p,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            onChanged: (nv) {
                              final m = Map<String, bool>.from(roleMap);
                              m[p] = nv;
                              setState(() => _roles[_role] = m);
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

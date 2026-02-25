// lib/pages/admin/system/admin_role_assign_page.dart
//
// ✅ AdminRoleAssignPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：subtype_of_sealed_class
// - 不再 extends / implements QueryDocumentSnapshot（cloud_firestore 版本中它是 sealed）
// - 改用 composition：把 doc 轉成一般資料結構（uid + data）
//
// ✅ 修正：use_build_context_synchronously
// - async gap 後不再使用 itemBuilder 的 BuildContext
// - 先抓 messenger（使用 State.context）再 await，await 後只用 messenger
// - TopBar 不再用 (context as Element).markNeedsBuild()，改由父層 setState 驅動
//
// ✅ 修正：deprecated_member_use
// - DropdownButtonFormField.value 已棄用 → 改用 initialValue
// - 加 ValueKey(bulkRole) 確保 bulkRole 改變時表單欄位重建，UI 同步
//
// ✅ 功能：
// - 讀取 users 清單（可搜尋）
// - 讀取 user_roles 對照（uid -> role）
// - 單筆指派角色（下拉選擇）
// - 批次指派角色（多選 + 套用）
// - 寫入：user_roles/{uid} + users/{uid}.role（雙寫，便於前台查）
//
// Firestore 結構（可自行調整 _usersRef / _rolesRef）：
// - users/{uid}: {displayName, name, email, phone, role?}
// - user_roles/{uid}: {role, updatedAt, updatedBy}
//
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminRoleAssignPage extends StatefulWidget {
  const AdminRoleAssignPage({super.key});

  @override
  State<AdminRoleAssignPage> createState() => _AdminRoleAssignPageState();
}

class _AdminRoleAssignPageState extends State<AdminRoleAssignPage> {
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      FirebaseFirestore.instance.collection('users');

  CollectionReference<Map<String, dynamic>> get _rolesRef =>
      FirebaseFirestore.instance.collection('user_roles');

  static const List<String> _roleOptions = <String>[
    'user',
    'vendor',
    'support',
    'admin',
    'super_admin',
  ];

  final _searchCtrl = TextEditingController();
  final Set<String> _selectedUids = <String>{};
  String? _bulkRole;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _displayName(Map<String, dynamic> u) {
    final dn = (u['displayName'] ?? '').toString().trim();
    if (dn.isNotEmpty) return dn;
    final name = (u['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final email = (u['email'] ?? '').toString().trim();
    if (email.isNotEmpty) return email;
    return '(未命名使用者)';
  }

  String _email(Map<String, dynamic> u) => (u['email'] ?? '').toString().trim();
  String _phone(Map<String, dynamic> u) => (u['phone'] ?? '').toString().trim();

  Future<void> _setUserRole({
    required String uid,
    required String role,
    String? updatedBy,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    batch.set(_rolesRef.doc(uid), <String, dynamic>{
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy != null) 'updatedBy': updatedBy,
    }, SetOptions(merge: true));

    batch.set(_usersRef.doc(uid), <String, dynamic>{
      'role': role,
      'roleUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> _applyBulkRole() async {
    final role = _bulkRole;
    if (role == null || role.trim().isEmpty) return;
    if (_selectedUids.isEmpty) return;

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final uids = _selectedUids.toList();
    try {
      const int maxUidsPerBatch = 200; // 200*2=400 ops
      for (int i = 0; i < uids.length; i += maxUidsPerBatch) {
        final chunk = uids.sublist(
          i,
          (i + maxUidsPerBatch).clamp(0, uids.length),
        );

        final batch = FirebaseFirestore.instance.batch();
        for (final uid in chunk) {
          batch.set(_rolesRef.doc(uid), <String, dynamic>{
            'role': role,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          batch.set(_usersRef.doc(uid), <String, dynamic>{
            'role': role,
            'roleUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await batch.commit();
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('已套用批次角色：$role（${uids.length} 位）')),
      );
      setState(() => _selectedUids.clear());
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('批次套用失敗：$e')));
    }
  }

  bool _matchSearch(String q, String uid, Map<String, dynamic> u) {
    if (q.isEmpty) return true;
    final s = q.toLowerCase();
    final name = _displayName(u).toLowerCase();
    final email = _email(u).toLowerCase();
    final phone = _phone(u).toLowerCase();
    return uid.toLowerCase().contains(s) ||
        name.contains(s) ||
        email.contains(s) ||
        phone.contains(s);
  }

  void _notifySearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('角色指派'),
        actions: [
          if (_selectedUids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Center(
                child: Text(
                  '已選：${_selectedUids.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _TopBar(
            searchCtrl: _searchCtrl,
            roleOptions: _roleOptions,
            selectedCount: _selectedUids.length,
            bulkRole: _bulkRole,
            onBulkRoleChanged: (v) => setState(() => _bulkRole = v),
            onApplyBulk: _selectedUids.isEmpty ? null : _applyBulkRole,
            onClearSelection: _selectedUids.isEmpty
                ? null
                : () => setState(() => _selectedUids.clear()),
            onSearchChanged: _notifySearchChanged,
            onClearSearch: () {
              _searchCtrl.clear();
              FocusScope.of(context).unfocus();
              _notifySearchChanged();
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _usersRef.limit(500).snapshots(),
              builder: (context, usersSnap) {
                if (usersSnap.hasError) {
                  return _ErrorView(message: '讀取 users 失敗：${usersSnap.error}');
                }
                if (!usersSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _rolesRef.snapshots(),
                  builder: (context, rolesSnap) {
                    if (rolesSnap.hasError) {
                      return _ErrorView(
                        message: '讀取 user_roles 失敗：${rolesSnap.error}',
                      );
                    }
                    if (!rolesSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final roleByUid = <String, String>{};
                    for (final d in rolesSnap.data!.docs) {
                      final m = d.data();
                      final role = (m['role'] ?? '').toString().trim();
                      if (role.isNotEmpty) roleByUid[d.id] = role;
                    }

                    final q = _searchCtrl.text.trim();
                    final docs = usersSnap.data!.docs;

                    final rows = <_UserRow>[];
                    for (final doc in docs) {
                      final uid = doc.id;
                      final data = doc.data();
                      if (_matchSearch(q, uid, data)) {
                        rows.add(_UserRow(uid: uid, data: data));
                      }
                    }

                    rows.sort(
                      (a, b) =>
                          _displayName(a.data).compareTo(_displayName(b.data)),
                    );

                    if (rows.isEmpty) {
                      return Center(
                        child: Text(
                          '查無使用者',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      );
                    }

                    final messenger = ScaffoldMessenger.of(this.context);

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        final uid = r.uid;
                        final u = r.data;

                        final currentRole =
                            (roleByUid[uid] ?? (u['role'] ?? '').toString())
                                .trim();
                        final role = currentRole.isEmpty ? 'user' : currentRole;

                        final selected = _selectedUids.contains(uid);

                        return Card(
                          elevation: 0.6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: selected,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedUids.add(uid);
                                      } else {
                                        _selectedUids.remove(uid);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _displayName(u),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 4,
                                        children: [
                                          _MetaChip(
                                            icon: Icons.alternate_email,
                                            text: _email(u).isEmpty
                                                ? '-'
                                                : _email(u),
                                          ),
                                          _MetaChip(
                                            icon: Icons.phone,
                                            text: _phone(u).isEmpty
                                                ? '-'
                                                : _phone(u),
                                          ),
                                          _MetaChip(icon: Icons.key, text: uid),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Text(
                                            '角色：',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          DropdownButton<String>(
                                            value: _roleOptions.contains(role)
                                                ? role
                                                : 'user',
                                            items: _roleOptions
                                                .map(
                                                  (e) => DropdownMenuItem(
                                                    value: e,
                                                    child: Text(e),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) async {
                                              final next = (v ?? '').trim();
                                              if (next.isEmpty) return;
                                              if (!mounted) return;

                                              try {
                                                await _setUserRole(
                                                  uid: uid,
                                                  role: next,
                                                );
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      '已更新 $uid → $next',
                                                    ),
                                                  ),
                                                );
                                              } catch (e) {
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text('更新失敗：$e'),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          const Spacer(),
                                          Text(
                                            role,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: role == 'super_admin'
                                                  ? Colors.deepPurple
                                                  : role == 'admin'
                                                  ? Colors.indigo
                                                  : Colors.grey[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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

class _UserRow {
  const _UserRow({required this.uid, required this.data});
  final String uid;
  final Map<String, dynamic> data;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchCtrl,
    required this.roleOptions,
    required this.selectedCount,
    required this.bulkRole,
    required this.onBulkRoleChanged,
    required this.onApplyBulk,
    required this.onClearSelection,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final TextEditingController searchCtrl;
  final List<String> roleOptions;
  final int selectedCount;
  final String? bulkRole;
  final ValueChanged<String?> onBulkRoleChanged;
  final VoidCallback? onApplyBulk;
  final VoidCallback? onClearSelection;

  final VoidCallback onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final initial = (bulkRole != null && roleOptions.contains(bulkRole))
        ? bulkRole
        : null;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋 uid / email / 姓名 / 電話',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                tooltip: '清除',
                onPressed: onClearSearch,
                icon: const Icon(Icons.clear),
              ),
            ),
            onChanged: (_) => onSearchChanged(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  // ✅ value 已棄用 → 改 initialValue
                  // ✅ key 讓 bulkRole 改變時重建，避免 FormField 保留舊狀態
                  key: ValueKey<String>('bulkRole_${initial ?? 'null'}'),
                  initialValue: initial,
                  decoration: InputDecoration(
                    labelText: '批次角色（選取後可套用）',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: roleOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: onBulkRoleChanged,
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onApplyBulk,
                icon: const Icon(Icons.done_all),
                label: const Text('套用'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onClearSelection,
                icon: const Icon(Icons.clear_all),
                label: Text('清除($selectedCount)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(text, overflow: TextOverflow.ellipsis),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

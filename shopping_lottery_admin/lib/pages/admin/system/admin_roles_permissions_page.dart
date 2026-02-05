// lib/pages/admin/system/admin_roles_permissions_page.dart
//
// ✅ AdminRolesPermissionsPage（專業版｜單檔完整版｜可編譯）
// ------------------------------------------------------------
// 功能摘要：
// - roles 集合：角色 CRUD（新增/編輯/刪除）
// - 權限矩陣：以 permissions(Map<String,bool>) 儲存，UI 勾選編輯
// - users 集合：指派角色（users.role）、設定 vendorId、停用/啟用（users.disabled）
// - 搜尋：角色搜尋 / 使用者搜尋
// - Responsive：寬螢幕左側角色列表 + 右側詳情；窄螢幕改上下布局
//
// Firestore 建議結構：
// roles/{roleId}
// {
//   name: "客服",
//   description: "可看訂單、處理退款，但不可改商品",
//   permissions: { "shop.orders.read": true, "shop.orders.write": true, ... },
//   isSystem: false,
//   createdAt: Timestamp,
//   updatedAt: Timestamp
// }
//
// users/{uid}
// {
//   displayName: "王小明",
//   email: "xx@gmail.com",
//   role: "admin" | "vendor" | "support" | "...(對應 roles docId 或內建)",
//   vendorId: "VENDOR_001", // role=vendor 時使用
//   disabled: false,
//   updatedAt: Timestamp,
//   createdAt: Timestamp
// }
//
// 依賴：cloud_firestore, flutter
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminRolesPermissionsPage extends StatefulWidget {
  const AdminRolesPermissionsPage({super.key});

  @override
  State<AdminRolesPermissionsPage> createState() => _AdminRolesPermissionsPageState();
}

class _AdminRolesPermissionsPageState extends State<AdminRolesPermissionsPage> {
  final _db = FirebaseFirestore.instance;

  // ✅ roles / users 使用 typed reference，避免 Object? 的 [] 問題
  CollectionReference<Map<String, dynamic>> get _rolesRef => _db.collection('roles');
  CollectionReference<Map<String, dynamic>> get _usersRef => _db.collection('users');

  final TextEditingController _roleSearch = TextEditingController();
  final TextEditingController _userSearch = TextEditingController();

  String? _selectedRoleId; // roles/{roleId}

  @override
  void dispose() {
    _roleSearch.dispose();
    _userSearch.dispose();
    super.dispose();
  }

  // ============================================================
  // 權限定義（你可以照你的功能再增修 key）
  // ============================================================
  static const _permissionGroups = <_PermGroup>[
    _PermGroup('商城管理', [
      _Perm('shop.orders.read', '訂單：檢視'),
      _Perm('shop.orders.write', '訂單：修改狀態/備註'),
      _Perm('shop.orders.delete', '訂單：刪除'),

      _Perm('shop.products.read', '商品：檢視'),
      _Perm('shop.products.write', '商品：新增/編輯'),
      _Perm('shop.products.delete', '商品：刪除'),

      _Perm('shop.categories.read', '分類：檢視'),
      _Perm('shop.categories.write', '分類：新增/編輯'),
      _Perm('shop.categories.delete', '分類：刪除'),

      _Perm('shop.shipping.read', '出貨/退款：檢視'),
      _Perm('shop.shipping.write', '出貨/退款：處理/更新'),
      _Perm('shop.cart.read', '購物車：檢視'),
      _Perm('shop.cart.write', '購物車：清空/刪除'),
    ]),
    _PermGroup('會員管理', [
      _Perm('member.read', '會員：檢視'),
      _Perm('member.write', '會員：修改資料/狀態'),
      _Perm('member.orders.read', '會員訂單：檢視'),
      _Perm('member.points.write', '積分/任務：加減點/派任務'),
    ]),
    _PermGroup('內容管理', [
      _Perm('content.news.read', '最新消息：檢視'),
      _Perm('content.news.write', '最新消息：新增/編輯'),
      _Perm('content.news.delete', '最新消息：刪除'),
      _Perm('content.pages.write', '頁面內容：新增/編輯'),
      _Perm('content.faq.write', 'FAQ：新增/編輯'),
    ]),
    _PermGroup('App 控制中心', [
      _Perm('app.center.read', '控制中心：檢視'),
      _Perm('app.center.write', '控制中心：修改'),
      _Perm('app.banners.read', 'Banner：檢視'),
      _Perm('app.banners.write', 'Banner：新增/編輯/排序/上下架'),
      _Perm('app.features.write', '功能開關：修改'),
      _Perm('app.devices.read', '裝置管理：檢視'),
      _Perm('app.devices.write', '裝置管理：修改'),
      _Perm('app.sos_health.write', 'SOS/健康：修改'),
    ]),
    _PermGroup('系統', [
      _Perm('system.notifications.read', '通知中心：檢視'),
      _Perm('system.notifications.write', '通知中心：發送/修改'),
      _Perm('system.reports.read', '報表分析：檢視'),
      _Perm('system.settings.write', '系統設定：修改'),
    ]),
    _PermGroup('內部管理', [
      _Perm('internal.roles.write', '角色/權限：管理'),
      _Perm('internal.approvals.write', '審核/工單：處理'),
      _Perm('internal.staff_announcements.write', '內部公告：發布/管理'),
    ]),
  ];

  // 內建角色（即使 roles collection 沒有，也可用於 users.role）
  static const _builtinRoles = <String>[
    'admin',
    'super_admin',
    'vendor',
    'support',
    'editor',
    'user',
  ];

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final isWide = c.maxWidth >= 980;

      return Scaffold(
        appBar: AppBar(
          title: const Text('角色與權限管理', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: '新增角色',
              icon: const Icon(Icons.add),
              onPressed: () => _openRoleEditor(context, roleId: null, initial: null),
            ),
            IconButton(
              tooltip: '重新整理',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {}),
            ),
          ],
        ),
        body: isWide
            ? Row(
                children: [
                  SizedBox(width: 360, child: _rolesPane()),
                  const VerticalDivider(width: 1),
                  Expanded(child: _detailPane()),
                ],
              )
            : Column(
                children: [
                  SizedBox(height: 320, child: _rolesPane()),
                  const Divider(height: 1),
                  Expanded(child: _detailPane()),
                ],
              ),
      );
    });
  }

  // ============================================================
  // 左側：角色列表
  // ============================================================
  Widget _rolesPane() {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _roleSearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋角色（名稱 / id）',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _HintCard(
            text: '提示：roles 只有 admin 可讀寫（依你的 rules）。若看到 permission-denied，請確認當前帳號 users/{uid}.role = admin。',
            icon: Icons.lock_outline,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _rolesRef.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _ErrorPanel(
                  title: 'roles 載入失敗',
                  message: snap.error.toString(),
                  onRetry: () => setState(() {}),
                );
              }

              final docs = (snap.data?.docs ?? []).toList();

              // 角色排序：先 isSystem，再 name，再 id
              docs.sort((a, b) {
                final ad = a.data();
                final bd = b.data();
                final aSys = ad['isSystem'] == true;
                final bSys = bd['isSystem'] == true;
                if (aSys != bSys) return aSys ? -1 : 1;

                final an = (ad['name'] ?? '').toString().toLowerCase();
                final bn = (bd['name'] ?? '').toString().toLowerCase();
                final byName = an.compareTo(bn);
                if (byName != 0) return byName;
                return a.id.compareTo(b.id);
              });

              final q = _roleSearch.text.trim().toLowerCase();
              final filtered = q.isEmpty
                  ? docs
                  : docs.where((d) {
                      final m = d.data();
                      final name = (m['name'] ?? '').toString().toLowerCase();
                      final id = d.id.toLowerCase();
                      return name.contains(q) || id.contains(q);
                    }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('沒有符合條件的角色'));
              }

              // ✅ 若未選角色，自動選第一個
              if (_selectedRoleId == null && filtered.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _selectedRoleId = filtered.first.id);
                });
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final doc = filtered[i];
                  final d = doc.data();
                  final name = (d['name'] ?? '(未命名角色)').toString();
                  final desc = (d['description'] ?? '').toString();
                  final isSystem = d['isSystem'] == true;
                  final perms = _asMap(d['permissions']);
                  final enabledPermCount = perms.values.where((v) => v == true).length;

                  final selected = doc.id == _selectedRoleId;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                    color: selected ? cs.primaryContainer.withOpacity(0.35) : null,
                    child: ListTile(
                      dense: true,
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(
                        [
                          'id: ${doc.id}',
                          if (desc.isNotEmpty) desc,
                          'permissions: $enabledPermCount',
                        ].join('  •  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                      ),
                      trailing: isSystem ? const _Pill(text: 'System') : const SizedBox.shrink(),
                      selected: selected,
                      onTap: () => setState(() => _selectedRoleId = doc.id),
                      onLongPress: () => _openRoleActions(doc),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openRoleActions(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    final isSystem = d['isSystem'] == true;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('編輯角色'),
                onTap: () {
                  Navigator.pop(context);
                  _openRoleEditor(context, roleId: doc.id, initial: d);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: isSystem ? Colors.grey : Colors.red),
                title: Text(isSystem ? '系統角色不可刪除' : '刪除角色'),
                enabled: !isSystem,
                onTap: isSystem
                    ? null
                    : () {
                        Navigator.pop(context);
                        _confirmDeleteRole(doc.id);
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // 右側：角色詳情 + 指派使用者
  // ============================================================
  Widget _detailPane() {
    if (_selectedRoleId == null) {
      return const Center(child: Text('請先選擇一個角色'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _rolesRef.doc(_selectedRoleId).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorPanel(
            title: '角色詳情載入失敗',
            message: snap.error.toString(),
            onRetry: () => setState(() {}),
          );
        }

        final exists = snap.data?.exists == true;
        final roleId = _selectedRoleId!;

        if (!exists) {
          return Center(
            child: _ErrorPanel(
              title: '角色不存在',
              message: 'roles/$roleId 已不存在或權限不足。',
              onRetry: () => setState(() {}),
            ),
          );
        }

        final data = snap.data?.data() ?? <String, dynamic>{};
        final name = (data['name'] ?? roleId).toString();
        final desc = (data['description'] ?? '').toString();
        final isSystem = data['isSystem'] == true;

        final perms = _asMap(data['permissions']);
        final enabledPerms = perms.entries.where((e) => e.value == true).map((e) => e.key).toSet();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            _RoleHeaderCard(
              roleId: roleId,
              name: name,
              description: desc,
              isSystem: isSystem,
              enabledPermCount: enabledPerms.length,
              onEdit: () => _openRoleEditor(context, roleId: roleId, initial: data),
              onDelete: isSystem ? null : () => _confirmDeleteRole(roleId),
            ),
            const SizedBox(height: 12),

            _SectionTitle(title: '權限矩陣', subtitle: '勾選後儲存在 roles/{roleId}.permissions（Map<String,bool>）'),
            const SizedBox(height: 8),
            _PermissionsMatrix(
              enabled: enabledPerms,
              onEdit: () => _openRoleEditor(context, roleId: roleId, initial: data),
              groups: _permissionGroups,
            ),

            const SizedBox(height: 14),
            _SectionTitle(title: '指派使用者', subtitle: '設定 users/{uid}.role / vendorId / disabled'),
            const SizedBox(height: 8),
            _AssignActionsCard(
              roleId: roleId,
              roleName: name,
              isVendorRole: _isVendorRoleId(roleId),
              onAssign: () => _openAssignUserDialog(roleId: roleId),
              onBatchAssign: () => _openBatchAssignDialog(roleId: roleId),
            ),

            const SizedBox(height: 12),
            _UsersInRoleList(
              usersRef: _usersRef,
              roleId: roleId,
              searchController: _userSearch,
              onChanged: () => setState(() {}),
              onEditUser: (uid, data) => _openUserEditor(uid: uid, initial: data),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // Role Editor Dialog
  // ============================================================
  Future<void> _openRoleEditor(
    BuildContext context, {
    required String? roleId,
    required Map<String, dynamic>? initial,
  }) async {
    final isEdit = roleId != null;
    final cs = Theme.of(context).colorScheme;

    final nameCtrl = TextEditingController(text: (initial?['name'] ?? '').toString());
    final descCtrl = TextEditingController(text: (initial?['description'] ?? '').toString());

    // 目前 permissions（Map<String,bool>）
    final currentPerms = <String, bool>{
      ..._allPermissionKeys().map((k) => MapEntry(k, false)),
      ..._asMap(initial?['permissions']).map((k, v) => MapEntry(k, v == true)),
    };

    // 系統角色：限制刪除，但仍允許編輯（你可自行改為不可編輯）
    final isSystem = initial?['isSystem'] == true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        bool saving = false;

        return StatefulBuilder(builder: (context, setSB) {
          Future<void> save() async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              _toast('請輸入角色名稱');
              return;
            }

            setSB(() => saving = true);
            try {
              final payload = <String, dynamic>{
                'name': name,
                'description': descCtrl.text.trim(),
                'permissions': currentPerms,
                'updatedAt': FieldValue.serverTimestamp(),
              };

              if (!isEdit) {
                // ✅ create：用 auto id，並寫 createdAt
                payload['createdAt'] = FieldValue.serverTimestamp();
                payload['isSystem'] = false;
                await _rolesRef.add(payload);
              } else {
                await _rolesRef.doc(roleId).set(payload, SetOptions(merge: true));
              }

              if (!mounted) return;
              Navigator.pop(context);
              _toast(isEdit ? '角色已更新' : '角色已新增');
            } catch (e) {
              _toast('儲存失敗：$e');
            } finally {
              setSB(() => saving = false);
            }
          }

          return AlertDialog(
            title: Text(isEdit ? '編輯角色' : '新增角色', style: const TextStyle(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isSystem)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HintCard(
                          text: '此角色標記為 System（isSystem=true）。建議不要刪除。若要鎖定不可改，可在 UI 或 Rules 再加限制。',
                          icon: Icons.info_outline,
                        ),
                      ),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '角色名稱',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '描述（可選）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('權限設定', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),

                    // 權限矩陣（可勾選）
                    ..._permissionGroups.map((g) {
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      FilledButton.tonal(
                                        onPressed: saving
                                            ? null
                                            : () {
                                                setSB(() {
                                                  for (final p in g.items) {
                                                    currentPerms[p.key] = true;
                                                  }
                                                });
                                              },
                                        child: const Text('全選'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.tonal(
                                        onPressed: saving
                                            ? null
                                            : () {
                                                setSB(() {
                                                  for (final p in g.items) {
                                                    currentPerms[p.key] = false;
                                                  }
                                                });
                                              },
                                        child: const Text('全不選'),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '已啟用：${g.items.where((p) => currentPerms[p.key] == true).length}/${g.items.length}',
                                        style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...g.items.map((p) {
                                    final v = currentPerms[p.key] == true;
                                    return CheckboxListTile(
                                      value: v,
                                      dense: true,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      subtitle: Text(p.key, style: TextStyle(color: cs.onSurfaceVariant)),
                                      onChanged: saving
                                          ? null
                                          : (nv) => setSB(() => currentPerms[p.key] = nv == true),
                                    );
                                  }),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? '儲存中...' : '儲存'),
              ),
            ],
          );
        });
      },
    );
  }

  Set<String> _allPermissionKeys() {
    final s = <String>{};
    for (final g in _permissionGroups) {
      for (final p in g.items) {
        s.add(p.key);
      }
    }
    return s;
  }

  // ============================================================
  // Delete Role
  // ============================================================
  Future<void> _confirmDeleteRole(String roleId) async {
    // 先檢查是否還有使用者綁定此角色（取 1 筆即可）
    int boundCount = 0;
    try {
      final q = await _usersRef.where('role', isEqualTo: roleId).limit(1).get();
      boundCount = q.docs.length;
    } catch (_) {
      // ignore
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除角色', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          boundCount > 0
              ? '此角色仍有使用者綁定（至少 1 位）。建議先將使用者改成其他角色。\n\n仍要刪除 roles/$roleId 嗎？'
              : '確定要刪除 roles/$roleId 嗎？刪除後無法復原。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
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
      await _rolesRef.doc(roleId).delete();
      if (!mounted) return;
      _toast('角色已刪除');
      setState(() {
        if (_selectedRoleId == roleId) _selectedRoleId = null;
      });
    } catch (e) {
      _toast('刪除失敗：$e');
    }
  }

  // ============================================================
  // Assign User Dialog (single assign)
  // ============================================================
  Future<void> _openAssignUserDialog({required String roleId}) async {
    final searchCtrl = TextEditingController();
    String? pickedUid;
    Map<String, dynamic>? pickedUser;

    await showDialog<void>(
      context: context,
      builder: (_) {
        bool saving = false;

        return StatefulBuilder(builder: (context, setSB) {
          Future<void> assign() async {
            if (pickedUid == null) {
              _toast('請先選擇要指派的使用者');
              return;
            }

            final isVendorRole = _isVendorRoleId(roleId);
            String vendorIdValue = '';

            if (isVendorRole) {
              vendorIdValue = await _askText(
                    title: '設定 vendorId',
                    hint: '例如：VENDOR_001',
                    initial: (pickedUser?['vendorId'] ?? '').toString(),
                  ) ??
                  '';
              vendorIdValue = vendorIdValue.trim();
              if (vendorIdValue.isEmpty) {
                _toast('vendor 角色需要 vendorId');
                return;
              }
            }

            setSB(() => saving = true);
            try {
              final patch = <String, dynamic>{
                'role': roleId,
                'updatedAt': FieldValue.serverTimestamp(),
              };
              if (isVendorRole) patch['vendorId'] = vendorIdValue;

              await _usersRef.doc(pickedUid).set(patch, SetOptions(merge: true));

              if (!mounted) return;
              Navigator.pop(context);
              _toast('已指派角色');
            } catch (e) {
              _toast('指派失敗：$e');
            } finally {
              setSB(() => saving = false);
            }
          }

          return AlertDialog(
            title: const Text('指派使用者角色', style: TextStyle(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 760,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setSB(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜尋 uid / email / displayName',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 420,
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _usersRef.limit(400).snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(child: Text('users 載入失敗：${snap.error}'));
                        }
                        final docs = (snap.data?.docs ?? []).toList();

                        final q = searchCtrl.text.trim().toLowerCase();
                        final filtered = q.isEmpty
                            ? docs
                            : docs.where((d) {
                                final m = d.data();
                                final uid = d.id.toLowerCase();
                                final email = (m['email'] ?? '').toString().toLowerCase();
                                final name = (m['displayName'] ?? '').toString().toLowerCase();
                                return uid.contains(q) || email.contains(q) || name.contains(q);
                              }).toList();

                        if (filtered.isEmpty) return const Center(child: Text('沒有符合條件的使用者'));

                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final doc = filtered[i];
                            final m = doc.data();
                            final uid = doc.id;
                            final name = (m['displayName'] ?? '未命名').toString();
                            final email = (m['email'] ?? '').toString();
                            final role = (m['role'] ?? '').toString();
                            final disabled = m['disabled'] == true;

                            final selected = pickedUid == uid;

                            return Card(
                              elevation: 0,
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(name.isNotEmpty ? name.substring(0, 1) : '?'),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                                subtitle: Text(
                                  [
                                    'uid: $uid',
                                    if (email.isNotEmpty) 'email: $email',
                                    if (role.isNotEmpty) 'role: $role',
                                    if (disabled) 'disabled',
                                  ].join('  •  '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: selected ? const Icon(Icons.check_circle) : null,
                                onTap: () => setSB(() {
                                  pickedUid = uid;
                                  pickedUser = m;
                                }),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : assign,
                icon: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.person_add_alt_1),
                label: Text(saving ? '指派中...' : '指派'),
              ),
            ],
          );
        });
      },
    );
  }

  // ============================================================
  // Batch Assign Dialog (multi select)
  // ============================================================
  Future<void> _openBatchAssignDialog({required String roleId}) async {
    final searchCtrl = TextEditingController();
    final selected = <String>{};

    await showDialog<void>(
      context: context,
      builder: (_) {
        bool saving = false;

        return StatefulBuilder(builder: (context, setSB) {
          Future<void> apply() async {
            if (selected.isEmpty) {
              _toast('請先選擇使用者');
              return;
            }

            final isVendorRole = _isVendorRoleId(roleId);
            String vendorIdValue = '';

            if (isVendorRole) {
              vendorIdValue = await _askText(
                    title: '批次設定 vendorId',
                    hint: '例如：VENDOR_001（批次指派同一個 vendorId）',
                    initial: '',
                  ) ??
                  '';
              vendorIdValue = vendorIdValue.trim();
              if (vendorIdValue.isEmpty) {
                _toast('vendor 角色需要 vendorId');
                return;
              }
            }

            setSB(() => saving = true);
            try {
              final batch = _db.batch();
              for (final uid in selected) {
                final ref = _usersRef.doc(uid);
                final patch = <String, dynamic>{
                  'role': roleId,
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                if (isVendorRole) patch['vendorId'] = vendorIdValue;
                batch.set(ref, patch, SetOptions(merge: true));
              }
              await batch.commit();

              if (!mounted) return;
              Navigator.pop(context);
              _toast('已批次指派角色（${selected.length} 位）');
            } catch (e) {
              _toast('批次指派失敗：$e');
            } finally {
              setSB(() => saving = false);
            }
          }

          return AlertDialog(
            title: const Text('批次指派角色', style: TextStyle(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 760,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setSB(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜尋 uid / email / displayName',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('已選：${selected.length}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: saving ? null : () => setSB(() => selected.clear()),
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 420,
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _usersRef.limit(500).snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(child: Text('users 載入失敗：${snap.error}'));
                        }

                        final docs = (snap.data?.docs ?? []).toList();
                        final q = searchCtrl.text.trim().toLowerCase();

                        final filtered = q.isEmpty
                            ? docs
                            : docs.where((d) {
                                final m = d.data();
                                final uid = d.id.toLowerCase();
                                final email = (m['email'] ?? '').toString().toLowerCase();
                                final name = (m['displayName'] ?? '').toString().toLowerCase();
                                return uid.contains(q) || email.contains(q) || name.contains(q);
                              }).toList();

                        if (filtered.isEmpty) return const Center(child: Text('沒有符合條件的使用者'));

                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final doc = filtered[i];
                            final m = doc.data();
                            final uid = doc.id;
                            final name = (m['displayName'] ?? '未命名').toString();
                            final email = (m['email'] ?? '').toString();
                            final role = (m['role'] ?? '').toString();
                            final disabled = m['disabled'] == true;

                            final checked = selected.contains(uid);

                            return Card(
                              elevation: 0,
                              child: CheckboxListTile(
                                value: checked,
                                onChanged: saving
                                    ? null
                                    : (v) => setSB(() {
                                          if (v == true) {
                                            selected.add(uid);
                                          } else {
                                            selected.remove(uid);
                                          }
                                        }),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                                subtitle: Text(
                                  [
                                    'uid: $uid',
                                    if (email.isNotEmpty) 'email: $email',
                                    if (role.isNotEmpty) 'role: $role',
                                    if (disabled) 'disabled',
                                  ].join('  •  '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('取消')),
              FilledButton.icon(
                onPressed: saving ? null : apply,
                icon: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.done_all),
                label: Text(saving ? '套用中...' : '套用'),
              ),
            ],
          );
        });
      },
    );
  }

  // ============================================================
  // User Editor (role/vendorId/disabled)
  // ============================================================
  Future<void> _openUserEditor({required String uid, required Map<String, dynamic> initial}) async {
    final cs = Theme.of(context).colorScheme;

    // role 下拉：roles + builtin
    final rolesSnap = await _rolesRef.get().catchError((_) => null);
    final roleIds = <String>{
      ..._builtinRoles,
      ...((rolesSnap is QuerySnapshot<Map<String, dynamic>>)
          ? rolesSnap.docs.map((d) => d.id)
          : const Iterable<String>.empty()),
    }.toList()
      ..sort();

    String roleValue = (initial['role'] ?? '').toString().trim();
    if (roleValue.isEmpty) roleValue = 'user';
    if (!roleIds.contains(roleValue)) roleValue = 'user';

    final vendorCtrl = TextEditingController(text: (initial['vendorId'] ?? '').toString());
    bool disabled = initial['disabled'] == true;

    await showDialog<void>(
      context: context,
      builder: (_) {
        bool saving = false;

        return StatefulBuilder(builder: (context, setSB) {
          Future<void> save() async {
            final chosenRole = roleValue.trim();
            final isVendor = _isVendorRoleId(chosenRole);
            final vendorIdText = vendorCtrl.text.trim();

            if (isVendor && vendorIdText.isEmpty) {
              _toast('vendor 角色需要 vendorId');
              return;
            }

            setSB(() => saving = true);
            try {
              final patch = <String, dynamic>{
                'role': chosenRole,
                'disabled': disabled,
                'updatedAt': FieldValue.serverTimestamp(),
              };
              if (isVendor) {
                patch['vendorId'] = vendorIdText;
              } else {
                // 若不是 vendor，保留 vendorId 或清掉由你決定
                // 這裡採「不清」以免誤刪資料：
                // patch['vendorId'] = FieldValue.delete();
              }

              await _usersRef.doc(uid).set(patch, SetOptions(merge: true));

              if (!mounted) return;
              Navigator.pop(context);
              _toast('已更新使用者');
            } catch (e) {
              _toast('更新失敗：$e');
            } finally {
              setSB(() => saving = false);
            }
          }

          final displayName = (initial['displayName'] ?? '未命名').toString();
          final email = (initial['email'] ?? '').toString();

          return AlertDialog(
            title: const Text('編輯使用者', style: TextStyle(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _kv('uid', uid),
                  _kv('名稱', displayName),
                  if (email.isNotEmpty) _kv('Email', email),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: roleValue,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '角色 role',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: roleIds.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: saving
                        ? null
                        : (v) => setSB(() {
                              roleValue = (v ?? 'user');
                            }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: vendorCtrl,
                    decoration: InputDecoration(
                      labelText: 'vendorId（role=vendor 時必填）',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      helperText: _isVendorRoleId(roleValue) ? '必填' : '非 vendor 可留空',
                    ),
                    enabled: !saving,
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: disabled,
                    onChanged: saving ? null : (v) => setSB(() => disabled = v),
                    title: const Text('停用帳號（disabled）', style: TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(
                      disabled ? '此帳號將被前台/後台視為停用（需你 App 端配合）' : '帳號正常',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('取消')),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? '儲存中...' : '儲存'),
              ),
            ],
          );
        });
      },
    );
  }

  // ============================================================
  // Utils / Helpers
  // ============================================================
  bool _isVendorRoleId(String roleId) => roleId.trim().toLowerCase() == 'vendor';

  Map<String, bool> _asMap(dynamic v) {
    if (v is Map) {
      final out = <String, bool>{};
      v.forEach((k, val) {
        out[k.toString()] = val == true;
      });
      return out;
    }
    return <String, bool>{};
  }

  Future<String?> _askText({
    required String title,
    required String hint,
    required String initial,
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('確定')),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 84, child: Text(k, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ============================================================
// Widgets
// ============================================================

class _RoleHeaderCard extends StatelessWidget {
  final String roleId;
  final String name;
  final String description;
  final bool isSystem;
  final int enabledPermCount;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _RoleHeaderCard({
    required this.roleId,
    required this.name,
    required this.description,
    required this.isSystem,
    required this.enabledPermCount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.admin_panel_settings_outlined, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 2),
                      Text('id: $roleId', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                if (isSystem) const _Pill(text: 'System'),
              ],
            ),
            const SizedBox(height: 10),
            if (description.isNotEmpty)
              Text(description, style: TextStyle(color: cs.onSurfaceVariant, height: 1.35)),
            if (description.isNotEmpty) const SizedBox(height: 10),
            Row(
              children: [
                _Pill(text: '已啟用權限：$enabledPermCount'),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('編輯'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onDelete,
                  style: FilledButton.styleFrom(backgroundColor: onDelete == null ? Colors.grey.shade300 : Colors.red),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(onDelete == null ? '不可刪' : '刪除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionsMatrix extends StatelessWidget {
  final Set<String> enabled;
  final VoidCallback onEdit;
  final List<_PermGroup> groups;

  const _PermissionsMatrix({
    required this.enabled,
    required this.onEdit,
    required this.groups,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('共 ${enabled.length} 項已啟用', style: const TextStyle(fontWeight: FontWeight.w900)),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.tune),
                  label: const Text('編輯權限'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...groups.map((g) {
              final enabledCount = g.items.where((p) => enabled.contains(p.key)).length;
              return ExpansionTile(
                initiallyExpanded: true,
                title: Text('${g.title}（$enabledCount/${g.items.length}）', style: const TextStyle(fontWeight: FontWeight.w900)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Column(
                      children: g.items.map((p) {
                        final ok = enabled.contains(p.key);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? Colors.green : Colors.grey),
                          title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(p.key, style: TextStyle(color: cs.onSurfaceVariant)),
                        );
                      }).toList(),
                    ),
                  )
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AssignActionsCard extends StatelessWidget {
  final String roleId;
  final String roleName;
  final bool isVendorRole;
  final VoidCallback onAssign;
  final VoidCallback onBatchAssign;

  const _AssignActionsCard({
    required this.roleId,
    required this.roleName,
    required this.isVendorRole,
    required this.onAssign,
    required this.onBatchAssign,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.person_add_alt_1, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '目前選擇角色：$roleName（$roleId）',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (isVendorRole) const _Pill(text: 'vendorId 必填'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onAssign,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('指派單一使用者'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onBatchAssign,
                    icon: const Icon(Icons.done_all),
                    label: const Text('批次指派'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersInRoleList extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> usersRef;
  final String roleId;
  final TextEditingController searchController;
  final VoidCallback onChanged;
  final void Function(String uid, Map<String, dynamic> data) onEditUser;

  const _UsersInRoleList({
    required this.usersRef,
    required this.roleId,
    required this.searchController,
    required this.onChanged,
    required this.onEditUser,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Text('此角色使用者', style: TextStyle(fontWeight: FontWeight.w900)),
                const Spacer(),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜尋 uid / email / displayName',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 420,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: usersRef.where('role', isEqualTo: roleId).limit(300).snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('載入失敗：${snap.error}'));
                  }

                  final docs = (snap.data?.docs ?? []).toList();
                  final q = searchController.text.trim().toLowerCase();

                  final filtered = q.isEmpty
                      ? docs
                      : docs.where((d) {
                          final m = d.data();
                          final uid = d.id.toLowerCase();
                          final email = (m['email'] ?? '').toString().toLowerCase();
                          final name = (m['displayName'] ?? '').toString().toLowerCase();
                          return uid.contains(q) || email.contains(q) || name.contains(q);
                        }).toList();

                  if (filtered.isEmpty) return const Center(child: Text('目前此角色沒有使用者或無符合條件'));

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.grey.shade200),
                    itemBuilder: (context, i) {
                      final doc = filtered[i];
                      final m = doc.data();
                      final uid = doc.id;

                      final name = (m['displayName'] ?? '未命名').toString();
                      final email = (m['email'] ?? '').toString();
                      final vendorId = (m['vendorId'] ?? '').toString();
                      final disabled = m['disabled'] == true;

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(child: Text(name.isNotEmpty ? name.substring(0, 1) : '?')),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          [
                            'uid: $uid',
                            if (email.isNotEmpty) 'email: $email',
                            if (vendorId.isNotEmpty) 'vendorId: $vendorId',
                            if (disabled) 'disabled',
                          ].join('  •  '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        trailing: FilledButton.tonalIcon(
                          onPressed: () => onEditUser(uid, m),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('編輯'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

class _HintCard extends StatelessWidget {
  final String text;
  final IconData icon;
  const _HintCard({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(color: cs.onSurfaceVariant, height: 1.35))),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  const _ErrorPanel({required this.title, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
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
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
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

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: cs.onPrimaryContainer)),
    );
  }
}

// ============================================================
// Permission Models
// ============================================================

class _Perm {
  final String key;
  final String label;
  const _Perm(this.key, this.label);
}

class _PermGroup {
  final String title;
  final List<_Perm> items;
  const _PermGroup(this.title, this.items);
}

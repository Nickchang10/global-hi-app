// lib/pages/admin/members/admin_members_page.dart
// =====================================================
// ✅ AdminMembersPage（修正版完整版）
// - 修正 RenderFlex overflow（Row 超寬）
// - 修正 DropdownButton assertion（value 不在 items / 重複）
// - Firestore: users collection（role / vendorId）
// =====================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminMembersPage extends StatefulWidget {
  const AdminMembersPage({super.key});

  @override
  State<AdminMembersPage> createState() => _AdminMembersPageState();
}

class _AdminMembersPageState extends State<AdminMembersPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _keyword = '';
  String _roleFilter = 'all'; // all/user/vendor/admin

  static const _roleOptions = <String>['user', 'vendor', 'admin'];
  static const _roleFilterOptions = <String>['all', 'user', 'vendor', 'admin'];

  final _df = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _keyword = v.trim().toLowerCase());
    });
  }

  // ✅ Dropdown 防呆：value 必須存在於 items
  T? _safeDropdownValue<T>(T? value, List<T> items) {
    if (value == null) return null;
    return items.contains(value) ? value : null;
  }

  Query<Map<String, dynamic>> _usersQuery() {
    // 你原本若有 createdAt/updatedAt index，可自行調整 orderBy
    // 沒有的話建議用 __name__ 排序（保證存在）
    var q = FirebaseFirestore.instance.collection('users').orderBy(FieldPath.documentId);

    // role 篩選（後端建 index 或簡單用前端過濾也行）
    if (_roleFilter != 'all') {
      q = q.where('role', isEqualTo: _roleFilter);
    }

    return q.limit(300);
  }

  bool _hitKeyword(Map<String, dynamic> m, String docId) {
    if (_keyword.isEmpty) return true;

    final name = (m['displayName'] ?? '').toString().toLowerCase();
    final email = (m['email'] ?? '').toString().toLowerCase();
    final phone = (m['phone'] ?? '').toString().toLowerCase();
    final role = (m['role'] ?? '').toString().toLowerCase();
    final vendorId = (m['vendorId'] ?? '').toString().toLowerCase();
    final id = docId.toLowerCase();

    return name.contains(_keyword) ||
        email.contains(_keyword) ||
        phone.contains(_keyword) ||
        role.contains(_keyword) ||
        vendorId.contains(_keyword) ||
        id.contains(_keyword);
  }

  Future<void> _updateUserRole({
    required String uid,
    required String newRole,
  }) async {
    if (!_roleOptions.contains(newRole)) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新 $uid role → $newRole')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失敗：$e')),
      );
    }
  }

  Future<void> _updateVendorId({
    required String uid,
    required String vendorId,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'vendorId': vendorId.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已更新 vendorId')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失敗：$e')),
      );
    }
  }

  Future<void> _openEditVendorDialog({
    required String uid,
    required String currentVendorId,
  }) async {
    final ctrl = TextEditingController(text: currentVendorId);
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('設定 vendorId'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: '例如：vendor_001',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('儲存'),
          ),
        ],
      ),
    );

    if (res == null) return;
    await _updateVendorId(uid: uid, vendorId: res);
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.deepPurple;
      case 'vendor':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  String _fmtTs(dynamic v) {
    if (v is Timestamp) return _df.format(v.toDate());
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('會員管理'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // =========================
          // Filters
          // =========================
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: LayoutBuilder(
              builder: (context, c) {
                // ✅ 小寬度時改成兩行，避免 Row overflow
                final isNarrow = c.maxWidth < 520;

                final search = TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: '搜尋：姓名 / email / phone / uid / vendorId / role',
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );

                final roleFilter = DropdownButtonFormField<String>(
                  value: _safeDropdownValue(_roleFilter, _roleFilterOptions) ?? 'all',
                  items: _roleFilterOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _roleFilter = v ?? 'all'),
                  isExpanded: true, // ✅ 避免 dropdown 自己造成超寬
                  decoration: InputDecoration(
                    labelText: '角色',
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      search,
                      const SizedBox(height: 10),
                      roleFilter,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    SizedBox(width: 220, child: roleFilter),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // =========================
          // List
          // =========================
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _usersQuery().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs
                    .where((d) => _hitKeyword(d.data(), d.id))
                    .toList(growable: false);

                if (docs.isEmpty) {
                  return const Center(child: Text('沒有符合條件的會員'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final m = d.data();

                    final uid = d.id;
                    final name = (m['displayName'] ?? '').toString().trim();
                    final email = (m['email'] ?? '').toString().trim();
                    final phone = (m['phone'] ?? '').toString().trim();
                    final roleRaw = (m['role'] ?? 'user').toString().trim();
                    final role = _roleOptions.contains(roleRaw) ? roleRaw : 'user'; // ✅ 防呆
                    final vendorId = (m['vendorId'] ?? '').toString().trim();

                    final updatedAt = _fmtTs(m['updatedAt']);
                    final createdAt = _fmtTs(m['createdAt']);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final isNarrow = c.maxWidth < 560;

                            final roleChip = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _roleColor(role).withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: _roleColor(role).withOpacity(0.25)),
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  color: _roleColor(role),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            );

                            final titleLine = Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (name.isEmpty ? '(未命名)' : name),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis, // ✅ 避免溢出
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                roleChip,
                              ],
                            );

                            final subLine = Text(
                              [
                                if (email.isNotEmpty) email,
                                if (phone.isNotEmpty) phone,
                                if (vendorId.isNotEmpty) 'vendorId: $vendorId',
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade700),
                            );

                            final metaLine = Text(
                              'uid: $uid\ncreated: $createdAt   updated: $updatedAt',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.2),
                            );

                            final roleDropdown = DropdownButtonFormField<String>(
                              value: _safeDropdownValue(role, _roleOptions) ?? 'user', // ✅ 防 assertion
                              items: _roleOptions
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                _updateUserRole(uid: uid, newRole: v);
                              },
                              isExpanded: true, // ✅ 避免 dropdown 造成 overflow
                              decoration: InputDecoration(
                                labelText: '變更角色',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );

                            final vendorBtn = OutlinedButton.icon(
                              onPressed: () => _openEditVendorDialog(uid: uid, currentVendorId: vendorId),
                              icon: const Icon(Icons.store_mall_directory_outlined, size: 18),
                              label: const Text('設定 vendorId'),
                            );

                            // ✅ 窄寬：改 Column，完全避免 Row 超寬
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  titleLine,
                                  const SizedBox(height: 6),
                                  subLine,
                                  const SizedBox(height: 8),
                                  metaLine,
                                  const SizedBox(height: 10),
                                  roleDropdown,
                                  const SizedBox(height: 10),
                                  vendorBtn,
                                ],
                              );
                            }

                            // ✅ 寬螢幕：右側操作區固定寬度，左側 Expanded
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      titleLine,
                                      const SizedBox(height: 6),
                                      subLine,
                                      const SizedBox(height: 8),
                                      metaLine,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 240,
                                  child: Column(
                                    children: [
                                      roleDropdown,
                                      const SizedBox(height: 10),
                                      vendorBtn,
                                    ],
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
            ),
          ),
        ],
      ),
    );
  }
}

// lib/pages/vendors_page.dart
//
// ✅ VendorsPage（可編譯完整版｜Admin 管理 vendors｜綁定使用者 vendorId）
//
// 功能：
// - 僅 Admin 可進（讀 users/{uid}.role）
// - vendors 清單 + 搜尋
// - 新增/編輯/刪除 vendor
// - 綁定使用者為 vendor：更新 users/{uid} -> role=vendor, vendorId=<選定vendorId>
//
// Firestore:
// - vendors/{vendorId}: { name, contactEmail, createdAt, updatedAt, notifyNewOrder, notifySystem }
// - users/{uid}: { role: 'admin'|'vendor', vendorId: 'xxx', email, displayName, updatedAt }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();

  String _q = '';

  String _s(dynamic v) => (v ?? '').toString().trim();

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _isAdmin(User user) async {
    final doc = await _db.collection('users').doc(user.uid).get();
    final role = _s(doc.data()?['role']).toLowerCase();
    return role == 'admin';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _vendorsStream() {
    return _db
        .collection('vendors')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Future<void> _openUpsertDialog({
    String? vendorId,
    Map<String, dynamic>? data,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _VendorUpsertDialog(vendorId: vendorId, initial: data),
    );
    if (ok == true) _snack(vendorId == null ? '已新增 vendor' : '已更新 vendor');
  }

  Future<void> _confirmDelete(String vendorId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除？'),
        content: Text(
          '將刪除 vendors/$vendorId。\n（不會自動清掉 users 的 vendorId，需自行處理）',
        ),
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
      await _db.collection('vendors').doc(vendorId).delete();
      _snack('已刪除 $vendorId');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  // ✅ 只保留一份，避免 duplicate_definition
  Future<void> _bindUserToVendor({required String vendorId}) async {
    final uidCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('綁定使用者成 Vendor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('將 users/{uid} 設為 role=vendor 並綁定 vendorId=$vendorId'),
            const SizedBox(height: 12),
            TextField(
              controller: uidCtrl,
              decoration: const InputDecoration(
                labelText: '使用者 UID（users/{uid}）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('綁定'),
          ),
        ],
      ),
    );

    final uid = uidCtrl.text.trim();
    uidCtrl.dispose();

    if (ok != true) return;

    if (uid.isEmpty) {
      _snack('UID 不可為空');
      return;
    }

    try {
      await _db.collection('users').doc(uid).set({
        'role': 'vendor',
        'vendorId': vendorId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('已綁定 users/$uid -> vendorId=$vendorId');
    } catch (e) {
      _snack('綁定失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        return FutureBuilder<bool>(
          future: _isAdmin(user),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (roleSnap.data != true) {
              return const Scaffold(body: Center(child: Text('需要 Admin 權限')));
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('廠商管理（Vendors）'),
                actions: [
                  IconButton(
                    tooltip: '新增廠商',
                    onPressed: () => _openUpsertDialog(),
                    icon: const Icon(Icons.add_business_outlined),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _openUpsertDialog(),
                icon: const Icon(Icons.add),
                label: const Text('新增廠商'),
              ),
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _q = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: '搜尋 vendorId / 名稱 / email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _vendorsStream(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(child: Text('讀取失敗：${snap.error}'));
                          }
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snap.data!.docs;
                          final q = _q.trim().toLowerCase();

                          final filtered = docs.where((d) {
                            final m = d.data();
                            final id = d.id.toLowerCase();
                            final name = _s(m['name']).toLowerCase();
                            final email = _s(m['contactEmail']).toLowerCase();
                            if (q.isEmpty) return true;
                            return id.contains(q) ||
                                name.contains(q) ||
                                email.contains(q);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(child: Text('沒有符合條件的廠商'));
                          }

                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final d = filtered[i];
                              final m = d.data();

                              final vendorId = d.id;
                              final name = _s(m['name']).isEmpty
                                  ? '(未命名)'
                                  : _s(m['name']);
                              final email = _s(m['contactEmail']);
                              final notifyNew = (m['notifyNewOrder'] is bool)
                                  ? (m['notifyNewOrder'] as bool)
                                  : true;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: cs
                                      .surfaceContainerHighest, // ✅ surfaceVariant -> surfaceContainerHighest
                                  child: const Icon(Icons.store_outlined),
                                ),
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  'vendorId: $vendorId'
                                  '${email.isNotEmpty ? ' ・ $email' : ''}'
                                  ' ・ 新訂單通知:${notifyNew ? '開' : '關'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Wrap(
                                  spacing: 6,
                                  children: [
                                    IconButton(
                                      tooltip: '複製 vendorId',
                                      icon: const Icon(Icons.copy),
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: vendorId),
                                        );
                                        _snack('已複製 vendorId');
                                      },
                                    ),
                                    IconButton(
                                      tooltip: '綁定使用者',
                                      icon: const Icon(Icons.link),
                                      onPressed: () =>
                                          _bindUserToVendor(vendorId: vendorId),
                                    ),
                                    IconButton(
                                      tooltip: '編輯',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _openUpsertDialog(
                                        vendorId: vendorId,
                                        data: m,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '刪除',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _confirmDelete(vendorId),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _VendorUpsertDialog extends StatefulWidget {
  const _VendorUpsertDialog({this.vendorId, this.initial});

  final String? vendorId;
  final Map<String, dynamic>? initial;

  @override
  State<_VendorUpsertDialog> createState() => _VendorUpsertDialogState();
}

class _VendorUpsertDialogState extends State<_VendorUpsertDialog> {
  final _db = FirebaseFirestore.instance;

  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _notifyNewOrder = true;
  bool _notifySystem = true;

  bool _saving = false;

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    if (widget.vendorId != null) _idCtrl.text = widget.vendorId!;
    final m = widget.initial ?? {};
    _nameCtrl.text = _s(m['name']);
    _emailCtrl.text = _s(m['contactEmail']);
    _notifyNewOrder = (m['notifyNewOrder'] is bool)
        ? (m['notifyNewOrder'] as bool)
        : true;
    _notifySystem = (m['notifySystem'] is bool)
        ? (m['notifySystem'] as bool)
        : true;
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入 vendorId')));
      return;
    }

    setState(() => _saving = true);
    try {
      final now = FieldValue.serverTimestamp();
      await _db.collection('vendors').doc(id).set({
        'name': _nameCtrl.text.trim(),
        'contactEmail': _emailCtrl.text.trim(),
        'notifyNewOrder': _notifyNewOrder,
        'notifySystem': _notifySystem,
        'updatedAt': now,
        if (widget.vendorId == null) 'createdAt': now,
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vendorId != null;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? '編輯廠商' : '新增廠商',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _idCtrl,
                enabled: !_saving && !isEdit,
                decoration: const InputDecoration(
                  labelText: 'vendorId（文件 ID）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: '廠商名稱',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: '聯絡 Email（可留空）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('新訂單通知'),
                value: _notifyNewOrder,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _notifyNewOrder = v),
              ),
              SwitchListTile(
                title: const Text('系統公告通知'),
                value: _notifySystem,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _notifySystem = v),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('儲存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

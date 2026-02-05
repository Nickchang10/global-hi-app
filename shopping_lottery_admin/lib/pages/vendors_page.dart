// lib/pages/vendors_page.dart
//
// ✅ VendorsPage（最終完整版｜可編譯｜Admin Only｜CRUD｜綁定 Vendor 使用者｜匯出 CSV｜可預覽廠商後台）
//
// Firestore 建議：vendors/{vendorId}
//   - name: String
//   - contactName: String
//   - phone: String
//   - email: String
//   - note: String
//   - isActive: bool
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//
// 使用者綁定：users/{uid}
//   - role: 'admin' | 'vendor' | ...
//   - vendorId: String
//   - email/displayName 可選
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
import 'vendor_dashboard_page.dart';

class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  final _db = FirebaseFirestore.instance;

  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  final _searchCtrl = TextEditingController();
  String _q = '';

  bool? _isActive; // null=全部, true=啟用, false=停用
  String? _selectedVendorId;

  bool _busy = false;
  String _busyLabel = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------- utils ----------
  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _isTrue(dynamic v) => v == true;

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

  // ---------- query ----------
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamVendors() {
    Query<Map<String, dynamic>> q = _db
        .collection('vendors')
        .orderBy('createdAt', descending: true)
        .limit(800);

    if (_isActive != null) {
      q = _db
          .collection('vendors')
          .where('isActive', isEqualTo: _isActive)
          .orderBy('createdAt', descending: true)
          .limit(800);
    }

    return q.snapshots();
  }

  bool _matchVendor(String id, Map<String, dynamic> d) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final name = _s(d['name']).toLowerCase();
    final contact = _s(d['contactName']).toLowerCase();
    final email = _s(d['email']).toLowerCase();
    final phone = _s(d['phone']).toLowerCase();
    final note = _s(d['note']).toLowerCase();
    final vid = id.toLowerCase();

    return vid.contains(q) ||
        name.contains(q) ||
        contact.contains(q) ||
        email.contains(q) ||
        phone.contains(q) ||
        note.contains(q);
  }

  void _previewVendorDashboard(String vendorId) {
    final vid = vendorId.trim();
    if (vid.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VendorDashboardPage(
          vendorId: vid,
          asAdminPreview: true,
        ),
      ),
    );
  }

  // ---------- CRUD ----------
  Future<void> _toggleActive(String vendorId, bool active) async {
    final id = vendorId.trim();
    if (id.isEmpty) return;

    await _setBusy(true, label: active ? '啟用中...' : '停用中...');
    try {
      await _db.collection('vendors').doc(id).set(
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

  Future<void> _deleteVendor(String vendorId) async {
    final id = vendorId.trim();
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除廠商'),
        content: Text('確定要刪除 vendor：$id 嗎？（不可復原）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (ok != true) return;

    await _setBusy(true, label: '刪除中...');
    try {
      await _db.collection('vendors').doc(id).delete();
      if (_selectedVendorId == id) _selectedVendorId = null;
      _snack('已刪除：$id');
    } catch (e) {
      _snack('刪除失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _openEditDialog({String? vendorId, Map<String, dynamic>? data}) async {
    final isCreate = vendorId == null || vendorId.trim().isEmpty;

    final nameCtrl = TextEditingController(text: _s(data?['name']));
    final contactCtrl = TextEditingController(text: _s(data?['contactName']));
    final phoneCtrl = TextEditingController(text: _s(data?['phone']));
    final emailCtrl = TextEditingController(text: _s(data?['email']));
    final noteCtrl = TextEditingController(text: _s(data?['note']));
    bool isActive = data == null ? true : _isTrue(data['isActive']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text(isCreate ? '新增廠商' : '編輯廠商'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '廠商名稱',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: contactCtrl,
                          decoration: const InputDecoration(
                            labelText: '聯絡人',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: '電話',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '備註',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('啟用 isActive'),
                    value: isActive,
                    onChanged: (v) => setInner(() => isActive = v),
                  ),
                  if (isCreate)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '提示：新增後 vendorId 會自動生成，可再到「綁定使用者」把 users/{uid}.vendorId 指向此 vendor。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
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
      ),
    );

    if (ok == true) {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        _snack('廠商名稱不可為空');
        nameCtrl.dispose();
        contactCtrl.dispose();
        phoneCtrl.dispose();
        emailCtrl.dispose();
        noteCtrl.dispose();
        return;
      }

      await _setBusy(true, label: '儲存中...');
      try {
        if (isCreate) {
          final ref = _db.collection('vendors').doc();
          await ref.set(<String, dynamic>{
            'name': name,
            'contactName': contactCtrl.text.trim(),
            'phone': phoneCtrl.text.trim(),
            'email': emailCtrl.text.trim(),
            'note': noteCtrl.text.trim(),
            'isActive': isActive,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          _selectedVendorId = ref.id;
          _snack('已新增廠商：${ref.id}');
        } else {
          final id = vendorId!.trim();
          await _db.collection('vendors').doc(id).set(<String, dynamic>{
            'name': name,
            'contactName': contactCtrl.text.trim(),
            'phone': phoneCtrl.text.trim(),
            'email': emailCtrl.text.trim(),
            'note': noteCtrl.text.trim(),
            'isActive': isActive,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          _snack('已更新：$id');
        }
      } catch (e) {
        _snack('儲存失敗：$e');
      } finally {
        await _setBusy(false);
      }
    }

    nameCtrl.dispose();
    contactCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    noteCtrl.dispose();
  }

  // ---------- bind vendor user ----------
  Future<void> _openBindUserDialog({required String vendorId}) async {
    final vid = vendorId.trim();
    if (vid.isEmpty) return;

    final inputCtrl = TextEditingController(); // uid or email
    bool setRoleVendor = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('綁定 Vendor 使用者'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InfoRow(
                  label: 'vendorId',
                  value: vid,
                  onCopy: () => _copy(vid, done: '已複製 vendorId'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: inputCtrl,
                  decoration: const InputDecoration(
                    labelText: '輸入使用者 UID 或 Email',
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: '例如：uidxxxx 或 user@mail.com',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('同時設定 users/{uid}.role = vendor'),
                  value: setRoleVendor,
                  onChanged: (v) => setInner(() => setRoleVendor = v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '說明：會寫入 users/{uid}.vendorId = vendorId。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('綁定')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final input = inputCtrl.text.trim();
      if (input.isEmpty) {
        _snack('請輸入 UID 或 Email');
        inputCtrl.dispose();
        return;
      }

      await _setBusy(true, label: '綁定中...');
      try {
        String uid = '';

        // email 模式：在 users collection 用 email 欄位查
        if (input.contains('@')) {
          final qs = await _db.collection('users').where('email', isEqualTo: input).limit(1).get();

          if (qs.docs.isEmpty) {
            _snack('找不到 email 對應的 users 文件：$input');
            await _setBusy(false);
            inputCtrl.dispose();
            return;
          }
          uid = qs.docs.first.id;
        } else {
          uid = input; // uid 模式：直接當 docId
        }

        final update = <String, dynamic>{
          'vendorId': vid,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (setRoleVendor) update['role'] = 'vendor';

        await _db.collection('users').doc(uid).set(update, SetOptions(merge: true));
        _snack('已綁定使用者：$uid');
      } catch (e) {
        _snack('綁定失敗：$e');
      } finally {
        await _setBusy(false);
      }
    }

    inputCtrl.dispose();
  }

  Future<void> _unbindUser({required String uid}) async {
    final u = uid.trim();
    if (u.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('解除綁定'),
        content: Text('確定要解除 users/$u 的 vendorId 嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('解除')),
        ],
      ),
    );

    if (ok != true) return;

    await _setBusy(true, label: '解除中...');
    try {
      await _db.collection('users').doc(u).set(
        <String, dynamic>{
          'vendorId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _snack('已解除：$u');
    } catch (e) {
      _snack('解除失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  // ---------- export ----------
  Future<void> _exportCsv(List<_VendorRow> vendors) async {
    if (vendors.isEmpty) return;

    final headers = <String>[
      'vendorId',
      'name',
      'contactName',
      'phone',
      'email',
      'isActive',
      'createdAt',
      'updatedAt',
      'note',
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));

    for (final v in vendors) {
      final d = v.data;
      final row = <String>[
        v.id,
        _s(d['name']),
        _s(d['contactName']),
        _s(d['phone']),
        _s(d['email']),
        _isTrue(d['isActive']).toString(),
        (_toDate(d['createdAt'])?.toIso8601String() ?? ''),
        (_toDate(d['updatedAt'])?.toIso8601String() ?? ''),
        _s(d['note']),
      ].map((e) => e.replaceAll(',', '，')).toList();

      buffer.writeln(row.join(','));
    }

    await downloadCsv('vendors_export.csv', buffer.toString());
    _snack('已匯出 vendors_export.csv');
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
          _selectedVendorId = null;
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
                appBar: AppBar(title: const Text('廠商管理')),
                body: Center(child: Text('讀取角色失敗：${roleSnap.error}')),
              );
            }

            final info = roleSnap.data;
            final isAdmin = _s(info?.role).toLowerCase() == 'admin';

            if (!isAdmin) {
              return Scaffold(
                appBar: AppBar(title: const Text('廠商管理')),
                body: const Center(child: Text('此頁僅限 Admin 使用')),
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('廠商管理', style: TextStyle(fontWeight: FontWeight.w900)),
                actions: [
                  IconButton(
                    tooltip: '新增廠商',
                    onPressed: _busy ? null : () => _openEditDialog(),
                    icon: const Icon(Icons.add_box_outlined),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: Stack(
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _streamVendors(),
                    builder: (context, snap) {
                      if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                      final rows = snap.data!.docs
                          .map((d) => _VendorRow(id: d.id, data: d.data()))
                          .where((r) => _matchVendor(r.id, r.data))
                          .toList();

                      return Column(
                        children: [
                          _VendorFilters(
                            searchCtrl: _searchCtrl,
                            isActive: _isActive,
                            countLabel: '${rows.length} 筆',
                            onQueryChanged: (v) => setState(() => _q = v),
                            onClearQuery: () {
                              _searchCtrl.clear();
                              setState(() => _q = '');
                            },
                            onActiveChanged: (v) => setState(() => _isActive = v),
                            onAdd: () => _openEditDialog(),
                            onExport: rows.isEmpty ? null : () => _exportCsv(rows),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final isWide = c.maxWidth >= 980;

                                final list = ListView.separated(
                                  itemCount: rows.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final r = rows[i];
                                    final d = r.data;

                                    final name = _s(d['name']).isEmpty ? '（未命名廠商）' : _s(d['name']);
                                    final contact = _s(d['contactName']);
                                    final email = _s(d['email']);
                                    final phone = _s(d['phone']);
                                    final active = _isTrue(d['isActive']);
                                    final updatedAt = _toDate(d['updatedAt'] ?? d['createdAt']);

                                    return ListTile(
                                      selected: r.id == _selectedVendorId,
                                      leading: Icon(active ? Icons.storefront_outlined : Icons.store_outlined),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w900),
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
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 4,
                                              children: [
                                                Text(
                                                  'ID：${r.id}',
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (contact.isNotEmpty)
                                                  Text(
                                                    '聯絡人：$contact',
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                if (phone.isNotEmpty)
                                                  Text(
                                                    '電話：$phone',
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                if (email.isNotEmpty)
                                                  Text(
                                                    'Email：$email',
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '更新：${_fmt(updatedAt)}',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        tooltip: '更多',
                                        onSelected: _busy
                                            ? null
                                            : (v) async {
                                                if (v == 'copy') {
                                                  await _copy(r.id, done: '已複製 vendorId');
                                                } else if (v == 'preview') {
                                                  _previewVendorDashboard(r.id);
                                                } else if (v == 'edit') {
                                                  await _openEditDialog(vendorId: r.id, data: d);
                                                } else if (v == 'active') {
                                                  await _toggleActive(r.id, !active);
                                                } else if (v == 'bind') {
                                                  await _openBindUserDialog(vendorId: r.id);
                                                } else if (v == 'delete') {
                                                  await _deleteVendor(r.id);
                                                }
                                              },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(value: 'copy', child: Text('複製 vendorId')),
                                          const PopupMenuItem(value: 'preview', child: Text('預覽廠商後台')),
                                          const PopupMenuItem(value: 'edit', child: Text('編輯')),
                                          PopupMenuItem(value: 'active', child: Text(active ? '停用' : '啟用')),
                                          const PopupMenuItem(value: 'bind', child: Text('綁定使用者（Vendor）')),
                                          const PopupMenuDivider(),
                                          const PopupMenuItem(value: 'delete', child: Text('刪除')),
                                        ],
                                      ),
                                      onTap: () {
                                        setState(() => _selectedVendorId = r.id);
                                        if (!isWide) {
                                          showDialog(
                                            context: context,
                                            builder: (_) => _VendorDetailDialog(
                                              id: r.id,
                                              data: d,
                                              fmt: _fmt,
                                              toDate: _toDate,
                                              onCopy: _copy,
                                              onPreview: () => _previewVendorDashboard(r.id),
                                              onEdit: () => _openEditDialog(vendorId: r.id, data: d),
                                              onToggleActive: () => _toggleActive(r.id, !active),
                                              onBindUser: () => _openBindUserDialog(vendorId: r.id),
                                              onDelete: () => _deleteVendor(r.id),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                                );

                                if (!isWide) return list;

                                final selected = _selectedVendorId == null
                                    ? null
                                    : rows.where((e) => e.id == _selectedVendorId).cast<_VendorRow?>().firstOrNull;

                                return Row(
                                  children: [
                                    Expanded(flex: 3, child: list),
                                    const VerticalDivider(width: 1),
                                    Expanded(
                                      flex: 2,
                                      child: selected == null
                                          ? Center(
                                              child: Text(
                                                '請選擇廠商',
                                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                              ),
                                            )
                                          : _VendorDetailPanel(
                                              id: selected.id,
                                              data: selected.data,
                                              fmt: _fmt,
                                              toDate: _toDate,
                                              onCopy: _copy,
                                              onPreview: () => _previewVendorDashboard(selected.id),
                                              onEdit: () => _openEditDialog(vendorId: selected.id, data: selected.data),
                                              onToggleActive: () => _toggleActive(
                                                selected.id,
                                                !_isTrue(selected.data['isActive']),
                                              ),
                                              onBindUser: () => _openBindUserDialog(vendorId: selected.id),
                                              onUnbindUser: (uid) => _unbindUser(uid: uid),
                                              onDelete: () => _deleteVendor(selected.id),
                                            ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (_busy)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _BusyBar(label: _busyLabel.isEmpty ? '處理中...' : _busyLabel),
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
// Models / Extensions
// ------------------------------------------------------------
class _VendorRow {
  final String id;
  final Map<String, dynamic> data;
  _VendorRow({required this.id, required this.data});
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ------------------------------------------------------------
// Filters UI
// ------------------------------------------------------------
class _VendorFilters extends StatelessWidget {
  const _VendorFilters({
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
        hintText: '搜尋：vendorId / 名稱 / 聯絡人 / Email / 電話 / 備註',
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
      onChanged: (v) => onActiveChanged(v),
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
                label: const Text('新增廠商'),
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

// ------------------------------------------------------------
// Detail Panel / Dialog
// ------------------------------------------------------------
class _VendorDetailPanel extends StatelessWidget {
  const _VendorDetailPanel({
    required this.id,
    required this.data,
    required this.fmt,
    required this.toDate,
    required this.onCopy,
    required this.onPreview,
    required this.onEdit,
    required this.onToggleActive,
    required this.onBindUser,
    required this.onUnbindUser,
    required this.onDelete,
  });

  final String id;
  final Map<String, dynamic> data;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  final Future<void> Function(String text, {String done}) onCopy;

  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onBindUser;
  final Future<void> Function(String uid) onUnbindUser;
  final VoidCallback onDelete;

  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _isTrue(dynamic v) => v == true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final name = _s(data['name']).isEmpty ? '（未命名廠商）' : _s(data['name']);
    final contact = _s(data['contactName']);
    final phone = _s(data['phone']);
    final email = _s(data['email']);
    final note = _s(data['note']);
    final active = _isTrue(data['isActive']);

    final createdAt = toDate(data['createdAt']);
    final updatedAt = toDate(data['updatedAt']);

    final userStream = FirebaseFirestore.instance
        .collection('users')
        .where('vendorId', isEqualTo: id)
        .limit(50)
        .snapshots();

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: active ? '啟用' : '停用', color: active ? cs.primary : cs.error),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'vendorId', value: id, onCopy: () => onCopy(id, done: '已複製 vendorId')),
          const SizedBox(height: 6),
          _InfoRow(label: '聯絡人', value: contact),
          const SizedBox(height: 6),
          _InfoRow(label: '電話', value: phone),
          const SizedBox(height: 6),
          _InfoRow(label: 'Email', value: email),
          const SizedBox(height: 6),
          _InfoRow(label: '建立', value: fmt(createdAt)),
          const SizedBox(height: 6),
          _InfoRow(label: '更新', value: fmt(updatedAt)),
          const SizedBox(height: 12),
          Text('備註', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline.withOpacity(0.18)),
            ),
            child: Text(note.isEmpty ? '（無備註）' : note),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPreview,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('預覽後台'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBindUser,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('綁定使用者'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggleActive,
                  icon: Icon(active ? Icons.pause_circle_outline : Icons.play_circle_outline),
                  label: Text(active ? '停用' : '啟用'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('編輯'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => onCopy(jsonEncode(data), done: '已複製 vendor JSON'),
                icon: const Icon(Icons.code),
                label: const Text('複製 JSON'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('刪除'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('此廠商綁定的使用者', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Expanded(
            child: Card(
              elevation: 0,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: userStream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('讀取 users 失敗：${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        '尚無綁定使用者',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final u = docs[i];
                      final d = u.data();
                      final email = _s(d['email']);
                      final name = _s(d['displayName']);
                      final role = _s(d['role']);

                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                          name.isNotEmpty ? name : (email.isNotEmpty ? email : u.id),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text('uid：${u.id}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                            if (email.isNotEmpty)
                              Text(email, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                            if (role.isNotEmpty)
                              Text('role：$role', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'copy_uid') {
                              await onCopy(u.id, done: '已複製 uid');
                            } else if (v == 'unbind') {
                              await onUnbindUser(u.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'copy_uid', child: Text('複製 uid')),
                            PopupMenuItem(value: 'unbind', child: Text('解除綁定')),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorDetailDialog extends StatelessWidget {
  const _VendorDetailDialog({
    required this.id,
    required this.data,
    required this.fmt,
    required this.toDate,
    required this.onCopy,
    required this.onPreview,
    required this.onEdit,
    required this.onToggleActive,
    required this.onBindUser,
    required this.onDelete,
  });

  final String id;
  final Map<String, dynamic> data;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  final Future<void> Function(String text, {String done}) onCopy;

  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onBindUser;
  final VoidCallback onDelete;

  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _isTrue(dynamic v) => v == true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final name = _s(data['name']).isEmpty ? '（未命名廠商）' : _s(data['name']);
    final active = _isTrue(data['isActive']);

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(
        width: 560,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                  IconButton(
                    tooltip: '複製 vendorId',
                    onPressed: () => onCopy(id, done: '已複製 vendorId'),
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: _Pill(label: active ? '啟用' : '停用', color: active ? cs.primary : cs.error),
              ),
              const SizedBox(height: 10),
              _InfoRow(label: 'vendorId', value: id),
              const SizedBox(height: 6),
              _InfoRow(label: 'Email', value: _s(data['email'])),
              const SizedBox(height: 6),
              _InfoRow(label: '電話', value: _s(data['phone'])),
              const SizedBox(height: 6),
              _InfoRow(label: '更新', value: fmt(toDate(data['updatedAt']))),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_s(data['note']).isEmpty ? '（無備註）' : _s(data['note'])),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onPreview();
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('預覽後台'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('編輯'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onToggleActive();
                    },
                    icon: Icon(active ? Icons.pause_circle_outline : Icons.play_circle_outline),
                    label: Text(active ? '停用' : '啟用'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onBindUser();
                    },
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('綁定使用者'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('刪除'),
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

// ------------------------------------------------------------
// Shared Widgets
// ------------------------------------------------------------
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.onCopy});
  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 86, child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
        Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w800))),
        if (onCopy != null)
          IconButton(
            tooltip: '複製',
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 18),
          ),
      ],
    );
  }
}

class _BusyBar extends StatelessWidget {
  const _BusyBar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

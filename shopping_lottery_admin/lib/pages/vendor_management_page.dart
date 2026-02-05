// lib/pages/vendor_management_page.dart
//
// ✅ VendorManagementPage（最終完整版｜廠商管理系統｜CRUD + 搜尋 + 分頁 + 綁定帳號）
// ------------------------------------------------------------
// Firestore 建議：
// vendors/{vendorId}
// - name: String
// - nameLower: String (for prefix search)
// - contactEmail: String?
// - phone: String?
// - address: String?
// - note: String?
// - isActive: bool
// - createdAt: Timestamp
// - updatedAt: Timestamp
//
// users/{uid}（你 AdminGate 已沿用）
// - email: String?
// - role: 'admin' / 'vendor' / 'customer'
// - vendorId: String?
// - displayName: String?
// - updatedAt: Timestamp
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VendorManagementPage extends StatefulWidget {
  const VendorManagementPage({super.key});

  @override
  State<VendorManagementPage> createState() => _VendorManagementPageState();
}

class _VendorManagementPageState extends State<VendorManagementPage> {
  final _db = FirebaseFirestore.instance;

  // filters
  final _searchCtrl = TextEditingController();
  String _q = '';
  String _status = '全部'; // 全部/啟用/停用

  // pagination
  static const int _pageSize = 20;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loading = false;

  final List<_VendorRow> _rows = [];

  // busy overlay
  bool _busy = false;
  String _busyLabel = '';

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _setBusy(bool v, {String label = ''}) {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  String _s(dynamic v) => (v ?? '').toString();
  bool _b(dynamic v) => v == true;

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    if (!refresh && !_hasMore) return;

    setState(() => _loading = true);
    try {
      if (refresh) {
        _rows.clear();
        _lastDoc = null;
        _hasMore = true;
      }

      Query<Map<String, dynamic>> q = _db.collection('vendors');

      // status filter
      if (_status != '全部') {
        q = q.where('isActive', isEqualTo: _status == '啟用');
      }

      final text = _q.trim().toLowerCase();

      // search: prefix on nameLower
      if (text.isNotEmpty) {
        q = q.orderBy('nameLower').startAt([text]).endAt(['$text\uf8ff']);
      } else {
        // default sort
        q = q.orderBy('updatedAt', descending: true);
      }

      q = q.limit(_pageSize);
      if (_lastDoc != null && !refresh) {
        q = q.startAfterDocument(_lastDoc!);
      }

      final snap = await q.get();
      final docs = snap.docs;

      final newRows = docs.map((d) {
        final data = d.data();
        return _VendorRow(
          id: d.id,
          name: _s(data['name']).trim(),
          contactEmail: _s(data['contactEmail']).trim(),
          phone: _s(data['phone']).trim(),
          address: _s(data['address']).trim(),
          note: _s(data['note']).trim(),
          isActive: _b(data['isActive']),
          createdAt: _toDate(data['createdAt']),
          updatedAt: _toDate(data['updatedAt']),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _rows.addAll(newRows);
        _hasMore = newRows.length == _pageSize;
        _lastDoc = docs.isNotEmpty ? docs.last : _lastDoc;
      });
    } catch (e) {
      _snack('載入廠商失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _VendorEditPage()),
    );
    if (ok == true) _load(refresh: true);
  }

  Future<void> _openEdit(_VendorRow r) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _VendorEditPage(vendorId: r.id)),
    );
    if (ok == true) _load(refresh: true);
  }

  Future<void> _deleteVendor(_VendorRow r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除廠商'),
        content: Text(
          '確定要刪除「${r.name.isEmpty ? r.id : r.name}」？\n（將同時解除綁定的 vendor 使用者）',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (confirm != true) return;

    _setBusy(true, label: '刪除中...');
    try {
      // 解除綁定 users（best effort）
      final usersSnap = await _db.collection('users').where('vendorId', isEqualTo: r.id).get();

      final batch = _db.batch();
      for (final u in usersSnap.docs) {
        final role = (u.data()['role'] ?? '').toString().toLowerCase().trim();
        batch.set(
          u.reference,
          {
            'vendorId': FieldValue.delete(),
            // 保守：若是 vendor 才降回 customer
            if (role == 'vendor') 'role': 'customer',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      batch.delete(_db.collection('vendors').doc(r.id));
      await batch.commit();

      _snack('已刪除廠商並解除綁定 ${usersSnap.size} 位使用者');
      await _load(refresh: true);
    } catch (e) {
      _snack('刪除失敗：$e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _toggleActive(_VendorRow r, bool toActive) async {
    _setBusy(true, label: toActive ? '啟用中...' : '停用中...');
    try {
      await _db.collection('vendors').doc(r.id).set(
        {
          'isActive': toActive,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _snack('已${toActive ? '啟用' : '停用'}：${r.name.isEmpty ? r.id : r.name}');
      await _load(refresh: true);
    } catch (e) {
      _snack('更新失敗：$e');
    } finally {
      _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusItems = const ['全部', '啟用', '停用'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('廠商管理'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(refresh: true),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // filter bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: '搜尋廠商（前綴）',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          setState(() => _q = v);
                          _load(refresh: true);
                        },
                      ),
                    ),
                    DropdownButton<String>(
                      value: statusItems.contains(_status) ? _status : '全部',
                      items: statusItems.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) {
                        setState(() => _status = v ?? '全部');
                        _load(refresh: true);
                      },
                    ),
                    Text('共 ${_rows.length} 筆', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: _rows.isEmpty
                    ? Center(
                        child: Text(
                          _loading ? '載入中...' : '尚無廠商資料',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _rows.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _rows.length) {
                            if (!_loading) _load();
                            return const Padding(
                              padding: EdgeInsets.all(14),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final r = _rows[i];
                          final name = r.name.isEmpty ? '(未命名)' : r.name;

                          final subParts = <String>[
                            if (r.contactEmail.isNotEmpty) r.contactEmail,
                            if (r.phone.isNotEmpty) r.phone,
                            if (r.address.isNotEmpty) r.address,
                          ];

                          final subtitle = subParts.isEmpty
                              ? 'vendorId：${r.id}'
                              : '${subParts.join(' · ')}\nvendorId：${r.id}';

                          return ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                r.isActive
                                    ? Icons.store_mall_directory_outlined
                                    : Icons.store_mall_directory,
                              ),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text(subtitle),
                            isThreeLine: subParts.isNotEmpty,
                            trailing: PopupMenuButton<String>(
                              onSelected: (k) {
                                if (k == 'edit') _openEdit(r);
                                if (k == 'on') _toggleActive(r, true);
                                if (k == 'off') _toggleActive(r, false);
                                if (k == 'del') _deleteVendor(r);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('編輯 / 綁定帳號')),
                                PopupMenuItem(
                                  value: r.isActive ? 'off' : 'on',
                                  child: Text(r.isActive ? '停用' : '啟用'),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'del',
                                  child: Text('刪除', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                            onTap: () => _openEdit(r),
                          );
                        },
                      ),
              ),
            ],
          ),

          if (_busy)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                elevation: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _busyLabel.isEmpty ? '處理中...' : _busyLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('新增廠商'),
      ),
    );
  }
}

class _VendorRow {
  final String id;
  final String name;
  final String contactEmail;
  final String phone;
  final String address;
  final String note;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  _VendorRow({
    required this.id,
    required this.name,
    required this.contactEmail,
    required this.phone,
    required this.address,
    required this.note,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}

// ------------------------------------------------------------
// Vendor Edit Page (Create/Edit + Bind vendor users)
// ------------------------------------------------------------
class _VendorEditPage extends StatefulWidget {
  final String? vendorId;
  const _VendorEditPage({this.vendorId});

  @override
  State<_VendorEditPage> createState() => _VendorEditPageState();
}

class _VendorEditPageState extends State<_VendorEditPage> {
  final _db = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _isActive = true;
  bool _loading = false;
  bool _saving = false;

  // bind user by email
  final _bindEmailCtrl = TextEditingController();
  bool _binding = false;

  bool get _isEdit => widget.vendorId != null;

  // ✅ 新增時先預生成 vendorId，讓你可直接拿來做綁定（仍建議先存檔）
  late final String _draftVendorId =
      widget.vendorId ?? _db.collection('vendors').doc().id;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    _noteCtrl.dispose();
    _bindEmailCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _s(dynamic v) => (v ?? '').toString();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final doc = await _db.collection('vendors').doc(_draftVendorId).get();
      if (!doc.exists) return;

      final d = doc.data() ?? {};
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = _s(d['name']).trim();
        _emailCtrl.text = _s(d['contactEmail']).trim();
        _phoneCtrl.text = _s(d['phone']).trim();
        _addrCtrl.text = _s(d['address']).trim();
        _noteCtrl.text = _s(d['note']).trim();
        _isActive = d['isActive'] == true;
      });
    } catch (e) {
      _snack('載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final payload = <String, dynamic>{
      'name': name,
      'nameLower': name.toLowerCase(),
      'contactEmail': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address': _addrCtrl.text.trim(),
      'note': _noteCtrl.text.trim(),
      'isActive': _isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    setState(() => _saving = true);
    try {
      final ref = _db.collection('vendors').doc(_draftVendorId);

      if (_isEdit) {
        await ref.set(payload, SetOptions(merge: true));
      } else {
        await ref.set(
          {
            ...payload,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;
      _snack('已儲存');
      Navigator.pop(context, true);
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _bindUserByEmail() async {
    if (_binding) return;

    // 建議：先存檔再綁定（確保 vendors/{vendorId} 存在）
    if (!_isEdit) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('提示'),
          content: const Text('建議先儲存廠商，再進行綁定。\n要先自動建立廠商資料嗎？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('建立並繼續')),
          ],
        ),
      );
      if (ok != true) return;

      // 先建立 vendors doc（不強制填滿，只要存在）
      try {
        await _db.collection('vendors').doc(_draftVendorId).set(
          {
            'name': _nameCtrl.text.trim(),
            'nameLower': _nameCtrl.text.trim().toLowerCase(),
            'contactEmail': _emailCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'address': _addrCtrl.text.trim(),
            'note': _noteCtrl.text.trim(),
            'isActive': _isActive,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (e) {
        _snack('建立廠商資料失敗：$e');
        return;
      }
    }

    final email = _bindEmailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      _snack('請輸入 Email');
      return;
    }

    setState(() => _binding = true);
    try {
      final snap = await _db.collection('users').where('email', isEqualTo: email).limit(10).get();
      if (snap.docs.isEmpty) {
        _snack('找不到 users 內對應 Email：$email（請確認 users 文件有寫入 email 欄位）');
        return;
      }

      // 若多筆（理論上不應），讓使用者選
      DocumentSnapshot<Map<String, dynamic>> picked = snap.docs.first;

      if (snap.docs.length > 1) {
        final id = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('選擇要綁定的使用者'),
            content: SizedBox(
              width: 420,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final d in snap.docs)
                    ListTile(
                      title: Text(
                        _s(d.data()['displayName']).trim().isEmpty
                            ? d.id
                            : _s(d.data()['displayName']).trim(),
                      ),
                      subtitle: Text('uid: ${d.id}'),
                      onTap: () => Navigator.pop(context, d.id),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ],
          ),
        );

        if (id == null) return;
        picked = snap.docs.firstWhere((e) => e.id == id);
      }

      await picked.reference.set(
        {
          'role': 'vendor',
          'vendorId': _draftVendorId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _snack('已綁定：${picked.id}');
      _bindEmailCtrl.clear();
      if (mounted) setState(() {});
    } catch (e) {
      _snack('綁定失敗：$e');
    } finally {
      if (mounted) setState(() => _binding = false);
    }
  }

  Future<void> _unbindUser(String uid) async {
    if (_binding) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('解除綁定'),
        content: Text('確定要解除綁定此使用者？\nuid: $uid'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('解除')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _binding = true);
    try {
      // 保守：只解除 vendorId；role 若要降級，通常只有 vendor 需要降。
      final userRef = _db.collection('users').doc(uid);
      final userDoc = await userRef.get();
      final role = (userDoc.data()?['role'] ?? '').toString().toLowerCase().trim();

      await userRef.set(
        {
          'vendorId': FieldValue.delete(),
          if (role == 'vendor') 'role': 'customer',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _snack('已解除綁定');
      if (mounted) setState(() {});
    } catch (e) {
      _snack('解除失敗：$e');
    } finally {
      if (mounted) setState(() => _binding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? '編輯廠商' : '新增廠商';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final vendorId = _draftVendorId;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '儲存',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Text(
                    'vendorId：$vendorId',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '廠商名稱',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? '請輸入廠商名稱' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: '聯絡 Email（選填）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: '電話（選填）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _addrCtrl,
                  decoration: const InputDecoration(
                    labelText: '地址（選填）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _noteCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '備註（選填）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('啟用狀態', style: TextStyle(fontWeight: FontWeight.w800)),
                  value: _isActive,
                  onChanged: _saving ? null : (v) => setState(() => _isActive = v),
                ),

                const Divider(height: 26),

                // ----------------------------
                // Bind vendor users
                // ----------------------------
                const Text('綁定廠商帳號（vendor）',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bindEmailCtrl,
                        decoration: const InputDecoration(
                          hintText: '輸入使用者 Email（users.email）',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: (_binding || _saving) ? null : _bindUserByEmail,
                      icon: const Icon(Icons.link),
                      label: const Text('綁定'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db.collection('users').where('vendorId', isEqualTo: vendorId).snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('尚無綁定的 vendor 使用者'),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('已綁定 ${docs.length} 位使用者',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        ...docs.map((d) {
                          final data = d.data();
                          final email = _s(data['email']).trim();
                          final name = _s(data['displayName']).trim();
                          final role = _s(data['role']).trim();

                          return Card(
                            child: ListTile(
                              title: Text(
                                name.isEmpty ? d.id : name,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text([
                                if (email.isNotEmpty) email,
                                if (role.isNotEmpty) 'role: $role',
                                'uid: ${d.id}',
                              ].join(' · ')),
                              trailing: TextButton(
                                onPressed: _binding ? null : () => _unbindUser(d.id),
                                child: const Text('解除'),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 18),

                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('儲存'),
                ),
              ],
            ),
          ),

          if (_saving || _binding)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: const [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Expanded(child: Text('處理中...', style: TextStyle(fontWeight: FontWeight.w800))),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

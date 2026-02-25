import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// AdminUsersPage（正式版｜完整版｜可直接編譯）
///
/// ✅ 修正：DropdownButtonFormField 的 value 已 deprecated → 改用 initialValue
/// ✅ 修正：Filter dropdown 加 ValueKey，確保 initialValue 變更時 UI 會更新
///
/// Firestore 建議：users/{uid}
/// - displayName: String
/// - email: String
/// - phone: String
/// - role: String              // user / vendor / admin / super_admin
/// - disabled: bool
/// - createdAt: Timestamp
/// - lastLoginAt: Timestamp?
/// - updatedAt: Timestamp
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _searchCtrl = TextEditingController();
  bool _busy = false;

  String _roleFilter = 'all';
  String _statusFilter = 'all'; // all / enabled / disabled

  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('users');

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

  Query<Map<String, dynamic>> _query() {
    // 建議用 createdAt 排序；若你資料一定有 updatedAt 也可改 orderBy('updatedAt', descending: true)
    return _ref.orderBy('createdAt', descending: true).limit(800);
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v.trim());
    return null;
  }

  String _fmtDate(dynamic v) {
    final dt = _toDate(v);
    if (dt == null) return '-';
    final l = dt.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-'
        '${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')}';
  }

  String _fmtDateTime(dynamic v) {
    final dt = _toDate(v);
    if (dt == null) return '-';
    final l = dt.toLocal();
    return '${_fmtDate(l)} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  bool _matchKeyword(String keyword, String id, Map<String, dynamic> m) {
    if (keyword.isEmpty) return true;
    final k = keyword.toLowerCase();

    String s(String key) => (m[key] ?? '').toString().toLowerCase();
    return id.toLowerCase().contains(k) ||
        s('displayName').contains(k) ||
        s('email').contains(k) ||
        s('phone').contains(k) ||
        s('role').contains(k);
  }

  bool _matchFilters(Map<String, dynamic> m) {
    final role = (m['role'] ?? 'user').toString();
    final disabled = m['disabled'] == true;

    if (_roleFilter != 'all' && role != _roleFilter) return false;
    if (_statusFilter == 'enabled' && disabled) return false;
    if (_statusFilter == 'disabled' && !disabled) return false;
    return true;
  }

  Future<void> _toggleDisabled(String uid, bool disabled) async {
    try {
      await _ref.doc(uid).set({
        'disabled': disabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('更新失敗：$e', error: true);
    }
  }

  Future<void> _openEditor(String uid, Map<String, dynamic> initial) async {
    final res = await showModalBottomSheet<_UserEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UserEditorSheet(uid: uid, initial: initial),
    );
    if (res == null) return;

    setState(() => _busy = true);
    try {
      await _ref.doc(uid).set({
        ...res.payload,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('已更新使用者');
    } catch (e) {
      _snack('保存失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createUserStub() async {
    final res = await showModalBottomSheet<_UserCreateResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CreateUserStubSheet(),
    );
    if (res == null) return;

    // 注意：此處是「建立 Firestore 使用者資料」；不含 Firebase Auth 建立帳號。
    setState(() => _busy = true);
    try {
      await _ref.doc(res.uid).set({
        'displayName': res.displayName,
        'email': res.email,
        'phone': res.phone,
        'role': res.role,
        'disabled': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('已建立使用者資料（不含 Auth）');
    } catch (e) {
      _snack('建立失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'super_admin':
        return Colors.purple;
      case 'admin':
        return Colors.indigo;
      case 'vendor':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'super_admin':
        return Icons.security;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'vendor':
        return Icons.storefront;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('使用者管理'),
        actions: [
          IconButton(
            tooltip: '建立使用者資料（Firestore stub）',
            onPressed: _busy ? null : _createUserStub,
            icon: const Icon(Icons.person_add),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: '搜尋：displayName / email / phone / role / uid',
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // ✅ FIX: value deprecated → initialValue + key
                        key: ValueKey('roleFilter=$_roleFilter'),
                        initialValue: _roleFilter,
                        decoration: InputDecoration(
                          labelText: '角色',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全部')),
                          DropdownMenuItem(value: 'user', child: Text('user')),
                          DropdownMenuItem(
                            value: 'vendor',
                            child: Text('vendor'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('admin'),
                          ),
                          DropdownMenuItem(
                            value: 'super_admin',
                            child: Text('super_admin'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _roleFilter = v ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // ✅ FIX: value deprecated → initialValue + key
                        key: ValueKey('statusFilter=$_statusFilter'),
                        initialValue: _statusFilter,
                        decoration: InputDecoration(
                          labelText: '狀態',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全部')),
                          DropdownMenuItem(value: 'enabled', child: Text('啟用')),
                          DropdownMenuItem(
                            value: 'disabled',
                            child: Text('停用'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _statusFilter = v ?? 'all'),
                      ),
                    ),
                  ],
                ),
              ],
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

                final docs = snap.data!.docs;
                final rows = docs
                    .where((d) {
                      final m = d.data();
                      return _matchFilters(m) &&
                          _matchKeyword(keyword, d.id, m);
                    })
                    .toList(growable: false);

                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      '沒有資料',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = rows[i];
                    final m = d.data();

                    final name = (m['displayName'] ?? '').toString().trim();
                    final email = (m['email'] ?? '').toString().trim();
                    final phone = (m['phone'] ?? '').toString().trim();
                    final role = (m['role'] ?? 'user').toString().trim();
                    final disabled = m['disabled'] == true;

                    final createdAt = _fmtDate(m['createdAt']);
                    final lastLoginAt = _fmtDateTime(m['lastLoginAt']);

                    return Card(
                      elevation: 0.7,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          child: Icon(_roleIcon(role), color: _roleColor(role)),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name.isEmpty ? '(未命名)' : name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(role),
                              labelStyle: TextStyle(color: _roleColor(role)),
                            ),
                            const SizedBox(width: 6),
                            if (disabled)
                              const Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('DISABLED'),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (phone.isNotEmpty)
                              Text(
                                phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.fingerprint,
                                    size: 16,
                                  ),
                                  label: Text('uid: ${d.id}'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                  ),
                                  label: Text('created: $createdAt'),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.login, size: 16),
                                  label: Text('lastLogin: $lastLoginAt'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 155,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Switch(
                                value: !disabled,
                                onChanged: _busy
                                    ? null
                                    : (v) => _toggleDisabled(d.id, !v),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                children: [
                                  IconButton(
                                    tooltip: '編輯',
                                    onPressed: _busy
                                        ? null
                                        : () => _openEditor(d.id, m),
                                    icon: const Icon(Icons.edit),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        onTap: _busy ? null : () => _openEditor(d.id, m),
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

// =====================
// Edit Sheet
// =====================

class _UserEditResult {
  const _UserEditResult(this.payload);
  final Map<String, dynamic> payload;
}

class _UserEditorSheet extends StatefulWidget {
  const _UserEditorSheet({required this.uid, required this.initial});

  final String uid;
  final Map<String, dynamic> initial;

  @override
  State<_UserEditorSheet> createState() => _UserEditorSheetState();
}

class _UserEditorSheetState extends State<_UserEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  String _role = 'user';
  bool _disabled = false;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _name = TextEditingController(text: (m['displayName'] ?? '').toString());
    _email = TextEditingController(text: (m['email'] ?? '').toString());
    _phone = TextEditingController(text: (m['phone'] ?? '').toString());

    _role = (m['role'] ?? 'user').toString();
    _disabled = m['disabled'] == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.pop(
      context,
      _UserEditResult({
        'displayName': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'role': _role,
        'disabled': _disabled,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  '編輯使用者',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'uid: ${widget.uid}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'displayName',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  // ✅ FIX: value deprecated → initialValue
                  key: ValueKey('editRole=$_role'),
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('user')),
                    DropdownMenuItem(value: 'vendor', child: Text('vendor')),
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                    DropdownMenuItem(
                      value: 'super_admin',
                      child: Text('super_admin'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'user'),
                ),
                const SizedBox(height: 10),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('disabled'),
                  value: _disabled,
                  onChanged: (v) => setState(() => _disabled = v),
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

// =====================
// Create User Stub Sheet
// =====================

class _UserCreateResult {
  const _UserCreateResult({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.role,
  });

  final String uid;
  final String displayName;
  final String email;
  final String phone;
  final String role;
}

class _CreateUserStubSheet extends StatefulWidget {
  const _CreateUserStubSheet();

  @override
  State<_CreateUserStubSheet> createState() => _CreateUserStubSheetState();
}

class _CreateUserStubSheetState extends State<_CreateUserStubSheet> {
  final _formKey = GlobalKey<FormState>();

  final _uid = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String _role = 'user';

  @override
  void dispose() {
    _uid.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _UserCreateResult(
        uid: _uid.text.trim(),
        displayName: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  '建立使用者資料（Firestore stub）',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _uid,
                  decoration: const InputDecoration(
                    labelText: 'uid（必填）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? '必填' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'displayName',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  // ✅ FIX: value deprecated → initialValue
                  key: ValueKey('createRole=$_role'),
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('user')),
                    DropdownMenuItem(value: 'vendor', child: Text('vendor')),
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                    DropdownMenuItem(
                      value: 'super_admin',
                      child: Text('super_admin'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'user'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save),
                    label: const Text('建立'),
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

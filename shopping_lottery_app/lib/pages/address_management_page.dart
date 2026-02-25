import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ 地址管理（AddressManagementPage）
/// Firestore: users/{uid}/addresses
class AddressManagementPage extends StatefulWidget {
  const AddressManagementPage({super.key});

  @override
  State<AddressManagementPage> createState() => _AddressManagementPageState();
}

class _AddressManagementPageState extends State<AddressManagementPage> {
  final _fs = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('地址管理')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('請先登入才能管理地址', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/login'),
                  child: const Text('前往登入'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final col = _fs.collection('users').doc(user.uid).collection('addresses');

    return Scaffold(
      appBar: AppBar(
        title: const Text('地址管理'),
        actions: [
          IconButton(
            tooltip: '新增地址',
            onPressed: () => _openEditor(context, uid: user.uid),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col
            .orderBy('isDefault', descending: true)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return _emptyState(user.uid);
          }

          final items = docs.map((d) => UserAddress.fromDoc(d)).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final a = items[i];
              return _addressCard(
                context,
                uid: user.uid,
                address: a,
                onEdit: () => _openEditor(context, uid: user.uid, address: a),
                onDelete: () =>
                    _deleteAddress(context, uid: user.uid, address: a),
                onSetDefault: () =>
                    _setDefault(context, uid: user.uid, address: a),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, uid: user.uid),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('新增地址'),
      ),
    );
  }

  Widget _emptyState(String uid) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 72,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text('尚未新增任何地址', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _openEditor(context, uid: uid),
              child: const Text('新增第一筆地址'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressCard(
    BuildContext context, {
    required String uid,
    required UserAddress address,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onSetDefault,
  }) {
    final title = [
      if (address.receiverName.isNotEmpty) address.receiverName,
      if (address.phone.isNotEmpty) address.phone,
    ].where((e) => e.trim().isNotEmpty).join(' • ');

    final full = address.fullAddressLine;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? '收件資訊' : title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (address.isDefault)
                  _pill('預設', Colors.green)
                else
                  TextButton(
                    onPressed: onSetDefault,
                    child: const Text('設為預設'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              full.isEmpty ? '（無地址內容）' : full,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('編輯'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('刪除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        // ✅ FIX: withOpacity -> withValues(alpha: ...)
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    required String uid,
    UserAddress? address,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressEditPage(
          uid: uid,
          // ✅ 這裡就是你原本報錯的 named parameter：address
          address: address,
        ),
      ),
    );
  }

  Future<void> _deleteAddress(
    BuildContext context, {
    required String uid,
    required UserAddress address,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除地址'),
        content: const Text('確定要刪除此地址嗎？此操作無法復原。'),
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

    try {
      await _fs
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .doc(address.id)
          .delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除地址')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  Future<void> _setDefault(
    BuildContext context, {
    required String uid,
    required UserAddress address,
  }) async {
    try {
      final col = _fs.collection('users').doc(uid).collection('addresses');

      // ✅ 將其他地址取消預設，再把指定地址設為預設
      final batch = _fs.batch();
      final snap = await col.get();

      for (final d in snap.docs) {
        final isDefault = (d.data()['isDefault'] ?? false) == true;
        if (isDefault) {
          batch.update(d.reference, {
            'isDefault': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      batch.set(col.doc(address.id), {
        ...address.toMap(),
        'isDefault': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已設為預設地址')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('設定失敗：$e')));
    }
  }
}

/// ✅ 地址編輯頁（AddressEditPage）
/// - 支援 AddressEditPage(address: xxx) ✅（解掉你現在的 undefined_named_parameter）
class AddressEditPage extends StatefulWidget {
  const AddressEditPage({
    super.key,
    required this.uid,
    this.address, // ✅ named parameter: address
  });

  final String uid;
  final UserAddress? address;

  @override
  State<AddressEditPage> createState() => _AddressEditPageState();
}

class _AddressEditPageState extends State<AddressEditPage> {
  final _fs = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _receiverName;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zip;
  late final TextEditingController _country;

  bool _isDefault = false;
  bool _saving = false;

  bool get _isEdit => widget.address != null;

  @override
  void initState() {
    super.initState();
    final a = widget.address;

    _receiverName = TextEditingController(text: a?.receiverName ?? '');
    _phone = TextEditingController(text: a?.phone ?? '');
    _line1 = TextEditingController(text: a?.line1 ?? '');
    _line2 = TextEditingController(text: a?.line2 ?? '');
    _city = TextEditingController(text: a?.city ?? '');
    _state = TextEditingController(text: a?.state ?? '');
    _zip = TextEditingController(text: a?.zip ?? '');
    _country = TextEditingController(text: a?.country ?? '台灣');

    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _receiverName.dispose();
    _phone.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '編輯地址' : '新增地址'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('儲存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_receiverName, label: '收件人姓名', validator: _required),
            const SizedBox(height: 10),
            _field(
              _phone,
              label: '電話',
              keyboard: TextInputType.phone,
              validator: _required,
            ),
            const SizedBox(height: 10),
            _field(_line1, label: '地址（路/街/號）', validator: _required),
            const SizedBox(height: 10),
            _field(_line2, label: '地址補充（樓層/門牌/備註）'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _field(_city, label: '城市/區', validator: _required),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(_state, label: '縣市', validator: _required),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _zip,
                    label: '郵遞區號',
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(_country, label: '國家/地區', validator: _required),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              onChanged: _saving ? null : (v) => setState(() => _isDefault = v),
              title: const Text('設為預設地址'),
              subtitle: const Text('結帳時將優先使用此地址'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_isEdit ? '儲存變更' : '新增地址'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) return '此欄位必填';
    return null;
  }

  Widget _field(
    TextEditingController c, {
    required String label,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final col = _fs
          .collection('users')
          .doc(widget.uid)
          .collection('addresses');

      final now = FieldValue.serverTimestamp();

      final data = UserAddress(
        id: widget.address?.id ?? col.doc().id,
        receiverName: _receiverName.text.trim(),
        phone: _phone.text.trim(),
        line1: _line1.text.trim(),
        line2: _line2.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        zip: _zip.text.trim(),
        country: _country.text.trim(),
        isDefault: _isDefault,
      ).toMap();

      // 若設為預設，先把其他地址取消預設（避免多筆預設）
      if (_isDefault) {
        final snap = await col.get();
        final batch = _fs.batch();

        for (final d in snap.docs) {
          final isDefault = (d.data()['isDefault'] ?? false) == true;
          if (isDefault && d.id != data['id']) {
            batch.update(d.reference, {'isDefault': false, 'updatedAt': now});
          }
        }

        batch.set(col.doc(data['id'] as String), {
          ...data,
          'updatedAt': now,
          if (!_isEdit) 'createdAt': now,
        }, SetOptions(merge: true));

        await batch.commit();
      } else {
        await col.doc(data['id'] as String).set({
          ...data,
          'updatedAt': now,
          if (!_isEdit) 'createdAt': now,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_isEdit ? '已更新地址' : '已新增地址')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }
}

/// ✅ 地址 Model
class UserAddress {
  final String id;

  final String receiverName;
  final String phone;

  final String line1;
  final String line2;

  final String city;
  final String state;
  final String zip;
  final String country;

  final bool isDefault;

  const UserAddress({
    required this.id,
    required this.receiverName,
    required this.phone,
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.zip,
    required this.country,
    required this.isDefault,
  });

  factory UserAddress.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return UserAddress(
      id: doc.id,
      receiverName: (d['receiverName'] ?? d['name'] ?? '').toString(),
      phone: (d['phone'] ?? '').toString(),
      line1: (d['line1'] ?? d['address1'] ?? d['address'] ?? '').toString(),
      line2: (d['line2'] ?? d['address2'] ?? '').toString(),
      city: (d['city'] ?? '').toString(),
      state: (d['state'] ?? d['county'] ?? '').toString(),
      zip: (d['zip'] ?? d['postalCode'] ?? '').toString(),
      country: (d['country'] ?? '台灣').toString(),
      isDefault: (d['isDefault'] ?? false) == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'receiverName': receiverName,
    'phone': phone,
    'line1': line1,
    'line2': line2,
    'city': city,
    'state': state,
    'zip': zip,
    'country': country,
    'isDefault': isDefault,
  };

  String get fullAddressLine {
    final parts = <String>[
      state,
      city,
      line1,
      if (line2.trim().isNotEmpty) line2,
      if (zip.trim().isNotEmpty) zip,
      if (country.trim().isNotEmpty) country,
    ].where((e) => e.trim().isNotEmpty).toList();
    return parts.join(' ');
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// 給 routing / Navigator 使用的參數
class AddressEditArgs {
  final String? addressId;
  final Map<String, dynamic>? initialData;

  const AddressEditArgs({this.addressId, this.initialData});

  /// 允許你從 settings.arguments 傳 Map 或 AddressEditArgs 都能吃
  static AddressEditArgs from(Object? args) {
    if (args is AddressEditArgs) return args;
    if (args is Map) {
      return AddressEditArgs(
        addressId: args['addressId']?.toString(),
        initialData: (args['initialData'] is Map)
            ? Map<String, dynamic>.from(args['initialData'] as Map)
            : null,
      );
    }
    return const AddressEditArgs();
  }
}

class AddressEditPage extends StatefulWidget {
  final Object? args;
  const AddressEditPage({super.key, this.args});

  @override
  State<AddressEditPage> createState() => _AddressEditPageState();
}

class _AddressEditPageState extends State<AddressEditPage> {
  final _label = TextEditingController(text: '收件地址');
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _isDefault = false;

  bool _loading = true;
  bool _saving = false;

  late final AddressEditArgs _a;

  @override
  void initState() {
    super.initState();
    _a = AddressEditArgs.from(widget.args);
    _init();
  }

  @override
  void dispose() {
    _label.dispose();
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // 1) 先吃 initialData（最快）
    final init = _a.initialData;
    if (init != null) {
      _apply(init);
      if (mounted) setState(() => _loading = false);
      return;
    }

    // 2) 如果是編輯但沒有 initialData，才去抓 doc
    if (_a.addressId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .doc(_a.addressId)
          .get();

      if (doc.exists && doc.data() != null) {
        _apply(doc.data()!);
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  void _apply(Map<String, dynamic> m) {
    _label.text = (m['label'] ?? '收件地址').toString();
    _name.text = (m['name'] ?? '').toString();
    _phone.text = (m['phone'] ?? '').toString();
    _address.text = (m['address'] ?? '').toString();
    _isDefault = (m['isDefault'] ?? false) == true;
  }

  Future<void> _setDefaultAndUnsetOthers({
    required WriteBatch batch,
    required CollectionReference<Map<String, dynamic>> col,
    required String keepId,
  }) async {
    final others = await col.where('isDefault', isEqualTo: true).get();
    for (final d in others.docs) {
      if (d.id == keepId) continue;
      batch.update(d.reference, {
        'isDefault': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final label = _label.text.trim();
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final address = _address.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入收件人姓名')));
      return;
    }
    if (phone.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入正確電話')));
      return;
    }
    if (address.length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入地址')));
      return;
    }

    setState(() => _saving = true);

    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('addresses');

      final batch = FirebaseFirestore.instance.batch();
      final now = FieldValue.serverTimestamp();

      DocumentReference<Map<String, dynamic>> ref;
      if (_a.addressId == null) {
        ref = col.doc(); // new
        batch.set(ref, {
          'label': label,
          'name': name,
          'phone': phone,
          'address': address,
          'isDefault': _isDefault,
          'createdAt': now,
          'updatedAt': now,
        });
      } else {
        ref = col.doc(_a.addressId);
        batch.update(ref, {
          'label': label,
          'name': name,
          'phone': phone,
          'address': address,
          'isDefault': _isDefault,
          'updatedAt': now,
        });
      }

      if (_isDefault) {
        await _setDefaultAndUnsetOthers(batch: batch, col: col, keepId: ref.id);
      }

      await batch.commit();
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

  Future<void> _delete() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_a.addressId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除地址'),
        content: const Text('確定要刪除這筆地址嗎？'),
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

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .doc(_a.addressId)
          .delete();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _a.addressId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '編輯地址' : '新增地址'),
        actions: [
          if (isEdit)
            IconButton(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _label,
                  decoration: const InputDecoration(labelText: '標籤（例如：家 / 公司）'),
                ),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: '收件人姓名'),
                ),
                TextField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: '電話'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: '地址'),
                  maxLines: 2,
                ),
                SwitchListTile(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                  title: const Text('設為預設地址'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('儲存'),
                ),
              ],
            ),
    );
  }
}

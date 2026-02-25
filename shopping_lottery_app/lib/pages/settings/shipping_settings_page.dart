import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ShippingSettingsPage extends StatefulWidget {
  const ShippingSettingsPage({super.key});

  @override
  State<ShippingSettingsPage> createState() => _ShippingSettingsPageState();
}

class _ShippingSettingsPageState extends State<ShippingSettingsPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  bool _hydrated = false;
  bool _saving = false;

  String get _uid => _auth.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> _userRef() =>
      _db.collection('users').doc(_uid);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> udoc) {
    if (_hydrated) return;
    _name.text = (udoc['receiverName'] ?? '').toString();
    _phone.text = (udoc['receiverPhone'] ?? '').toString();
    _address.text = (udoc['receiverAddress'] ?? '').toString();
    _hydrated = true;
  }

  String? _vNonEmpty(String? v, String msg) =>
      (v ?? '').trim().isEmpty ? msg : null;

  String? _vPhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '請輸入電話';
    if (s.length < 8) return '電話格式可能不正確';
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await _userRef().set({
        'receiverName': _name.text.trim(),
        'receiverPhone': _phone.text.trim(),
        'receiverAddress': _address.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存收件資訊')));
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
    if (_auth.currentUser == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('收件資訊')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userRef().snapshots(),
        builder: (context, snap) {
          final udoc = snap.data?.data() ?? <String, dynamic>{};
          _hydrate(udoc);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _name,
                          validator: (v) => _vNonEmpty(v, '請輸入收件人姓名'),
                          decoration: const InputDecoration(
                            labelText: '收件人姓名',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          validator: _vPhone,
                          decoration: const InputDecoration(
                            labelText: '收件人電話',
                            prefixIcon: Icon(Icons.call_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _address,
                          validator: (v) => _vNonEmpty(v, '請輸入收件地址'),
                          minLines: 1,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: '收件地址',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('儲存'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

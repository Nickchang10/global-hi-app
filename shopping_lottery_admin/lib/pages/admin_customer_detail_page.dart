// lib/pages/admin_customer_detail_page.dart
//
// ✅ AdminCustomerDetailPage（顧客詳細｜編輯 / 查看訂單）
// ------------------------------------------------------------
// Firestore: users/{uid}, orders where userId==uid
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminCustomerDetailPage extends StatefulWidget {
  final String userId;
  const AdminCustomerDetailPage({super.key, required this.userId});

  @override
  State<AdminCustomerDetailPage> createState() => _AdminCustomerDetailPageState();
}

class _AdminCustomerDetailPageState extends State<AdminCustomerDetailPage> {
  final _db = FirebaseFirestore.instance;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();

  bool _active = true;
  bool _loading = true;
  bool _saving = false;

  Map<String, dynamic>? _userData;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _roleCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final doc = await _db.collection('users').doc(widget.userId).get();
    if (!doc.exists) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final d = doc.data()!;
    setState(() {
      _userData = d;
      _nameCtrl.text = d['displayName'] ?? '';
      _emailCtrl.text = d['email'] ?? '';
      _phoneCtrl.text = d['phone'] ?? '';
      _roleCtrl.text = d['role'] ?? '';
      _active = d['isActive'] == true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _db.collection('users').doc(widget.userId).update({
        'displayName': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'role': _roleCtrl.text.trim(),
        'isActive': _active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack('已儲存');
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmt(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('yyyy/MM/dd HH:mm').format(ts.toDate());
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final d = _userData ?? {};
    final createdAt = _fmt(d['createdAt']);
    final lastLogin = _fmt(d['lastLoginAt']);

    return Scaffold(
      appBar: AppBar(title: Text('顧客詳細 - ${_nameCtrl.text}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '姓名', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: '電話', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _roleCtrl,
              decoration: const InputDecoration(labelText: '角色', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('啟用帳號'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const Divider(),
            Text('建立時間：$createdAt'),
            Text('最後登入：$lastLogin'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? '儲存中...' : '儲存變更'),
            ),
            const SizedBox(height: 24),
            const Text('訂單紀錄', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('orders')
                  .where('userId', isEqualTo: widget.userId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty) return const Text('（無訂單紀錄）');

                return Column(
                  children: docs.map((o) {
                    final d = o.data();
                    final total = d['total'] ?? 0;
                    final status = d['status'] ?? '';
                    return ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text('訂單 #${o.id}'),
                      subtitle: Text('金額：\$${total.toString()}｜狀態：$status'),
                      onTap: () {
                        Navigator.pushNamed(context, '/orders/${o.id}');
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

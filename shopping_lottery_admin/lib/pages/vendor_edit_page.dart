// lib/pages/vendor_edit_page.dart
//
// ✅ VendorEditPage（最終完整版）
// ------------------------------------------------------------
// 功能：新增 / 編輯 / 刪除 廠商資料
// Firestore: vendors/{vendorId}
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VendorEditPage extends StatefulWidget {
  final String? vendorId;
  const VendorEditPage({super.key, this.vendorId});

  @override
  State<VendorEditPage> createState() => _VendorEditPageState();
}

class _VendorEditPageState extends State<VendorEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _isActive = true;
  bool _loading = false;
  bool get _isEdit => widget.vendorId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadVendor();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVendor() async {
    setState(() => _loading = true);
    try {
      final doc = await _db.collection('vendors').doc(widget.vendorId).get();
      if (!doc.exists) {
        _snack('找不到此廠商資料');
        Navigator.pop(context, false);
        return;
      }
      final data = doc.data()!;
      _nameCtrl.text = (data['name'] ?? '').toString();
      _contactCtrl.text = (data['contact'] ?? '').toString();
      _phoneCtrl.text = (data['phone'] ?? '').toString();
      _emailCtrl.text = (data['email'] ?? '').toString();
      _noteCtrl.text = (data['note'] ?? '').toString();
      _isActive = data['isActive'] == true;
    } catch (e) {
      _snack('載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameCtrl.text.trim(),
      'contact': _contactCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'note': _noteCtrl.text.trim(),
      'isActive': _isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    setState(() => _loading = true);
    try {
      if (_isEdit) {
        await _db.collection('vendors').doc(widget.vendorId).set(data, SetOptions(merge: true));
      } else {
        await _db.collection('vendors').add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      _snack('已儲存');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除此廠商？此動作無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _db.collection('vendors').doc(widget.vendorId).delete();
      _snack('已刪除');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('刪除失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? '編輯廠商' : '新增廠商';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: '刪除此廠商',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            tooltip: '儲存',
            icon: const Icon(Icons.save_outlined),
            onPressed: _save,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '廠商名稱 *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入廠商名稱' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactCtrl,
                      decoration: const InputDecoration(
                        labelText: '聯絡人 *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入聯絡人' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: '電話 *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入電話' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        labelText: '備註',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('啟用狀態'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('儲存'),
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

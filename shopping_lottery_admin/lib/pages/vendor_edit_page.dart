// lib/pages/vendor_edit_page.dart
//
// ✅ VendorEditPage（最終完整版｜可編譯｜修正 use_build_context_synchronously + control_flow_in_finally）
// ------------------------------------------------------------
// - Firestore: vendors/{vendorId}
// - 支援：新增/編輯、儲存、刪除、複製 ID
// - arguments / ctor 皆可帶 vendorId

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorEditPage extends StatefulWidget {
  const VendorEditPage({super.key, this.vendorId});

  final String? vendorId;

  @override
  State<VendorEditPage> createState() => _VendorEditPageState();
}

class _VendorEditPageState extends State<VendorEditPage> {
  final _db = FirebaseFirestore.instance;

  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _vendorId = '';
  bool _active = true;

  bool _loading = true;
  bool _saving = false;

  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    _vendorId = _resolveVendorId(context);

    if (_vendorId.isEmpty) {
      setState(() => _loading = false);
    } else {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _resolveVendorId(BuildContext context) {
    final arg = ModalRoute.of(context)?.settings.arguments;
    final fromArg = arg is String ? arg.trim() : '';
    final fromCtor = (widget.vendorId ?? '').trim();
    return fromArg.isNotEmpty ? fromArg : fromCtor;
  }

  DocumentReference<Map<String, dynamic>> _ref(String id) =>
      _db.collection('vendors').doc(id);

  Future<void> _load() async {
    if (_vendorId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final snap = await _ref(_vendorId).get();
      if (!mounted) return;

      if (snap.exists) {
        final d = snap.data() ?? <String, dynamic>{};
        _nameCtrl.text = _s(d['name']);
        _contactCtrl.text = _s(d['contactName']);
        _phoneCtrl.text = _s(d['phone']);
        _emailCtrl.text = _s(d['email']);
        _addressCtrl.text = _s(d['address']);
        _descCtrl.text = _s(d['description']);
        _active = (d['active'] is bool) ? (d['active'] as bool) : true;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('讀取失敗：$e')));
    } finally {
      // ✅ finally 裡不要 return，避免 control_flow_in_finally
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyId() async {
    final id = _vendorId.trim();
    if (id.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已複製 Vendor ID')));
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('廠商名稱不可空白')));
      return;
    }

    if (!mounted) return;
    setState(() => _saving = true);

    try {
      if (_vendorId.trim().isEmpty) {
        // 這裡不涉及 async，直接 setState 讓 UI 立即顯示新 ID
        setState(() => _vendorId = _db.collection('vendors').doc().id);
      }

      final docRef = _ref(_vendorId);

      final existsSnap = await docRef.get();
      final isNew = !existsSnap.exists;

      final now = FieldValue.serverTimestamp();
      final payload = <String, dynamic>{
        'name': name,
        'contactName': _contactCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'active': _active,
        'updatedAt': now,
      };
      if (isNew) payload['createdAt'] = now;

      await docRef.set(payload, SetOptions(merge: true));
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存')));
      setState(() {}); // 刷新顯示（例如顯示 Vendor ID）
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      // ✅ finally 裡不要 return，避免 control_flow_in_finally
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_vendorId.trim().isEmpty) return;

    final displayName = _nameCtrl.text.trim().isEmpty
        ? _vendorId
        : _nameCtrl.text.trim();

    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('刪除廠商？'),
            content: Text('將刪除：$displayName'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('刪除'),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;
    if (!ok) return;

    try {
      await _ref(_vendorId).delete();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_vendorId.isEmpty ? '新增廠商' : '編輯廠商'),
        actions: [
          if (_vendorId.isNotEmpty)
            IconButton(
              tooltip: '複製 Vendor ID',
              onPressed: _copyId,
              icon: const Icon(Icons.copy),
            ),
          if (_vendorId.isNotEmpty)
            IconButton(
              tooltip: '刪除',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: _saving,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _field(_nameCtrl, '廠商名稱*'),
                          Row(
                            children: [
                              Expanded(child: _field(_contactCtrl, '聯絡人')),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _field(
                                  _phoneCtrl,
                                  '電話',
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),
                          _field(
                            _emailCtrl,
                            'Email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _field(_addressCtrl, '地址', maxLines: 2),
                          _field(_descCtrl, '描述', maxLines: 4),
                          const SizedBox(height: 6),
                          SwitchListTile(
                            value: _active,
                            onChanged: (v) => setState(() => _active = v),
                            title: const Text('啟用（active）'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? '儲存中…' : '儲存'),
                  ),
                  if (_vendorId.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Vendor ID：$_vendorId',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

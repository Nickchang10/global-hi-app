// lib/pages/admin/vendors/admin_vendors_edit_page.dart
//
// ✅ AdminVendorEditPage（完整最終版｜可編譯）
// ------------------------------------------------------------
// - 支援「新增」與「編輯」模式
// - Firestore 集合：vendors
// - 欄位：名稱、Email、電話、地區、狀態、描述
// - ✅ 修正：手機／平板自適應表單、無 overflow
// - 提交後返回廠商列表，自動刷新
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminVendorEditPage extends StatefulWidget {
  final Map<String, dynamic>? vendor;

  const AdminVendorEditPage({super.key, this.vendor});

  @override
  State<AdminVendorEditPage> createState() => _AdminVendorEditPageState();
}

class _AdminVendorEditPageState extends State<AdminVendorEditPage> {
  final _db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _region = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  String _status = 'active';
  bool _saving = false;
  late bool _isEdit;
  late String _title;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.vendor != null;
    _title = _isEdit ? '編輯廠商' : '新增廠商';

    if (_isEdit) {
      final v = widget.vendor!;
      _name.text = v['name'] ?? '';
      _email.text = v['email'] ?? '';
      _phone.text = v['phone'] ?? '';
      _region.text = v['region'] ?? '';
      _desc.text = v['description'] ?? '';
      _status = v['status'] ?? 'active';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _region.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '儲存廠商',
            onPressed: _saving ? null : _saveVendor,
          ),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final children = [
                  _buildTextField(_name, '廠商名稱', Icons.store, true),
                  _buildTextField(_email, 'Email', Icons.email, false),
                  _buildTextField(_phone, '電話', Icons.phone, false),
                  _buildTextField(_region, '地區', Icons.location_on, false),
                  _buildDropdown(),
                  _buildDescField(),
                ];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: isWide
                        ? Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            children: [
                              for (final w in children)
                                SizedBox(
                                  width: constraints.maxWidth / 2 - 32,
                                  child: w,
                                ),
                            ],
                          )
                        : Column(
                            children: [
                              for (final w in children) ...[
                                w,
                                const SizedBox(height: 20),
                              ],
                            ],
                          ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          icon: const Icon(Icons.save),
          label: Text(_isEdit ? '更新廠商' : '新增廠商'),
          onPressed: _saving ? null : _saveVendor,
        ),
      ),
    );
  }

  // ======================================================
  // 一般欄位
  // ======================================================
  Widget _buildTextField(TextEditingController c, String label, IconData icon, bool required) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? '請輸入$label' : null
          : null,
    );
  }

  // ======================================================
  // 狀態選單
  // ======================================================
  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _status,
      decoration: InputDecoration(
        labelText: '狀態',
        prefixIcon: const Icon(Icons.toggle_on),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: const [
        DropdownMenuItem(value: 'active', child: Text('啟用')),
        DropdownMenuItem(value: 'inactive', child: Text('停用')),
      ],
      onChanged: (v) => setState(() => _status = v ?? 'active'),
    );
  }

  // ======================================================
  // 描述欄
  // ======================================================
  Widget _buildDescField() {
    return TextFormField(
      controller: _desc,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: '廠商描述',
        alignLabelWithHint: true,
        prefixIcon: const Icon(Icons.description_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ======================================================
  // 儲存 Firestore
  // ======================================================
  Future<void> _saveVendor() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final data = {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'region': _region.text.trim(),
        'description': _desc.text.trim(),
        'status': _status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEdit && widget.vendor?['id'] != null) {
        await _db.collection('vendors').doc(widget.vendor!['id']).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await _db.collection('vendors').add(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? '廠商已更新' : '廠商已新增')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

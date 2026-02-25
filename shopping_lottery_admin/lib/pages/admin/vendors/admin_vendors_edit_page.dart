// lib/pages/admin/vendors/admin_vendors_edit_page.dart
// =====================================================
// ✅ AdminVendorsEditPage（最終完整版｜已修正 control_flow_in_finally）
// - Firestore: vendors collection
// - 支援新增 / 編輯 / 刪除
// - ✅ DropdownButtonFormField: value -> initialValue（v3.33+ deprecated 修正）
// - ✅ 使用 ValueKey 讓 initialValue 在資料載入後可正確刷新
// - ✅ finally 區塊不使用 return（修正 control_flow_in_finally）
// - ✅ async gap 後使用 context 前先 mounted 檢查
// =====================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminVendorsEditPage extends StatefulWidget {
  /// 編輯模式傳 vendorId；新增模式可為 null
  final String? vendorId;

  /// 可選：外部先帶入初始資料（例如從列表點入已拿到 doc data）
  final Map<String, dynamic>? initialData;

  const AdminVendorsEditPage({super.key, this.vendorId, this.initialData});

  @override
  State<AdminVendorsEditPage> createState() => _AdminVendorsEditPageState();
}

class _AdminVendorsEditPageState extends State<AdminVendorsEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // Dropdown (✅ 用 initialValue)
  static const _statusOptions = <String>['active', 'inactive', 'suspended'];
  String _status = 'active';

  // tags (用逗號分隔輸入)
  final _tagsCtrl = TextEditingController();

  String get _title => _isEdit ? '編輯廠商' : '新增廠商';
  bool get _isEdit => (widget.vendorId ?? '').trim().isNotEmpty;

  DocumentReference<Map<String, dynamic>> _docRef(String id) =>
      _db.collection('vendors').doc(id);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _taxIdCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountCtrl.dispose();
    _noteCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // 1) 若有 initialData 先套用（通常更快）
    if (widget.initialData != null) {
      _applyData(widget.initialData!);
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    // 2) 新增模式不需要讀取
    if (!_isEdit) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    // 3) 編輯模式讀取 Firestore
    try {
      final id = widget.vendorId!.trim();
      final snap = await _docRef(id).get();
      final data = snap.data();
      if (data != null) {
        _applyData(data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('讀取廠商資料失敗：$e')));
      }
    } finally {
      // ✅ FIX: finally 不使用 return
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _applyData(Map<String, dynamic> d) {
    _nameCtrl.text = (d['name'] ?? '').toString();
    _contactCtrl.text = (d['contactName'] ?? '').toString();
    _emailCtrl.text = (d['email'] ?? '').toString();
    _phoneCtrl.text = (d['phone'] ?? '').toString();
    _addressCtrl.text = (d['address'] ?? '').toString();
    _taxIdCtrl.text = (d['taxId'] ?? '').toString();
    _bankNameCtrl.text = (d['bankName'] ?? '').toString();
    _bankAccountCtrl.text = (d['bankAccount'] ?? '').toString();
    _noteCtrl.text = (d['adminNote'] ?? '').toString();

    final statusRaw = (d['status'] ?? 'active').toString().trim();
    _status = _statusOptions.contains(statusRaw) ? statusRaw : 'active';

    final tags = (d['tags'] is List)
        ? (d['tags'] as List).cast<String>()
        : <String>[];
    _tagsCtrl.text = tags.join(', ');
  }

  List<String> _parseTags(String raw) {
    final parts = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    final seen = <String>{};
    final out = <String>[];
    for (final t in parts) {
      if (seen.add(t)) {
        out.add(t);
      }
    }
    return out;
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final nowServer = FieldValue.serverTimestamp();
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'contactName': _contactCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'taxId': _taxIdCtrl.text.trim(),
        'bankName': _bankNameCtrl.text.trim(),
        'bankAccount': _bankAccountCtrl.text.trim(),
        'adminNote': _noteCtrl.text.trim(),
        'status': _status,
        'tags': _parseTags(_tagsCtrl.text),
        'updatedAt': nowServer,
      };

      DocumentReference<Map<String, dynamic>> ref;

      if (_isEdit) {
        ref = _docRef(widget.vendorId!.trim());
        await ref.set(data, SetOptions(merge: true));
      } else {
        ref = _db.collection('vendors').doc();
        await ref.set({
          ...data,
          'createdAt': nowServer,
        }, SetOptions(merge: true));
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_isEdit ? '已更新廠商' : '已新增廠商')));

      Navigator.pop(context, ref.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
      }
    } finally {
      // ✅ FIX: finally 不使用 return
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    if (!_isEdit || _saving) {
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除？'),
        content: Text(
          '確定要刪除廠商「${_nameCtrl.text.trim().isEmpty ? widget.vendorId : _nameCtrl.text.trim()}」嗎？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _docRef(widget.vendorId!.trim()).delete();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('廠商已刪除')));

      Navigator.pop(context, '__deleted__');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
      }
    } finally {
      // ✅ FIX: finally 不使用 return
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendorId = (widget.vendorId ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: '刪除廠商',
              onPressed: _saving ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: (_loading || _saving) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? '儲存中' : '儲存'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (_isEdit) ...[
                          _InfoTile(
                            title: 'vendorId',
                            value: vendorId,
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 12),
                        ],

                        _SectionCard(
                          title: '基本資料',
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameCtrl,
                                decoration: _dec(
                                  '廠商名稱 *',
                                  hint: '例如：Osmile 合作店',
                                ),
                                validator: (v) {
                                  if ((v ?? '').trim().isEmpty) {
                                    return '請輸入廠商名稱';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _contactCtrl,
                                decoration: _dec('聯絡人'),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _emailCtrl,
                                      decoration: _dec('Email'),
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneCtrl,
                                      decoration: _dec('電話'),
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _addressCtrl,
                                decoration: _dec('地址'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        _SectionCard(
                          title: '狀態 / 標籤',
                          child: Column(
                            children: [
                              // ✅ value deprecated → initialValue + ValueKey
                              DropdownButtonFormField<String>(
                                key: ValueKey('vendor_status_$_status'),
                                initialValue: _status,
                                items: _statusOptions
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) {
                                    return;
                                  }
                                  setState(() {
                                    _status = v;
                                  });
                                },
                                isExpanded: true,
                                decoration: _dec('狀態'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _tagsCtrl,
                                decoration: _dec(
                                  '標籤（用逗號分隔）',
                                  hint: '例如：北區, 維修, 門市',
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        _SectionCard(
                          title: '財務 / 統編（可選）',
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _taxIdCtrl,
                                decoration: _dec('統一編號'),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _bankNameCtrl,
                                      decoration: _dec('銀行名稱'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _bankAccountCtrl,
                                      decoration: _dec('銀行帳號'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        _SectionCard(
                          title: '管理備註',
                          child: TextFormField(
                            controller: _noteCtrl,
                            decoration: _dec('Admin Note'),
                            maxLines: 4,
                          ),
                        ),

                        const SizedBox(height: 24),

                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(_saving ? '儲存中' : '儲存'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(value),
      ),
    );
  }
}

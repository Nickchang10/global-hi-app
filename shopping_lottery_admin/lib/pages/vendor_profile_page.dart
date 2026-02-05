// lib/pages/vendor_profile_page.dart
//
// ✅ VendorProfilePage（完整版｜可編譯｜Vendor Only｜編輯 vendors/{vendorId}）
// 功能：
// - 讀取 vendors/{vendorId} 資料
// - 編輯並儲存：name/contactName/email/phone/address/description/logoUrl/note/isActive
// - 顯示 createdAt / updatedAt（若存在）
// - 複製 vendorId / 查看 JSON
//
// Firestore 建議：vendors/{vendorId}
//   - name: String
//   - contactName: String
//   - phone: String
//   - email: String
//   - address: String
//   - description: String
//   - logoUrl: String
//   - note: String
//   - isActive: bool
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//
// 依賴：cloud_firestore, flutter/material, flutter/services

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorProfilePage extends StatefulWidget {
  const VendorProfilePage({
    super.key,
    required this.vendorId,
  });

  final String vendorId;

  @override
  State<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends State<VendorProfilePage> {
  final _db = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;

  Map<String, dynamic> _raw = {};

  // controllers
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _isActive = true;

  String get _vid => widget.vendorId.trim();
  DocumentReference<Map<String, dynamic>> get _ref => _db.collection('vendors').doc(_vid);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    _logoUrlCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Utils
  // -------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _isTrue(dynamic v) => v == true;

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null; // email 可選
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    if (!ok) return 'Email 格式不正確';
    return null;
  }

  String? _validateUrl(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final ok = Uri.tryParse(s)?.hasAbsolutePath ?? false;
    // Uri 判斷不夠嚴格，這裡只做基本檢查
    if (!s.startsWith('http://') && !s.startsWith('https://')) return '請輸入 http/https 開頭的網址';
    if (!ok) return '網址格式不正確';
    return null;
  }

  // -------------------------
  // Data
  // -------------------------
  Future<void> _load() async {
    if (_vid.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final snap = await _ref.get();
      final d = snap.data() ?? <String, dynamic>{};

      _raw = d;

      _nameCtrl.text = _s(d['name']);
      _contactCtrl.text = _s(d['contactName']);
      _emailCtrl.text = _s(d['email']);
      _phoneCtrl.text = _s(d['phone']);
      _addressCtrl.text = _s(d['address']);
      _descCtrl.text = _s(d['description']);
      _logoUrlCtrl.text = _s(d['logoUrl']);
      _noteCtrl.text = _s(d['note']);
      _isActive = d.isEmpty ? true : _isTrue(d['isActive']);
    } catch (e) {
      _snack('載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_vid.isEmpty) {
      _snack('vendorId 不可為空');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('公司/店家名稱不可為空');
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'name': name,
        'contactName': _contactCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'logoUrl': _logoUrlCtrl.text.trim(),
        'note': _noteCtrl.text.trim(),
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 初次建立時補 createdAt（若不存在）
      final snap = await _ref.get();
      if (!snap.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      } else {
        final existing = snap.data();
        if (existing == null || !existing.containsKey('createdAt')) {
          payload['createdAt'] = FieldValue.serverTimestamp();
        }
      }

      await _ref.set(payload, SetOptions(merge: true));
      _snack('已儲存');

      // 重新載入更新 updatedAt 顯示
      await _load();
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openJsonDialog() async {
    final jsonText = const JsonEncoder.withIndent('  ').convert(_raw);
    await showDialog(
      context: context,
      builder: (_) => _JsonDialog(title: 'Vendor JSON', jsonText: jsonText),
    );
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_vid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('vendorId 不可為空')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('廠商資料', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '複製 vendorId',
            onPressed: _saving ? null : () => _copy(_vid, done: '已複製 vendorId'),
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: '查看 JSON',
            onPressed: _saving ? null : _openJsonDialog,
            icon: const Icon(Icons.code),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth >= 980;

                final left = _ProfileForm(
                  formKey: _formKey,
                  saving: _saving,
                  nameCtrl: _nameCtrl,
                  contactCtrl: _contactCtrl,
                  emailCtrl: _emailCtrl,
                  phoneCtrl: _phoneCtrl,
                  addressCtrl: _addressCtrl,
                  descCtrl: _descCtrl,
                  logoUrlCtrl: _logoUrlCtrl,
                  noteCtrl: _noteCtrl,
                  isActive: _isActive,
                  onActiveChanged: (v) => setState(() => _isActive = v),
                  validateEmail: _validateEmail,
                  validateUrl: _validateUrl,
                );

                final right = _MetaPanel(
                  raw: _raw,
                  fmt: _fmtDateTime,
                  toDate: _toDate,
                  vendorId: _vid,
                  isActive: _isActive,
                );

                final actions = Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('儲存'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                await _load();
                                _snack('已重新載入');
                              },
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新載入'),
                      ),
                    ],
                  ),
                );

                if (!isWide) {
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              left,
                              const SizedBox(height: 12),
                              right,
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      actions,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: left,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: right,
                            ),
                          ),
                          const Divider(height: 1),
                          actions,
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: _saving
          ? Material(
              color: cs.surface,
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('儲存中...', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

// ------------------------------------------------------------
// Form Widget
// ------------------------------------------------------------
class _ProfileForm extends StatelessWidget {
  const _ProfileForm({
    required this.formKey,
    required this.saving,
    required this.nameCtrl,
    required this.contactCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.descCtrl,
    required this.logoUrlCtrl,
    required this.noteCtrl,
    required this.isActive,
    required this.onActiveChanged,
    required this.validateEmail,
    required this.validateUrl,
  });

  final GlobalKey<FormState> formKey;

  final bool saving;

  final TextEditingController nameCtrl;
  final TextEditingController contactCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController descCtrl;
  final TextEditingController logoUrlCtrl;
  final TextEditingController noteCtrl;

  final bool isActive;
  final ValueChanged<bool> onActiveChanged;

  final String? Function(String?) validateEmail;
  final String? Function(String?) validateUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('基本資料', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),

              TextFormField(
                controller: nameCtrl,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: '公司/店家名稱（name）*',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return '名稱不可為空';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: contactCtrl,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: '聯絡人（contactName）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: phoneCtrl,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: '電話（phone）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: emailCtrl,
                enabled: !saving,
                validator: validateEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email（email）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: addressCtrl,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: '地址（address）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: logoUrlCtrl,
                enabled: !saving,
                validator: validateUrl,
                decoration: const InputDecoration(
                  labelText: 'LOGO 圖片網址（logoUrl）',
                  hintText: 'https://.../logo.png',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: descCtrl,
                enabled: !saving,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '簡介（description）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: noteCtrl,
                enabled: !saving,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '備註（note）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('啟用 isActive'),
                value: isActive,
                onChanged: saving ? null : onActiveChanged,
              ),

              const SizedBox(height: 6),
              Text(
                '提示：此頁直接寫入 vendors/{vendorId}，主後台若讀同集合將即時同步。',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Meta Panel
// ------------------------------------------------------------
class _MetaPanel extends StatelessWidget {
  const _MetaPanel({
    required this.raw,
    required this.fmt,
    required this.toDate,
    required this.vendorId,
    required this.isActive,
  });

  final Map<String, dynamic> raw;
  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  final String vendorId;
  final bool isActive;

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final createdAt = toDate(raw['createdAt']);
    final updatedAt = toDate(raw['updatedAt']);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('系統資訊', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),

            _InfoRow(label: 'vendorId', value: vendorId),
            const SizedBox(height: 6),
            _InfoRow(label: '狀態', value: isActive ? '啟用' : '停用'),
            const SizedBox(height: 6),
            _InfoRow(label: '建立時間', value: fmt(createdAt)),
            const SizedBox(height: 6),
            _InfoRow(label: '更新時間', value: fmt(updatedAt)),

            const SizedBox(height: 12),
            Text('原始資料（摘要）', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline.withOpacity(0.18)),
              ),
              child: Text(
                _s(raw['description']).isEmpty ? '（無簡介）' : _s(raw['description']),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 86, child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
        Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w800))),
      ],
    );
  }
}

// ------------------------------------------------------------
// JSON Dialog
// ------------------------------------------------------------
class _JsonDialog extends StatelessWidget {
  const _JsonDialog({required this.title, required this.jsonText});
  final String title;
  final String jsonText;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(
        width: 760,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
                  IconButton(
                    tooltip: '複製 JSON',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: jsonText));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製 JSON')));
                      }
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonText,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('關閉'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

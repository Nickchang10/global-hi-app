// lib/pages/address_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_mock_service.dart';

class AddressPage extends StatefulWidget {
  final bool selectMode;
  final String? selectedAddressId;

  const AddressPage({
    super.key,
    this.selectMode = false,
    this.selectedAddressId,
  });

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  static const Color _bg = Color(0xFFF6F7F9);
  static const Color _brand = Colors.blueAccent;
  static const String _prefsKey = 'osmile_addresses_v1';

  bool _loading = true;
  final List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ======================================================
  // Storage
  // ======================================================
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);

      _addresses.clear();

      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map) {
              final m = Map<String, dynamic>.from(e);
              // ensure id
              if ((m['id'] ?? '').toString().trim().isEmpty) {
                m['id'] = 'addr_${DateTime.now().millisecondsSinceEpoch}_${_addresses.length}';
              }
              // ensure isDefault
              if (m['isDefault'] != true) m['isDefault'] = false;
              _addresses.add(m);
            }
          }
        }
      }

      // seed demo if empty
      if (_addresses.isEmpty) {
        final demo = FirestoreMockService.demoAddresses()
            .map((e) => {
                  'id': 'addr_${DateTime.now().millisecondsSinceEpoch}_${e['title'] ?? ''}',
                  'title': e['title'] ?? '地址',
                  'name': e['name'] ?? '',
                  'phone': e['phone'] ?? '',
                  'fullAddress': e['fullAddress'] ?? '',
                  'isDefault': e['isDefault'] == true,
                  'createdAt': DateTime.now().toIso8601String(),
                })
            .toList();

        // ensure only one default
        bool anyDefault = demo.any((e) => e['isDefault'] == true);
        if (!anyDefault && demo.isNotEmpty) demo.first['isDefault'] = true;

        _addresses.addAll(demo);
        await _save();
      } else {
        // ensure at least one default
        if (!_addresses.any((a) => a['isDefault'] == true) && _addresses.isNotEmpty) {
          _addresses.first['isDefault'] = true;
          await _save();
        }
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_addresses));
  }

  // ======================================================
  // Helpers
  // ======================================================
  Map<String, dynamic>? _defaultAddress() {
    for (final a in _addresses) {
      if (a['isDefault'] == true) return a;
    }
    return _addresses.isEmpty ? null : _addresses.first;
  }

  void _setDefault(String id) async {
    bool changed = false;
    for (final a in _addresses) {
      final isTarget = (a['id'] ?? '').toString() == id;
      final bool next = isTarget;
      if (a['isDefault'] != next) {
        a['isDefault'] = next;
        changed = true;
      }
    }
    if (changed) {
      await _save();
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteAddress(String id) async {
    final idx = _addresses.indexWhere((a) => (a['id'] ?? '').toString() == id);
    if (idx == -1) return;

    final wasDefault = _addresses[idx]['isDefault'] == true;

    _addresses.removeAt(idx);

    // if deleted default -> set first default
    if (wasDefault && _addresses.isNotEmpty) {
      for (final a in _addresses) {
        a['isDefault'] = false;
      }
      _addresses.first['isDefault'] = true;
    }

    await _save();
    if (mounted) setState(() {});
  }

  // ======================================================
  // Editor (Add / Edit)
  // ======================================================
  Future<void> _openEditor({Map<String, dynamic>? initial}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _AddressEditorSheet(
        initial: initial,
      ),
    );

    if (!mounted || result == null) return;

    final incoming = Map<String, dynamic>.from(result);
    final incomingId = (incoming['id'] ?? '').toString();

    // normalize
    incoming['title'] = (incoming['title'] ?? '').toString().trim().isEmpty
        ? '地址'
        : incoming['title'].toString().trim();
    incoming['name'] = (incoming['name'] ?? '').toString().trim();
    incoming['phone'] = (incoming['phone'] ?? '').toString().trim();
    incoming['fullAddress'] = (incoming['fullAddress'] ?? '').toString().trim();
    incoming['isDefault'] = incoming['isDefault'] == true;

    if (incomingId.isEmpty) {
      incoming['id'] = 'addr_${DateTime.now().millisecondsSinceEpoch}_${_addresses.length}';
    }
    incoming['createdAt'] = (incoming['createdAt'] ?? DateTime.now().toIso8601String()).toString();

    // upsert
    final idx = _addresses.indexWhere((a) => (a['id'] ?? '').toString() == (incoming['id'] ?? '').toString());
    if (idx == -1) {
      _addresses.insert(0, incoming);
    } else {
      _addresses[idx] = {..._addresses[idx], ...incoming};
    }

    // default logic
    if (incoming['isDefault'] == true) {
      for (final a in _addresses) {
        a['isDefault'] = (a['id'] ?? '').toString() == (incoming['id'] ?? '').toString();
      }
    } else {
      // ensure at least one default remains
      if (!_addresses.any((a) => a['isDefault'] == true) && _addresses.isNotEmpty) {
        _addresses.first['isDefault'] = true;
      }
    }

    await _save();
    if (!mounted) return;
    setState(() {});
  }

  // ======================================================
  // Select mode
  // ======================================================
  void _selectAndPop(Map<String, dynamic> address) {
    Navigator.pop(context, Map<String, dynamic>.from(address));
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final def = _defaultAddress();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(widget.selectMode ? '選擇地址' : '我的地址',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.6,
        actions: [
          if (!widget.selectMode && _addresses.isNotEmpty)
            IconButton(
              tooltip: '重新載入',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          if (widget.selectMode && def != null)
            TextButton(
              onPressed: () => _selectAndPop(def),
              child: const Text('用預設', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新增', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _addresses.isEmpty
                ? _EmptyState(onAdd: () => _openEditor())
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
                    itemCount: _addresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final a = _addresses[i];
                      final id = (a['id'] ?? '').toString();
                      final name = (a['name'] ?? '').toString();
                      final phone = (a['phone'] ?? '').toString();
                      final full = (a['fullAddress'] ?? '').toString();
                      final isDefault = a['isDefault'] == true;

                      final selected = widget.selectMode
                          ? (widget.selectedAddressId != null &&
                              widget.selectedAddressId!.isNotEmpty &&
                              widget.selectedAddressId == id)
                          : false;

                      return _AddressCard(
                        name: name,
                        phone: phone,
                        fullAddress: full,
                        isDefault: isDefault,
                        selected: selected,
                        selectMode: widget.selectMode,
                        onTap: widget.selectMode ? () => _selectAndPop(a) : null,
                        onEdit: () => _openEditor(initial: a),
                        onSetDefault: () => _setDefault(id),
                        onDelete: () async {
                          final ok = await _confirmDelete();
                          if (ok == true) await _deleteAddress(id);
                        },
                      );
                    },
                  ),
      ),
    );
  }

  Future<bool?> _confirmDelete() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除地址', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('確定要刪除這筆地址嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// Card UI (match screenshot style)
// ======================================================
class _AddressCard extends StatelessWidget {
  final String name;
  final String phone;
  final String fullAddress;
  final bool isDefault;

  final bool selectMode;
  final bool selected;

  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.name,
    required this.phone,
    required this.fullAddress,
    required this.isDefault,
    required this.selectMode,
    required this.selected,
    this.onTap,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? Colors.blueAccent : Colors.transparent;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.5),
            color: const Color(0xFFF3F5F8), // light gray card like screenshot
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LeadingMarker(
                selected: selected,
                selectMode: selectMode,
              ),
              const SizedBox(width: 10),
              const Icon(Icons.location_on_rounded, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          name.isEmpty ? '（未填姓名）' : name,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '預設',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      phone.isEmpty ? '（未填電話）' : phone,
                      style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fullAddress.isEmpty ? '（未填地址）' : fullAddress,
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: onSetDefault,
                          icon: Icon(
                            isDefault ? Icons.verified_rounded : Icons.verified_outlined,
                            size: 18,
                            color: isDefault ? Colors.blueAccent : Colors.grey.shade700,
                          ),
                          label: Text(
                            isDefault ? '預設地址' : '設為預設',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDefault ? Colors.blueAccent : Colors.grey.shade800,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: '刪除',
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        ),
                        IconButton(
                          tooltip: '編輯',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadingMarker extends StatelessWidget {
  final bool selected;
  final bool selectMode;

  const _LeadingMarker({
    required this.selected,
    required this.selectMode,
  });

  @override
  Widget build(BuildContext context) {
    if (!selectMode) {
      // spacing placeholder (keeps alignment close to screenshot)
      return const SizedBox(width: 4, height: 4);
    }

    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.blueAccent : Colors.grey.shade400,
          width: 2,
        ),
        color: selected ? Colors.blueAccent : Colors.transparent,
      ),
      child: selected
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }
}

// ======================================================
// Empty state
// ======================================================
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_outlined, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('尚未新增地址', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text('新增收件地址以便結帳快速帶入。', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('新增地址'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// Editor Sheet
// ======================================================
class _AddressEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;

  const _AddressEditorSheet({this.initial});

  @override
  State<_AddressEditorSheet> createState() => _AddressEditorSheetState();
}

class _AddressEditorSheetState extends State<_AddressEditorSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addrCtrl;

  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;

    _titleCtrl = TextEditingController(text: (i?['title'] ?? '').toString());
    _nameCtrl = TextEditingController(text: (i?['name'] ?? '').toString());
    _phoneCtrl = TextEditingController(text: (i?['phone'] ?? '').toString());
    _addrCtrl = TextEditingController(text: (i?['fullAddress'] ?? '').toString());
    _isDefault = i?['isDefault'] == true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final full = _addrCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || full.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請填寫：姓名、電話、地址'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final out = <String, dynamic>{
      'id': (widget.initial?['id'] ?? '').toString(),
      'title': title.isEmpty ? '地址' : title,
      'name': name,
      'phone': phone,
      'fullAddress': full,
      'isDefault': _isDefault,
      'createdAt': (widget.initial?['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
    };

    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isEdit ? '編輯地址' : '新增地址',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '標籤（例如：家 / 公司，可不填）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '收件人姓名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '電話',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _addrCtrl,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: '完整地址',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
            title: const Text('設為預設地址', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(
              '結帳時會優先帶入此地址',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(isEdit ? '儲存' : '新增', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

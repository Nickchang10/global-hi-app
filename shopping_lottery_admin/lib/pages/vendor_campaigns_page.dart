// lib/pages/vendor_campaigns_page.dart
//
// ✅ VendorCampaignsPage（完整版｜可編譯）
// 功能：
// - 顯示 vendorId 自己的 campaigns
// - 搜尋、啟用/停用、CRUD
// - 與主後台 campaign 集合連動（同資料集）
//
// Firestore 結構：campaigns/{campaignId}
//   - vendorId: String
//   - title: String
//   - description: String
//   - startDate: Timestamp
//   - endDate: Timestamp
//   - isActive: bool
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//
// 依賴：cloud_firestore, flutter/material, flutter/services

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorCampaignsPage extends StatefulWidget {
  const VendorCampaignsPage({super.key, required this.vendorId});

  final String vendorId;

  @override
  State<VendorCampaignsPage> createState() => _VendorCampaignsPageState();
}

class _VendorCampaignsPageState extends State<VendorCampaignsPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _q = '';
  bool? _isActive;
  bool _busy = false;
  String _busyLabel = '';

  String get _vid => widget.vendorId.trim();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // utils
  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _isTrue(dynamic v) => v == true;
  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _snack('已複製');
  }

  Future<void> _setBusy(bool v, {String label = ''}) async {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamCampaigns() {
    Query<Map<String, dynamic>> q = _db
        .collection('campaigns')
        .where('vendorId', isEqualTo: _vid)
        .orderBy('createdAt', descending: true);
    if (_isActive != null) {
      q = q.where('isActive', isEqualTo: _isActive);
    }
    return q.snapshots();
  }

  bool _match(Map<String, dynamic> d, String id) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    final title = _s(d['title']).toLowerCase();
    final desc = _s(d['description']).toLowerCase();
    return id.toLowerCase().contains(q) || title.contains(q) || desc.contains(q);
  }

  // CRUD
  Future<void> _toggleActive(String id, bool active) async {
    await _setBusy(true, label: active ? '啟用中...' : '停用中...');
    try {
      await _db.collection('campaigns').doc(id).set({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack(active ? '已啟用' : '已停用');
    } catch (e) {
      _snack('錯誤：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除活動'),
        content: Text('確定要刪除 $id？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;
    await _setBusy(true, label: '刪除中...');
    try {
      await _db.collection('campaigns').doc(id).delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _openEditor({String? id, Map<String, dynamic>? data}) async {
    final isCreate = id == null;
    final titleCtrl = TextEditingController(text: _s(data?['title']));
    final descCtrl = TextEditingController(text: _s(data?['description']));
    final startCtrl = TextEditingController(
        text: data != null && data['startDate'] != null ? _fmt(_toDate(data['startDate'])) : '');
    final endCtrl = TextEditingController(
        text: data != null && data['endDate'] != null ? _fmt(_toDate(data['endDate'])) : '');
    bool active = data == null ? true : _isTrue(data['isActive']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text(isCreate ? '新增活動' : '編輯活動'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: '標題',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '描述',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startCtrl,
                          decoration: const InputDecoration(labelText: '開始日 (YYYY-MM-DD)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: endCtrl,
                          decoration: const InputDecoration(labelText: '結束日 (YYYY-MM-DD)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('啟用'),
                    value: active,
                    onChanged: (v) => setInner(() => active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('儲存')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    if (titleCtrl.text.trim().isEmpty) {
      _snack('標題不可為空');
      return;
    }

    await _setBusy(true, label: '儲存中...');
    try {
      final startDate = DateTime.tryParse(startCtrl.text.trim());
      final endDate = DateTime.tryParse(endCtrl.text.trim());

      final dataToSave = {
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'startDate': startDate == null ? null : Timestamp.fromDate(startDate),
        'endDate': endDate == null ? null : Timestamp.fromDate(endDate),
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isCreate) {
        await _db.collection('campaigns').add({
          ...dataToSave,
          'vendorId': _vid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _snack('已新增活動');
      } else {
        await _db.collection('campaigns').doc(id!).set(dataToSave, SetOptions(merge: true));
        _snack('已更新活動');
      }
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search),
                        hintText: '搜尋標題 / 描述',
                        border: const OutlineInputBorder(),
                        suffixIcon: _searchCtrl.text.trim().isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _q = '');
                                },
                              ),
                      ),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<bool?>(
                      value: _isActive,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        labelText: '狀態',
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('全部')),
                        DropdownMenuItem(value: true, child: Text('啟用')),
                        DropdownMenuItem(value: false, child: Text('停用')),
                      ],
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _openEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('新增活動'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _streamCampaigns(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('錯誤：${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs.where((d) => _match(d.data(), d.id)).toList();
                  if (docs.isEmpty) {
                    return Center(child: Text('目前沒有資料', style: TextStyle(color: cs.onSurfaceVariant)));
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final d = docs[i].data();
                      final id = docs[i].id;
                      final title = _s(d['title']).isEmpty ? '(未命名)' : _s(d['title']);
                      final desc = _s(d['description']);
                      final active = _isTrue(d['isActive']);
                      final start = _toDate(d['startDate']);
                      final end = _toDate(d['endDate']);

                      return ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _Pill(
                              label: active ? '啟用' : '停用',
                              color: active ? cs.primary : cs.error,
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                              Text('期間：${_fmt(start)} ~ ${_fmt(end)}',
                                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                            ],
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: _busy
                              ? null
                              : (v) async {
                                  if (v == 'edit') {
                                    await _openEditor(id: id, data: d);
                                  } else if (v == 'toggle') {
                                    await _toggleActive(id, !active);
                                  } else if (v == 'copy') {
                                    await _copy(id);
                                  } else if (v == 'delete') {
                                    await _delete(id);
                                  } else if (v == 'json') {
                                    await _viewJson('活動 JSON', d);
                                  }
                                },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('編輯')),
                            PopupMenuItem(value: 'toggle', child: Text(active ? '停用' : '啟用')),
                            const PopupMenuItem(value: 'copy', child: Text('複製 ID')),
                            const PopupMenuItem(value: 'json', child: Text('查看 JSON')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'delete', child: Text('刪除')),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        if (_busy)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BusyBar(label: _busyLabel),
          ),
      ],
    );
  }

  Future<void> _viewJson(String title, Map<String, dynamic> data) async {
    await showDialog(
      context: context,
      builder: (_) => _JsonDialog(
        title: title,
        jsonText: const JsonEncoder.withIndent('  ').convert(data),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _BusyBar extends StatelessWidget {
  const _BusyBar({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }
}

class _JsonDialog extends StatelessWidget {
  const _JsonDialog({required this.title, required this.jsonText});
  final String title;
  final String jsonText;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(
        width: 700,
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
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('已複製 JSON')));
                      }
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(jsonText, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

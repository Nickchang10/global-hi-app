// lib/pages/admin/system/system_notifications_page.dart
//
// ✅ SystemNotificationsPage（完整版｜可編譯｜已修正 DropdownButtonFormField: value → initialValue）
// ------------------------------------------------------------
// - 管理後台推播/站內通知模板（Firestore: system_notifications）
// - 建立/編輯/刪除
// - 立即預覽 payload
// - Web/桌面/手機相容
//
// ⚠️ 你原本錯誤：DropdownButtonFormField 使用 value（deprecated）
// ✅ 已全部改成 initialValue + ValueKey 讓值變動時能重建

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SystemNotificationsPage extends StatefulWidget {
  const SystemNotificationsPage({super.key});

  @override
  State<SystemNotificationsPage> createState() =>
      _SystemNotificationsPageState();
}

class _SystemNotificationsPageState extends State<SystemNotificationsPage> {
  final _db = FirebaseFirestore.instance;
  final _df = DateFormat('yyyy/MM/dd HH:mm');

  String _typeFilter = 'all'; // all/push/in_app/email/sms
  String _statusFilter = 'all'; // all/active/inactive
  String _search = '';

  static const _typeOptions = <String>['push', 'in_app', 'email', 'sms'];
  static const _typeFilterOptions = <String>[
    'all',
    'push',
    'in_app',
    'email',
    'sms',
  ];
  static const _statusOptions = <String>['active', 'inactive'];
  static const _statusFilterOptions = <String>['all', 'active', 'inactive'];

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> q = _db
        .collection('system_notifications')
        .orderBy('updatedAt', descending: true);

    if (_typeFilter != 'all') {
      q = q.where('type', isEqualTo: _typeFilter);
    }
    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }
    return q.limit(300);
  }

  bool _hit(Map<String, dynamic> d, String id) {
    final k = _search.trim().toLowerCase();
    if (k.isEmpty) return true;

    final title = (d['title'] ?? '').toString().toLowerCase();
    final body = (d['body'] ?? '').toString().toLowerCase();
    final code = (d['code'] ?? '').toString().toLowerCase();
    final type = (d['type'] ?? '').toString().toLowerCase();

    return id.toLowerCase().contains(k) ||
        title.contains(k) ||
        body.contains(k) ||
        code.contains(k) ||
        type.contains(k);
  }

  String _fmtTs(dynamic v) {
    if (v is Timestamp) return _df.format(v.toDate());
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '系統通知管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '新增',
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(),
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs
                    .where((e) => _hit(e.data(), e.id))
                    .toList(growable: false);

                if (docs.isEmpty) {
                  return const Center(child: Text('目前沒有通知模板'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _tile(docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 640;

          final search = TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋：title / body / code / id',
              isDense: true,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _search = v),
          );

          // ✅ FIX: value → initialValue + key
          final typeFilter = DropdownButtonFormField<String>(
            key: ValueKey('typeFilter_$_typeFilter'),
            initialValue: _typeFilter,
            items: _typeFilterOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _typeFilter = v ?? 'all'),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '類型',
              isDense: true,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          );

          // ✅ FIX: value → initialValue + key
          final statusFilter = DropdownButtonFormField<String>(
            key: ValueKey('statusFilter_$_statusFilter'),
            initialValue: _statusFilter,
            items: _statusFilterOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '狀態',
              isDense: true,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          );

          if (isNarrow) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: typeFilter),
                    const SizedBox(width: 10),
                    Expanded(child: statusFilter),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 10),
              SizedBox(width: 220, child: typeFilter),
              const SizedBox(width: 10),
              SizedBox(width: 220, child: statusFilter),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};

    final title = (d['title'] ?? '').toString().trim();
    final body = (d['body'] ?? '').toString().trim();
    final typeRaw = (d['type'] ?? 'push').toString().trim();
    final type = _typeOptions.contains(typeRaw) ? typeRaw : 'push';

    final statusRaw = (d['status'] ?? 'active').toString().trim();
    final status = _statusOptions.contains(statusRaw) ? statusRaw : 'active';

    final code = (d['code'] ?? '').toString().trim();
    final updatedAt = _fmtTs(d['updatedAt']);
    final createdAt = _fmtTs(d['createdAt']);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, c) {
            final isNarrow = c.maxWidth < 720;

            final head = Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? '（未命名通知）' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _pill(type),
                const SizedBox(width: 8),
                _pill(status, isStatus: true),
              ],
            );

            final desc = Text(
              body.isEmpty ? '（無內容）' : body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade700),
            );

            final meta = Text(
              'id: ${doc.id}  •  code: ${code.isEmpty ? '-' : code}\ncreated: $createdAt   updated: $updatedAt',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                height: 1.2,
              ),
            );

            final actions = Column(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _openEditor(doc: doc),
                  icon: const Icon(Icons.edit),
                  label: const Text('編輯'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _preview(doc),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('預覽'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _delete(doc),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('刪除'),
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  head,
                  const SizedBox(height: 6),
                  desc,
                  const SizedBox(height: 8),
                  meta,
                  const SizedBox(height: 10),
                  Row(children: [Expanded(child: actions)]),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      head,
                      const SizedBox(height: 6),
                      desc,
                      const SizedBox(height: 8),
                      meta,
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 220, child: actions),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pill(String text, {bool isStatus = false}) {
    final Color bg;
    final Color fg;

    if (!isStatus) {
      bg = Colors.blue.shade50;
      fg = Colors.blueGrey.shade900;
    } else {
      if (text == 'active') {
        bg = Colors.green.shade50;
        fg = Colors.green.shade900;
      } else {
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade900;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w900),
      ),
    );
  }

  // ======================================================
  // CRUD
  // ======================================================
  Future<void> _openEditor({
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final d = doc?.data() ?? <String, dynamic>{};

    final titleCtrl = TextEditingController(
      text: (d['title'] ?? '').toString(),
    );
    final bodyCtrl = TextEditingController(text: (d['body'] ?? '').toString());
    final codeCtrl = TextEditingController(text: (d['code'] ?? '').toString());

    String type = (d['type'] ?? 'push').toString();
    if (!_typeOptions.contains(type)) type = 'push';

    String status = (d['status'] ?? 'active').toString();
    if (!_statusOptions.contains(status)) status = 'active';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: Text(doc == null ? '新增通知模板' : '編輯通知模板'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: '標題'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '內容'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: '代碼（可空）'),
                    ),
                    const SizedBox(height: 10),

                    // ✅ FIX: value → initialValue + key（避免 deprecated）
                    DropdownButtonFormField<String>(
                      key: ValueKey('edit_type_$type'),
                      initialValue: type,
                      items: _typeOptions
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => type = v ?? 'push'),
                      decoration: const InputDecoration(labelText: '類型'),
                      isExpanded: true,
                    ),
                    const SizedBox(height: 10),

                    // ✅ FIX: value → initialValue + key（避免 deprecated）
                    DropdownButtonFormField<String>(
                      key: ValueKey('edit_status_$status'),
                      initialValue: status,
                      items: _statusOptions
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => status = v ?? 'active'),
                      decoration: const InputDecoration(labelText: '狀態'),
                      isExpanded: true,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check),
                label: const Text('儲存'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) {
      titleCtrl.dispose();
      bodyCtrl.dispose();
      codeCtrl.dispose();
      return;
    }

    final payload = <String, dynamic>{
      'title': titleCtrl.text.trim(),
      'body': bodyCtrl.text.trim(),
      'code': codeCtrl.text.trim(),
      'type': type,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (doc == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await _db.collection('system_notifications').add(payload);
      } else {
        await doc.reference.update(payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(doc == null ? '已新增' : '已更新')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      titleCtrl.dispose();
      bodyCtrl.dispose();
      codeCtrl.dispose();
    }
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除？'),
        content: Text('確定要刪除「${(doc.data()?['title'] ?? '').toString()}」嗎？'),
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
    if (ok != true) return;

    try {
      await doc.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  void _preview(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('通知預覽'),
        content: SelectableText(
          'id: ${doc.id}\n'
          'type: ${(d['type'] ?? '').toString()}\n'
          'status: ${(d['status'] ?? '').toString()}\n'
          'code: ${(d['code'] ?? '').toString()}\n\n'
          'title: ${(d['title'] ?? '').toString()}\n\n'
          'body:\n${(d['body'] ?? '').toString()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }
}

// lib/pages/admin/internal/admin_staff_announcements_page.dart
//
// ✅ AdminStaffAnnouncementsPage（最終完整版｜內部公告管理 + 已讀回條｜可直接使用）
// ------------------------------------------------------------
// Firestore：staff_announcements/{id}
// 子集合：staff_announcements/{id}/reads/{uid}
//
// 建議資料結構（彈性存在）：
// staff_announcements/{id} {
//   title: "系統維護公告",
//   body: "本週六 02:00–04:00 維護…",
//   status: "draft" | "published",
//   isPinned: true,
//   requireReadReceipt: true,     // 是否啟用已讀回條（可選）
//   visibleRoles: ["admin","vendor"], // 可見角色（可選；空=全部 staff）
//   readsCount: 12,               // 已讀數（可選；由 App 端交易自動累加）
//   createdAt: Timestamp,
//   updatedAt: Timestamp,
//   createdBy: "admin/uid",
//   updatedBy: "admin/uid",
// }
//
// reads/{uid} {
//   uid: "uid",
//   name: "王小明" (可選)
//   role: "admin/vendor" (可選)
//   readAt: Timestamp
// }
//
// 功能：
// - 列表：搜尋（title/body/id）
// - 篩選：狀態（all/draft/published）、置頂（all/pinned/unpinned）
// - 新增 / 編輯：Dialog
// - 批次：上架 / 下架 / 刪除
// - 已讀回條：一鍵查看 reads 子集合
//
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminStaffAnnouncementsPage extends StatefulWidget {
  const AdminStaffAnnouncementsPage({super.key});

  @override
  State<AdminStaffAnnouncementsPage> createState() =>
      _AdminStaffAnnouncementsPageState();
}

class _AdminStaffAnnouncementsPageState
    extends State<AdminStaffAnnouncementsPage> {
  final _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col =
      _db.collection('staff_announcements');

  final _searchCtl = TextEditingController();
  String _search = '';

  bool _selectionMode = false;
  final Set<String> _selected = {};

  static const _statusAll = 'all';
  static const _statusDraft = 'draft';
  static const _statusPublished = 'published';
  String _status = _statusAll;

  static const _pinAll = 'all';
  static const _pinPinned = 'pinned';
  static const _pinUnpinned = 'unpinned';
  String _pin = _pinAll;

  final _fmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    // 先取回再前端篩選，避免 where+orderBy 索引陷阱
    return _col.orderBy('updatedAt', descending: true).limit(1000).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('內部公告管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: '批次上架',
              icon: const Icon(Icons.publish_outlined),
              onPressed: _selected.isEmpty ? null : () => _batchSetStatus(_statusPublished),
            ),
            IconButton(
              tooltip: '批次下架',
              icon: const Icon(Icons.unpublished_outlined),
              onPressed: _selected.isEmpty ? null : () => _batchSetStatus(_statusDraft),
            ),
            IconButton(
              tooltip: '批次刪除',
              icon: const Icon(Icons.delete_outline),
              onPressed: _selected.isEmpty ? null : _confirmBatchDelete,
            ),
          ],
          IconButton(
            tooltip: _selectionMode ? '退出多選' : '多選模式',
            icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
            onPressed: () {
              setState(() {
                _selectionMode = !_selectionMode;
                if (!_selectionMode) _selected.clear();
              });
            },
          ),
          IconButton(
            tooltip: '新增公告',
            icon: const Icon(Icons.add),
            onPressed: _openCreate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('新增公告'),
      ),
      body: Column(
        children: [
          _filterBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    title: '載入失敗',
                    message: snap.error.toString(),
                    hint: '若出現 permission-denied，請確認 rules：/staff_announcements 允許 isAdmin() 讀寫。',
                    onRetry: () => setState(() {}),
                  );
                }

                final docs = (snap.data?.docs ?? const [])
                    .map((d) => _AnnDoc.fromDoc(d))
                    .toList();

                // 排序：置頂 → updatedAt desc
                docs.sort((a, b) {
                  final p = (b.isPinned ? 1 : 0) - (a.isPinned ? 1 : 0);
                  if (p != 0) return p;
                  final at = a.updatedAt?.millisecondsSinceEpoch ?? 0;
                  final bt = b.updatedAt?.millisecondsSinceEpoch ?? 0;
                  return bt.compareTo(at);
                });

                final filtered = _applyFilters(docs);

                return Column(
                  children: [
                    _summaryRow(filtered.length, cs),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('目前沒有符合條件的公告'))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _buildTile(filtered[i], cs),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Filters
  // ============================================================

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(builder: (context, c) {
        final narrow = c.maxWidth < 980;

        final search = TextField(
          controller: _searchCtl,
          onChanged: (v) => setState(() => _search = v.trim()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: '搜尋：標題 / 內容 / ID',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: _searchCtl.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: '清除',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _searchCtl.clear();
                        _search = '';
                      });
                    },
                  ),
          ),
        );

        final statusDD = DropdownButtonFormField<String>(
          value: _status,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: '狀態',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: const [
            DropdownMenuItem(value: _statusAll, child: Text('全部')),
            DropdownMenuItem(value: _statusDraft, child: Text('草稿')),
            DropdownMenuItem(value: _statusPublished, child: Text('已上架')),
          ],
          onChanged: (v) => setState(() => _status = v ?? _statusAll),
        );

        final pinDD = DropdownButtonFormField<String>(
          value: _pin,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: '置頂',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: const [
            DropdownMenuItem(value: _pinAll, child: Text('全部')),
            DropdownMenuItem(value: _pinPinned, child: Text('置頂')),
            DropdownMenuItem(value: _pinUnpinned, child: Text('未置頂')),
          ],
          onChanged: (v) => setState(() => _pin = v ?? _pinAll),
        );

        if (narrow) {
          return Column(
            children: [
              search,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: statusDD),
                  const SizedBox(width: 10),
                  Expanded(child: pinDD),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 5, child: search),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: statusDD),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: pinDD),
          ],
        );
      }),
    );
  }

  Widget _summaryRow(int count, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Text(
            '共 $count 筆',
            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('重新整理'),
          ),
        ],
      ),
    );
  }

  List<_AnnDoc> _applyFilters(List<_AnnDoc> input) {
    final q = _search.toLowerCase();

    return input.where((d) {
      final matchQ = q.isEmpty ||
          d.id.toLowerCase().contains(q) ||
          d.title.toLowerCase().contains(q) ||
          d.body.toLowerCase().contains(q);

      final matchStatus = _status == _statusAll || d.status == _status;

      final matchPin = _pin == _pinAll ||
          (_pin == _pinPinned && d.isPinned) ||
          (_pin == _pinUnpinned && !d.isPinned);

      return matchQ && matchStatus && matchPin;
    }).toList();
  }

  // ============================================================
  // Tile
  // ============================================================

  Widget _buildTile(_AnnDoc d, ColorScheme cs) {
    final selected = _selected.contains(d.id);
    final updated = d.updatedAt == null ? '—' : _fmt.format(d.updatedAt!);

    final readsText = d.readsCount == null ? '—' : '${d.readsCount}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: d.isPinned ? Colors.orange : cs.primaryContainer,
          child: Icon(
            d.isPinned ? Icons.push_pin : Icons.campaign_outlined,
            color: d.isPinned ? Colors.white : cs.onPrimaryContainer,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                d.title.isEmpty ? '(未填標題)' : d.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            _chip(d.status == _statusPublished ? '上架' : '草稿',
                enabled: d.status == _statusPublished),
            if (d.requireReadReceipt) ...[
              const SizedBox(width: 6),
              _chip('回條：$readsText', enabled: true),
            ],
          ],
        ),
        subtitle: Text(
          [
            '更新：$updated',
            if (d.visibleRoles.isNotEmpty) '可見角色：${d.visibleRoles.join(', ')}',
            d.body,
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _selectionMode
            ? Checkbox(
                value: selected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(d.id);
                    } else {
                      _selected.remove(d.id);
                    }
                  });
                },
              )
            : PopupMenuButton<String>(
                onSelected: (v) => _handleAction(v, d),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('編輯')),
                  const PopupMenuItem(value: 'togglePin', child: Text('切換置頂')),
                  if (d.requireReadReceipt)
                    const PopupMenuItem(value: 'reads', child: Text('查看已讀回條')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'copyId', child: Text('複製 ID')),
                  const PopupMenuItem(value: 'delete', child: Text('刪除')),
                ],
              ),
        onTap: () {
          if (_selectionMode) {
            setState(() {
              if (selected) {
                _selected.remove(d.id);
              } else {
                _selected.add(d.id);
              }
            });
            return;
          }
          _openEdit(d);
        },
        onLongPress: () {
          setState(() {
            _selectionMode = true;
            _selected.add(d.id);
          });
        },
      ),
    );
  }

  Widget _chip(String text, {required bool enabled}) {
    final bg = enabled ? Colors.green.shade100 : Colors.grey.shade200;
    final fg = enabled ? Colors.green.shade900 : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }

  // ============================================================
  // Actions
  // ============================================================

  Future<void> _handleAction(String v, _AnnDoc d) async {
    switch (v) {
      case 'edit':
        await _openEdit(d);
        break;
      case 'togglePin':
        await _col.doc(d.id).set(
          {
            'isPinned': !d.isPinned,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': 'admin',
          },
          SetOptions(merge: true),
        );
        break;
      case 'reads':
        await _openReadsDialog(d.id);
        break;
      case 'copyId':
        await Clipboard.setData(ClipboardData(text: d.id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製 ID')));
        }
        break;
      case 'delete':
        await _confirmDeleteOne(d.id);
        break;
    }
  }

  Future<void> _openCreate() async {
    await _openEditor(_AnnDoc.empty(), isCreate: true);
  }

  Future<void> _openEdit(_AnnDoc d) async {
    await _openEditor(d, isCreate: false);
  }

  Future<void> _openEditor(_AnnDoc d, {required bool isCreate}) async {
    final result = await showDialog<_EditResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditorDialog(initial: d),
    );
    if (result == null) return;

    try {
      final payload = <String, dynamic>{
        ...result.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      };

      if (isCreate) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['createdBy'] = 'admin';
        final ref = _col.doc(); // auto id
        await ref.set(payload, SetOptions(merge: true));
      } else {
        await _col.doc(d.id).set(payload, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isCreate ? '已新增公告' : '已更新公告')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
      }
    }
  }

  Future<void> _batchSetStatus(String status) async {
    final ok = await _confirm(
      title: '批次更新狀態',
      message: '共選取 ${_selected.length} 筆，確定要更新為「${status == _statusPublished ? '上架' : '草稿'}」？',
      confirmText: '確認',
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.set(
        _col.doc(id),
        {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': 'admin',
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    if (!mounted) return;
    setState(() => _selected.clear());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已批次更新狀態')));
  }

  Future<void> _confirmBatchDelete() async {
    final ok = await _confirm(
      title: '批次刪除',
      message: '共選取 ${_selected.length} 筆，刪除後無法復原。',
      confirmText: '刪除',
      isDanger: true,
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.delete(_col.doc(id));
    }
    await batch.commit();

    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除選取公告')));
  }

  Future<void> _confirmDeleteOne(String id) async {
    final ok = await _confirm(
      title: '刪除公告',
      message: '確定要刪除這則公告嗎？\nID: $id',
      confirmText: '刪除',
      isDanger: true,
    );
    if (ok != true) return;

    await _col.doc(id).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除')));
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool isDanger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDanger ? cs.error : null,
              foregroundColor: isDanger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ Reads Dialog (已讀回條)
  // ============================================================

  Future<void> _openReadsDialog(String annId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ReadsDialog(annId: annId),
    );
  }
}

// ============================================================
// Editor Dialog
// ============================================================

class _EditorDialog extends StatefulWidget {
  final _AnnDoc initial;
  const _EditorDialog({required this.initial});

  @override
  State<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<_EditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _roles; // comma-separated

  late String _status;
  late bool _isPinned;
  late bool _requireReadReceipt;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _title = TextEditingController(text: d.title);
    _body = TextEditingController(text: d.body);
    _roles = TextEditingController(text: d.visibleRoles.join(','));
    _status = d.status.isEmpty ? 'draft' : d.status;
    _isPinned = d.isPinned;
    _requireReadReceipt = d.requireReadReceipt;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _roles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('公告編輯', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: '標題（title）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _body,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: '內容（body）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '狀態（status）',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('草稿')),
                        DropdownMenuItem(value: 'published', child: Text('已上架')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'draft'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('置頂（isPinned）',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      value: _isPinned,
                      onChanged: (v) => setState(() => _isPinned = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('啟用已讀回條（requireReadReceipt）',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        _requireReadReceipt ? '會寫入 reads 子集合 + readsCount' : '不追蹤已讀',
                        style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                      ),
                      value: _requireReadReceipt,
                      onChanged: (v) => setState(() => _requireReadReceipt = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _roles,
                decoration: const InputDecoration(
                  labelText: '可見角色（visibleRoles，逗號分隔；空白=全部 staff）',
                  border: OutlineInputBorder(),
                  hintText: '例如：admin,vendor,super_admin',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('儲存'),
        ),
      ],
    );
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請填寫標題')));
      return;
    }

    final roles = _roles.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    Navigator.pop(
      context,
      _EditResult(
        title: title,
        body: _body.text.trim(),
        status: _status,
        isPinned: _isPinned,
        requireReadReceipt: _requireReadReceipt,
        visibleRoles: roles,
      ),
    );
  }
}

class _EditResult {
  final String title;
  final String body;
  final String status;
  final bool isPinned;
  final bool requireReadReceipt;
  final List<String> visibleRoles;

  _EditResult({
    required this.title,
    required this.body,
    required this.status,
    required this.isPinned,
    required this.requireReadReceipt,
    required this.visibleRoles,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'status': status,
        'isPinned': isPinned,
        'requireReadReceipt': requireReadReceipt,
        'visibleRoles': visibleRoles,
      };
}

// ============================================================
// Reads Dialog
// ============================================================

class _ReadsDialog extends StatefulWidget {
  final String annId;
  const _ReadsDialog({required this.annId});

  @override
  State<_ReadsDialog> createState() => _ReadsDialogState();
}

class _ReadsDialogState extends State<_ReadsDialog> {
  final _db = FirebaseFirestore.instance;
  final _fmt = DateFormat('yyyy/MM/dd HH:mm');

  String _q = '';
  final _qCtl = TextEditingController();

  @override
  void dispose() {
    _qCtl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return _db
        .collection('staff_announcements')
        .doc(widget.annId)
        .collection('reads')
        .orderBy('readAt', descending: true)
        .limit(2000)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('已讀回條：${widget.annId}',
          style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _qCtl,
              onChanged: (v) => setState(() => _q = v.trim()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋：uid / name / role',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _qCtl.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _qCtl.clear();
                          _q = '';
                        }),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _stream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('載入失敗：${snap.error}'));
                  }

                  final docs = (snap.data?.docs ?? const [])
                      .map((d) => _ReadDoc.fromDoc(d))
                      .toList();

                  final q = _q.toLowerCase();
                  final filtered = q.isEmpty
                      ? docs
                      : docs.where((d) {
                          final hay = '${d.uid} ${d.name} ${d.role}'.toLowerCase();
                          return hay.contains(q);
                        }).toList();

                  return Column(
                    children: [
                      Row(
                        children: [
                          Text('共 ${filtered.length} 筆',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: filtered.isEmpty
                                ? null
                                : () async {
                                    final lines = filtered.map((e) {
                                      final t = e.readAt == null ? '' : _fmt.format(e.readAt!);
                                      return '${e.uid}\t${e.name}\t${e.role}\t$t';
                                    }).join('\n');
                                    await Clipboard.setData(ClipboardData(text: lines));
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('已複製回條名單（tsv）')),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('複製名單'),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('尚無已讀回條'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final d = filtered[i];
                                  final t = d.readAt == null ? '—' : _fmt.format(d.readAt!);
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: cs.primaryContainer,
                                      child: Icon(Icons.person, color: cs.onPrimaryContainer),
                                    ),
                                    title: Text(
                                      d.name.isEmpty ? d.uid : d.name,
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                    subtitle: Text('uid: ${d.uid}  •  role: ${d.role.isEmpty ? '—' : d.role}  •  $t'),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
      ],
    );
  }
}

class _ReadDoc {
  final String uid;
  final String name;
  final String role;
  final DateTime? readAt;

  const _ReadDoc({
    required this.uid,
    required this.name,
    required this.role,
    required this.readAt,
  });

  factory _ReadDoc.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _ReadDoc(
      uid: (d['uid'] ?? doc.id).toString(),
      name: (d['name'] ?? '').toString(),
      role: (d['role'] ?? '').toString(),
      readAt: _toDateTime(d['readAt']),
    );
  }
}

// ============================================================
// Model
// ============================================================

class _AnnDoc {
  final String id;
  final String title;
  final String body;
  final String status;
  final bool isPinned;
  final bool requireReadReceipt;
  final List<String> visibleRoles;
  final int? readsCount;
  final DateTime? updatedAt;

  const _AnnDoc({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    required this.isPinned,
    required this.requireReadReceipt,
    required this.visibleRoles,
    required this.readsCount,
    required this.updatedAt,
  });

  factory _AnnDoc.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final roles = (d['visibleRoles'] is List)
        ? (d['visibleRoles'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final rc = d['readsCount'];
    final readsCount = rc is int ? rc : (rc is num ? rc.toInt() : null);

    return _AnnDoc(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      body: (d['body'] ?? '').toString(),
      status: (d['status'] ?? 'draft').toString(),
      isPinned: d['isPinned'] == true,
      requireReadReceipt: d['requireReadReceipt'] == true,
      visibleRoles: roles,
      readsCount: readsCount,
      updatedAt: _toDateTime(d['updatedAt']),
    );
  }

  factory _AnnDoc.empty() => const _AnnDoc(
        id: '',
        title: '',
        body: '',
        status: 'draft',
        isPinned: false,
        requireReadReceipt: false,
        visibleRoles: <String>[],
        readsCount: null,
        updatedAt: null,
      );
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

// ============================================================
// Error View
// ============================================================

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
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

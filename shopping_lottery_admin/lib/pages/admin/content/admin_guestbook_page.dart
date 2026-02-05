// lib/pages/admin/content/admin_guestbook_page.dart
//
// ✅ AdminGuestbookPage（內容管理｜留言板審核｜A. 基礎專業版｜單檔完整版｜可編譯）
// ------------------------------------------------------------
// Firestore：guestbook 集合
//
// 功能：
// 1) 列表：搜尋 / 狀態篩選（new/approved/rejected）/ 置頂篩選
// 2) 審核：通過 / 駁回（寫回 status）
// 3) 置頂：isPinned
// 4) 多選批次：通過 / 駁回 / 置頂 / 取消置頂 / 刪除
// 5) 詳情視窗：顯示留言內容、聯絡資訊、裝置資訊（若有）、建立/更新時間
// 6) 欄位容錯：Map 轉型、Timestamp → DateTime、缺欄位不崩潰
//
// 建議資料結構：guestbook/{id}
// {
//   status: "new" | "approved" | "rejected",
//   isPinned: false,
//   name: "王小明",
//   phone: "09xx",
//   email: "xx@xx.com",
//   message: "留言內容...",
//   source: "app" | "web" | "line" | ... (可選)
//   deviceId: "xxx" (可選)
//   userId: "uid" (可選)
//   vendorId: "vid" (可選)
//   note: "後台備註" (可選)
//   createdAt: Timestamp,
//   updatedAt: Timestamp,
//   updatedBy: "admin"
// }
//
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminGuestbookPage extends StatefulWidget {
  const AdminGuestbookPage({super.key});

  @override
  State<AdminGuestbookPage> createState() => _AdminGuestbookPageState();
}

class _AdminGuestbookPageState extends State<AdminGuestbookPage> {
  final _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col = _db.collection('guestbook');

  final _search = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selected = {};

  static const String _statusAll = 'all';
  static const String _statusNew = 'new';
  static const String _statusApproved = 'approved';
  static const String _statusRejected = 'rejected';
  String _status = _statusAll;

  static const String _pinAll = 'all';
  static const String _pinPinned = 'pinned';
  static const String _pinNormal = 'normal';
  String _pin = _pinAll;

  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    // ✅ 不做 where/orderBy：避免缺欄位導致查詢失敗；後台用 client-side filter
    return _col.limit(1000).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('內容管理：留言板審核', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: '批次通過',
              icon: const Icon(Icons.verified_outlined),
              onPressed: _selected.isEmpty ? null : () => _batchSetStatus(_statusApproved),
            ),
            IconButton(
              tooltip: '批次駁回',
              icon: const Icon(Icons.block_outlined),
              onPressed: _selected.isEmpty ? null : () => _batchSetStatus(_statusRejected),
            ),
            IconButton(
              tooltip: '批次置頂',
              icon: const Icon(Icons.push_pin),
              onPressed: _selected.isEmpty ? null : () => _batchSetPinned(true),
            ),
            IconButton(
              tooltip: '取消置頂',
              icon: const Icon(Icons.push_pin_outlined),
              onPressed: _selected.isEmpty ? null : () => _batchSetPinned(false),
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
        ],
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
                    onRetry: () => setState(() {}),
                    hint: '請確認 Firestore rules：guestbook 允許 admin 讀寫。',
                  );
                }

                final docs = (snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map((d) => _GuestbookDoc.fromDoc(d))
                    .toList();

                // ✅ 排序：置頂優先 -> updatedAt/createdAt desc
                docs.sort((a, b) {
                  if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
                  final at = (a.updatedAt ?? a.createdAt)?.millisecondsSinceEpoch ?? 0;
                  final bt = (b.updatedAt ?? b.createdAt)?.millisecondsSinceEpoch ?? 0;
                  return bt.compareTo(at);
                });

                final filtered = _applyFilters(docs);

                return Column(
                  children: [
                    _summaryRow(count: filtered.length, cs: cs),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('沒有符合條件的留言'))
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) => _buildTile(filtered[i]),
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
  // Filter UI
  // ============================================================

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 900;

          final searchField = TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋（姓名 / 電話 / Email / 內容 / userId / deviceId / id）',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          final statusDD = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _status,
            decoration: InputDecoration(
              isDense: true,
              labelText: '狀態',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: _statusAll, child: Text('全部')),
              DropdownMenuItem(value: _statusNew, child: Text('待審核')),
              DropdownMenuItem(value: _statusApproved, child: Text('已通過')),
              DropdownMenuItem(value: _statusRejected, child: Text('已駁回')),
            ],
            onChanged: (v) => setState(() => _status = v ?? _statusAll),
          );

          final pinDD = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _pin,
            decoration: InputDecoration(
              isDense: true,
              labelText: '置頂',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: _pinAll, child: Text('全部')),
              DropdownMenuItem(value: _pinPinned, child: Text('置頂')),
              DropdownMenuItem(value: _pinNormal, child: Text('一般')),
            ],
            onChanged: (v) => setState(() => _pin = v ?? _pinAll),
          );

          final clearBtn = TextButton(
            onPressed: () {
              setState(() {
                _search.clear();
                _status = _statusAll;
                _pin = _pinAll;
              });
            },
            child: const Text('清除篩選'),
          );

          if (narrow) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: statusDD),
                    const SizedBox(width: 10),
                    Expanded(child: pinDD),
                    const SizedBox(width: 6),
                    clearBtn,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 4, child: searchField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: statusDD),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: pinDD),
              const SizedBox(width: 6),
              clearBtn,
            ],
          );
        },
      ),
    );
  }

  Widget _summaryRow({required int count, required ColorScheme cs}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Text('共 $count 筆', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
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

  List<_GuestbookDoc> _applyFilters(List<_GuestbookDoc> input) {
    final q = _search.text.trim().toLowerCase();

    return input.where((d) {
      final matchQ = q.isEmpty ||
          d.id.toLowerCase().contains(q) ||
          d.name.toLowerCase().contains(q) ||
          d.phone.toLowerCase().contains(q) ||
          d.email.toLowerCase().contains(q) ||
          d.message.toLowerCase().contains(q) ||
          d.userId.toLowerCase().contains(q) ||
          d.deviceId.toLowerCase().contains(q);

      final matchStatus = switch (_status) {
        _statusAll => true,
        _statusNew => d.status == _statusNew,
        _statusApproved => d.status == _statusApproved,
        _statusRejected => d.status == _statusRejected,
        _ => true,
      };

      final matchPin = switch (_pin) {
        _pinAll => true,
        _pinPinned => d.isPinned,
        _pinNormal => !d.isPinned,
        _ => true,
      };

      return matchQ && matchStatus && matchPin;
    }).toList();
  }

  // ============================================================
  // Tile
  // ============================================================

  Widget _buildTile(_GuestbookDoc d) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selected.contains(d.id);

    final t = d.updatedAt ?? d.createdAt;
    final timeText = t == null ? '—' : _dtFmt.format(t);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: d.isPinned ? cs.primaryContainer : Colors.grey.shade200,
          child: Icon(
            d.isPinned ? Icons.push_pin_outlined : Icons.chat_bubble_outline,
            color: d.isPinned ? cs.onPrimaryContainer : Colors.grey.shade600,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                d.name.isEmpty ? '(未填姓名)' : d.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            if (d.isPinned) _pill('置頂', enabled: true),
            const SizedBox(width: 6),
            _pill(_statusText(d.status), enabled: d.status == _statusApproved),
          ],
        ),
        subtitle: Text(
          [
            if (d.phone.isNotEmpty) '電話：${d.phone}',
            if (d.email.isNotEmpty) 'Email：${d.email}',
            if (d.source.isNotEmpty) '來源：${d.source}',
            '時間：$timeText',
            d.message.isEmpty ? '' : d.message,
          ].where((e) => e.isNotEmpty).join('  •  '),
          maxLines: 2,
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
            : SizedBox(
                width: 240,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: '通過',
                      icon: const Icon(Icons.verified_outlined),
                      onPressed: d.status == _statusApproved ? null : () => _setStatus(d.id, _statusApproved),
                    ),
                    IconButton(
                      tooltip: '駁回',
                      icon: const Icon(Icons.block_outlined),
                      onPressed: d.status == _statusRejected ? null : () => _setStatus(d.id, _statusRejected),
                    ),
                    IconButton(
                      tooltip: d.isPinned ? '取消置頂' : '置頂',
                      icon: Icon(d.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                      onPressed: () => _setPinned(d.id, !d.isPinned),
                    ),
                    IconButton(
                      tooltip: '詳情',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openDetail(d),
                    ),
                  ],
                ),
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
          _openDetail(d);
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

  Widget _pill(String text, {bool enabled = true}) {
    final cs = Theme.of(context).colorScheme;
    final bg = enabled ? Colors.green.shade100 : Colors.grey.shade200;
    final fg = enabled ? Colors.green.shade900 : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
    );
  }

  String _statusText(String s) {
    return switch (s) {
      _statusNew => '待審核',
      _statusApproved => '已通過',
      _statusRejected => '已駁回',
      _ => s.isEmpty ? '—' : s,
    };
  }

  // ============================================================
  // Detail
  // ============================================================

  Future<void> _openDetail(_GuestbookDoc d) async {
    await showDialog(
      context: context,
      builder: (_) => _GuestbookDetailDialog(
        doc: d,
        dtFmt: _dtFmt,
        onCopy: _copyText,
        onSetStatus: (s) => _setStatus(d.id, s),
        onTogglePinned: () => _setPinned(d.id, !d.isPinned),
        onDelete: () => _confirmDeleteOne(d.id),
        onSaveNote: (note) => _saveNote(d.id, note),
      ),
    );
  }

  Future<void> _saveNote(String id, String note) async {
    try {
      await _col.doc(id).set(
        {'note': note.trim(), 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': 'admin'},
        SetOptions(merge: true),
      );
      _toast('已更新備註');
    } catch (e) {
      _toast('更新失敗：$e');
    }
  }

  // ============================================================
  // Single actions
  // ============================================================

  Future<void> _setStatus(String id, String status) async {
    try {
      await _col.doc(id).set(
        {'status': status, 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': 'admin'},
        SetOptions(merge: true),
      );
      _toast('已更新狀態：${_statusText(status)}');
    } catch (e) {
      _toast('更新失敗：$e');
    }
  }

  Future<void> _setPinned(String id, bool pinned) async {
    try {
      await _col.doc(id).set(
        {'isPinned': pinned, 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': 'admin'},
        SetOptions(merge: true),
      );
      _toast(pinned ? '已置頂' : '已取消置頂');
    } catch (e) {
      _toast('更新失敗：$e');
    }
  }

  // ============================================================
  // Batch operations
  // ============================================================

  Future<void> _batchSetStatus(String status) async {
    final ok = await _confirm(
      title: status == _statusApproved ? '批次通過' : '批次駁回',
      message: '共選取 ${_selected.length} 筆，確定要${status == _statusApproved ? '通過' : '駁回'}？',
      confirmText: '確認',
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.set(
        _col.doc(id),
        {'status': status, 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': 'admin'},
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    if (!mounted) return;
    setState(() => _selected.clear());
    _toast('已批次更新狀態');
  }

  Future<void> _batchSetPinned(bool pinned) async {
    final ok = await _confirm(
      title: pinned ? '批次置頂' : '取消置頂',
      message: '共選取 ${_selected.length} 筆，確定要${pinned ? '置頂' : '取消置頂'}？',
      confirmText: '確認',
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.set(
        _col.doc(id),
        {'isPinned': pinned, 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': 'admin'},
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    if (!mounted) return;
    setState(() => _selected.clear());
    _toast('已批次更新置頂');
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
    _toast('已刪除選取留言');
  }

  Future<void> _confirmDeleteOne(String id) async {
    final ok = await _confirm(
      title: '刪除留言',
      message: '確定要刪除這則留言嗎？\nID: $id',
      confirmText: '刪除',
      isDanger: true,
    );
    if (ok != true) return;

    await _col.doc(id).delete();
    if (!mounted) return;
    _toast('已刪除');
  }

  // ============================================================
  // Helpers
  // ============================================================

  Future<void> _copyText(String text) async {
    final v = text.trim();
    if (v.isEmpty) {
      _toast('無可複製內容');
      return;
    }
    await Clipboard.setData(ClipboardData(text: v));
    _toast('已複製');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
}

// ============================================================
// Detail Dialog
// ============================================================

class _GuestbookDetailDialog extends StatefulWidget {
  final _GuestbookDoc doc;
  final DateFormat dtFmt;

  final Future<void> Function(String text) onCopy;
  final Future<void> Function(String status) onSetStatus;
  final Future<void> Function() onTogglePinned;
  final Future<void> Function() onDelete;
  final Future<void> Function(String note) onSaveNote;

  const _GuestbookDetailDialog({
    required this.doc,
    required this.dtFmt,
    required this.onCopy,
    required this.onSetStatus,
    required this.onTogglePinned,
    required this.onDelete,
    required this.onSaveNote,
  });

  @override
  State<_GuestbookDetailDialog> createState() => _GuestbookDetailDialogState();
}

class _GuestbookDetailDialogState extends State<_GuestbookDetailDialog> {
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.doc.note);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = widget.doc;

    final created = d.createdAt == null ? '—' : widget.dtFmt.format(d.createdAt!);
    final updated = d.updatedAt == null ? '—' : widget.dtFmt.format(d.updatedAt!);

    return AlertDialog(
      title: Text('留言詳情', style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('ID', d.id, onCopy: widget.onCopy),
              _kv('狀態', d.status),
              _kv('置頂', d.isPinned ? '是' : '否'),
              _kv('姓名', d.name),
              _kv('電話', d.phone, onCopy: widget.onCopy),
              _kv('Email', d.email, onCopy: widget.onCopy),
              _kv('來源', d.source),
              _kv('userId', d.userId, onCopy: widget.onCopy),
              _kv('deviceId', d.deviceId, onCopy: widget.onCopy),
              _kv('建立時間', created),
              _kv('更新時間', updated),
              const Divider(height: 22),
              Text('留言內容', style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(d.message.isEmpty ? '（空）' : d.message),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '後台備註（不影響前台）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    await widget.onSaveNote(_note.text);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已儲存備註')));
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('儲存備註'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            await widget.onDelete();
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('刪除'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
        FilledButton.tonalIcon(
          onPressed: () async {
            Navigator.pop(context);
            await widget.onTogglePinned();
          },
          icon: Icon(d.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
          label: Text(d.isPinned ? '取消置頂' : '置頂'),
        ),
        FilledButton.tonalIcon(
          onPressed: d.status == 'approved'
              ? null
              : () async {
                  Navigator.pop(context);
                  await widget.onSetStatus('approved');
                },
          icon: const Icon(Icons.verified_outlined),
          label: const Text('通過'),
        ),
        FilledButton.tonalIcon(
          onPressed: d.status == 'rejected'
              ? null
              : () async {
                  Navigator.pop(context);
                  await widget.onSetStatus('rejected');
                },
          icon: const Icon(Icons.block_outlined),
          label: const Text('駁回'),
        ),
      ],
    );
  }

  Widget _kv(String k, String v, {Future<void> Function(String text)? onCopy}) {
    final cs = Theme.of(context).colorScheme;
    final value = v.trim().isEmpty ? '—' : v.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(k, style: TextStyle(color: cs.onSurfaceVariant))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (onCopy != null && value != '—')
            IconButton(
              tooltip: '複製',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => onCopy(value),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Model + Utils
// ============================================================

class _GuestbookDoc {
  final String id;
  final Map<String, dynamic> raw;

  final String status;
  final bool isPinned;

  final String name;
  final String phone;
  final String email;
  final String message;

  final String source;
  final String deviceId;
  final String userId;

  final String note;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  _GuestbookDoc({
    required this.id,
    required this.raw,
    required this.status,
    required this.isPinned,
    required this.name,
    required this.phone,
    required this.email,
    required this.message,
    required this.source,
    required this.deviceId,
    required this.userId,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _GuestbookDoc.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _GuestbookDoc(
      id: doc.id,
      raw: d,
      status: (d['status'] ?? 'new').toString(),
      isPinned: d['isPinned'] == true,
      name: (d['name'] ?? '').toString(),
      phone: (d['phone'] ?? '').toString(),
      email: (d['email'] ?? '').toString(),
      message: (d['message'] ?? '').toString(),
      source: (d['source'] ?? '').toString(),
      deviceId: (d['deviceId'] ?? '').toString(),
      userId: (d['userId'] ?? '').toString(),
      note: (d['note'] ?? '').toString(),
      createdAt: _toDateTime(d['createdAt']),
      updatedAt: _toDateTime(d['updatedAt']),
    );
  }
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
  final VoidCallback onRetry;
  final String? hint;

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

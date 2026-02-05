// lib/pages/admin/content/admin_news_page.dart
//
// ✅ AdminNewsPage（內容管理｜最新消息｜A. 基礎專業版｜單檔完整版｜可編譯）
// ------------------------------------------------------------
// Firestore：news 集合（你 rules 內已存在 match /news/{nid}）
//
// 建議資料結構：news/{id}
// {
//   title: "最新消息標題",
//   summary: "摘要（可選）",
//   body: "內文（純文字或 Markdown）",
//   coverImageUrl: "https://...（可選）",
//   tags: ["活動","公告"],   // 可選
//   status: "draft" | "published",
//   isPublic: true,
//   pinned: false,
//   publishedAt: Timestamp,   // 上架時間（可選）
//   updatedAt: Timestamp,
//   updatedBy: "uid/admin"
// }
//
// 功能：
// - 列表：搜尋（title/summary/body/tag）
// - 篩選：狀態 / 公開 / 置頂
// - 新增/編輯：Dialog（含封面圖 URL）
// - 批次：多選批次上架/下架/刪除、批次置頂/取消置頂
// - 排序：pinned desc、publishedAt desc、updatedAt desc
//
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminNewsPage extends StatefulWidget {
  const AdminNewsPage({super.key});

  @override
  State<AdminNewsPage> createState() => _AdminNewsPageState();
}

class _AdminNewsPageState extends State<AdminNewsPage> {
  final _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col =
      _db.collection('news');

  final _search = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selected = {};

  // filters
  static const String _statusAll = 'all';
  static const String _statusDraft = 'draft';
  static const String _statusPublished = 'published';
  String _status = _statusAll;

  static const String _pubAll = 'all';
  static const String _pubPublic = 'public';
  static const String _pubPrivate = 'private';
  String _pub = _pubAll;

  static const String _pinAll = 'all';
  static const String _pinPinned = 'pinned';
  static const String _pinNotPinned = 'not_pinned';
  String _pin = _pinAll;

  final _dtFmt = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    // 先不在 query 端 where（避免索引不足），改成 client-side filter
    return _col.limit(1000).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('內容管理：最新消息（news）',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: '批次上架',
              icon: const Icon(Icons.publish_outlined),
              onPressed:
                  _selected.isEmpty ? null : () => _batchSetStatus(_statusPublished),
            ),
            IconButton(
              tooltip: '批次下架（草稿）',
              icon: const Icon(Icons.unpublished_outlined),
              onPressed:
                  _selected.isEmpty ? null : () => _batchSetStatus(_statusDraft),
            ),
            IconButton(
              tooltip: '批次置頂',
              icon: const Icon(Icons.push_pin_outlined),
              onPressed: _selected.isEmpty ? null : () => _batchSetPinned(true),
            ),
            IconButton(
              tooltip: '取消置頂',
              icon: const Icon(Icons.push_pin),
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
          IconButton(
            tooltip: '新增消息',
            icon: const Icon(Icons.add),
            onPressed: _openCreate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('新增消息'),
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
                    hint: '請確認 Firestore rules：news 允許 admin 讀寫。',
                  );
                }

                final docs = (snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map((d) => _NewsDoc.fromDoc(d))
                    .toList();

                // ✅ pinned desc、publishedAt desc、updatedAt desc
                docs.sort((a, b) {
                  final pin = (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0);
                  if (pin != 0) return pin;

                  final pa = (a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .millisecondsSinceEpoch;
                  final pb = (b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .millisecondsSinceEpoch;
                  final pubCmp = pb.compareTo(pa);
                  if (pubCmp != 0) return pubCmp;

                  final ua = (a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .millisecondsSinceEpoch;
                  final ub = (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .millisecondsSinceEpoch;
                  return ub.compareTo(ua);
                });

                final filtered = _applyFilters(docs);

                return Column(
                  children: [
                    _summaryRow(count: filtered.length, cs: cs),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('沒有符合條件的最新消息'))
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 90),
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
  // Filters UI
  // ============================================================

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 1100;

          final searchField = TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋（title / summary / body / tag）',
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
              DropdownMenuItem(value: _statusDraft, child: Text('草稿')),
              DropdownMenuItem(value: _statusPublished, child: Text('已上架')),
            ],
            onChanged: (v) => setState(() => _status = v ?? _statusAll),
          );

          final pubDD = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _pub,
            decoration: InputDecoration(
              isDense: true,
              labelText: '公開',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: _pubAll, child: Text('全部')),
              DropdownMenuItem(value: _pubPublic, child: Text('公開')),
              DropdownMenuItem(value: _pubPrivate, child: Text('不公開')),
            ],
            onChanged: (v) => setState(() => _pub = v ?? _pubAll),
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
              DropdownMenuItem(value: _pinNotPinned, child: Text('非置頂')),
            ],
            onChanged: (v) => setState(() => _pin = v ?? _pinAll),
          );

          final clearBtn = TextButton(
            onPressed: () {
              setState(() {
                _search.clear();
                _status = _statusAll;
                _pub = _pubAll;
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
                    Expanded(child: pubDD),
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
              Expanded(flex: 5, child: searchField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: statusDD),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: pubDD),
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
          Text('共 $count 筆',
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
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

  List<_NewsDoc> _applyFilters(List<_NewsDoc> input) {
    final q = _search.text.trim().toLowerCase();

    return input.where((d) {
      final matchQ = q.isEmpty ||
          d.id.toLowerCase().contains(q) ||
          d.title.toLowerCase().contains(q) ||
          d.summary.toLowerCase().contains(q) ||
          d.body.toLowerCase().contains(q) ||
          d.tags.any((t) => t.toLowerCase().contains(q));

      final matchStatus = switch (_status) {
        _statusAll => true,
        _statusDraft => d.status == _statusDraft,
        _statusPublished => d.status == _statusPublished,
        _ => true,
      };

      final matchPub = switch (_pub) {
        _pubAll => true,
        _pubPublic => d.isPublic,
        _pubPrivate => !d.isPublic,
        _ => true,
      };

      final matchPin = switch (_pin) {
        _pinAll => true,
        _pinPinned => d.pinned,
        _pinNotPinned => !d.pinned,
        _ => true,
      };

      return matchQ && matchStatus && matchPub && matchPin;
    }).toList();
  }

  // ============================================================
  // Tile
  // ============================================================

  Widget _buildTile(_NewsDoc d) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selected.contains(d.id);

    final pubText = d.publishedAt == null ? '—' : _dtFmt.format(d.publishedAt!);
    final updText = d.updatedAt == null ? '—' : _dtFmt.format(d.updatedAt!);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        leading: _cover(d.coverImageUrl),
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
            if (d.pinned) _pill('置頂', enabled: true),
            const SizedBox(width: 6),
            _pill(d.status == _statusPublished ? '上架' : '草稿',
                enabled: d.status == _statusPublished),
            const SizedBox(width: 6),
            _pill(d.isPublic ? '公開' : '不公開', enabled: d.isPublic),
          ],
        ),
        subtitle: Text(
          [
            if (d.summary.isNotEmpty) d.summary,
            '上架：$pubText',
            '更新：$updText',
            if (d.tags.isNotEmpty) '標籤：${d.tags.take(3).join(', ')}${d.tags.length > 3 ? '…' : ''}',
          ].join('  •  '),
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
            : SizedBox(
                width: 260,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: d.pinned ? '取消置頂' : '置頂',
                      icon: Icon(d.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                      onPressed: () => _setPinned(d.id, !d.pinned),
                    ),
                    IconButton(
                      tooltip: '複製 ID',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => _copy(d.id),
                    ),
                    IconButton(
                      tooltip: '編輯',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openEdit(d),
                    ),
                    IconButton(
                      tooltip: '刪除',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDeleteOne(d.id),
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

  Widget _cover(String? url) {
    final bg = Colors.grey.shade200;
    if (url == null || url.trim().isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.image_not_supported),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url.trim(),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 56,
          height: 56,
          color: bg,
          child: const Icon(Icons.broken_image),
        ),
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

  // ============================================================
  // Create / Edit
  // ============================================================

  Future<void> _openCreate() async {
    final draft = _NewsDoc(
      id: '',
      title: '',
      summary: '',
      body: '',
      coverImageUrl: null,
      tags: const [],
      status: _statusDraft,
      isPublic: true,
      pinned: false,
      publishedAt: null,
      updatedAt: null,
    );
    await _openEditor(draft, isCreate: true);
  }

  Future<void> _openEdit(_NewsDoc d) => _openEditor(d, isCreate: false);

  Future<void> _openEditor(_NewsDoc d, {required bool isCreate}) async {
    final result = await showDialog<_NewsEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NewsEditorDialog(initial: d, isCreate: isCreate),
    );
    if (result == null) return;

    try {
      final data = {
        ...result.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      };

      if (isCreate) {
        final docRef = _col.doc(); // auto id
        await docRef.set(data, SetOptions(merge: true));
      } else {
        await _col.doc(d.id).set(data, SetOptions(merge: true));
      }

      _toast(isCreate ? '已新增最新消息' : '已更新最新消息');
    } catch (e) {
      _toast('儲存失敗：$e');
    }
  }

  // ============================================================
  // Single updates
  // ============================================================

  Future<void> _setPinned(String id, bool pinned) async {
    try {
      await _col.doc(id).set({
        'pinned': pinned,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      }, SetOptions(merge: true));
      _toast(pinned ? '已置頂' : '已取消置頂');
    } catch (e) {
      _toast('更新失敗：$e');
    }
  }

  // ============================================================
  // Batch
  // ============================================================

  Future<void> _batchSetStatus(String status) async {
    final ok = await _confirm(
      title: '批次更新狀態',
      message: '共選取 ${_selected.length} 筆，確定要更新為「${status == _statusPublished ? '上架' : '草稿'}」？',
      confirmText: '確認',
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      final patch = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      };
      // ✅ 上架時補 publishedAt（若原本沒有）
      if (status == _statusPublished) {
        patch['publishedAt'] = FieldValue.serverTimestamp();
      }
      batch.set(_col.doc(id), patch, SetOptions(merge: true));
    }
    await batch.commit();

    if (!mounted) return;
    setState(() => _selected.clear());
    _toast('已批次更新狀態');
  }

  Future<void> _batchSetPinned(bool pinned) async {
    final ok = await _confirm(
      title: pinned ? '批次置頂' : '批次取消置頂',
      message: '共選取 ${_selected.length} 筆，確定要${pinned ? '置頂' : '取消置頂'}？',
      confirmText: '確認',
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final id in _selected) {
      batch.set(
        _col.doc(id),
        {
          'pinned': pinned,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': 'admin',
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    if (!mounted) return;
    setState(() => _selected.clear());
    _toast(pinned ? '已批次置頂' : '已批次取消置頂');
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
    _toast('已刪除選取消息');
  }

  Future<void> _confirmDeleteOne(String id) async {
    final ok = await _confirm(
      title: '刪除消息',
      message: '確定要刪除這則最新消息嗎？\nID: $id',
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

  Future<void> _copy(String text) async {
    final v = text.trim();
    if (v.isEmpty) return;
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
// Editor Dialog
// ============================================================

class _NewsEditorDialog extends StatefulWidget {
  final _NewsDoc initial;
  final bool isCreate;

  const _NewsEditorDialog({required this.initial, required this.isCreate});

  @override
  State<_NewsEditorDialog> createState() => _NewsEditorDialogState();
}

class _NewsEditorDialogState extends State<_NewsEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _cover;
  late final TextEditingController _tags;
  late final TextEditingController _body;

  late String _status;
  late bool _isPublic;
  late bool _pinned;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _title = TextEditingController(text: d.title);
    _summary = TextEditingController(text: d.summary);
    _cover = TextEditingController(text: d.coverImageUrl ?? '');
    _tags = TextEditingController(text: d.tags.join(', '));
    _body = TextEditingController(text: d.body);

    _status = d.status.isEmpty ? 'draft' : d.status;
    _isPublic = d.isPublic;
    _pinned = d.pinned;
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _cover.dispose();
    _tags.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.isCreate ? '新增最新消息' : '編輯最新消息',
          style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 920,
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
                controller: _summary,
                decoration: const InputDecoration(
                  labelText: '摘要（summary，可選）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _cover,
                      decoration: const InputDecoration(
                        labelText: '封面圖 URL（coverImageUrl，可選）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _tags,
                      decoration: const InputDecoration(
                        labelText: '標籤（tags，用逗號分隔）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _body,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: '內文（body，可存純文字或 Markdown）',
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
                        labelText: '狀態',
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
                      title: const Text('公開（isPublic）',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(_isPublic ? '前台可見' : '前台不可見',
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600)),
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('置頂（pinned）',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(_pinned ? '列表置頂' : '不置頂',
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600)),
                      value: _pinned,
                      onChanged: (v) => setState(() => _pinned = v),
                    ),
                  ),
                ],
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

    final tags = _tags.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    Navigator.pop(
      context,
      _NewsEditResult(
        title: title,
        summary: _summary.text.trim(),
        body: _body.text.trim(),
        coverImageUrl: _cover.text.trim().isEmpty ? null : _cover.text.trim(),
        tags: tags,
        status: _status,
        isPublic: _isPublic,
        pinned: _pinned,
      ),
    );
  }
}

class _NewsEditResult {
  final String title;
  final String summary;
  final String body;
  final String? coverImageUrl;
  final List<String> tags;
  final String status;
  final bool isPublic;
  final bool pinned;

  _NewsEditResult({
    required this.title,
    required this.summary,
    required this.body,
    required this.coverImageUrl,
    required this.tags,
    required this.status,
    required this.isPublic,
    required this.pinned,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'title': title,
      'summary': summary,
      'body': body,
      'tags': tags,
      'status': status,
      'isPublic': isPublic,
      'pinned': pinned,
    };
    if (coverImageUrl != null) m['coverImageUrl'] = coverImageUrl;

    // ✅ 若儲存時狀態為 published，補 publishedAt（若沒有）
    if (status == 'published') {
      m['publishedAt'] = FieldValue.serverTimestamp();
    }
    return m;
  }
}

// ============================================================
// Model + Utils
// ============================================================

class _NewsDoc {
  final String id;
  final String title;
  final String summary;
  final String body;
  final String? coverImageUrl;
  final List<String> tags;
  final String status;
  final bool isPublic;
  final bool pinned;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  const _NewsDoc({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.coverImageUrl,
    required this.tags,
    required this.status,
    required this.isPublic,
    required this.pinned,
    required this.publishedAt,
    required this.updatedAt,
  });

  factory _NewsDoc.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _NewsDoc(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      summary: (d['summary'] ?? '').toString(),
      body: (d['body'] ?? '').toString(),
      coverImageUrl: d['coverImageUrl'] is String ? (d['coverImageUrl'] as String) : null,
      tags: _asStringList(d['tags']),
      status: (d['status'] ?? 'draft').toString(),
      isPublic: d['isPublic'] == true,
      pinned: d['pinned'] == true,
      publishedAt: _toDateTime(d['publishedAt']),
      updatedAt: _toDateTime(d['updatedAt']),
    );
  }
}

List<String> _asStringList(dynamic v) {
  if (v is List) {
    return v.map((e) => e?.toString() ?? '').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  return const [];
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

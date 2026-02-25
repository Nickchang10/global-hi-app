// lib/pages/guestbook_page.dart
//
// ✅ GuestbookPage（最終可編譯完整版｜留言板｜即時監聽｜新增/刪除｜搜尋｜複製到剪貼簿｜Web+App）
//
// Firestore：guestbook/{id}
// - name: String
// - message: String
// - createdAt: Timestamp
// - updatedAt: Timestamp
// - uid: String? (選用：登入者 uid)
// - isHidden: bool? (選用)
//
// 依賴：cloud_firestore, flutter/material, flutter/services, flutter/foundation
// firebase_auth 可選：若不使用登入，可移除並註解相關 uid 寫入

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 若你前台不使用登入，可移除並註解 uid 寫入
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GuestbookPage extends StatefulWidget {
  const GuestbookPage({super.key, this.collectionPath = 'guestbook'});

  static const String routeName = '/guestbook';
  final String collectionPath;

  @override
  State<GuestbookPage> createState() => _GuestbookPageState();
}

class _GuestbookPageState extends State<GuestbookPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _nameCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _q = '';
  bool _busy = false;
  String _busyLabel = '';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(widget.collectionPath);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Utils
  // -------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v.trim());
    return null;
  }

  String _fmt(DateTime? d) {
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

  void _setBusy(bool v, {String label = ''}) {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  bool _matchLocal(_GbRow r) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final d = r.data;
    final id = r.id.toLowerCase();
    final name = _s(d['name']).toLowerCase();
    final msg = _s(d['message']).toLowerCase();
    final uid = _s(d['uid']).toLowerCase();

    return id.contains(q) ||
        name.contains(q) ||
        msg.contains(q) ||
        uid.contains(q);
  }

  // -------------------------
  // Actions
  // -------------------------
  Future<void> _create() async {
    final name = _s(_nameCtrl.text);
    final msg = _s(_msgCtrl.text);

    if (name.isEmpty) {
      _snack('請輸入姓名');
      return;
    }
    if (msg.isEmpty) {
      _snack('請輸入留言內容');
      return;
    }
    if (msg.length > 500) {
      _snack('留言內容最多 500 字');
      return;
    }

    _setBusy(true, label: '送出留言...');
    try {
      final uid = _auth.currentUser?.uid; // 允許 null（未登入）

      final payload = <String, dynamic>{
        'name': name,
        'message': msg,
        'isHidden': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ✅ 只有 uid != null 才寫入（避免某些 rules/型別期待 string 時出錯）
      if (uid != null && uid.trim().isNotEmpty) {
        payload['uid'] = uid.trim();
      }

      await _col.add(payload);

      _msgCtrl.clear();
      _snack('已送出');
    } catch (e) {
      _snack('送出失敗：$e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除留言'),
        content: const Text('確定要刪除此留言嗎？此操作不可復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    _setBusy(true, label: '刪除中...');
    try {
      await _col.doc(id).delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _openDetail(_GbRow row) async {
    final d = row.data;
    final name = _s(d['name']).isEmpty ? '（未填姓名）' : _s(d['name']);
    final msg = _s(d['message']);
    final uid = _s(d['uid']);
    final createdAt = _toDate(d['createdAt']);
    final updatedAt = _toDate(d['updatedAt']);

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 680,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '複製留言',
                      onPressed: () => _copy(msg, done: '已複製留言內容'),
                      icon: const Icon(Icons.copy),
                    ),
                    IconButton(
                      tooltip: '刪除',
                      onPressed: _busy
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _delete(row.id);
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _InfoRow(label: '留言ID', value: row.id),
                const SizedBox(height: 6),
                _InfoRow(label: 'uid', value: uid),
                const SizedBox(height: 6),
                _InfoRow(label: 'createdAt', value: _fmt(createdAt)),
                const SizedBox(height: 6),
                _InfoRow(label: 'updatedAt', value: _fmt(updatedAt)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '內容',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final cs = Theme.of(context).colorScheme;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cs.outline.withValues(alpha: 0.18),
                        ),
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.22,
                        ),
                      ),
                      child: Text(msg.isEmpty ? '（無內容）' : msg),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copy(row.id, done: '已複製留言ID'),
                      icon: const Icon(Icons.tag),
                      label: const Text('複製ID'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _copy('$name\n$msg', done: '已複製姓名+內容'),
                      icon: const Icon(Icons.copy_all),
                      label: const Text('複製全文'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('關閉'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('留言板'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Debug：複製集合路徑',
              onPressed: () => _copy(widget.collectionPath, done: '已複製集合路徑'),
              icon: const Icon(Icons.bug_report_outlined),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 發文區
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '姓名',
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '留言內容（最多 500 字）',
                        isDense: true,
                      ),
                      minLines: 2,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : _create,
                              icon: const Icon(Icons.send),
                              label: const Text(
                                '送出留言',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 搜尋
              Padding(
                padding: const EdgeInsets.all(12),
                child: StatefulBuilder(
                  builder: (context, setLocal) {
                    return TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        hintText: '搜尋：姓名 / 內容 / uid / id',
                        suffixIcon: _searchCtrl.text.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: '清除',
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _q = '');
                                  setLocal(() {});
                                },
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                      onChanged: (v) {
                        setState(() => _q = v);
                        setLocal(() {});
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),

              // 清單
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _col
                      .orderBy('createdAt', descending: true)
                      .limit(400)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('讀取失敗：${snap.error}'));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final rows = snap.data!.docs
                        .map((d) => _GbRow(id: d.id, data: d.data()))
                        .where(_matchLocal)
                        .toList();

                    if (rows.isEmpty) {
                      return Center(
                        child: Text(
                          '目前沒有留言',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        final d = r.data;

                        final name = _s(d['name']).isEmpty
                            ? '（未填姓名）'
                            : _s(d['name']);
                        final msg = _s(d['message']);
                        final createdAt = _toDate(d['createdAt']);

                        return Card(
                          elevation: 0,
                          child: ListTile(
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                msg.isEmpty ? '（無內容）' : msg,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _fmt(createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                PopupMenuButton<String>(
                                  tooltip: '更多',
                                  onSelected: _busy
                                      ? null
                                      : (v) async {
                                          if (v == 'detail') {
                                            await _openDetail(r);
                                          } else if (v == 'copy') {
                                            await _copy(msg, done: '已複製留言內容');
                                          } else if (v == 'delete') {
                                            await _delete(r.id);
                                          }
                                        },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'detail',
                                      child: Text('查看詳情'),
                                    ),
                                    PopupMenuItem(
                                      value: 'copy',
                                      child: Text('複製留言'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('刪除'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _openDetail(r),
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
              child: _BusyBar(
                label: _busyLabel.isEmpty ? '處理中...' : _busyLabel,
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------
// Models / Widgets
// -------------------------
class _GbRow {
  final String id;
  final Map<String, dynamic> data;
  _GbRow({required this.id, required this.data});
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
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ),
        Expanded(
          child: SelectableText(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
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
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

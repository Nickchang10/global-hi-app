// lib/pages/vendor_message_center_page.dart
//
// ✅ VendorMessageCenterPage（完整版｜可編譯｜Vendor Only｜訊息中心｜即時聊天｜系統公告｜已讀狀態｜搜尋｜匯出CSV(複製剪貼簿)｜Web+App）
//
// 目的：
// - 廠商後台與主後台/客服（Admin）訊息互通（同一份 Firestore 資料，達到「連動」）
// - 支援兩類：
//   1) 系統公告（announcements）
//   2) 訊息對話（threads + thread_messages）
//
// Firestore 結構建議（推薦，擴展性佳）：
//
// 1) announcements/{id}
//   - audience: 'all' | 'vendors' | 'users' | ...
//   - title: String
//   - body: String
//   - createdAt: Timestamp
//   - published: bool
//
// 2) message_threads/{threadId}
//   - vendorId: String
//   - vendorName: String (選用)
//   - lastMessage: String
//   - lastSenderRole: 'vendor' | 'admin'
//   - lastAt: Timestamp
//   - vendorUnread: int (vendor 未讀數，通常給 admin 用；此頁會用到 adminUnread)
//   - adminUnread: int (vendor 端未讀數)
//   - status: 'open' | 'closed'
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//
// 3) message_threads/{threadId}/messages/{messageId}
//   - senderRole: 'vendor' | 'admin'
//   - senderId: String (uid/email)
//   - text: String
//   - createdAt: Timestamp
//   - readByVendorAt: Timestamp (選用)
//   - readByAdminAt: Timestamp (選用)
//
// 索引建議：
// - message_threads: where(vendorId) + orderBy(lastAt desc)
// - messages 子集合：orderBy(createdAt asc)
// - announcements: where(audience in ['vendors','all']) + orderBy(createdAt desc) (in 需要索引)
//
// 若你現有資料結構不同：你可以只要把 collection 名稱/欄位對映改掉即可。
//
// 依賴：cloud_firestore, flutter/material, flutter/services

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorMessageCenterPage extends StatefulWidget {
  const VendorMessageCenterPage({
    super.key,
    required this.vendorId,
    this.vendorName,
    this.vendorIdentity, // 回覆時寫入 senderId（uid/email）
    this.threadCollection = 'message_threads',
    this.announcementCollection = 'announcements',
  });

  final String vendorId;
  final String? vendorName;
  final String? vendorIdentity;

  final String threadCollection;
  final String announcementCollection;

  @override
  State<VendorMessageCenterPage> createState() => _VendorMessageCenterPageState();
}

class _VendorMessageCenterPageState extends State<VendorMessageCenterPage> with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _q = '';

  bool _busy = false;
  String _busyLabel = '';

  String? _selectedThreadId;

  late final TabController _tab;

  CollectionReference<Map<String, dynamic>> get _threads => _db.collection(widget.threadCollection);
  CollectionReference<Map<String, dynamic>> get _ann => _db.collection(widget.announcementCollection);

  String get _vid => widget.vendorId.trim();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
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
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  Future<void> _setBusy(bool v, {String label = ''}) async {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  bool _matchThread(_ThreadRow r) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final d = r.data;
    final id = r.id.toLowerCase();
    final last = _s(d['lastMessage']).toLowerCase();
    final status = _s(d['status']).toLowerCase();
    final vendorName = _s(d['vendorName']).toLowerCase();

    return id.contains(q) || last.contains(q) || status.contains(q) || vendorName.contains(q);
  }

  // -------------------------
  // Data Streams
  // -------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamThreads() {
    if (_vid.isEmpty) return const Stream.empty();
    return _threads
        .where('vendorId', isEqualTo: _vid)
        .orderBy('lastAt', descending: true)
        .limit(200)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamAnnouncements() {
    // 只取 published=true 且 audience=vendors/all
    // audience in 查詢需要索引；若你不想 in，可改為 audience='vendors' 或把 all 另外拉一次合併
    return _ann
        .where('published', isEqualTo: true)
        .where('audience', whereIn: const ['vendors', 'all'])
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  CollectionReference<Map<String, dynamic>> _messagesCol(String threadId) =>
      _threads.doc(threadId).collection('messages');

  // -------------------------
  // Thread create / ensure
  // -------------------------
  Future<String> _ensureThread() async {
    // 找最新一個 open thread，沒有就建立新的
    final qs = await _threads
        .where('vendorId', isEqualTo: _vid)
        .orderBy('lastAt', descending: true)
        .limit(10)
        .get();

    for (final doc in qs.docs) {
      final d = doc.data();
      final status = _s(d['status']).isEmpty ? 'open' : _s(d['status']);
      if (status.toLowerCase() != 'closed') {
        return doc.id;
      }
    }

    final ref = _threads.doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'vendorId': _vid,
      'vendorName': (widget.vendorName ?? '').trim(),
      'lastMessage': '',
      'lastSenderRole': 'vendor',
      'lastAt': now,
      'adminUnread': 0, // vendor 端未讀數（這頁用）
      'vendorUnread': 0,
      'status': 'open',
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    return ref.id;
  }

  // -------------------------
  // Send / Read / Export
  // -------------------------
  Future<void> _sendMessage(String threadId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    await _setBusy(true, label: '送出中...');
    try {
      final now = FieldValue.serverTimestamp();
      final senderId = (widget.vendorIdentity ?? '').trim();

      final msgRef = _messagesCol(threadId).doc();
      final batch = _db.batch();

      batch.set(msgRef, <String, dynamic>{
        'senderRole': 'vendor',
        'senderId': senderId,
        'text': t,
        'createdAt': now,
        'readByVendorAt': now, // 自己送的，視為已讀
      }, SetOptions(merge: true));

      // 更新 thread 摘要 + 增加 adminUnread (讓 admin 端知道有新訊息)
      batch.set(_threads.doc(threadId), <String, dynamic>{
        'lastMessage': t,
        'lastSenderRole': 'vendor',
        'lastAt': now,
        'updatedAt': now,
        'vendorName': (widget.vendorName ?? '').trim(),
        'adminUnread': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await batch.commit();

      _snack('已送出');
    } catch (e) {
      _snack('送出失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _markThreadReadAsVendor(String threadId) async {
    // 清掉 vendor 端未讀數（此結構用 adminUnread 表示 vendor 未讀數）
    await _threads.doc(threadId).set(
      <String, dynamic>{
        'adminUnread': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // (可選) 同步標記 message 的 readByVendorAt（成本高，不建議大量做）
  }

  Future<void> _exportThreadCsv(String threadId) async {
    await _setBusy(true, label: '匯出中...');
    try {
      final qs = await _messagesCol(threadId).orderBy('createdAt', descending: false).limit(2000).get();

      final headers = <String>['threadId', 'messageId', 'senderRole', 'senderId', 'text', 'createdAt'];
      final buffer = StringBuffer()..writeln(headers.join(','));

      for (final doc in qs.docs) {
        final d = doc.data();
        final line = <String>[
          threadId,
          doc.id,
          _s(d['senderRole']),
          _s(d['senderId']),
          _s(d['text']),
          (_toDate(d['createdAt'])?.toIso8601String() ?? ''),
        ].map((e) => e.replaceAll(',', '，')).toList();

        buffer.writeln(line.join(','));
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      _snack('已複製 CSV 到剪貼簿（可貼到 Excel）');
    } catch (e) {
      _snack('匯出失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _closeThread(String threadId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('關閉對話'),
        content: const Text('確定要關閉此對話（status=closed）嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('關閉')),
        ],
      ),
    );
    if (ok != true) return;

    await _setBusy(true, label: '關閉中...');
    try {
      await _threads.doc(threadId).set(
        <String, dynamic>{
          'status': 'closed',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _snack('已關閉');
    } catch (e) {
      _snack('關閉失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    if (_vid.isEmpty) {
      return const Scaffold(body: Center(child: Text('vendorId 不可為空')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('訊息中心', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '對話'),
            Tab(text: '公告'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '新建/開啟對話',
            onPressed: _busy
                ? null
                : () async {
                    final id = await _ensureThread();
                    setState(() => _selectedThreadId = id);
                    if (mounted) _tab.animateTo(0);
                    await _markThreadReadAsVendor(id);
                  },
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tab,
            children: [
              _buildThreadsTab(context),
              _buildAnnouncementsTab(context),
            ],
          ),
          if (_busy)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BusyBar(label: _busyLabel.isEmpty ? '處理中...' : _busyLabel),
            ),
        ],
      ),
    );
  }

  Widget _buildThreadsTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamThreads(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final rows = snap.data!.docs
            .map((d) => _ThreadRow(id: d.id, data: d.data()))
            .where(_matchThread)
            .toList();

        final ids = rows.map((e) => e.id).toSet();
        if (_selectedThreadId != null && !ids.contains(_selectedThreadId)) _selectedThreadId = null;

        return Column(
          children: [
            _ThreadFilters(
              searchCtrl: _searchCtrl,
              countLabel: '${rows.length} 筆',
              onQueryChanged: (v) => setState(() => _q = v),
              onClearQuery: () {
                _searchCtrl.clear();
                setState(() => _q = '');
              },
              onNewThread: _busy
                  ? null
                  : () async {
                      final id = await _ensureThread();
                      setState(() => _selectedThreadId = id);
                      await _markThreadReadAsVendor(id);
                    },
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 980;

                  final list = ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      final d = r.data;
                      final status = _s(d['status']).isEmpty ? 'open' : _s(d['status']);
                      final last = _s(d['lastMessage']).isEmpty ? '（尚無訊息）' : _s(d['lastMessage']);
                      final lastAt = _toDate(d['lastAt']);
                      final unread = (d['adminUnread'] is int) ? (d['adminUnread'] as int) : 0;

                      return ListTile(
                        selected: r.id == _selectedThreadId,
                        leading: Icon(status.toLowerCase() == 'closed' ? Icons.lock_outline : Icons.forum_outlined),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '對話 ${r.id.substring(0, r.id.length.clamp(0, 8))}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            if (unread > 0) _Badge(count: unread),
                            const SizedBox(width: 8),
                            _Pill(label: status, color: _threadStatusColor(context, status)),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                last,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '更新：${_fmt(lastAt)}',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: _busy
                              ? null
                              : (v) async {
                                  if (v == 'copy') {
                                    await _copy(r.id, done: '已複製 threadId');
                                  } else if (v == 'export') {
                                    await _exportThreadCsv(r.id);
                                  } else if (v == 'close') {
                                    await _closeThread(r.id);
                                  }
                                },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'copy', child: Text('複製 threadId')),
                            PopupMenuItem(value: 'export', child: Text('匯出CSV(複製)')),
                            PopupMenuDivider(),
                            PopupMenuItem(value: 'close', child: Text('關閉對話')),
                          ],
                        ),
                        onTap: () async {
                          setState(() => _selectedThreadId = r.id);
                          await _markThreadReadAsVendor(r.id);
                          if (!wide) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => _ThreadChatSheet(
                                threadId: r.id,
                                messagesCol: _messagesCol(r.id),
                                onSend: (text) => _sendMessage(r.id, text),
                                onExport: () => _exportThreadCsv(r.id),
                                onClose: () => _closeThread(r.id),
                                fmt: _fmt,
                                toDate: _toDate,
                              ),
                            );
                          }
                        },
                      );
                    },
                  );

                  if (!wide) return list;

                  return Row(
                    children: [
                      Expanded(flex: 3, child: list),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 2,
                        child: _selectedThreadId == null
                            ? Center(
                                child: Text(
                                  '請選擇一個對話',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              )
                            : _ThreadChatPanel(
                                threadId: _selectedThreadId!,
                                messagesCol: _messagesCol(_selectedThreadId!),
                                onSend: (text) => _sendMessage(_selectedThreadId!, text),
                                onExport: () => _exportThreadCsv(_selectedThreadId!),
                                onClose: () => _closeThread(_selectedThreadId!),
                                fmt: _fmt,
                                toDate: _toDate,
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnnouncementsTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamAnnouncements(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              '目前沒有公告',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final title = _s(d['title']).isEmpty ? '（無標題公告）' : _s(d['title']);
            final body = _s(d['body']).isEmpty ? '（無內容）' : _s(d['body']);
            final createdAt = _toDate(d['createdAt']);

            return Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      _fmt(createdAt),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Text(body),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _copy(jsonEncode(d), done: '已複製公告 JSON'),
                        icon: const Icon(Icons.copy),
                        label: const Text('複製JSON'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------
// Models / Extensions
// ------------------------------------------------------------
class _ThreadRow {
  final String id;
  final Map<String, dynamic> data;
  _ThreadRow({required this.id, required this.data});
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ------------------------------------------------------------
// Filters UI
// ------------------------------------------------------------
class _ThreadFilters extends StatelessWidget {
  const _ThreadFilters({
    required this.searchCtrl,
    required this.countLabel,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onNewThread,
  });

  final TextEditingController searchCtrl;
  final String countLabel;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final VoidCallback? onNewThread;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 980;

          final search = TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              hintText: '搜尋對話：lastMessage / status / threadId',
              suffixIcon: searchCtrl.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除',
                      onPressed: onClearQuery,
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onChanged: onQueryChanged,
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: onNewThread,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('新建/開啟對話'),
                    ),
                    const SizedBox(width: 10),
                    Text('共 $countLabel', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onNewThread,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('新建/開啟對話'),
              ),
              const SizedBox(width: 10),
              Text('共 $countLabel', style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Chat Panel / Sheet
// ------------------------------------------------------------
class _ThreadChatPanel extends StatefulWidget {
  const _ThreadChatPanel({
    required this.threadId,
    required this.messagesCol,
    required this.onSend,
    required this.onExport,
    required this.onClose,
    required this.fmt,
    required this.toDate,
  });

  final String threadId;
  final CollectionReference<Map<String, dynamic>> messagesCol;

  final Future<void> Function(String text) onSend;
  final Future<void> Function() onExport;
  final Future<void> Function() onClose;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  @override
  State<_ThreadChatPanel> createState() => _ThreadChatPanelState();
}

class _ThreadChatPanelState extends State<_ThreadChatPanel> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    await widget.onSend(text);
    await Future.delayed(const Duration(milliseconds: 120));
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChatHeader(
          threadId: widget.threadId,
          onExport: widget.onExport,
          onClose: widget.onClose,
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.messagesCol.orderBy('createdAt', descending: false).limit(500).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final msgs = snap.data!.docs;

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final d = msgs[i].data();
                  final role = (d['senderRole'] ?? 'vendor').toString();
                  final isMe = role == 'vendor';
                  final text = (d['text'] ?? '').toString();
                  final at = widget.toDate(d['createdAt']);
                  return _ChatBubble(
                    isMe: isMe,
                    text: text,
                    timeLabel: widget.fmt(at),
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: '輸入訊息…',
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _send,
                icon: const Icon(Icons.send),
                label: const Text('送出'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThreadChatSheet extends StatelessWidget {
  const _ThreadChatSheet({
    required this.threadId,
    required this.messagesCol,
    required this.onSend,
    required this.onExport,
    required this.onClose,
    required this.fmt,
    required this.toDate,
  });

  final String threadId;
  final CollectionReference<Map<String, dynamic>> messagesCol;

  final Future<void> Function(String text) onSend;
  final Future<void> Function() onExport;
  final Future<void> Function() onClose;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.92,
      child: _ThreadChatPanel(
        threadId: threadId,
        messagesCol: messagesCol,
        onSend: onSend,
        onExport: onExport,
        onClose: onClose,
        fmt: fmt,
        toDate: toDate,
      ),
    );
  }
}

// ------------------------------------------------------------
// Shared Widgets
// ------------------------------------------------------------
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.threadId,
    required this.onExport,
    required this.onClose,
  });

  final String threadId;
  final Future<void> Function() onExport;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '對話 $threadId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download_outlined),
            label: const Text('匯出CSV'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.lock_outline),
            label: const Text('關閉'),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.isMe,
    required this.text,
    required this.timeLabel,
  });

  final bool isMe;
  final String text;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = isMe ? cs.primaryContainer : cs.surfaceContainerHighest.withOpacity(0.45);
    final fg = isMe ? cs.onPrimaryContainer : cs.onSurface;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withOpacity(0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(timeLabel, style: TextStyle(color: fg.withOpacity(0.7), fontSize: 11)),
            ],
          ),
        ),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.error.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.error.withOpacity(0.25)),
      ),
      child: Text(
        '$count',
        style: TextStyle(color: cs.error, fontWeight: FontWeight.w900, fontSize: 12),
      ),
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

Color _threadStatusColor(BuildContext context, String status) {
  final s = status.trim().toLowerCase();
  final cs = Theme.of(context).colorScheme;
  if (s == 'closed') return cs.error;
  return cs.primary;
}

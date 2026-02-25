// lib/services/vendor_message_center_page.dart
//
// ✅ VendorMessageCenterPage（廠商訊息中心｜RWD｜可編譯完整版）
// ------------------------------------------------------------
// ✅ 修正：移除未使用的 firstOrNull 宣告（避免 unused_element 警告）
// ✅ 修正：所有 withOpacity(...) → withValues(alpha: ...)
// ✅ 修正：ColorScheme.surfaceVariant deprecated → surfaceContainerHighest
// ------------------------------------------------------------
//
// Firestore 建議結構（可自行調整欄位，但本頁已做容錯）：
// - vendor_threads/{threadId}
//   - vendorId: String
//   - userId: String
//   - subject: String (optional)
//   - lastText: String (optional)
//   - lastSender: 'vendor'|'user' (optional)
//   - unreadVendor: int (optional)
//   - unreadUser: int (optional)
//   - status: 'open'|'closed' (optional)
//   - updatedAt: Timestamp (optional)
//   - createdAt: Timestamp (optional)
//   - meta: Map (optional)
//
// - vendor_threads/{threadId}/messages/{messageId}
//   - threadId: String (optional)
//   - vendorId: String
//   - userId: String
//   - senderRole: 'vendor'|'user'|'system'
//   - senderId: String (optional)
//   - text: String
//   - createdAt: Timestamp
//
// 依賴：cloud_firestore, firebase_auth, flutter/material.dart
//

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorMessageCenterPage extends StatefulWidget {
  final String? vendorId;

  const VendorMessageCenterPage({super.key, this.vendorId});

  @override
  State<VendorMessageCenterPage> createState() =>
      _VendorMessageCenterPageState();
}

class _VendorMessageCenterPageState extends State<VendorMessageCenterPage> {
  final _db = FirebaseFirestore.instance;

  String _vendorId = '';
  String _query = '';
  String _statusFilter = 'all'; // all/open/closed
  String _error = '';
  bool _hydrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;

    // vendorId 優先順序：Widget參數 > route args > currentUser.uid
    String vid = (widget.vendorId ?? '').trim();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (vid.isEmpty && args is String) {
      vid = args.trim();
    } else if (vid.isEmpty && args is Map) {
      final v = args['vendorId'] ?? args['vendor_id'] ?? args['uid'];
      if (v != null) vid = v.toString().trim();
    }

    if (vid.isEmpty) {
      vid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    }

    setState(() => _vendorId = vid);
  }

  CollectionReference<Map<String, dynamic>> get _threads =>
      _db.collection('vendor_threads');

  Query<Map<String, dynamic>> _buildThreadsQuery() {
    Query<Map<String, dynamic>> q = _threads
        .where('vendorId', isEqualTo: _vendorId)
        .orderBy('updatedAt', descending: true);

    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }

    // 簡易搜尋：用 client-side filter（避免需要額外複合索引）
    return q;
  }

  void _setFilter(String v) => setState(() => _statusFilter = v);

  void _openThread(BuildContext context, VendorThread thread) async {
    if (!mounted) return;

    final wide = MediaQuery.of(context).size.width >= 980;
    if (wide) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorThreadChatPage(
            vendorId: _vendorId,
            threadId: thread.id,
            thread: thread,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorThreadChatPage(
            vendorId: _vendorId,
            threadId: thread.id,
            thread: thread,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_vendorId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('訊息中心')),
        body: const Center(child: Text('尚未取得 vendorId（請先登入）')),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('廠商訊息中心'),
        actions: [
          IconButton(
            tooltip: '新增測試對話（可刪）',
            onPressed: _createDemoThread,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _TopBar(
            query: _query,
            onQueryChanged: (v) => setState(() => _query = v),
            status: _statusFilter,
            onStatusChanged: _setFilter,
          ),
          if (_error.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: cs.errorContainer.withValues(alpha: 0.5),
              child: Text(_error, style: TextStyle(color: cs.onErrorContainer)),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildThreadsQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                final threads = docs
                    .map((d) => VendorThread.fromDoc(d))
                    .where((t) => _matchQuery(t, _query))
                    .toList();

                if (threads.isEmpty) {
                  return const Center(child: Text('目前沒有任何對話'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: threads.length,
                  itemBuilder: (_, i) {
                    final t = threads[i];
                    return _ThreadTile(
                      thread: t,
                      onTap: () => _openThread(context, t),
                      onClose: () => _setThreadStatus(t.id, 'closed'),
                      onOpen: () => _setThreadStatus(t.id, 'open'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matchQuery(VendorThread t, String q) {
    final qq = q.trim().toLowerCase();
    if (qq.isEmpty) return true;
    return t.userId.toLowerCase().contains(qq) ||
        t.subject.toLowerCase().contains(qq) ||
        t.lastText.toLowerCase().contains(qq) ||
        t.id.toLowerCase().contains(qq);
  }

  Future<void> _setThreadStatus(String threadId, String status) async {
    try {
      await _threads.doc(threadId).set({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '更新狀態失敗：$e');
    }
  }

  /// 可刪：快速建立一個測試 thread + message，方便你先看到畫面
  Future<void> _createDemoThread() async {
    try {
      final now = DateTime.now();
      final tid = _threads.doc().id;
      final userId = 'demo_user_${now.millisecondsSinceEpoch % 10000}';

      final threadRef = _threads.doc(tid);
      final msgRef = threadRef.collection('messages').doc();

      await _db.runTransaction((tx) async {
        tx.set(threadRef, {
          'vendorId': _vendorId,
          'userId': userId,
          'subject': '測試對話',
          'lastText': '你好，我是廠商（測試訊息）',
          'lastSender': 'vendor',
          'unreadVendor': 0,
          'unreadUser': 1,
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.set(msgRef, {
          'threadId': tid,
          'vendorId': _vendorId,
          'userId': userId,
          'senderRole': 'vendor',
          'senderId': _vendorId,
          'text': '你好，我是廠商（測試訊息）',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '建立測試對話失敗：$e');
    }
  }
}

// ============================================================
// Thread Chat Page
// ============================================================

class VendorThreadChatPage extends StatefulWidget {
  final String vendorId;
  final String threadId;
  final VendorThread? thread;

  const VendorThreadChatPage({
    super.key,
    required this.vendorId,
    required this.threadId,
    this.thread,
  });

  @override
  State<VendorThreadChatPage> createState() => _VendorThreadChatPageState();
}

class _VendorThreadChatPageState extends State<VendorThreadChatPage> {
  final _db = FirebaseFirestore.instance;
  final _input = TextEditingController();
  bool _sending = false;
  String _error = '';
  VendorThread? _thread;

  DocumentReference<Map<String, dynamic>> get _threadRef =>
      _db.collection('vendor_threads').doc(widget.threadId);

  CollectionReference<Map<String, dynamic>> get _msgsRef =>
      _threadRef.collection('messages');

  @override
  void initState() {
    super.initState();
    _thread = widget.thread;
    _markVendorRead();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _markVendorRead() async {
    try {
      await _threadRef.set({
        'unreadVendor': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // 不阻塞 UI
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (_sending) return;

    setState(() {
      _sending = true;
      _error = '';
    });

    try {
      // 確保 thread 資料存在
      final snap = await _threadRef.get();
      final t = VendorThread.fromDocSnap(widget.threadId, snap.data());
      _thread = t;

      final msgId = _msgsRef.doc().id;
      final msgData = <String, dynamic>{
        'threadId': widget.threadId,
        'vendorId': widget.vendorId,
        'userId': t.userId,
        'senderRole': 'vendor',
        'senderId': widget.vendorId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _db.runTransaction((tx) async {
        tx.set(_msgsRef.doc(msgId), msgData);

        tx.set(_threadRef, {
          'vendorId': widget.vendorId,
          'userId': t.userId,
          'subject': t.subject,
          'lastText': text,
          'lastSender': 'vendor',
          'unreadVendor': 0,
          'unreadUser': FieldValue.increment(1),
          'status': (t.status.isEmpty) ? 'open' : t.status,
          'updatedAt': FieldValue.serverTimestamp(),
          if (t.createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (!mounted) return;
      setState(() {
        _sending = false;
        _input.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '送出失敗：$e';
      });
    }
  }

  Future<void> _closeThread() async {
    try {
      await _threadRef.set({
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '關閉對話失敗：$e');
    }
  }

  Future<void> _openThread() async {
    try {
      await _threadRef.set({
        'status': 'open',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '重新開啟失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('對話內容'),
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _threadRef.snapshots(),
            builder: (_, snap) {
              final data = snap.data?.data();
              final t = VendorThread.fromDocSnap(widget.threadId, data);
              final isClosed = t.status.toLowerCase() == 'closed';

              return Row(
                children: [
                  if (isClosed)
                    TextButton.icon(
                      onPressed: _openThread,
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text('重新開啟'),
                    )
                  else
                    TextButton.icon(
                      onPressed: _closeThread,
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: const Text('關閉'),
                    ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _threadRef.snapshots(),
            builder: (_, snap) {
              final t = VendorThread.fromDocSnap(
                widget.threadId,
                snap.data?.data(),
              );
              _thread = t;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  // ✅ surfaceVariant deprecated → surfaceContainerHighest
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                  border: Border(bottom: BorderSide(color: cs.outlineVariant)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: cs.primary.withValues(alpha: 0.12),
                      child: Icon(Icons.person_outline, color: cs.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User：${t.userId.isEmpty ? '(unknown)' : t.userId}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (t.subject.isNotEmpty)
                            Text(
                              t.subject,
                              style: const TextStyle(color: Colors.black54),
                            ),
                        ],
                      ),
                    ),
                    if (t.status.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: cs.outlineVariant),
                          color: t.status == 'closed'
                              ? cs.errorContainer.withValues(alpha: 0.35)
                              : cs.primaryContainer.withValues(alpha: 0.35),
                        ),
                        child: Text(
                          t.status == 'closed' ? '已關閉' : '進行中',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: t.status == 'closed'
                                ? cs.onErrorContainer
                                : cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (_error.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: cs.errorContainer.withValues(alpha: 0.5),
              child: Text(_error, style: TextStyle(color: cs.onErrorContainer)),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _msgsRef
                  .orderBy('createdAt', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('讀取訊息失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('尚無訊息'));
                }

                final msgs = docs.map((d) => VendorMessage.fromDoc(d)).toList();

                // 進頁即把 vendor 未讀清掉（簡單做法：可自行加節流）
                _markVendorRead();

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final mine = m.senderRole == 'vendor';
                    return _MessageBubble(message: m, mine: mine);
                  },
                );
              },
            ),
          ),
          _ComposerBar(
            controller: _input,
            sending: _sending,
            onSend: _send,
            enabledBuilder: () => (_thread?.status.toLowerCase() != 'closed'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// UI Components
// ============================================================

class _TopBar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onQueryChanged;
  final String status;
  final ValueChanged<String> onStatusChanged;

  const _TopBar({
    required this.query,
    required this.onQueryChanged,
    required this.status,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋 userId / 標題 / 內容…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onQueryChanged,
              controller: TextEditingController(text: query)
                ..selection = TextSelection.collapsed(offset: query.length),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: status,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('全部')),
              DropdownMenuItem(value: 'open', child: Text('進行中')),
              DropdownMenuItem(value: 'closed', child: Text('已關閉')),
            ],
            onChanged: (v) => onStatusChanged(v ?? 'all'),
          ),
        ],
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final VendorThread thread;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  const _ThreadTile({
    required this.thread,
    required this.onTap,
    required this.onClose,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unread = thread.unreadVendor;
    final isClosed = thread.status.toLowerCase() == 'closed';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: cs.primary.withValues(alpha: 0.12),
          child: Icon(Icons.person_outline, color: cs.primary),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                thread.userId.isEmpty ? thread.id : thread.userId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              _fmtDate(thread.updatedAt),
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thread.subject.isNotEmpty)
              Text(
                thread.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
            Text(
              thread.lastText.isEmpty ? '（無訊息）' : thread.lastText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _StatusChip(status: thread.status),
                const SizedBox(width: 8),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: cs.errorContainer.withValues(alpha: 0.7),
                    ),
                    child: Text(
                      '未讀 $unread',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cs.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'close') onClose();
            if (v == 'open') onOpen();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: isClosed ? 'open' : 'close',
              child: Text(isClosed ? '重新開啟' : '關閉對話'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = status.trim().isEmpty ? 'open' : status.trim().toLowerCase();
    final closed = s == 'closed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
        color: closed
            ? cs.errorContainer.withValues(alpha: 0.35)
            : cs.primaryContainer.withValues(alpha: 0.35),
      ),
      child: Text(
        closed ? '已關閉' : '進行中',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: closed ? cs.onErrorContainer : cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final bool Function() enabledBuilder;

  const _ComposerBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.enabledBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = enabledBuilder();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled && !sending,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: enabled ? '輸入訊息…' : '此對話已關閉，無法回覆',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => (enabled && !sending) ? onSend() : null,
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: (enabled && !sending) ? onSend : null,
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(sending ? '送出中' : '送出'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final VendorMessage message;
  final bool mine;

  const _MessageBubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ surfaceVariant deprecated → surfaceContainerHighest
    final bg = mine
        ? cs.primaryContainer
        : cs.surfaceContainerHighest.withValues(alpha: 0.40);
    final fg = mine ? cs.onPrimaryContainer : cs.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: mine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(color: fg, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _fmtDate(message.createdAt),
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Models + Helpers (無不必要 cast / 無 unused_element)
// ============================================================

class VendorThread {
  final String id;
  final String vendorId;
  final String userId;
  final String subject;
  final String lastText;
  final String lastSender;
  final int unreadVendor;
  final int unreadUser;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> meta;

  const VendorThread({
    required this.id,
    required this.vendorId,
    required this.userId,
    required this.subject,
    required this.lastText,
    required this.lastSender,
    required this.unreadVendor,
    required this.unreadUser,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.meta,
  });

  factory VendorThread.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return VendorThread.fromDocSnap(doc.id, doc.data());
  }

  static VendorThread fromDocSnap(String id, Map<String, dynamic>? data) {
    final d = data ?? <String, dynamic>{};
    return VendorThread(
      id: id,
      vendorId: _s(d['vendorId']),
      userId: _s(d['userId']),
      subject: _s(d['subject']),
      lastText: _s(d['lastText']),
      lastSender: _s(d['lastSender']),
      unreadVendor: _asInt(d['unreadVendor']),
      unreadUser: _asInt(d['unreadUser']),
      status: _s(d['status']).isEmpty ? 'open' : _s(d['status']).toLowerCase(),
      createdAt: _toDate(d['createdAt']),
      updatedAt: _toDate(d['updatedAt']),
      meta: _asMap(d['meta']),
    );
  }
}

class VendorMessage {
  final String id;
  final String threadId;
  final String vendorId;
  final String userId;
  final String senderRole; // vendor/user/system
  final String senderId;
  final String text;
  final DateTime? createdAt;

  const VendorMessage({
    required this.id,
    required this.threadId,
    required this.vendorId,
    required this.userId,
    required this.senderRole,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory VendorMessage.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return VendorMessage(
      id: doc.id,
      threadId: _s(d['threadId']),
      vendorId: _s(d['vendorId']),
      userId: _s(d['userId']),
      senderRole: _s(d['senderRole']).isEmpty ? 'user' : _s(d['senderRole']),
      senderId: _s(d['senderId']),
      text: _s(d['text']),
      createdAt: _toDate(d['createdAt']),
    );
  }
}

String _s(dynamic v) => (v ?? '').toString().trim();

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = _s(v);
  return int.tryParse(s) ?? 0;
}

DateTime? _toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String _fmtDate(DateTime? dt) {
  if (dt == null) return '';
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${dt.year}/${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

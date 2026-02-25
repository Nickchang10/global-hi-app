import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ ChatRoomPage（聊天房｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正/強化：
/// - ✅ control_flow_in_finally：finally 只做收尾，不使用 return（包含 if(!mounted) return 也不行）
/// - ✅ withOpacity -> withValues(alpha: ...)（避免 deprecated_member_use）
/// - ✅ async gap 後使用 context：先檢查 mounted
///
/// Firestore 結構建議：
/// chat_rooms/{roomId}
///   - title: String
///   - updatedAt: Timestamp
///   - createdAt: Timestamp
///   - lastMessage: String
///   - lastSenderId: String
///
/// chat_rooms/{roomId}/messages/{messageId}
///   - text: String
///   - senderId: String
///   - senderName: String (optional)
///   - createdAt: Timestamp
///   - type: "text" (可擴充)
class ChatRoomPage extends StatefulWidget {
  final String roomId;
  final String? title;

  const ChatRoomPage({super.key, required this.roomId, this.title});

  /// 若你用命名路由：Navigator.pushNamed(context, '/chat', arguments: {...})
  static ChatRoomPage fromRouteArgs(Object? args) {
    final map = (args is Map) ? args : <String, dynamic>{};
    final roomId = (map['roomId'] ?? map['id'] ?? '').toString();
    final title = (map['title'] ?? '').toString();
    return ChatRoomPage(
      roomId: roomId.isEmpty ? 'general' : roomId,
      title: title.isEmpty ? null : title,
    );
  }

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _sending = false;
  String? _sendError;

  DocumentReference<Map<String, dynamic>> get _roomRef =>
      _fs.collection('chat_rooms').doc(widget.roomId);

  CollectionReference<Map<String, dynamic>> get _msgRef =>
      _roomRef.collection('messages');

  String? get _uid => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _ensureRoomDoc();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureRoomDoc() async {
    try {
      final doc = await _roomRef.get();
      if (doc.exists) {
        return;
      }
      await _roomRef.set(<String, dynamic>{
        'title': widget.title ?? '聊天室',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastSenderId': '',
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore (rules/權限未設好時不阻擋 UI)
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messageStream() {
    return _msgRef
        .orderBy('createdAt', descending: false)
        .limit(300)
        .snapshots();
  }

  Future<void> _sendText() async {
    final uid = _uid;
    if (uid == null) {
      _snack('請先登入');
      return;
    }

    final text = _inputCtrl.text.trim();
    if (text.isEmpty) {
      return;
    }

    if (_sending) {
      return;
    }

    setState(() {
      _sending = true;
      _sendError = null;
    });

    try {
      _inputCtrl.clear();

      final user = _auth.currentUser;
      final senderName = (user?.displayName ?? user?.email ?? '').trim();

      await _msgRef.add(<String, dynamic>{
        'type': 'text',
        'text': text,
        'senderId': uid,
        'senderName': senderName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _roomRef.set(<String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': text,
        'lastSenderId': uid,
        if ((widget.title ?? '').trim().isNotEmpty)
          'title': widget.title!.trim(),
      }, SetOptions(merge: true));

      _scrollToBottomSoon();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _sendError = '送出失敗：$e');
    } finally {
      // ✅ finally 只做收尾，不可以有 return（包含 if(!mounted) return 也不行）
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _clearMyMessages() async {
    final uid = _uid;
    if (uid == null) {
      _snack('請先登入');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除我的訊息'),
        content: const Text('只會刪除你自己送出的訊息，確定要繼續？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    try {
      final snap = await _msgRef.where('senderId', isEqualTo: uid).get();
      if (snap.docs.isEmpty) {
        _snack('沒有可刪除的訊息');
        return;
      }

      final batch = _fs.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      _snack('已清除你的訊息');
    } catch (e) {
      _snack('清除失敗：$e');
    }
  }

  void _snack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) {
        return;
      }
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final uid = _uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('聊天室')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  '請先登入才能使用聊天功能',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pushNamed('/login'),
                  child: const Text('前往登入'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final title = (widget.title ?? '聊天室').trim().isEmpty
        ? '聊天室'
        : widget.title!.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '清除我的訊息',
            onPressed: _clearMyMessages,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          _roomHintBar(cs),
          const Divider(height: 1),
          Expanded(child: _messageList(cs, uid)),
          const Divider(height: 1),
          _composer(cs),
        ],
      ),
    );
  }

  Widget _roomHintBar(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.forum_outlined, color: cs.onSurfaceVariant, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Room: ${widget.roomId}',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageList(ColorScheme cs, String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messageStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '載入失敗：${snap.error}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Text(
              '還沒有訊息，輸入一句話開始聊天吧',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          );
        }

        // 每次更新後把畫面往下（避免一直跳，可依需求關掉）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollCtrl.hasClients) {
            return;
          }
          final max = _scrollCtrl.position.maxScrollExtent;
          if (max <= 0) {
            return;
          }
          _scrollCtrl.jumpTo(max);
        });

        return ListView.separated(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final senderId = (d['senderId'] ?? '').toString();
            final senderName = (d['senderName'] ?? '').toString();
            final text = (d['text'] ?? '').toString();
            final createdAt = (d['createdAt'] is Timestamp)
                ? (d['createdAt'] as Timestamp).toDate()
                : null;

            final isMe = senderId == uid;

            return _bubble(
              cs,
              isMe: isMe,
              senderLabel: isMe
                  ? '我'
                  : (senderName.trim().isEmpty ? '對方' : senderName.trim()),
              text: text.isEmpty ? '(空訊息)' : text,
              time: createdAt,
            );
          },
        );
      },
    );
  }

  Widget _bubble(
    ColorScheme cs, {
    required bool isMe,
    required String senderLabel,
    required String text,
    DateTime? time,
  }) {
    final bg = isMe
        ? cs.primary.withValues(alpha: 0.12)
        : cs.secondary.withValues(alpha: 0.12);
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Icon(
              isMe ? Icons.person : Icons.support_agent,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              senderLabel,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (time != null) ...[
              const SizedBox(width: 8),
              Text(
                _fmtTime(time),
                style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _composer(ColorScheme cs) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sendError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Text(
                  _sendError!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !_sending,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendText(),
                    decoration: const InputDecoration(
                      hintText: '輸入訊息…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: '送出',
                  onPressed: _sending ? null : _sendText,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }
}

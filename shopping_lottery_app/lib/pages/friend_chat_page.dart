// lib/pages/friend_chat_page.dart
//
// ✅ FriendChatPage（可編譯完整版｜一對一聊天｜修正 Object? -> String 類型錯誤）
//
// Firestore 建議結構：
// chatRooms/{roomId}
//   - members: [uid1, uid2]
//   - lastMessage: String
//   - lastAt: Timestamp
//   - updatedAt: Timestamp
//
// chatRooms/{roomId}/messages/{mid}
//   - text: String
//   - senderUid: String
//   - createdAt: Timestamp
//
// 依賴：cloud_firestore, firebase_auth, flutter/material

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FriendChatPage extends StatefulWidget {
  const FriendChatPage({
    super.key,
    required this.friendUid,
    this.friendName,
    this.roomId,
  });

  /// 對方 uid（必填）
  final String friendUid;

  /// 對方名稱（可選）
  final String? friendName;

  /// 若你已有 roomId 可直接傳入；否則會用 currentUid + friendUid 生成
  final String? roomId;

  @override
  State<FriendChatPage> createState() => _FriendChatPageState();
}

class _FriendChatPageState extends State<FriendChatPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String _roomId = '';
  String _meUid = '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------- utils ----------
  String _s(dynamic v) => (v ?? '').toString().trim();

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _makeRoomId(String a, String b) {
    final x = a.trim();
    final y = b.trim();
    final pair = [x, y]..sort();
    return '${pair[0]}__${pair[1]}';
  }

  DocumentReference<Map<String, dynamic>> get _roomRef =>
      _db.collection('chatRooms').doc(_roomId);

  CollectionReference<Map<String, dynamic>> get _msgsCol =>
      _roomRef.collection('messages');

  // ---------- bootstrap ----------
  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _meUid = user.uid;
    _roomId = (widget.roomId ?? '').trim().isNotEmpty
        ? widget.roomId!.trim()
        : _makeRoomId(_meUid, widget.friendUid);

    // 確保 chatRoom 存在（best effort）
    try {
      final roomSnap = await _roomRef.get();
      if (!roomSnap.exists) {
        await _roomRef.set({
          'members': [_meUid, widget.friendUid],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}

    if (mounted) setState(() {});
  }

  // ---------- send ----------
  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('請先登入');
      return;
    }
    if (_roomId.isEmpty) {
      _snack('聊天室初始化中，請稍後再試');
      return;
    }

    final text = _input.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      _input.clear();

      final msgRef = _msgsCol.doc();
      final now = FieldValue.serverTimestamp();

      final batch = _db.batch();
      batch.set(msgRef, {
        'text': text,
        'senderUid': user.uid,
        'createdAt': now,
      });

      batch.set(_roomRef, {
        'members': [_meUid, widget.friendUid],
        'lastMessage': text,
        'lastAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      await batch.commit();

      // 讓列表滾到最底（最新訊息在底）
      _scrollToBottomSoon();
    } catch (e) {
      _snack('送出失敗：$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0, // 因為我們用 reverse:true，0 是底部
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('請先登入才能聊天')));
    }

    final title = (widget.friendName ?? '').trim().isNotEmpty
        ? widget.friendName!.trim()
        : '好友聊天';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: _roomId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _messagesView(meUid: user.uid)),
                const Divider(height: 1),
                _composer(),
              ],
            ),
    );
  }

  Widget _messagesView({required String meUid}) {
    // createdAt 若有少數舊資料缺欄位會 orderBy 報錯 → 建議補上 createdAt
    final stream = _msgsCol
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('讀取失敗：${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('開始第一句聊天吧 🙂'));
        }

        return ListView.builder(
          controller: _scroll,
          reverse: true, // 最新在底
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();

            // ✅ 關鍵：全部用 _s()，避免 Object? -> String 類型錯誤
            final text = _s(d['text']);
            final senderUid = _s(d['senderUid']);
            final isMe = senderUid == meUid;

            return _bubble(text: text.isEmpty ? '(空訊息)' : text, isMe: isMe);
          },
        );
      },
    );
  }

  Widget _bubble({required String text, required bool isMe}) {
    final cs = Theme.of(context).colorScheme;

    final bg = isMe ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = isMe ? cs.onPrimaryContainer : cs.onSurface;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            text,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '輸入訊息...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('送出'),
          ),
        ],
      ),
    );
  }
}

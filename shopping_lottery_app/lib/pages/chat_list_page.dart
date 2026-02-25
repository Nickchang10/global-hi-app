// lib/pages/chat_list_page.dart
//
// ✅ ChatListPage（完整版｜可編譯）
// - 顯示目前使用者的聊天室列表（FireStore: chats）
// - 點擊聊天室 -> 進入 ChatRoomPage
// - ✅ 修正重點：ChatRoomPage 沒有 currentUser 參數，所以不要再傳 currentUser:
//
// 依賴：cloud_firestore, firebase_auth, flutter/material
// 需要你專案已有：chat_room_page.dart（內含 ChatRoomPage，至少有 roomId/title 參數）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_room_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _db = FirebaseFirestore.instance;

  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatsStream(String uid) {
    return _db
        .collection('chats')
        .where('memberUids', arrayContains: uid)
        .snapshots();
  }

  String _peerName(Map<String, dynamic> d, String myUid) {
    final title = _s(d['title']);
    if (title.isNotEmpty) return title;

    final members = d['members'];
    if (members is Map) {
      for (final entry in members.entries) {
        final uid = entry.key?.toString() ?? '';
        if (uid.isEmpty || uid == myUid) continue;
        final info = entry.value;
        if (info is Map) {
          final name = _s(info['displayName'] ?? info['name']);
          if (name.isNotEmpty) return name;
        }
        return uid;
      }
    }

    final memberUids = d['memberUids'];
    if (memberUids is List) {
      for (final x in memberUids) {
        final uid = _s(x);
        if (uid.isNotEmpty && uid != myUid) return uid;
      }
    }

    return '(未命名聊天室)';
  }

  String? _peerPhotoUrl(Map<String, dynamic> d, String myUid) {
    final members = d['members'];
    if (members is Map) {
      for (final entry in members.entries) {
        final uid = entry.key?.toString() ?? '';
        if (uid.isEmpty || uid == myUid) continue;
        final info = entry.value;
        if (info is Map) {
          final url = _s(info['photoUrl'] ?? info['avatarUrl']);
          if (url.isNotEmpty) return url;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('聊天室')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 46,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '請先登入才能查看聊天室',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text('前往登入'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天室', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chatsStream(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('載入失敗：${snap.error}'),
              ),
            );
          }

          final docs = (snap.data?.docs ?? []).toList();

          // client-side 排序（避免缺索引）
          docs.sort((a, b) {
            final ad = a.data();
            final bd = b.data();
            final at =
                _toDate(ad['updatedAt']) ??
                _toDate(ad['createdAt']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bt =
                _toDate(bd['updatedAt']) ??
                _toDate(bd['createdAt']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bt.compareTo(at);
          });

          if (docs.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: cs.primary,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '目前沒有聊天室',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '當你和客服/廠商/會員開始對話後，就會出現在這裡。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();

              final title = _peerName(d, user.uid);
              final lastMsg = _s(d['lastMessage']);
              final time = _toDate(d['updatedAt']) ?? _toDate(d['createdAt']);
              final photoUrl = _peerPhotoUrl(d, user.uid);

              return Card(
                elevation: 0,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.surfaceContainerHighest,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? const Icon(Icons.person_outline)
                        : null,
                  ),
                  title: Text(
                    title.isEmpty ? '(未命名聊天室)' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    lastMsg.isEmpty ? '（尚無訊息）' : lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _fmtTime(time),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatRoomPage(
                          roomId: doc.id, // ✅ required
                          title: title, // ✅ required
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// lib/pages/friend_feed_page.dart
//
// ✅ FriendFeedPage（最終完整版｜可直接使用｜已修正 use_build_context_synchronously）
// - 修正：build(BuildContext context) 參數 context 的 async gap 後使用，改用 context.mounted guard
// - 功能：好友動態牆（示範）/ 搜尋 / 下拉更新 / 貼文操作 / 留言 BottomSheet
//
// 需要：cloud_firestore
// 若集合尚未建立，會顯示空狀態；可用右上角「✨」塞示範資料。

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FriendFeedPage extends StatefulWidget {
  const FriendFeedPage({super.key});

  @override
  State<FriendFeedPage> createState() => _FriendFeedPageState();
}

class _FriendFeedPageState extends State<FriendFeedPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _q = '';

  CollectionReference<Map<String, dynamic>> _feedRef() =>
      FirebaseFirestore.instance.collection('friend_feed_posts');

  // ✅ 會被「留言數 / 留言列表」實際使用
  CollectionReference<Map<String, dynamic>> _commentsRef(String postId) =>
      _feedRef().doc(postId).collection('comments');

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _q = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _queryPosts() {
    return _feedRef().orderBy('createdAt', descending: true).limit(50);
  }

  bool _matchSearch(Map<String, dynamic> data) {
    if (_q.isEmpty) return true;
    final s = _q.toLowerCase();
    final author = (data['author'] ?? '').toString().toLowerCase();
    final content = (data['content'] ?? '').toString().toLowerCase();
    return author.contains(s) || content.contains(s);
  }

  Future<void> _seedDemoIfEmpty() async {
    final snap = await _feedRef().limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final rand = Random();
    final batch = FirebaseFirestore.instance.batch();

    final demo = List.generate(6, (i) {
      final id = 'demo_${i + 1}';
      return <String, dynamic>{
        'id': id,
        'author': i.isEven ? '小美' : 'David',
        'avatarColor': i.isEven ? 0xFF9C27B0 : 0xFF2196F3,
        'content': i.isEven ? '今天跑了 5 公里，Osmile 手錶心率很穩！' : '剛收到 S5，睡眠報告很詳細，推薦～',
        'image': 'https://picsum.photos/seed/friend_${i + 1}/900/500',
        'likes': 10 + rand.nextInt(120),
        'liked': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
    });

    for (final p in demo) {
      final id = (p['id'] as String);
      final doc = _feedRef().doc(id);
      batch.set(doc, p, SetOptions(merge: true));

      final cRef = doc.collection('comments');
      final cCount = id.hashCode.abs() % 3; // 0~2
      for (int j = 0; j < cCount; j++) {
        batch.set(cRef.doc(), <String, dynamic>{
          'user': j.isEven ? '阿宏' : '小王',
          'text': '留言示範 $j',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('好友動態'),
        actions: [
          IconButton(
            tooltip: '塞示範資料（如原本為空）',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () async {
              await _seedDemoIfEmpty();

              // ✅ FIX: build() 參數 context 的 async gap 後使用 -> context.mounted
              if (!context.mounted) return;

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已嘗試建立示範資料（如原本為空）')));
              setState(() {});
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [_searchBar(), const SizedBox(height: 12), _feedList()],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: '搜尋作者或內容（示範）',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_q.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _searchCtrl.clear()),
            ),
        ],
      ),
    );
  }

  Widget _feedList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _queryPosts().snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        if (snap.hasError) return _emptyState('讀取失敗：${snap.error}');

        final docs = snap.data?.docs ?? [];
        final filtered = docs.where((d) => _matchSearch(d.data())).toList();
        if (filtered.isEmpty) return _emptyState('目前尚無好友動態');

        return Column(
          children: filtered.map((d) => _postCard(d.id, d.data())).toList(),
        );
      },
    );
  }

  Widget _postCard(String postId, Map<String, dynamic> data) {
    final author = (data['author'] ?? '').toString();
    final content = (data['content'] ?? '').toString();
    final image = (data['image'] ?? '').toString();
    final likes = (data['likes'] is num) ? (data['likes'] as num).toInt() : 0;
    final liked = data['liked'] == true;

    final avatarColorInt = (data['avatarColor'] is int)
        ? data['avatarColor'] as int
        : 0xFF9E9E9E;
    final avatarColor = Color(avatarColorInt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarColor,
                  child: Text(
                    author.isNotEmpty ? author[0] : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    author,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: '更多',
                  onPressed: () => _postActions(postId),
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
          ),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(content),
            ),
          if (image.isNotEmpty)
            SizedBox(
              height: 190,
              width: double.infinity,
              child: Image.network(image, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: Colors.pink,
                  ),
                  onPressed: () => _toggleLike(postId, data),
                ),
                Text('$likes'),
                const SizedBox(width: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _commentsRef(postId).snapshots(),
                  builder: (ctx, snap) {
                    final c = snap.data?.size ?? 0;
                    return TextButton.icon(
                      onPressed: () => _openCommentsBottomSheet(postId),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text('$c'),
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  tooltip: '分享',
                  onPressed: () => ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('分享（示範）'))),
                  icon: const Icon(Icons.share),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike(String postId, Map<String, dynamic> data) async {
    final liked = data['liked'] == true;
    final likes = (data['likes'] is num) ? (data['likes'] as num).toInt() : 0;

    setState(() {
      data['liked'] = !liked;
      data['likes'] = max(0, likes + (!liked ? 1 : -1));
    });

    try {
      await _feedRef().doc(postId).set({
        'liked': !liked,
        'likes': max(0, likes + (!liked ? 1 : -1)),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _postActions(String postId) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('查看留言'),
              onTap: () {
                Navigator.pop(context);
                _openCommentsBottomSheet(postId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('刪除貼文（示範）'),
              onTap: () async {
                Navigator.pop(context);

                try {
                  await _feedRef().doc(postId).delete();
                  if (!mounted) return;

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已刪除（示範）')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCommentsBottomSheet(String postId) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final ctrl = TextEditingController();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _commentsRef(postId)
                          .orderBy('createdAt', descending: true)
                          .limit(80)
                          .snapshots(),
                      builder: (ctx, snap) {
                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(child: Text('目前尚無留言'));
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 12),
                          itemBuilder: (_, i) {
                            final c = docs[i].data();
                            final user = (c['user'] ?? '匿名').toString();
                            final text = (c['text'] ?? '').toString();
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  child: Text(user.isNotEmpty ? user[0] : '?'),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(text),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: '寫下留言（示範）',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            final t = ctrl.text.trim();
                            if (t.isEmpty) return;
                            ctrl.clear();
                            await _commentsRef(postId).add({
                              'user': '我',
                              'text': t,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          },
                          child: const Text('送出'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.people_alt_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            Text(msg, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

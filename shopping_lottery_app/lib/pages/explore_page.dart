// lib/pages/explore_page.dart
//
// ✅ ExplorePage（最終完整版｜可直接使用｜已修正 lint）
// - ✅ 修正：use_build_context_synchronously（await 後不再使用 BuildContext；改用 messenger 先取出）
// - ✅ 修正：withOpacity(deprecated) → withValues(alpha: ...)
// - ✅ 保留：_commentsRef 實際使用（貼文卡片 StreamBuilder 讀留言數）
// - 功能：探索頁(示範) / 搜尋 / 分類 chips / 熱門貼文 / 進貼文詳情（可接你的頁）
//
// 依賴：cloud_firestore

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _q = '';
  String _category = '全部';

  final List<String> _categories = const [
    '全部',
    '新品',
    '運動',
    '健康',
    '穿搭',
    '3C',
    '社群',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _q = _searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> _postsRef() =>
      FirebaseFirestore.instance.collection('explore_posts');

  CollectionReference<Map<String, dynamic>> _commentsRef(String postId) =>
      FirebaseFirestore.instance
          .collection('explore_posts')
          .doc(postId)
          .collection('comments');

  Query<Map<String, dynamic>> _queryPosts() {
    Query<Map<String, dynamic>> q = _postsRef().orderBy(
      'hotScore',
      descending: true,
    );

    if (_category != '全部') {
      q = q.where('category', isEqualTo: _category);
    }

    return q.limit(30);
  }

  bool _matchSearch(Map<String, dynamic> data) {
    if (_q.isEmpty) return true;
    final s = _q.toLowerCase();
    final title = (data['title'] ?? '').toString().toLowerCase();
    final content = (data['content'] ?? '').toString().toLowerCase();
    final author = (data['author'] ?? '').toString().toLowerCase();
    return title.contains(s) || content.contains(s) || author.contains(s);
  }

  Future<void> _seedDemoIfEmpty() async {
    final snap = await _postsRef().limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final rand = Random();
    final batch = FirebaseFirestore.instance.batch();

    final demo = List.generate(6, (i) {
      final id = 'demo_${i + 1}';
      final category =
          _categories[(i % (_categories.length - 1)) + 1]; // skip 全部
      return {
        'id': id,
        'title': '探索熱門貼文 #${i + 1}',
        'content': '這是一段示範內容：Osmile 相關話題、產品體驗、健康分享等。',
        'author': i.isEven ? 'Osmile 官方' : '用戶${i + 1}',
        'category': category,
        'image': 'https://picsum.photos/seed/explore_${i + 1}/900/500',
        'hotScore': 1000 - i * 37 + rand.nextInt(50),
        'likes': 20 + rand.nextInt(200),
        'createdAt': FieldValue.serverTimestamp(),
      };
    });

    for (final p in demo) {
      final doc = _postsRef().doc(p['id'] as String);
      batch.set(doc, p, SetOptions(merge: true));

      final cRef = doc.collection('comments');
      for (int j = 0; j < (p['id'] as String).hashCode.abs() % 3; j++) {
        batch.set(cRef.doc(), {
          'user': '路人$j',
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
        title: const Text('探索'),
        actions: [
          IconButton(
            tooltip: '塞入示範資料',
            onPressed: () async {
              // ✅ 關鍵：await 前先取出 messenger，await 後不再用 context
              final messenger = ScaffoldMessenger.of(context);

              await _seedDemoIfEmpty();
              if (!mounted) return;

              messenger.showSnackBar(
                const SnackBar(content: Text('已嘗試建立示範資料（如原本為空）')),
              );
              setState(() {});
            },
            icon: const Icon(Icons.auto_awesome),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            _searchBar(),
            const SizedBox(height: 10),
            _categoryChips(),
            const SizedBox(height: 12),
            _hotPosts(),
          ],
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

  Widget _categoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = _categories[i];
          final active = c == _category;
          return ChoiceChip(
            label: Text(c),
            selected: active,
            onSelected: (_) => setState(() => _category = c),
            selectedColor: Colors.blue,
            labelStyle: TextStyle(
              color: active ? Colors.white : Colors.black87,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
            backgroundColor: const Color(0xFFF3F4F6),
          );
        },
      ),
    );
  }

  Widget _hotPosts() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _queryPosts().snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        if (snap.hasError) {
          return _emptyState('讀取失敗：${snap.error}');
        }
        final docs = snap.data?.docs ?? [];
        final filtered = docs.where((d) => _matchSearch(d.data())).toList();

        if (filtered.isEmpty) return _emptyState('目前沒有符合條件的內容');

        return Column(
          children: filtered.map((d) => _postCard(d.id, d.data())).toList(),
        );
      },
    );
  }

  Widget _postCard(String postId, Map<String, dynamic> data) {
    final title = (data['title'] ?? '').toString();
    final author = (data['author'] ?? '').toString();
    final category = (data['category'] ?? '').toString();
    final likes = (data['likes'] is num) ? (data['likes'] as num).toInt() : 0;
    final image = (data['image'] ?? '').toString();
    final content = (data['content'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPostDetail(postId, data),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image.isNotEmpty)
              SizedBox(
                height: 180,
                width: double.infinity,
                child: Image.network(image, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category.isEmpty ? '未分類' : category,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 18,
                            color: Colors.pink,
                          ),
                          const SizedBox(width: 6),
                          Text('$likes'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by $author',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _commentsRef(postId).snapshots(),
                    builder: (context, snap) {
                      final count = snap.data?.size ?? 0;
                      return Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$count 則留言',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _openCommentsBottomSheet(postId),
                            child: const Text('查看留言'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPostDetail(String postId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(
                  (data['title'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'by ${(data['author'] ?? '').toString()}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Text((data['content'] ?? '').toString()),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openCommentsBottomSheet(postId),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('留言區'),
                ),
              ],
            );
          },
        );
      },
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
                          .limit(50)
                          .snapshots(),
                      builder: (context, snap) {
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
                            final user = (c['user'] ?? '?').toString();
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  child: Text(user.isEmpty ? '?' : user[0]),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.isEmpty ? '匿名' : user,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text((c['text'] ?? '').toString()),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(color: Colors.white),
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
                            final text = ctrl.text.trim();
                            if (text.isEmpty) return;
                            ctrl.clear();
                            await _commentsRef(postId).add({
                              'user': '我',
                              'text': text,
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
            const Icon(Icons.travel_explore, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            Text(msg, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

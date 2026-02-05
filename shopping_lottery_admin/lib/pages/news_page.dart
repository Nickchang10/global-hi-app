// lib/pages/news_page.dart
//
// ✅ NewsPage（最終穩定可編譯完整版｜清單 + 點擊進詳情）
// ------------------------------------------------------------
// Route: /news
// 點擊：Navigator.pushNamed('/news_detail', arguments: id)
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  static const String routeName = '/news';

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final _coll = FirebaseFirestore.instance.collection('news');

  void _goDetail(String id) {
    final newsId = id.trim();
    if (newsId.isEmpty) return;
    Navigator.pushNamed(context, '/news_detail', arguments: newsId);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('最新消息'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _coll.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return _ErrorBody(
              '讀取失敗：${snap.error}\n\n提示：請確認 rules 已開放 /news read，且每筆都有 createdAt(Timestamp)。',
            );
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const _EmptyBody();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final id = docs[i].id;

              final title = (data['title'] ?? '').toString().trim();
              final summary = (data['summary'] ?? '').toString().trim();
              final imageUrl = (data['imageUrl'] ?? '').toString().trim();

              final ts = data['createdAt'];
              final dt = ts is Timestamp ? ts.toDate() : null;
              final dateStr = dt != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(dt)
                  : '—';

              return Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (kDebugMode) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('點擊了：${title.isEmpty ? id : title}（id=$id）'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                    _goDetail(id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              imageUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 80,
                                height: 80,
                                color: cs.surfaceVariant.withOpacity(0.2),
                                child: const Icon(Icons.image_not_supported),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 80,
                            height: 80,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: cs.surfaceVariant.withOpacity(0.15),
                              border: Border.all(color: cs.outline.withOpacity(0.12)),
                            ),
                            child: const Icon(Icons.newspaper_outlined),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isEmpty ? '(未命名)' : title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                summary.isEmpty ? '(暫無摘要內容)' : summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dateStr,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.outline),
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
        },
      ),
      bottomNavigationBar: kDebugMode
          ? Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: const Text(
                'Debug：collection=news orderBy=createdAt desc',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            )
          : null,
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '目前尚無最新消息，請稍後再查看。',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody(this.message);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: TextStyle(color: cs.error, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

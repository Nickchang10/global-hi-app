// lib/pages/news_home_page.dart
//
// ✅ NewsHomePage（可編譯完整版｜修正：surfaceVariant deprecated → surfaceContainerHighest）
// ------------------------------------------------------------
// - 讀取 site_contents (category=news) 顯示最新消息列表
// - 點擊導向 detail route（預設 /news/detail）
// - 支援簡單搜尋
//
// Firestore 建議欄位：
// - title(String)
// - body(String) / plainText(String) 可選
// - imageUrl(String) 或 images(List<String>) / imageUrls(List<String>) 任一
// - updatedAt(Timestamp) 或 createdAt(Timestamp)
//
// 導頁：Navigator.pushNamed('/news/detail', arguments: {'newsId': id})

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NewsHomePage extends StatefulWidget {
  const NewsHomePage({
    super.key,
    this.collection = 'site_contents',
    this.category = 'news',
    this.routeName = '/news/detail',
    this.limit = 50,
  });

  final String collection;
  final String category;
  final String routeName;
  final int limit;

  @override
  State<NewsHomePage> createState() => _NewsHomePageState();
}

class _NewsHomePageState extends State<NewsHomePage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();

  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return null;
  }

  String _pickImage(Map<String, dynamic> d) {
    final img = _s(d['imageUrl']);
    if (img.isNotEmpty) return img;

    final images = d['images'];
    if (images is List && images.isNotEmpty) {
      final first = _s(images.first);
      if (first.isNotEmpty) return first;
    }

    final imageUrls = d['imageUrls'];
    if (imageUrls is List && imageUrls.isNotEmpty) {
      final first = _s(imageUrls.first);
      if (first.isNotEmpty) return first;
    }

    return '';
  }

  String _pickBodyPreview(Map<String, dynamic> d) {
    final p = _s(d['plainText']);
    if (p.isNotEmpty) return p;
    final b = _s(d['body']);
    if (b.isNotEmpty) return b;
    return '';
  }

  Query<Map<String, dynamic>> _buildQuery({required bool useUpdatedAt}) {
    final col = _db.collection(widget.collection);
    final base = col.where('category', isEqualTo: widget.category);
    if (useUpdatedAt) {
      return base.orderBy('updatedAt', descending: true).limit(widget.limit);
    }
    return base.orderBy('createdAt', descending: true).limit(widget.limit);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openNews(
    BuildContext context,
    String newsId,
    Map<String, dynamic> data,
  ) {
    Navigator.pushNamed(
      context,
      widget.routeName,
      arguments: {'newsId': newsId, 'data': data},
    );
  }

  bool _matchKeyword(String keyword, String id, Map<String, dynamic> d) {
    if (keyword.isEmpty) return true;
    final k = keyword.toLowerCase();

    String s(dynamic v) => _s(v).toLowerCase();
    return id.toLowerCase().contains(k) ||
        s(d['title']).contains(k) ||
        s(d['plainText']).contains(k) ||
        s(d['body']).contains(k);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ surfaceVariant deprecated → surfaceContainerHighest
    final fallbackBg = cs.surfaceContainerHighest;

    final keyword = _searchCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('最新消息')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋：標題 / 內容 / id',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  tooltip: '清除',
                  onPressed: () {
                    _searchCtrl.clear();
                    FocusScope.of(context).unfocus();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery(useUpdatedAt: true).snapshots(),
              builder: (context, snap) {
                // updatedAt query 若噴錯（缺 index/欄位不一致）則 fallback createdAt
                if (snap.hasError) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _buildQuery(useUpdatedAt: false).snapshots(),
                    builder: (context, snap2) {
                      return _buildList(
                        context,
                        snap2,
                        cs,
                        fallbackBg,
                        keyword,
                      );
                    },
                  );
                }
                return _buildList(context, snap, cs, fallbackBg, keyword);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
    ColorScheme cs,
    Color fallbackBg,
    String keyword,
  ) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snap.hasError) {
      return Center(
        child: Text('讀取失敗：${snap.error}', style: TextStyle(color: cs.error)),
      );
    }

    final docs = snap.data?.docs ?? [];
    final rows = docs
        .where((d) => _matchKeyword(keyword, d.id, d.data()))
        .toList(growable: false);

    if (rows.isEmpty) {
      return Center(
        child: Text('沒有資料', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final doc = rows[i];
        final d = doc.data();

        final title = _s(d['title']).isNotEmpty ? _s(d['title']) : '（未命名）';
        final body = _pickBodyPreview(d);
        final image = _pickImage(d);

        final dt = _toDate(d['updatedAt']) ?? _toDate(d['createdAt']);
        final dateText = dt == null
            ? ''
            : '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

        return Card(
          elevation: 0.6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openNews(context, doc.id, d),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 96,
                      height: 72,
                      child: image.isEmpty
                          ? Container(
                              color: fallbackBg,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                              ),
                            )
                          : Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: fallbackBg,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                              loadingBuilder: (_, child, ev) => ev == null
                                  ? child
                                  : Container(
                                      color: fallbackBg,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dateText.isNotEmpty)
                          Text(
                            dateText,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

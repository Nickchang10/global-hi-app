// lib/pages/news_home_carousel.dart
//
// ✅ NewsHomeCarousel（可編譯完整版｜修正：不再缺 newsId｜修正：surfaceVariant / withOpacity deprecated）
// ------------------------------------------------------------
// - 從 Firestore 讀取最新消息並顯示輪播
// - 點擊輪播：用 Navigator.pushNamed 丟出 newsId
// - 預設資料來源：collection = site_contents，category = news
//
// Firestore 建議欄位：
// - title(String)
// - body(String) 可選
// - imageUrl(String) 或 images(List<String>) / imageUrls(List<String>) 任一
// - updatedAt(Timestamp) 或 createdAt(Timestamp) 任一
//
// 導頁：
// - 預設 pushNamed('/news/detail', arguments: {'newsId': id})

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NewsHomeCarousel extends StatefulWidget {
  const NewsHomeCarousel({
    super.key,
    this.collection = 'site_contents',
    this.category = 'news',
    this.limit = 5,
    this.height = 220,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.onOpenNews,
    this.routeName = '/news/detail',
  });

  final String collection;
  final String category;
  final int limit;
  final double height;

  final bool autoPlay;
  final Duration autoPlayInterval;

  /// 自訂點擊開啟新聞
  final void Function(
    BuildContext context,
    String newsId,
    Map<String, dynamic> data,
  )?
  onOpenNews;

  /// 預設的 routeName（pushNamed，帶 arguments）
  final String routeName;

  @override
  State<NewsHomeCarousel> createState() => _NewsHomeCarouselState();
}

class _NewsHomeCarouselState extends State<NewsHomeCarousel> {
  final _db = FirebaseFirestore.instance;
  final _pageCtrl = PageController();

  Timer? _timer;
  int _index = 0;

  int _lastItemCount = -1; // ✅ 避免反覆 start autoplay

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

  /// ✅ 建立 query：優先 updatedAt，若沒有 updatedAt index/欄位造成錯誤則 fallback createdAt
  Query<Map<String, dynamic>> _buildQuery({required bool useUpdatedAt}) {
    final col = _db.collection(widget.collection);
    final base = col.where('category', isEqualTo: widget.category);

    if (useUpdatedAt) {
      return base.orderBy('updatedAt', descending: true).limit(widget.limit);
    }
    return base.orderBy('createdAt', descending: true).limit(widget.limit);
  }

  void _startAutoPlay(int itemCount) {
    if (_lastItemCount == itemCount && _timer != null) return; // ✅ 不重啟
    _lastItemCount = itemCount;

    _timer?.cancel();
    if (!widget.autoPlay) return;
    if (itemCount <= 1) return;

    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted) return;
      _index = (_index + 1) % itemCount;
      _pageCtrl.animateToPage(
        _index,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
      );
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _openNews(
    BuildContext context,
    String newsId,
    Map<String, dynamic> data,
  ) {
    if (widget.onOpenNews != null) {
      widget.onOpenNews!(context, newsId, data);
      return;
    }

    Navigator.pushNamed(
      context,
      widget.routeName,
      arguments: {'newsId': newsId, 'data': data},
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ Flutter 3.18+：surfaceVariant deprecated → surfaceContainerHighest
    final fallbackBg = cs.surfaceContainerHighest;

    // 先用 updatedAt query；如果 snapshot error（常見：缺 index / 欄位不一致）就 fallback createdAt
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _buildQuery(useUpdatedAt: true).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _buildQuery(useUpdatedAt: false).snapshots(),
            builder: (context, snap2) {
              return _buildBody(
                context,
                snap2,
                cs,
                fallbackBg,
                queryError: snap.error,
              );
            },
          );
        }

        return _buildBody(context, snap, cs, fallbackBg);
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
    ColorScheme cs,
    Color fallbackBg, {
    Object? queryError,
  }) {
    if (snap.connectionState == ConnectionState.waiting) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (snap.hasError) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            '載入輪播失敗：${snap.error}',
            style: TextStyle(color: cs.error),
          ),
        ),
      );
    }

    final docs = snap.data?.docs ?? [];
    if (docs.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text('尚無最新消息', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startAutoPlay(docs.length);
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final doc = docs[i];
                final d = doc.data();

                final title = _s(d['title']).isNotEmpty
                    ? _s(d['title'])
                    : '（未命名）';
                final body = _s(d['body']);
                final image = _pickImage(d);

                final dt = _toDate(d['updatedAt']) ?? _toDate(d['createdAt']);
                final dateText = dt == null
                    ? ''
                    : '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

                return InkWell(
                  onTap: () => _openNews(context, doc.id, d),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image.isNotEmpty)
                        Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: fallbackBg,
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                          loadingBuilder: (_, child, ev) {
                            if (ev == null) return child;
                            return Container(
                              color: fallbackBg,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          color: fallbackBg,
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        ),

                      // overlay
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              // ✅ withOpacity deprecated → withValues(alpha:)
                              Colors.black.withValues(
                                alpha: 38,
                              ), // 0.15 * 255 ≈ 38
                              Colors.black.withValues(
                                alpha: 153,
                              ), // 0.60 * 255 ≈ 153
                            ],
                          ),
                        ),
                      ),

                      // text
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (dateText.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  // ✅ 0.35 * 255 ≈ 89
                                  color: Colors.black.withValues(alpha: 89),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  dateText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  // ✅ white70 也可以保留；若你也要避掉 opacity，可用 withValues(alpha: 179)
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),

        // dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(docs.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? cs.primary : cs.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),

        if (queryError != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '（已自動改用 createdAt 排序：$queryError）',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

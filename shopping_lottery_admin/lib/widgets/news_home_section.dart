// lib/widgets/news_home_section.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 首頁最新消息輪播（Carousel）
/// - Firestore collection: news
/// - 條件：isActive == true
/// - 排序：date desc
/// - 筆數：limit (預設 5)
///
/// 支援：
/// - 自動輪播
/// - 指示點
/// - 點擊預設彈出 Dialog（也可用 onTapItem 自訂跳頁）
class NewsHomeSection extends StatefulWidget {
  const NewsHomeSection({
    super.key,
    this.collectionPath = 'news',
    this.limit = 5,
    this.height = 170,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.viewportFraction = 0.92,
    this.onTapItem,
    this.onTapMore,
    this.title = '最新消息',
    this.moreText = '查看全部',
  });

  final String collectionPath;
  final int limit;
  final double height;
  final Duration autoPlayInterval;
  final double viewportFraction;

  /// 點擊某一則消息（若不傳，預設顯示 Dialog 預覽）
  final void Function(BuildContext context, String id, Map<String, dynamic> data)? onTapItem;

  /// 右上角「查看全部」
  final VoidCallback? onTapMore;

  final String title;
  final String moreText;

  @override
  State<NewsHomeSection> createState() => _NewsHomeSectionState();
}

class _NewsHomeSectionState extends State<NewsHomeSection> {
  PageController? _pc;
  Timer? _timer;
  int _index = 0;

  // 用來避免使用者手動滑動時被 Timer 搶走
  bool _userDragging = false;

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: widget.viewportFraction);
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _pc?.dispose();
    super.dispose();
  }

  void _startAutoPlay({required int itemCount}) {
    _stopAutoPlay();
    if (itemCount <= 1) return;

    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted) return;
      if (_userDragging) return;
      final next = (_index + 1) % itemCount;

      _pc?.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _stopAutoPlay() {
    _timer?.cancel();
    _timer = null;
  }

  Query<Map<String, dynamic>> _query() {
    // 你原本 NewsPage 用：orderBy('date', descending: true)
    // 這裡延續同樣規格（date 可以是 Timestamp 或 String，顯示時會自動處理）
    return FirebaseFirestore.instance
        .collection(widget.collectionPath)
        .where('isActive', isEqualTo: true)
        .orderBy('date', descending: true)
        .limit(widget.limit);
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _formatDate(dynamic v) {
    if (v == null) return '';
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    // 若 date 是字串（例如 2025-12-24）
    final s = _s(v);
    return s;
  }

  /// 嘗試挑一張可用圖片 URL
  /// 常見欄位：imageUrl / coverUrl / bannerUrl / thumbUrl / primaryImage.url / images[0].url
  String _pickImageUrl(Map<String, dynamic> data) {
    final direct = _s(data['imageUrl']);
    if (direct.isNotEmpty) return direct;

    final cover = _s(data['coverUrl']);
    if (cover.isNotEmpty) return cover;

    final banner = _s(data['bannerUrl']);
    if (banner.isNotEmpty) return banner;

    final thumb = _s(data['thumbUrl']);
    if (thumb.isNotEmpty) return thumb;

    final primary = data['primaryImage'];
    if (primary is Map) {
      final u = _s(primary['url']);
      if (u.isNotEmpty) return u;
    }

    final images = data['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is String) {
        final u = first.trim();
        if (u.isNotEmpty) return u;
      }
      if (first is Map) {
        final u = _s(first['url']);
        if (u.isNotEmpty) return u;
      }
    }

    final legacy = data['imagesUrls'];
    if (legacy is List && legacy.isNotEmpty) {
      final u = _s(legacy.first);
      if (u.isNotEmpty) return u;
    }

    return '';
  }

  Future<void> _defaultPreview(BuildContext context, String id, Map<String, dynamic> data) async {
    final title = _s(data['title']).isEmpty ? '（未命名）' : _s(data['title']);
    final cat = _s(data['category']).isEmpty ? '最新消息' : _s(data['category']);
    final date = _formatDate(data['date']);
    final content = _s(data['content']).isEmpty ? _s(data['body']) : _s(data['content']);

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$cat｜$date', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Text(content.isEmpty ? '（此公告沒有內容）' : content),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _query().snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _loading(cs);
        }
        if (snap.hasError) {
          return _error(cs, '${snap.error}');
        }

        final docs = snap.data?.docs ?? const [];
        final items = docs.map((d) => {'id': d.id, ...d.data()}).toList();

        if (items.isEmpty) {
          return _empty(cs);
        }

        // 啟動/更新自動輪播
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _startAutoPlay(itemCount: items.length);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                TextButton(
                  onPressed: widget.onTapMore,
                  child: Text(widget.moreText),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Carousel
            SizedBox(
              height: widget.height,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollStartNotification) _userDragging = true;
                  if (n is ScrollEndNotification) _userDragging = false;
                  return false;
                },
                child: PageView.builder(
                  controller: _pc,
                  itemCount: items.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) {
                    final data = Map<String, dynamic>.from(items[i]);
                    final id = _s(data['id']);
                    final title = _s(data['title']).isEmpty ? '（未命名）' : _s(data['title']);
                    final cat = _s(data['category']).isEmpty ? '最新消息' : _s(data['category']);
                    final date = _formatDate(data['date']);
                    final isHot = (data['isHot'] ?? false) == true;
                    final img = _pickImageUrl(data);

                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _BannerCard(
                        title: title,
                        category: cat,
                        date: date,
                        imageUrl: img,
                        isHot: isHot,
                        onTap: () {
                          final cb = widget.onTapItem;
                          if (cb != null) {
                            cb(context, id, data);
                          } else {
                            _defaultPreview(context, id, data);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? cs.primary : cs.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _loading(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Text(widget.moreText, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ],
    );
  }

  Widget _empty(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            TextButton(onPressed: widget.onTapMore, child: Text(widget.moreText)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text('目前沒有最新消息', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _error(ColorScheme cs, String msg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            TextButton(onPressed: widget.onTapMore, child: Text(widget.moreText)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: widget.height,
          padding: const EdgeInsets.all(12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: cs.errorContainer.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text('讀取公告失敗：$msg', style: TextStyle(color: cs.onErrorContainer)),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.title,
    required this.category,
    required this.date,
    required this.imageUrl,
    required this.isHot,
    required this.onTap,
  });

  final String title;
  final String category;
  final String date;
  final String imageUrl;
  final bool isHot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasImg = imageUrl.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: cs.surfaceVariant.withOpacity(0.18),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              if (hasImg)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: cs.surfaceVariant.withOpacity(0.3)),
                )
              else
                Container(color: cs.surfaceVariant.withOpacity(0.3)),

              // Gradient overlay
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // tags
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.surface.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        if (isHot)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.errorContainer.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text('熱門', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onErrorContainer)),
                          ),
                        const Spacer(),
                        Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.9)),
                      ],
                    ),

                    const Spacer(),

                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      date.isEmpty ? '' : date,
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

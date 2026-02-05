import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'news_detail_page.dart';
import 'news_page.dart';

class NewsHomeCarousel extends StatefulWidget {
  const NewsHomeCarousel({super.key});

  @override
  State<NewsHomeCarousel> createState() => _NewsHomeCarouselState();
}

class _NewsHomeCarouselState extends State<NewsHomeCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.9);
  int _current = 0;
  late final PageController _pageController;
  late final ValueNotifier<int> _pageIndex;
  late final PageController _autoPageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _pageIndex = ValueNotifier<int>(0);

    // 自動播放定時器
    _autoPageController = _pageController;
    Future.delayed(const Duration(seconds: 3), _autoPlay);
  }

  void _autoPlay() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) break;
      if (_autoPageController.hasClients) {
        final nextPage = (_autoPageController.page?.round() ?? 0) + 1;
        _autoPageController.animateToPage(
          nextPage % 5,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final query = FirebaseFirestore.instance
        .collection('news')
        .where('isActive', isEqualTo: true)
        .orderBy('date', descending: true)
        .limit(5);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('目前沒有最新消息')),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _pageController,
                itemCount: docs.length,
                onPageChanged: (index) => _pageIndex.value = index,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final title = data['title'] ?? '';
                  final date = data['date'] ?? '';
                  final category = data['category'] ?? '';
                  final imageUrl = data['imageUrl'] ?? '';
                  final isHot = data['isHot'] ?? false;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NewsDetailPage(id: docs[index].id, data: data),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: cs.surfaceVariant.withOpacity(0.2),
                        image: imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(
                                    Colors.black.withOpacity(0.3),
                                    BlendMode.darken),
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 16,
                            bottom: 20,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isHot)
                                  const Icon(Icons.local_fire_department,
                                      color: Colors.red, size: 20),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$category｜$date',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: _pageIndex,
              builder: (_, value, __) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    docs.length,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            i == value ? cs.primary : cs.outlineVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.newspaper_outlined),
              label: const Text('查看更多消息'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewsPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

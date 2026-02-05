import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ShopBannerCarousel extends StatefulWidget {
  final double height;
  final BorderRadius borderRadius;
  final int limit;

  const ShopBannerCarousel({
    super.key,
    this.height = 160,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.limit = 10,
  });

  @override
  State<ShopBannerCarousel> createState() => _ShopBannerCarouselState();
}

class _ShopBannerCarouselState extends State<ShopBannerCarousel> {
  final _pageController = PageController(viewportFraction: 0.92);
  int _index = 0;

  DocumentReference<Map<String, dynamic>> get _appCenterRef =>
      FirebaseFirestore.instance.collection('app_config').doc('app_center');

  Query<Map<String, dynamic>> get _bannersQuery => FirebaseFirestore.instance
      .collection('shop_config')
      .doc('banners')
      .collection('items')
      .where('enabled', isEqualTo: true)
      .orderBy('order')
      .limit(widget.limit);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 先讀 app_center 的 bannerEnabled（總開關）
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _appCenterRef.snapshots(),
      builder: (context, appSnap) {
        // 文件不存在時，預設視為 true（不擋住前台）
        final appData = appSnap.data?.data();
        final bannerEnabled = (appData?['bannerEnabled'] ?? true) == true;

        if (!bannerEnabled) return const SizedBox.shrink();

        // 再讀 banners/items（啟用的 Banner 清單）
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _bannersQuery.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              // 載入中給一個占位高度，避免畫面跳動
              return SizedBox(height: widget.height);
            }
            if (snap.hasError) {
              return const SizedBox.shrink();
            }

            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();

            // 防止 index 超界（例如後台刪除 banner）
            if (_index >= docs.length) _index = 0;

            return Column(
              children: [
                SizedBox(
                  height: widget.height,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: docs.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final m = docs[i].data();
                      final title = (m['title'] ?? '').toString();
                      final imageUrl = (m['imageUrl'] ?? '').toString();
                      final link = (m['link'] ?? '').toString();

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: widget.borderRadius,
                          child: Material(
                            color: Colors.white,
                            child: InkWell(
                              onTap: () => _onTapBanner(context, link),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (imageUrl.isNotEmpty)
                                    Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _fallbackBg(),
                                    )
                                  else
                                    _fallbackBg(),
                                  // 漸層遮罩 + 標題（可拿掉）
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.55),
                                          ],
                                        ),
                                      ),
                                      child: Text(
                                        title.isEmpty ? ' ' : title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                _Dots(count: docs.length, index: _index),
              ],
            );
          },
        );
      },
    );
  }

  Widget _fallbackBg() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.grey.shade400,
            Colors.grey.shade200,
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 40, color: Colors.white70),
      ),
    );
  }

  void _onTapBanner(BuildContext context, String link) {
    // 先支援站內路由：例如 /shop /product/xxx 之類
    if (link.startsWith('/')) {
      Navigator.pushNamed(context, link);
      return;
    }

    // 沒裝 url_launcher 前，先用提示避免編譯/依賴問題
    if (link.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('外部連結尚未啟用（可改用 url_launcher）')),
      );
    }
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;

  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: selected ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? Colors.black87 : Colors.black26,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

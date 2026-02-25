// lib/widgets/shop_banner_carousel.dart
//
// ✅ ShopBannerCarousel（最終可編譯版）
// ------------------------------------------------------------
// 修正：withOpacity(deprecated) → withValues(alpha: ...)
// - 你報錯位置：line ~117（通常是 BoxShadow / color / overlay 在用 withOpacity）
// ------------------------------------------------------------

import 'dart:async';
import 'package:flutter/material.dart';

class ShopBannerCarousel extends StatefulWidget {
  const ShopBannerCarousel({
    super.key,
    this.height = 160,
    this.autoPlay = true,
    this.interval = const Duration(seconds: 5),
  });

  final double height;
  final bool autoPlay;
  final Duration interval;

  @override
  State<ShopBannerCarousel> createState() => _ShopBannerCarouselState();
}

class _ShopBannerCarouselState extends State<ShopBannerCarousel> {
  final PageController _pc = PageController(viewportFraction: 0.92);
  int _idx = 0;
  Timer? _timer;

  // ✅ 可改成從 Firestore / Remote Config 取得
  final List<_BannerItem> _items = const [
    _BannerItem(
      title: '限時優惠｜ED1000 免運',
      subtitle: '活動期間下單即享免運與加碼點數',
      tag: 'HOT',
      icon: Icons.local_fire_department_rounded,
    ),
    _BannerItem(
      title: '抽獎週開跑',
      subtitle: '完成任務獲得票券，抽好禮！',
      tag: 'NEW',
      icon: Icons.casino_rounded,
    ),
    _BannerItem(
      title: '點數商城上線',
      subtitle: '用點數兌換優惠券與好禮',
      tag: 'POINTS',
      icon: Icons.stars_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  void _startAuto() {
    _timer?.cancel();
    if (!widget.autoPlay || _items.isEmpty) return;

    _timer = Timer.periodic(widget.interval, (_) {
      if (!_pc.hasClients || _items.isEmpty) return;
      final next = (_idx + 1) % _items.length;
      _pc.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void didUpdateWidget(covariant ShopBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.interval != widget.interval) {
      _startAuto();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pc,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _idx = i),
            itemBuilder: (_, i) {
              final it = _items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _card(it),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _items.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _idx == i ? 14 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: _idx == i ? Colors.blueAccent : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(_BannerItem it) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Colors.blueAccent, Colors.purpleAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            // ✅ withOpacity → withValues(alpha: ...)
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Expanded(child: _text(it)),
            const SizedBox(width: 10),
            Icon(it.icon, size: 44, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _text(_BannerItem it) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            if (it.tag.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  // ✅ withOpacity → withValues(alpha: ...)
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  it.tag,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          it.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          it.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _BannerItem {
  const _BannerItem({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
}

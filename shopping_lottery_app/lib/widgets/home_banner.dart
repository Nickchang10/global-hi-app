// lib/widgets/home_banner.dart
//
// ✅ HomeBanner（首頁輪播 Banner｜最終完整版｜已修正 withOpacity -> withValues(alpha: ...)）
//
// 使用方式：直接放在首頁 ListView / CustomScrollView 內即可
// - 不依賴外部套件
// - Web / App 皆可用
//

import 'dart:async';
import 'package:flutter/material.dart';

class HomeBanner extends StatefulWidget {
  const HomeBanner({super.key});

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  final PageController _pc = PageController(viewportFraction: 0.94);
  Timer? _timer;
  int _idx = 0;

  // 你可改成從遠端或 Firestore 取資料
  final List<_BannerItem> _items = const [
    _BannerItem(
      title: '新春限定優惠',
      subtitle: '指定商品最高 9 折，結帳再送抽獎券',
      icon: Icons.local_fire_department_rounded,
      c1: Color(0xFF2563EB),
      c2: Color(0xFF7C3AED),
      tag: '限時',
    ),
    _BannerItem(
      title: '抽獎週進行中',
      subtitle: '每日任務集點，轉盤抽 ED1000 周邊',
      icon: Icons.casino_outlined,
      c1: Color(0xFF0EA5E9),
      c2: Color(0xFF22C55E),
      tag: '熱門',
    ),
    _BannerItem(
      title: '點數商城上線',
      subtitle: '點數可兌換折價券、好禮與加值服務',
      icon: Icons.redeem_outlined,
      c1: Color(0xFFF97316),
      c2: Color(0xFFEF4444),
      tag: '新功能',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pc.hasClients || _items.isEmpty) return;
      final next = (_idx + 1) % _items.length;
      _pc.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '✨ 推薦活動',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pc,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _idx = i),
            itemBuilder: (_, i) {
              final b = _items[i];
              return _card(context, b);
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
              width: _idx == i ? 16 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _idx == i ? Colors.blueAccent : Colors.grey[400],
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, _BannerItem b) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [b.c1, b.c2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            // ✅ withOpacity(deprecated) → withValues(alpha: ...)
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          // 需要跳頁可自行改成 pushNamed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('點擊：${b.title}'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(milliseconds: 900),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Expanded(child: _text(b)),
              const SizedBox(width: 10),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(b.icon, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _text(_BannerItem b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (b.tag.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              b.tag,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        Text(
          b.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          b.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.2,
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
    required this.icon,
    required this.c1,
    required this.c2,
    this.tag = '',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color c1;
  final Color c2;
  final String tag;
}

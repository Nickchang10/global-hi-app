// lib/widgets/dashboard_events_banner.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// 🎉 儀表板上方「即時活動輪播」Banner
///
/// 功能：
/// - 自動輪播活動卡片
/// - 支援左右滑動
/// - 下方小點顯示當前頁面
class DashboardEventsBanner extends StatefulWidget {
  const DashboardEventsBanner({super.key});

  @override
  State<DashboardEventsBanner> createState() => _DashboardEventsBannerState();
}

class _DashboardEventsBannerState extends State<DashboardEventsBanner> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;
  Timer? _timer;

  // 🔔 可之後改成從後端 / 設定檔抓
  final List<Map<String, String>> _events = [
    {
      "title": "🎄 聖誕活動倒數",
      "subtitle": "每日簽到加倍送，完成 3 個任務再抽 ED1000！",
      "tag": "限時活動",
    },
    {
      "title": "🎰 抽獎週進行中",
      "subtitle": "轉盤抽獎中獎機率提升中，快來試試手氣～",
      "tag": "抽獎週",
    },
    {
      "title": "🛒 智慧照護專區 9 折",
      "subtitle": "ED1000、Lumi 2、體脂秤限定優惠中！",
      "tag": "商城優惠",
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pageController.hasClients || _events.isEmpty) return;
      final next = (_currentPage + 1) % _events.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            "🔥 即時活動 / 預告",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _events.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, index) {
              final e = _events[index];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueAccent.withOpacity(0.9),
                      Colors.purpleAccent.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildEventText(e),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _events.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == index ? 14 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? Colors.blueAccent
                    : Colors.grey[400],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventText(Map<String, String> e) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (e["tag"] != null && e["tag"]!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              e["tag"]!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Text(
          e["title"] ?? "",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          e["subtitle"] ?? "",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

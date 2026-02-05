import 'package:flutter/material.dart';
import 'package:flutter_swiper_null_safety/flutter_swiper_null_safety.dart';

/// 🎡 首頁活動 Banner 輪播
class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final banners = [
      {
        "image": "https://picsum.photos/800/300?random=101",
        "title": "限時抽獎活動 🎁",
        "desc": "參加活動贏 Osmile 智慧手錶！"
      },
      {
        "image": "https://picsum.photos/800/300?random=102",
        "title": "新品上市 🚀",
        "desc": "ED1000 本週特價 \$3990！"
      },
      {
        "image": "https://picsum.photos/800/300?random=103",
        "title": "邀請好友 🤝",
        "desc": "邀請好友一起來抽獎拿積分～"
      },
    ];

    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Swiper(
        itemCount: banners.length,
        autoplay: true,
        pagination: const SwiperPagination(),
        itemBuilder: (context, index) {
          final banner = banners[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(banner["image"]!, fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 14,
                  left: 14,
                  right: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner["title"]!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        banner["desc"]!,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

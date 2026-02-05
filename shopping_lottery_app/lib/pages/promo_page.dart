import 'package:flutter/material.dart';
import 'lottery_page.dart';

class PromoPage extends StatelessWidget {
  const PromoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final promos = [
      {
        "title": "雙 11 購物節",
        "desc": "全館 85 折，滿 3000 再送 500 購物金",
        "image": "assets/images/promo1.png"
      },
      {
        "title": "Osmile 健康週",
        "desc": "智慧手錶系列全面 9 折，限時 3 天！",
        "image": "assets/images/promo2.png"
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("優惠活動"),
        backgroundColor: const Color(0xFF007BFF),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final p in promos)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              clipBehavior: Clip.hardEdge,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(p["image"]!, height: 160, fit: BoxFit.cover),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p["title"]!,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(p["desc"]!),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LotteryPage()),
                          ),
                          icon: const Icon(Icons.casino),
                          label: const Text("立即抽獎"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007BFF),
                              foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }
}

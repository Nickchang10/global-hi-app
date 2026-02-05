import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cart_service.dart';

class Ed1000IntroPage extends StatefulWidget {
  const Ed1000IntroPage({super.key});

  @override
  State<Ed1000IntroPage> createState() => _Ed1000IntroPageState();
}

class _Ed1000IntroPageState extends State<Ed1000IntroPage> {
  final CartService _cart = CartService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("ED1000 智能手錶"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頂部圖片 Banner
            Stack(
              children: [
                Image.network(
                  "https://images.unsplash.com/photo-1512499617640-c2f999098c1a?auto=format&fit=crop&w=1200&q=80",
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 20,
                  left: 20,
                  child: Text(
                    "ED1000 智能手錶",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(1, 1),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 商品簡介
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "智慧健康・安全守護・展場熱銷中！",
                style: GoogleFonts.notoSansTc(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "ED1000 是一款融合健康偵測與 SOS 求助功能的智慧手錶，適合長輩與孩童使用。透過手機 App，家人可即時查看健康狀況與定位。",
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),

            const SizedBox(height: 20),

            // 特色區塊
            _buildFeatureSection(),

            const SizedBox(height: 16),

            // 影片展示（可放產品影片）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black12,
                  height: 180,
                  child: const Center(
                    child: Icon(Icons.play_circle_fill,
                        size: 60, color: Colors.blueAccent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "（此區可嵌入產品影片或操作介紹）",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 24),

            // 規格表
            _buildSpecSection(),

            const SizedBox(height: 24),
          ],
        ),
      ),

      // 底部購買欄
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text("加入購物車"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.blueAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onPressed: () {
                    _cart.addProduct({
                      "name": "ED1000 智能手錶",
                      "price": 3990,
                      "image":
                          "https://images.unsplash.com/photo-1512499617640-c2f999098c1a?auto=format&fit=crop&w=800&q=80",
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("ED1000 已加入購物車")),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.payment),
                  label: const Text("立即購買"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("結帳流程 Demo 中")),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 特色區塊
  Widget _buildFeatureSection() {
    final features = [
      {
        "icon": Icons.health_and_safety_outlined,
        "title": "健康監測",
        "desc": "支援心率、血氧、步數與睡眠追蹤，24 小時健康守護。"
      },
      {
        "icon": Icons.sos_outlined,
        "title": "SOS 緊急求助",
        "desc": "長按側邊按鈕即可一鍵求助，App 端即時通知家人。"
      },
      {
        "icon": Icons.location_on_outlined,
        "title": "GPS 即時定位",
        "desc": "精準定位家人位置，防走失功能安心可靠。"
      },
      {
        "icon": Icons.water_drop_outlined,
        "title": "防潑水設計",
        "desc": "生活防水等級，日常使用不怕雨水或汗水。"
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "功能特色",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...features.map((f) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(f["icon"] as IconData,
                      color: Colors.blueAccent, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f["title"].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          f["desc"].toString(),
                          style:
                              const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// 規格表
  Widget _buildSpecSection() {
    final specs = [
      ["產品型號", "ED1000 智能手錶"],
      ["螢幕尺寸", "1.54 吋彩色觸控螢幕"],
      ["藍牙版本", "Bluetooth 5.0"],
      ["電池容量", "400mAh（續航約 5 天）"],
      ["防水等級", "IP67 生活防潑水"],
      ["適用系統", "Android / iOS 皆支援"],
      ["保固服務", "一年保固（非人為損壞）"],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "產品規格",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: specs.map((s) {
                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      title: Text(
                        s[0],
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        s[1],
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (s != specs.last)
                      const Divider(height: 1, color: Color(0x11000000)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

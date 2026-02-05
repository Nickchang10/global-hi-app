import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TutorialPage extends StatelessWidget {
  const TutorialPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> tutorials = [
      {
        "title": "快速認識 ED1000 智能手錶",
        "desc": "帶你用 1 分鐘了解 ED1000 的主要功能與適用族群。",
        "tag": "產品介紹",
      },
      {
        "title": "如何設定家長 App 帳號與綁定手錶",
        "desc": "一步一步教你從下載 App 到綁定手錶的完整流程。",
        "tag": "帳號設定",
      },
      {
        "title": "SOS 求助功能實際示範",
        "desc": "示範小朋友長按按鍵、家長手機收到通知的過程。",
        "tag": "安全守護",
      },
      {
        "title": "如何查看步數、心率與睡眠紀錄",
        "desc": "教你在 App 裡查看家人健康數據的方式。",
        "tag": "健康數據",
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        title: Text(
          "教學與影片",
          style: GoogleFonts.notoSansTc(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 頂部說明卡
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "這裡可以放教學影片、操作示範與圖文教學，讓展場來賓快速了解產品。",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            "精選教學影片（示意）",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 影片預留區（可以換成真的播放器）
          _buildVideoPlaceholder(
            title: "ED1000 介紹影片（Demo）",
            subtitle: "可嵌入 YouTube / 自家影片連結",
          ),
          _buildVideoPlaceholder(
            title: "家長 App 操作教學（Demo）",
            subtitle: "示範綁定手錶、查看健康資訊等功能",
          ),

          const SizedBox(height: 20),

          const Text(
            "圖文教學列表",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...tutorials.map((t) {
            return _buildTutorialItem(
              tag: t["tag"] ?? "",
              title: t["title"] ?? "",
              desc: t["desc"] ?? "",
            );
          }).toList(),

          const SizedBox(height: 24),
          Center(
            child: Text(
              "本頁為教學示意，可日後串接真實影片與說明連結。",
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // 影片區塊（目前是示意，可換成真正的播放器 widget）
  Widget _buildVideoPlaceholder({
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // 上方影片黑框示意
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14),
            ),
            child: Container(
              height: 160,
              color: Colors.black87,
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white70,
                  size: 50,
                ),
              ),
            ),
          ),
          // 下方文字
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 圖文教學項目
  Widget _buildTutorialItem({
    required String tag,
    required String title,
    required String desc,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              color: Colors.blueAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tag.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.blueAccent),
                    ),
                  ),
                if (tag.isNotEmpty) const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}

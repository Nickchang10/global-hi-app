import 'package:flutter/material.dart';

/// 🎬 單一直播播放頁（模擬播放畫面 + 點讚功能）
class LivePlayerPage extends StatefulWidget {
  final Map<String, dynamic> room;

  const LivePlayerPage({super.key, required this.room});

  @override
  State<LivePlayerPage> createState() => _LivePlayerPageState();
}

class _LivePlayerPageState extends State<LivePlayerPage> {
  late int _likes;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();

    // ✅ 強制轉為 int，避免 num 錯誤
    final idValue = widget.room["id"];
    final id = (idValue is int)
        ? idValue
        : int.tryParse(idValue.toString()) ?? 0;

    _likes = 100 + id * 2;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.room["title"].toString();
    final host = widget.room["host"]?.toString() ?? "未知";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF5F8FA),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.live_tv, size: 120, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text("🎥 正在觀看：$title",
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("主持人：$host", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          Text("👍 $_likes 個讚",
              style: const TextStyle(fontSize: 20, color: Colors.black87)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
            ),
            label: Text(_isLiked ? "已送出愛心 ❤️" : "送出愛心"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              setState(() {
                _likes++;
                _isLiked = true;
              });
            },
          ),
        ],
      ),
    );
  }
}

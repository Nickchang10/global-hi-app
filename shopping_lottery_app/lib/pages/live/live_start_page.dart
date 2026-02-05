// lib/pages/live/live_start_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/live_service.dart';

/// 🎙️ Osmile 主播開播頁（完整版模板）
///
/// 功能：
/// ✅ 主播可設定直播標題與主題標籤  
/// ✅ 模擬開播（假直播）  
/// ✅ 實時聊天室互動（觀眾隨機留言）  
/// ✅ 顯示觀看數、愛心數、即時訊息  
/// ✅ 支援關播退出
class LiveStartPage extends StatefulWidget {
  const LiveStartPage({super.key});

  @override
  State<LiveStartPage> createState() => _LiveStartPageState();
}

class _LiveStartPageState extends State<LiveStartPage> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _tagCtrl = TextEditingController();
  final List<String> _tags = [];
  bool _isLive = false;
  int _viewers = 0;
  int _likes = 0;
  Timer? _simTimer;
  final List<Map<String, dynamic>> _chat = [];

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }

  void _startLive() {
    if (_titleCtrl.text.trim().isEmpty) return;

    setState(() {
      _isLive = true;
      _viewers = 10 + DateTime.now().second; // 假人數初始值
      _likes = 0;
      _chat.clear();
    });

    // 模擬觀眾互動
    _simTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isLive) return;
      final messages = [
        "好漂亮的畫面 😍",
        "主播你好！",
        "這是什麼產品？",
        "我剛買也覺得很好用～",
        "期待抽獎活動 🎁",
      ];
      setState(() {
        _viewers += 1;
        _chat.add({
          "user": "觀眾${_viewers % 99}",
          "message": messages[_viewers % messages.length],
          "time": DateTime.now(),
        });
      });
    });
  }

  void _stopLive() {
    setState(() => _isLive = false);
    _simTimer?.cancel();
  }

  void _sendMsg(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _chat.add({"user": "我", "message": text, "time": DateTime.now()});
    });
  }

  void _addLike() {
    setState(() => _likes++);
  }

  @override
  Widget build(BuildContext context) {
    final liveService = context.read<LiveService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLive ? "🎙️ 正在直播中" : "開始直播"),
        backgroundColor: _isLive ? Colors.black87 : Colors.white,
        foregroundColor: _isLive ? Colors.white : Colors.black,
        actions: [
          if (_isLive)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _stopLive();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("直播已結束 👋")),
                );
              },
            ),
        ],
      ),
      body: _isLive ? _buildLiveRoom() : _buildSetupForm(liveService),
      backgroundColor: _isLive ? Colors.black : Colors.grey[100],
    );
  }

  // 🧩 開播前設定區
  Widget _buildSetupForm(LiveService liveService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("設定你的直播",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: "直播標題",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagCtrl,
            decoration: InputDecoration(
              labelText: "新增標籤（按下 Enter 加入）",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) {
                setState(() {
                  _tags.add(v.trim());
                  _tagCtrl.clear();
                });
              }
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: _tags
                .map((t) => Chip(
                      label: Text(t),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => setState(() => _tags.remove(t)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 30),
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.videocam),
              label: const Text("開始直播"),
              onPressed: _startLive,
            ),
          ),
        ],
      ),
    );
  }

  // 🎬 主播直播畫面（模擬直播進行中）
  Widget _buildLiveRoom() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.black87,
            child: Center(
              child: Icon(Icons.videocam, size: 120, color: Colors.white30),
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLiveStats(),
            const Spacer(),
            _buildChatList(),
            _buildBottomBar(),
          ],
        ),
      ],
    );
  }

  // 👥 顯示直播數據
  Widget _buildLiveStats() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text("LIVE",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text("👀 $_viewers", style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 10),
            Text("❤️ $_likes", style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // 💬 聊天訊息區
  Widget _buildChatList() {
    return Container(
      height: 250,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.builder(
        reverse: true,
        itemCount: _chat.length,
        itemBuilder: (_, i) {
          final msg = _chat[_chat.length - 1 - i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                      text: "${msg["user"]}: ",
                      style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  TextSpan(
                      text: msg["message"],
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 🧩 底部留言與按讚
  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        color: Colors.black45,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "輸入訊息…",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none),
                ),
                onSubmitted: _sendMsg,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.lightBlueAccent),
              onPressed: () => _sendMsg("大家好 👋"),
            ),
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
              onPressed: _addLike,
            ),
          ],
        ),
      ),
    );
  }
}

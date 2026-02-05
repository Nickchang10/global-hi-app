// lib/pages/live/live_room_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:osmile_shopping_app/services/live_service.dart';

/// 🎬 Osmile 直播間（完整社群互動模板）
///
/// 功能：
/// ✅ 模擬影片播放背景（假）
/// ✅ 主播資訊＋觀看數動態更新
/// ✅ 即時聊天室（本地訊息流）
/// ✅ 發送訊息、送愛心動畫
/// ✅ 自動浮動愛心特效
class LiveRoomPage extends StatefulWidget {
  final String roomId;
  const LiveRoomPage({super.key, required this.roomId});

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _msgCtrl = TextEditingController();
  final Random _random = Random();
  final List<_Heart> _hearts = [];
  Timer? _viewerTimer;
  Timer? _autoMsgTimer;
  Timer? _heartTimer;

  @override
  void initState() {
    super.initState();
    // 模擬觀看人數波動
    _viewerTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      context.read<LiveService>().randomBumpViewers(widget.roomId);
    });

    // 模擬觀眾自動留言
    _autoMsgTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final live = context.read<LiveService>();
      final samples = [
        "好酷喔 😍",
        "這功能真不錯",
        "買過真的推推 👍",
        "請問防水嗎？",
        "想看更多顏色！"
      ];
      live.sendMessage(
        roomId: widget.roomId,
        user: "觀眾${_random.nextInt(99)}",
        message: samples[_random.nextInt(samples.length)],
      );
    });

    // 模擬自動愛心
    _heartTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _spawnHeart();
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _viewerTimer?.cancel();
    _autoMsgTimer?.cancel();
    _heartTimer?.cancel();
    super.dispose();
  }

  void _spawnHeart() {
    setState(() {
      _hearts.add(_Heart(
        left: _random.nextDouble() * 200,
        color: Colors.primaries[_random.nextInt(Colors.primaries.length)],
        id: DateTime.now().millisecondsSinceEpoch,
      ));
    });
    Future.delayed(const Duration(seconds: 3), () {
      setState(() => _hearts.removeWhere((h) =>
          DateTime.now().millisecondsSinceEpoch - h.id > 2500));
    });
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveService>();
    final room = live.getRoomById(widget.roomId);

    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("直播間")),
        body: const Center(child: Text("找不到直播內容 😢")),
      );
    }

    final chats = live.getChats(widget.roomId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text(room["title"], style: const TextStyle(color: Colors.white)),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                const Icon(Icons.remove_red_eye,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 4),
                Text("${room["viewerCount"]}",
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          // 假影片背景
          Positioned.fill(
            child: Image.asset(
              room["cover"],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey.shade900),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // ❤️ 飄浮愛心動畫
          ..._hearts.map((h) => _AnimatedHeart(heart: h)),

          // 聊天室與主播資訊
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHostBar(room),
              const Spacer(),
              _buildChatList(chats),
              _buildInputBar(context),
            ],
          ),
        ],
      ),
    );
  }

  // 主播資訊列
  Widget _buildHostBar(Map<String, dynamic> room) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(room["host"],
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(999)),
              child: const Text("LIVE",
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // 聊天室訊息
  Widget _buildChatList(List<Map<String, dynamic>> chats) {
    return Container(
      height: 240,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView.builder(
        reverse: true,
        itemCount: chats.length,
        itemBuilder: (_, i) {
          final msg = chats[chats.length - 1 - i];
          final time = DateFormat("HH:mm").format(msg["time"]);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: "${msg["user"]}: ",
                    style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                TextSpan(
                    text: msg["message"],
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                TextSpan(
                    text: "  [$time]",
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10)),
              ]),
            ),
          );
        },
      ),
    );
  }

  // 留言輸入列
  Widget _buildInputBar(BuildContext context) {
    final live = context.read<LiveService>();
    return SafeArea(
      child: Container(
        color: Colors.black45,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "發送留言...",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.lightBlueAccent),
              onPressed: () {
                final text = _msgCtrl.text.trim();
                if (text.isEmpty) return;
                live.sendMessage(
                    roomId: widget.roomId, user: "我", message: text);
                _msgCtrl.clear();
              },
            ),
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
              onPressed: () {
                live.likeLive(widget.roomId);
                _spawnHeart();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ❤️ 飄浮愛心物件模型
class _Heart {
  final double left;
  final Color color;
  final int id;
  _Heart({required this.left, required this.color, required this.id});
}

// ❤️ 飄浮動畫 widget
class _AnimatedHeart extends StatefulWidget {
  final _Heart heart;
  const _AnimatedHeart({required this.heart});

  @override
  State<_AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<_AnimatedHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..forward();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Positioned(
          left: widget.heart.left,
          bottom: 80 + 100 * _ctrl.value,
          child: Opacity(
            opacity: 1 - _ctrl.value,
            child: Transform.scale(
              scale: 1 + 0.5 * _ctrl.value,
              child: Icon(Icons.favorite,
                  color: widget.heart.color.withOpacity(0.8), size: 28),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

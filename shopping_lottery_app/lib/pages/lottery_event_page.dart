// lib/pages/lottery_event_page.dart
//
// ✅ LotteryEventPage（最終完整版｜已修正 withOpacity -> withValues）
// - 修正 lint: deprecated_member_use（withOpacity）
// - 其餘邏輯不變：倒數、任務完成、報名、抽獎（Demo）

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/event_lottery_service.dart';
import '../services/user_service.dart';

class LotteryEventPage extends StatefulWidget {
  const LotteryEventPage({super.key});

  @override
  State<LotteryEventPage> createState() => _LotteryEventPageState();
}

class _LotteryEventPageState extends State<LotteryEventPage> {
  final _event = EventLotteryService.instance;
  final _user = UserService.instance;

  bool liked = false;
  bool commented = false;
  bool shared = false;

  Timer? _countdownTimer;
  Duration _timeLeft = const Duration();

  @override
  void initState() {
    super.initState();

    // 模擬活動時間（可改成從後端抓）
    if (!_event.isActive) {
      _event.startEvent(
        endTime: DateTime.now().add(const Duration(minutes: 5)),
      );
    }

    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // -----------------------------------------------------------------
  // ⏰ 倒數邏輯
  // -----------------------------------------------------------------
  void _updateCountdown() {
    if (!_event.isActive || _event.eventEndTime == null) return;

    final now = DateTime.now();
    final diff = _event.eventEndTime!.difference(now);

    if (diff.isNegative) {
      _countdownTimer?.cancel();
      setState(() {
        _timeLeft = Duration.zero;
      });
      _event.endEvent();
    } else {
      setState(() {
        _timeLeft = diff;
      });
    }
  }

  // -----------------------------------------------------------------
  // 📝 任務完成條件
  // -----------------------------------------------------------------
  bool get isAllTasksDone => liked && commented && shared;

  void _onLike() => setState(() => liked = true);
  void _onComment() => setState(() => commented = true);
  void _onShare() => setState(() => shared = true);

  // -----------------------------------------------------------------
  // ✅ 登錄參加
  // -----------------------------------------------------------------
  void _registerParticipant() {
    if (!_event.isActive) {
      _showDialog("活動已結束", "下次再參加喔！");
      return;
    }

    if (!isAllTasksDone) {
      _showDialog("任務未完成", "請完成所有任務後再報名參加抽獎！");
      return;
    }

    _event.registerParticipant(_user.name);
    _showDialog("報名成功", "您已完成任務，將參與抽獎！");
  }

  // -----------------------------------------------------------------
  // 🏆 管理員抽獎（Demo 模式）
  // -----------------------------------------------------------------
  void _drawWinner() {
    final result = _event.drawWinner();
    if (result == null) {
      _showDialog("無法抽獎", "目前尚無參加者。");
      return;
    }

    final winner = result["winner"]["name"];
    final prize = result["prize"]["name"];

    _showDialog("🎉 抽獎結果", "$winner 抽中 $prize！");
  }

  // -----------------------------------------------------------------
  // 💬 彈窗
  // -----------------------------------------------------------------
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // 🧩 UI
  // -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isActive = _event.isActive;
    final minutes = _timeLeft.inMinutes.remainder(60);
    final seconds = _timeLeft.inSeconds.remainder(60);

    return Scaffold(
      appBar: AppBar(title: const Text("🎉 限時活動抽獎"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // 🕓 活動倒數
            if (isActive)
              Column(
                children: [
                  const Text("距離活動結束還有", style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 6),
                  Text(
                    "$minutes 分 $seconds 秒",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              )
            else
              const Text("活動已結束", style: TextStyle(color: Colors.grey)),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // ✅ FIX: withOpacity -> withValues(alpha: ...)
                color: Colors.orangeAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orangeAccent),
              ),
              child: const Text(
                "🔥 活動說明：\n\n"
                "1️⃣ 按讚主辦方粉絲專頁\n"
                "2️⃣ 在貼文下留言「我想抽中！」\n"
                "3️⃣ 分享活動貼文到個人塗鴉牆\n\n"
                "完成以上三步，即可參加限時抽獎！",
                style: TextStyle(fontSize: 15, height: 1.6),
              ),
            ),

            const SizedBox(height: 30),

            // 🧩 任務按鈕
            _taskButton("按讚", liked, _onLike, Icons.thumb_up),
            _taskButton("留言", commented, _onComment, Icons.chat),
            _taskButton("分享", shared, _onShare, Icons.share),

            const SizedBox(height: 30),

            // 🟢 報名按鈕
            ElevatedButton.icon(
              onPressed: _registerParticipant,
              style: ElevatedButton.styleFrom(
                backgroundColor: isAllTasksDone
                    ? Colors.green
                    : Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: const Icon(Icons.how_to_vote),
              label: const Text(
                "報名參加抽獎",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 40),

            // 🧾 參加名單（模擬顯示）
            if (_event.participants.isNotEmpty) ...[
              const Text(
                "已報名參加名單",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              ..._event.participants.map(
                (p) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(p["name"]),
                  subtitle: Text(p["time"].toString().substring(0, 19)),
                ),
              ),
            ],

            const SizedBox(height: 40),

            // 🎁 Demo：活動結束後手動抽獎（管理員用）
            ElevatedButton.icon(
              onPressed: _drawWinner,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.emoji_events),
              label: const Text("抽出中獎者"),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // 🟠 任務按鈕元件
  // -----------------------------------------------------------------
  Widget _taskButton(
    String text,
    bool done,
    VoidCallback onTap,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        onPressed: done ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: done ? Colors.green : Colors.blueAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          done ? "$text ✅" : text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

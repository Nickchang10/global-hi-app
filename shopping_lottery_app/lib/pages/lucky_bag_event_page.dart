import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/coin_reward_popup.dart';

class LuckyBagEventPage extends StatefulWidget {
  final int currentPoints;
  final Function(int) onPointsUpdate;

  const LuckyBagEventPage({
    super.key,
    required this.currentPoints,
    required this.onPointsUpdate,
  });

  @override
  State<LuckyBagEventPage> createState() => _LuckyBagEventPageState();
}

class _LuckyBagEventPageState extends State<LuckyBagEventPage> {
  bool hasOpenedToday = false;
  DateTime eventTime = DateTime.now()
      .add(const Duration(minutes: 1)); // 🔧 測試用：1 分鐘後開啟（可改為每天 12:00）
  late Timer timer;
  Duration remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final now = DateTime.now();
    setState(() {
      remaining = eventTime.difference(now);
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  void _openLuckyBag() {
    if (hasOpenedToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("今天已開啟過福袋，請明天再來 🎁")),
      );
      return;
    }

    const prizes = [
      {"type": "積分", "value": 100, "msg": "🎉 獲得 100 積分！"},
      {"type": "折價券", "value": 50, "msg": "🎊 獲得 NT\$50 折價券！"},
      {"type": "抽獎券", "value": 1, "msg": "🎁 獲得抽獎券 1 張！"},
      {"type": "積分", "value": 200, "msg": "🌟 超幸運！獲得 200 積分！"},
    ];

    final prize = prizes[Random().nextInt(prizes.length)];

    setState(() {
      hasOpenedToday = true;
      if (prize["type"] == "積分") {
        widget.onPointsUpdate(prize["value"] as int);
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CoinRewardPopup(
        points: prize["type"] == "積分" ? (prize["value"] as int) : 0,
        message: prize["msg"]!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReady = remaining.isNegative;
    final timeText = isReady
        ? "活動開放中！"
        : "${remaining.inHours.remainder(24).toString().padLeft(2, '0')}:"
          "${remaining.inMinutes.remainder(60).toString().padLeft(2, '0')}:"
          "${remaining.inSeconds.remainder(60).toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(
        title: const Text("🎁 限時福袋活動"),
        centerTitle: true,
        backgroundColor: Colors.pinkAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "每日限時開啟時間",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              "🕛 ${eventTime.hour.toString().padLeft(2, '0')}:${eventTime.minute.toString().padLeft(2, '0')}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  "https://cdn-icons-png.flaticon.com/512/3069/3069609.png",
                  width: 200,
                  height: 200,
                ),
                if (!isReady)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    alignment: Alignment.center,
                    child: Text(
                      timeText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.card_giftcard),
              label: Text(
                hasOpenedToday
                    ? "今日已開啟"
                    : (isReady ? "立即開啟福袋" : "等待開啟"),
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    hasOpenedToday ? Colors.grey : Colors.orangeAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 60, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isReady && !hasOpenedToday ? _openLuckyBag : null,
            ),
            const SizedBox(height: 30),
            Text(
              "我的目前積分：${widget.currentPoints}",
              style: const TextStyle(
                  fontSize: 16,
                  color: Colors.pinkAccent,
                  fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }
}

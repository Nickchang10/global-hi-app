import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class FriendChallengePage extends StatefulWidget {
  final String friendName;
  const FriendChallengePage({super.key, required this.friendName});

  @override
  State<FriendChallengePage> createState() => _FriendChallengePageState();
}

class _FriendChallengePageState extends State<FriendChallengePage> {
  late Timer _timer;
  late ConfettiController _confetti;
  double myProgress = 0.0;
  double friendProgress = 0.0;
  int secondsLeft = 20;
  bool finished = false;
  bool win = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _startChallenge();
  }

  void _startChallenge() {
    _timer = Timer.periodic(const Duration(milliseconds: 600), (t) {
      if (secondsLeft > 0 && !finished) {
        setState(() {
          myProgress += Random().nextDouble() * 0.08;
          friendProgress += Random().nextDouble() * 0.08;
          if (myProgress > 1) myProgress = 1;
          if (friendProgress > 1) friendProgress = 1;
          secondsLeft--;
        });
      } else {
        t.cancel();
        _endChallenge();
      }
    });
  }

  void _endChallenge() {
    setState(() {
      finished = true;
      win = myProgress >= friendProgress;
    });
    if (win) _confetti.play();

    Future.delayed(const Duration(seconds: 2), () {
      _showResultDialog();
    });
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              win ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              color: win ? Colors.orangeAccent : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 8),
            Text(
              win ? "挑戰成功！" : "挑戰失敗",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              win
                  ? "你贏了 ${widget.friendName}！\n獲得 +50 積分"
                  : "${widget.friendName} 表現更好，下次再接再厲！",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("返回好友頁"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff9fafb),
      appBar: AppBar(
        title: Text("挑戰 ${widget.friendName}"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.8,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          _buildChallengeBody(),
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 25,
            gravity: 0.3,
            colors: const [
              Colors.orangeAccent,
              Colors.amber,
              Colors.pinkAccent,
              Colors.blueAccent,
              Colors.green,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeBody() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _buildCountdown(),
          const SizedBox(height: 40),
          _buildPlayerBar("我", myProgress, Colors.blueAccent, true),
          const SizedBox(height: 24),
          _buildPlayerBar(
            widget.friendName,
            friendProgress,
            Colors.orangeAccent,
            false,
          ),
          const Spacer(),
          _buildChallengeInfo(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCountdown() {
    return Column(
      children: [
        Text(
          "倒數計時",
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "$secondsLeft 秒",
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerBar(String name, double progress, Color color, bool me) {
    return Column(
      crossAxisAlignment: me
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: me
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            if (me)
              const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, color: Colors.white),
              ),
            if (!me) const Spacer(),
            if (!me)
              CircleAvatar(
                // ✅ FIX: withOpacity -> withValues(alpha: ...)
                backgroundColor: Colors.orangeAccent.withValues(alpha: 0.8),
                child: const Icon(Icons.star, color: Colors.white),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 20,
              width: MediaQuery.of(context).size.width * progress * 0.8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    // ✅ FIX: withOpacity -> withValues(alpha: ...)
                    color.withValues(alpha: 0.8),
                    color,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "$name ${(progress * 100).toStringAsFixed(0)}%",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: me ? Colors.blueAccent : Colors.orangeAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeInfo() {
    return Column(
      children: [
        const Text(
          "挑戰項目：今日步數比拼",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        if (finished)
          Text(
            win ? "你贏了！🔥" : "差一點，下次再挑戰！",
            style: TextStyle(
              color: win ? Colors.orangeAccent : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          )
        else
          const Text(
            "比賽進行中...",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),
      ],
    );
  }
}

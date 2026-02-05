import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/lottery_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../firebase_options.dart';

/// 🎁 大型活動抽獎（含 Firebase + 自動開獎）
class EventLotteryPage extends StatefulWidget {
  const EventLotteryPage({super.key});

  @override
  State<EventLotteryPage> createState() => _EventLotteryPageState();
}

class _EventLotteryPageState extends State<EventLotteryPage> {
  final _user = UserService.instance;
  final _lottery = LotteryService.instance;
  bool _hasLiked = false;
  bool _hasCommented = false;
  bool _hasShared = false;
  bool _isJoined = false;

  final _commentCtrl = TextEditingController();
  Timer? _timer;
  Duration _remaining = Duration.zero;
  final DateTime _eventTime = DateTime(2025, 12, 1, 20, 0, 0); // 開獎時間

  @override
  void initState() {
    super.initState();
    _initFirebase();
    _startCountdown();
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {
      // 已初始化
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final diff = _eventTime.difference(now);
      if (diff.isNegative) {
        _timer?.cancel();
        _autoDrawWinners();
      } else {
        setState(() => _remaining = diff);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text("🎉 大型活動抽獎")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildBanner(),
            const SizedBox(height: 20),
            _buildRules(),
            const SizedBox(height: 20),
            _buildCountdown(hours, minutes, seconds),
            const SizedBox(height: 20),
            _buildActions(),
            const SizedBox(height: 20),
            _buildCommentBox(),
            const SizedBox(height: 30),
            _buildJoinButton(),
            const SizedBox(height: 40),
            _buildWinners(),
          ],
        ),
      ),
    );
  }

  // 🖼 活動封面
  Widget _buildBanner() => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          "https://images.unsplash.com/photo-1607082349566-187342145b33?auto=format&fit=crop&w=1200&q=80",
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );

  // 📜 活動規則
  Widget _buildRules() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("🎯 活動規則", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("1️⃣ 按讚活動貼文"),
            Text("2️⃣ 留言你最喜歡的 Osmile 商品"),
            Text("3️⃣ 分享活動貼文到個人頁"),
            SizedBox(height: 8),
            Text("🏆 獎品：Osmile 智慧手錶 ED1000"),
            Text("⏰ 開獎時間：2025/12/01 20:00"),
          ],
        ),
      );

  // ⏰ 倒數計時
  Widget _buildCountdown(String h, String m, String s) {
    return Column(
      children: [
        const Text("距離開獎倒數", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text("$h:$m:$s",
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
      ],
    );
  }

  // 👍 動作按鈕組
  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _socialButton(Icons.thumb_up, "按讚", _hasLiked, () => setState(() => _hasLiked = !_hasLiked)),
        _socialButton(Icons.comment, "留言", _hasCommented, () => setState(() => _hasCommented = !_hasCommented)),
        _socialButton(Icons.share, "分享", _hasShared, () => setState(() => _hasShared = !_hasShared)),
      ],
    );
  }

  Widget _socialButton(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 32, color: active ? Colors.pinkAccent : Colors.grey),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: active ? Colors.pinkAccent : Colors.black54)),
        ],
      ),
    );
  }

  // 💬 留言框
  Widget _buildCommentBox() => TextField(
        controller: _commentCtrl,
        enabled: _hasCommented,
        decoration: InputDecoration(
          labelText: "留言內容",
          hintText: "輸入留言內容",
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  // 🧾 加入抽獎按鈕
  Widget _buildJoinButton() {
    final canJoin = _hasLiked && _hasCommented && _hasShared;
    return ElevatedButton.icon(
      icon: const Icon(Icons.emoji_events),
      label: Text(_isJoined ? "已參加 ✅" : "參加抽獎"),
      style: ElevatedButton.styleFrom(
        backgroundColor: canJoin ? Colors.pinkAccent : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      onPressed: canJoin && !_isJoined ? _joinEvent : null,
    );
  }

  // 🏆 得獎名單區
  Widget _buildWinners() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("event_winners").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text("尚未開獎");
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text("尚未開獎");

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("🏆 得獎名單", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            for (final d in docs)
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: Text(d["name"]),
                subtitle: Text(d["prize"]),
              ),
          ],
        );
      },
    );
  }

  // ✅ 加入活動名單
  Future<void> _joinEvent() async {
    setState(() => _isJoined = true);
    await FirebaseFirestore.instance.collection("event_participants").add({
      "name": _user.name,
      "comment": _commentCtrl.text,
      "time": DateTime.now(),
    });
    NotificationService.instance.addNotification(
      title: "✅ 已參加活動",
      message: "您已成功加入抽獎名單！",
      type: "event",
      target: "event",
      icon: Icons.celebration,
    );
  }

  // ⏰ 自動開獎流程（隨機抽出 3 名）
  Future<void> _autoDrawWinners() async {
    final participants = await FirebaseFirestore.instance.collection("event_participants").get();
    if (participants.docs.isEmpty) return;

    final all = participants.docs.toList()..shuffle();
    final winners = all.take(3);

    for (final w in winners) {
      await FirebaseFirestore.instance.collection("event_winners").add({
        "name": w["name"],
        "prize": "Osmile 智慧手錶 ED1000",
        "time": DateTime.now(),
      });

      NotificationService.instance.addNotification(
        title: "🎉 恭喜中獎！",
        message: "${w["name"]} 抽中 Osmile 智慧手錶 ED1000 🎁",
        type: "event",
        target: "event",
        icon: Icons.emoji_events,
      );
    }
  }
}

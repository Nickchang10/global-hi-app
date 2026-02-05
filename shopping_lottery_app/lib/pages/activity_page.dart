import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  int selectedCategory = 0;
  int userPoints = 120;
  late Timer _timer;
  Duration remaining = const Duration(days: 2, hours: 8, minutes: 30);

  final List<String> categories = ['全部', '健康挑戰', '親子互動', 'Osmile 功能'];

  final List<Map<String, dynamic>> activities = [
    {
      'title': '親子互動日',
      'subtitle': '完成 3 次親子任務，獲得「親子之星」徽章！',
      'image':
          'https://images.unsplash.com/photo-1558611848-73f7eb4001a1?auto=format&fit=crop&w=1200&q=80',
      'progress': 0.75,
      'points': 45,
      'tag': '親子',
    },
    {
      'title': 'Osmile 健走活動',
      'subtitle': '12/20 - 12/31 完成每日 5,000 步可抽好禮！',
      'image':
          'https://images.unsplash.com/photo-1502767089025-6572583495b0?auto=format&fit=crop&w=1200&q=80',
      'progress': 0.3,
      'points': 30,
      'tag': '健走',
    },
    {
      'title': '健康挑戰賽',
      'subtitle': '每天堅持心率紀錄滿 7 天可獲專屬徽章。',
      'image':
          'https://images.unsplash.com/photo-1594737625785-c1e6f0d8e2f5?auto=format&fit=crop&w=1200&q=80',
      'progress': 0.5,
      'points': 60,
      'tag': '健康',
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    setState(() {
      if (remaining.inSeconds > 0) {
        remaining -= const Duration(seconds: 1);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${d.inDays}天 ${twoDigits(d.inHours % 24)}:${twoDigits(d.inMinutes % 60)}:${twoDigits(d.inSeconds % 60)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff9fafb),
      appBar: AppBar(
        title: const Text('活動'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.8,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orangeAccent,
        child: const Icon(Icons.casino),
        onPressed: _showLuckyDraw,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildCountdownCard(),
            const SizedBox(height: 16),
            _buildCategoryTabs(),
            const SizedBox(height: 16),
            ...activities.map((a) => _buildActivityCard(a)).toList(),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // 活動中心頭部卡
  // ===========================================================
  Widget _buildHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 28,
            child: Icon(Icons.emoji_events, color: Colors.orange, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '活動中心\n任務挑戰 × 點數兌換 × 成就徽章',
              style: GoogleFonts.notoSansTc(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
          Column(
            children: [
              Text('$userPoints',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Text('點數',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // 倒數計時卡
  // ===========================================================
  Widget _buildCountdownCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  color: Colors.orangeAccent, size: 28),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('限時活動倒數',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(_formatDuration(remaining),
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 13)),
                ],
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('活動詳情開發中...')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('查看'),
          )
        ],
      ),
    );
  }

  // ===========================================================
  // 分類標籤
  // ===========================================================
  Widget _buildCategoryTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(categories.length, (i) {
          final selected = selectedCategory == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(categories[i]),
              selected: selected,
              selectedColor: Colors.orangeAccent,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => setState(() => selectedCategory = i),
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================
  // 活動卡
  // ===========================================================
  Widget _buildActivityCard(Map<String, dynamic> a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            child: Image.network(a['image'],
                height: 150, width: double.infinity, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a['title'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(a['subtitle'],
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: a['progress'],
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.orangeAccent,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('完成 +${a['points']} 點',
                        style: const TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                      ),
                      icon: const Icon(Icons.check_circle_outline,
                          size: 18, color: Colors.white),
                      label: const Text('報名',
                          style:
                              TextStyle(color: Colors.white, fontSize: 13)),
                      onPressed: () => _completeActivity(a),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // 完成活動邏輯 + 點數動畫
  // ===========================================================
  void _completeActivity(Map<String, dynamic> activity) {
    setState(() {
      userPoints += activity['points'];
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.green,
      content: Text('完成任務！+${activity['points']} 點'),
      duration: const Duration(seconds: 2),
    ));
  }

  // ===========================================================
  // 幸運抽獎 (遊戲互動)
  // ===========================================================
  void _showLuckyDraw() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.card_giftcard,
                  color: Colors.orangeAccent, size: 60),
              const SizedBox(height: 12),
              const Text('今日抽獎任務',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('完成今日任務即可抽取隨機好禮！'),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12)),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('恭喜獲得：「50 點數券」！')));
                },
                child: const Text('立即抽獎'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

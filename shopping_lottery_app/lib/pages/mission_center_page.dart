// lib/pages/mission_center_page.dart
//
// ✅ MissionCenterPage（最終完整版｜已修正 withOpacity -> withValues(alpha: )）
//
// 你原本第 202 行用到 withOpacity 會觸發 deprecated_member_use
// 這版統一改成 withValues(alpha: ...)

import 'package:flutter/material.dart';

class MissionCenterPage extends StatefulWidget {
  const MissionCenterPage({super.key});

  @override
  State<MissionCenterPage> createState() => _MissionCenterPageState();
}

class _MissionCenterPageState extends State<MissionCenterPage> {
  // ✅ alpha helper：確保是 0~1 的 double
  double _a(num v) {
    final d = v.toDouble();
    if (d.isNaN) return 1.0;
    if (d < 0) return 0.0;
    if (d > 1) return 1.0;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(title: const Text('任務中心')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _missionCard(
            title: '每日任務',
            subtitle: '完成任務獲得積分',
            icon: Icons.checklist_rounded,
            color: Colors.blueAccent,
            onTap: () {
              // 依你專案路由調整
              Navigator.of(context).pushNamed('/daily_mission');
            },
          ),
          const SizedBox(height: 12),
          _missionCard(
            title: '好友挑戰',
            subtitle: '與好友比拼拿獎勵',
            icon: Icons.emoji_events_rounded,
            color: Colors.orangeAccent,
            onTap: () {
              Navigator.of(context).pushNamed('/friend');
            },
          ),
          const SizedBox(height: 12),
          _missionCard(
            title: '活動抽獎',
            subtitle: '完成任務參加抽獎',
            icon: Icons.casino_rounded,
            color: Colors.deepOrange,
            onTap: () {
              Navigator.of(context).pushNamed('/lottery_event');
            },
          ),
        ],
      ),
    );
  }

  Widget _missionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              // ✅ FIX: withOpacity -> withValues(alpha: ...)
              backgroundColor: color.withValues(alpha: _a(0.12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.withValues(alpha: _a(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

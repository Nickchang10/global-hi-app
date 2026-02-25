// lib/pages/lottery_widgets.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum PrizeType { product, points, voucher, none }

class Prize {
  final String name;
  final PrizeType type;
  final int value;
  Prize(this.name, this.type, this.value);
}

/// 積分卡片
class PointsCard extends StatelessWidget {
  final int points;
  final bool freeUsed;
  final bool spinning;
  final VoidCallback onSpin;
  const PointsCard({
    super.key,
    required this.points,
    required this.freeUsed,
    required this.spinning,
    required this.onSpin,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (points % 100) / 100;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Colors.orange,
                child: Icon(Icons.star, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '我的積分',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$points',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      freeUsed ? '今日免費已使用' : '今日第一次抽獎免費',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      color: Colors.orange,
                      backgroundColor: Colors.orange.shade100,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '積分越高，中獎機率越大！',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: spinning ? null : onSpin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size(100, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: spinning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('立即抽獎'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 今日任務
class DailyMissionSection extends StatelessWidget {
  final Function(int) onAddPoints;
  const DailyMissionSection({super.key, required this.onAddPoints});

  @override
  Widget build(BuildContext context) {
    return _sectionCard(
      title: '📋 今日任務',
      child: Column(
        children: [
          _missionRow('每日登入', '+5 積分', () => onAddPoints(5)),
          _missionRow('分享抽獎頁', '+10 積分', () => onAddPoints(10)),
          _missionRow('完成簽到', '+15 積分', () => onAddPoints(15)),
        ],
      ),
    );
  }

  Widget _missionRow(String title, String reward, VoidCallback onTap) {
    return ListTile(
      title: Text(title),
      subtitle: Text(reward, style: const TextStyle(color: Colors.green)),
      trailing: ElevatedButton(onPressed: onTap, child: const Text('完成任務')),
    );
  }
}

/// 簽到區
class SignInSection extends StatefulWidget {
  final Function(int) onSigned;
  const SignInSection({super.key, required this.onSigned});
  @override
  State<SignInSection> createState() => _SignInSectionState();
}

class _SignInSectionState extends State<SignInSection> {
  int day = 0;

  @override
  Widget build(BuildContext context) {
    return _sectionCard(
      title: '📅 連續簽到',
      child: Column(
        children: [
          Text(
            '已連續簽到 $day 天',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              setState(() => day++);
              final bonus = (day % 7 == 0) ? 50 : 10;
              widget.onSigned(bonus);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('簽到成功！獲得 $bonus 積分'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('立即簽到'),
          ),
        ],
      ),
    );
  }
}

/// 排行榜
class LeaderboardSection extends StatelessWidget {
  const LeaderboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> players = List.generate(
      10,
      (i) => {'name': '玩家${i + 1}', 'points': 500 - i * 30},
    );

    return _sectionCard(
      title: '🏆 本週積分排行榜',
      child: Column(
        children: players
            .map(
              (p) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text('${players.indexOf(p) + 1}'),
                ),
                title: Text(p['name'] as String),
                trailing: Text(
                  '${p['points']} 分',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// 分享
class ShareSection extends StatelessWidget {
  const ShareSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _sectionCard(
      title: '💬 分享抽獎',
      child: Column(
        children: [
          const Text('分享至 LINE / FB 可再獲一次免費抽獎機會！'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已模擬分享成功，獲得 1 次免費抽獎！')),
              );
            },
            icon: const Icon(Icons.share),
            label: const Text('立即分享'),
          ),
        ],
      ),
    );
  }
}

/// 抽獎轉盤
class PrizeWheelPainter extends CustomPainter {
  final List<Prize> prizes;
  final int? highlightIndex;
  PrizeWheelPainter(this.prizes, {this.highlightIndex});

  final List<List<Color>> palette = [
    [const Color(0xFFB3E5FC), const Color(0xFF81D4FA)],
    [const Color(0xFFC8E6C9), const Color(0xFFA5D6A7)],
    [const Color(0xFFFFF9C4), const Color(0xFFFFF59D)],
    [const Color(0xFFFFE0B2), const Color(0xFFFFCC80)],
    [const Color(0xFFE1BEE7), const Color(0xFFCE93D8)],
    [const Color(0xFFFFCDD2), const Color(0xFFEF9A9A)],
    [const Color(0xFFDCEDC8), const Color(0xFFC5E1A5)],
    [const Color(0xFFD1C4E9), const Color(0xFFB39DDB)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final n = prizes.length;
    if (n == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sector = 2 * pi / n;

    for (int i = 0; i < n; i++) {
      final start = -pi / 2 + i * sector;
      final sweep = sector;
      final base = palette[i % palette.length];
      final isHighlight = i == highlightIndex;

      final paint = Paint()
        ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, base)
        ..colorFilter = isHighlight
            ? const ui.ColorFilter.mode(Colors.white70, BlendMode.softLight)
            : null;

      canvas.drawArc(rect, start, sweep, true, paint);
    }

    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.03
      ..color = Colors.white.withValues(alpha: 0.95); // ✅ 修正
    canvas.drawCircle(center, radius, outer);

    final innerR = radius * 0.3;
    final iconR = innerR + (radius - innerR) * 0.6;
    final textR = innerR + (radius - innerR) * 0.4;

    for (int i = 0; i < n; i++) {
      final mid = -pi / 2 + i * sector + sector / 2;
      final prize = prizes[i];
      final bg = palette[i % palette.length][0];
      final bright = bg.computeLuminance() > 0.65;
      final textColor = bright ? Colors.black87 : Colors.white;

      final icon = Offset(
        center.dx + cos(mid) * iconR,
        center.dy + sin(mid) * iconR,
      );
      final emoji = _emojiForType(prize.type);
      final tpEmoji = TextPainter(
        text: TextSpan(
          text: emoji,
          style: TextStyle(fontSize: radius * 0.10),
        ),
        textDirection: TextDirection.ltr,
      );
      tpEmoji.layout();
      tpEmoji.paint(
        canvas,
        Offset(icon.dx - tpEmoji.width / 2, icon.dy - tpEmoji.height / 2),
      );

      final textPos = Offset(
        center.dx + cos(mid) * textR,
        center.dy + sin(mid) * textR,
      );
      final titleTp = TextPainter(
        text: TextSpan(
          text: prize.name,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.055,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      titleTp.layout(maxWidth: radius * 0.46);
      titleTp.paint(
        canvas,
        Offset(textPos.dx - titleTp.width / 2, textPos.dy - titleTp.height / 2),
      );
    }

    final innerPaint = Paint()
      ..shader = ui.Gradient.radial(center, innerR, [
        Colors.white,
        Colors.blue.shade50,
      ]);
    canvas.drawCircle(center, innerR, innerPaint);

    final innerBorder = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
          .withValues(alpha: 0.95) // ✅ 修正
      ..strokeWidth = max(3.0, radius * 0.02);
    canvas.drawCircle(center, innerR, innerBorder);
  }

  String _emojiForType(PrizeType t) {
    switch (t) {
      case PrizeType.product:
        return '🎁';
      case PrizeType.points:
        return '💠';
      case PrizeType.voucher:
        return '🎟️';
      case PrizeType.none:
        return '✨';
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 共用樣式
Widget _sectionCard({required String title, required Widget child}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    ),
  );
}

// lib/pages/points_ecosystem_page.dart
//
// ✅ PointsEcosystemPage（最終完整版｜已修正 prefer_const_declarations）
// ------------------------------------------------------------
// - 修正：把「final + 常數值」改成 const（你報錯的 242-247 行區段）
// - 其餘維持可編譯、無 curly_braces_in_flow_control_structures
//
// 你可以在 routes 註冊：
// '/points' : (_) => const PointsEcosystemPage(),

import 'package:flutter/material.dart';

class PointsEcosystemPage extends StatefulWidget {
  const PointsEcosystemPage({super.key});

  @override
  State<PointsEcosystemPage> createState() => _PointsEcosystemPageState();
}

class _PointsEcosystemPageState extends State<PointsEcosystemPage> {
  static const Color _brand = Color(0xFF3B82F6);

  // 示範數據（你要接 Firestore / Provider 也可）
  int _points = 1280;
  int _todayEarned = 60;
  String _tier = 'Silver';

  void _toast(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  String _tierHint(String tier) {
    switch (tier) {
      case 'Gold':
        return '黃金會員：加倍回饋、專屬活動（示範）';
      case 'Platinum':
        return '白金會員：最高回饋、優先客服（示範）';
      case 'Silver':
      default:
        return '白銀會員：累積積分解鎖更高等級（示範）';
    }
  }

  double _tierProgress(String tier) {
    switch (tier) {
      case 'Gold':
        return 0.65;
      case 'Platinum':
        return 0.90;
      case 'Silver':
      default:
        return 0.35;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _tierProgress(_tier);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('積分生態'),
        actions: [
          IconButton(
            tooltip: '刷新（示範）',
            onPressed: () {
              setState(() {
                _points += 5;
                _todayEarned += 1;
              });
              _toast('已刷新（示範）');
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 22),
        children: [
          _summaryCard(progress: progress),
          const SizedBox(height: 12),
          _earnWaysCard(),
          const SizedBox(height: 12),
          _redeemIdeasCard(),
          const SizedBox(height: 12),
          _ctaRow(),
          const SizedBox(height: 18),
          Text(
            '提示：你可以把本頁的積分、等級、任務入口接到 Firestore：users/{uid}（points、tier）與任務系統（missions）。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({required double progress}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.stars_rounded, color: _brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '我的積分',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '今日獲得：$_todayEarned 點（示範）',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_points',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '等級：$_tier',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(_brand),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _tierHint(_tier),
            style: TextStyle(color: Colors.grey.shade700, height: 1.25),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (_tier == 'Silver') {
                      setState(() => _tier = 'Gold');
                    } else if (_tier == 'Gold') {
                      setState(() => _tier = 'Platinum');
                    } else {
                      setState(() => _tier = 'Silver');
                    }
                    _toast('切換等級（示範）');
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text(
                    '切換等級（示範）',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brand,
                    side: const BorderSide(color: _brand),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _earnWaysCard() {
    // ✅ 修正 prefer_const_declarations：常數 list 用 const
    const ways = <Map<String, Object>>[
      {'t': '每日簽到', 'd': '每日打卡可獲得積分（依活動）', 'i': Icons.calendar_month_outlined},
      {'t': '完成任務', 'd': '任務中心完成任務領取積分', 'i': Icons.task_alt_outlined},
      {'t': '下單購物', 'd': '消費回饋積分（依等級）', 'i': Icons.shopping_bag_outlined},
      {'t': '直播互動', 'd': '直播留言/下單可能加碼', 'i': Icons.live_tv_outlined},
    ];

    return _sectionCard(
      title: '如何獲得積分？',
      subtitle: '以下為常見方式（示範）',
      icon: Icons.add_circle_outline,
      child: Column(
        children: ways.map((m) {
          final t = m['t'] as String;
          final d = m['d'] as String;
          final i = m['i'] as IconData;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _brand.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(i, color: _brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '前往（示範）',
                  onPressed: () {
                    if (t == '完成任務') {
                      _tryGo('/tasks');
                    } else {
                      _toast('前往：$t（示範）');
                    }
                  },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _redeemIdeasCard() {
    // ✅ 常數 list 用 const
    const ideas = <Map<String, String>>[
      {'t': '折抵購物金', 'd': '結帳時可用積分折抵（依規則）'},
      {'t': '兌換優惠券', 'd': '到「我的優惠券」兌換專屬券'},
      {'t': '參與抽獎', 'd': '活動期間用積分換取抽獎資格'},
    ];

    return _sectionCard(
      title: '積分可以做什麼？',
      subtitle: '兌換建議（示範）',
      icon: Icons.redeem_outlined,
      child: Column(
        children: ideas.map((m) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.circle, size: 6, color: Colors.black54),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['t']!,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m['d']!,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _ctaRow() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _tryGo('/coupon_list'),
            icon: const Icon(Icons.local_offer_outlined),
            label: const Text(
              '我的優惠券',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _tryGo('/tasks'),
            icon: const Icon(Icons.task_alt_outlined),
            label: const Text(
              '任務中心',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brand,
              side: const BorderSide(color: _brand),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  void _tryGo(String route) {
    if (!mounted) {
      return;
    }
    try {
      Navigator.pushNamed(context, route);
    } catch (_) {
      _toast('此 route 未註冊：$route');
    }
  }
}

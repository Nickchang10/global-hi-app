import 'package:flutter/material.dart';

/// ✅ RewardsHubPage（獎勵中心｜最終完整版｜可編譯｜已優化 const）
/// ------------------------------------------------------------
/// - 這頁不依賴你專案的 service（避免你專案服務介面變動造成編譯錯）
/// - 內建：
///   - 積分摘要
///   - 快捷入口（優惠券/訂單/抽獎/客服）
///   - 任務列表（本地示範：可勾選完成）
/// - 導頁用 try/catch：就算你沒設 routes 也不會讓 App 掛掉
class RewardsHubPage extends StatefulWidget {
  const RewardsHubPage({super.key});

  @override
  State<RewardsHubPage> createState() => _RewardsHubPageState();
}

class _RewardsHubPageState extends State<RewardsHubPage> {
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _brand = Color(0xFF3B82F6);
  static const Color _accent = Color(0xFFFF9800);

  // ✅ 本地示範：已完成任務
  final Set<String> _completed = <String>{};

  // ✅ 本地示範：積分
  int _points = 120;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _safeNav(String route, {Object? arguments}) {
    try {
      Navigator.of(context).pushNamed(route, arguments: arguments);
    } catch (_) {
      _toast('尚未設定路由：$route');
    }
  }

  void _toggleMission(String id, int rewardPoints) {
    setState(() {
      if (_completed.contains(id)) {
        _completed.remove(id);
        _points = (_points - rewardPoints).clamp(0, 999999);
      } else {
        _completed.add(id);
        _points = (_points + rewardPoints).clamp(0, 999999);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final missions = <_Mission>[
      const _Mission(
        id: 'm_login',
        icon: Icons.login_rounded,
        title: '每日登入',
        subtitle: '每天打開 App 獲得積分',
        rewardPoints: 5,
      ),
      const _Mission(
        id: 'm_steps',
        icon: Icons.directions_walk_rounded,
        title: '完成步數目標',
        subtitle: '達成今日步數目標',
        rewardPoints: 10,
      ),
      const _Mission(
        id: 'm_share',
        icon: Icons.share_rounded,
        title: '分享活動',
        subtitle: '分享任一活動給朋友',
        rewardPoints: 8,
      ),
      const _Mission(
        id: 'm_order',
        icon: Icons.shopping_bag_rounded,
        title: '完成一次下單',
        subtitle: '完成支付並建立訂單',
        rewardPoints: 20,
      ),
    ];

    final doneCount = missions.where((m) => _completed.contains(m.id)).length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          '獎勵中心',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => _toast('已刷新'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
        children: [
          _PointsHeaderCard(
            points: _points,
            done: doneCount,
            total: missions.length,
            onOpenCoupons: () => _safeNav('/coupons'),
            onOpenOrders: () => _safeNav('/orders'),
            onOpenLottery: () => _safeNav('/lottery'),
          ),
          const SizedBox(height: 12),

          const _SectionTitle(title: '快捷入口'),
          const SizedBox(height: 8),
          _QuickGrid(
            items: [
              _QuickItem(
                icon: Icons.local_offer_outlined,
                label: '優惠券',
                onTap: () => _safeNav('/coupons'),
              ),
              _QuickItem(
                icon: Icons.receipt_long_outlined,
                label: '我的訂單',
                onTap: () => _safeNav('/orders'),
              ),
              _QuickItem(
                icon: Icons.emoji_events_outlined,
                label: '抽獎活動',
                onTap: () => _safeNav('/lottery'),
              ),
              _QuickItem(
                icon: Icons.support_agent_outlined,
                label: '客服',
                onTap: () => _safeNav('/support'),
              ),
              _QuickItem(
                icon: Icons.person_outline,
                label: '會員中心',
                onTap: () => _safeNav('/member'),
              ),
              _QuickItem(
                icon: Icons.settings_outlined,
                label: '設定',
                onTap: () => _safeNav('/settings'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const _SectionTitle(title: '任務中心'),
          const SizedBox(height: 8),
          _MissionListCard(
            brand: _brand,
            accent: _accent,
            missions: missions,
            completed: _completed,
            onToggle: _toggleMission,
          ),
          const SizedBox(height: 12),

          const _SectionTitle(title: '使用說明'),
          const SizedBox(height: 8),
          const _InfoCard(),
          const SizedBox(height: 70),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        onPressed: () => _safeNav('/points'),
        icon: const Icon(Icons.stars_rounded),
        label: const Text(
          '積分明細',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

// ======================================================
// Models
// ======================================================

class _Mission {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final int rewardPoints;

  const _Mission({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rewardPoints,
  });
}

class _QuickItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

// ======================================================
// Widgets
// ======================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }
}

class _PointsHeaderCard extends StatelessWidget {
  final int points;
  final int done;
  final int total;
  final VoidCallback onOpenCoupons;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenLottery;

  const _PointsHeaderCard({
    required this.points,
    required this.done,
    required this.total,
    required this.onOpenCoupons,
    required this.onOpenOrders,
    required this.onOpenLottery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(Icons.stars_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '我的積分',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$points',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                  ],
                ),
              ),
              _Pill(text: '任務 $done/$total'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniAction(
                  icon: Icons.local_offer_outlined,
                  label: '優惠券',
                  onTap: onOpenCoupons,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniAction(
                  icon: Icons.receipt_long_outlined,
                  label: '訂單',
                  onTap: onOpenOrders,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniAction(
                  icon: Icons.emoji_events_outlined,
                  label: '抽獎',
                  onTap: onOpenLottery,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  final List<_QuickItem> items;
  const _QuickGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (_, i) {
        final it = items[i];
        return InkWell(
          onTap: it.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(it.icon, color: const Color(0xFF3B82F6), size: 26),
                const SizedBox(height: 8),
                Text(
                  it.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MissionListCard extends StatelessWidget {
  final Color brand;
  final Color accent;
  final List<_Mission> missions;
  final Set<String> completed;
  final void Function(String id, int rewardPoints) onToggle;

  const _MissionListCard({
    required this.brand,
    required this.accent,
    required this.missions,
    required this.completed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (int i = 0; i < missions.length; i++) ...[
            _MissionTile(
              brand: brand,
              accent: accent,
              mission: missions[i],
              done: completed.contains(missions[i].id),
              onTap: () => onToggle(missions[i].id, missions[i].rewardPoints),
            ),
            if (i != missions.length - 1)
              Divider(height: 1, color: Colors.grey.shade200),
          ],
        ],
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  final Color brand;
  final Color accent;
  final _Mission mission;
  final bool done;
  final VoidCallback onTap;

  const _MissionTile({
    required this.brand,
    required this.accent,
    required this.mission,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeText = done ? '已完成' : '+${mission.rewardPoints}';
    final badgeColor = done ? Colors.green : accent;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: brand.withValues(alpha: 0.12),
        child: Icon(mission.icon, color: brand),
      ),
      title: Text(
        mission.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        mission.subtitle,
        style: TextStyle(color: Colors.grey.shade700),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
        ),
        child: Text(
          badgeText,
          style: TextStyle(
            color: badgeColor,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blueGrey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '此頁為示範版獎勵中心。\n'
                '若你要串接 Firestore/Points/任務完成狀態，我可以直接幫你接到 users/{uid}/points、missions 結構。',
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AchievementPage extends StatefulWidget {
  const AchievementPage({super.key});

  @override
  State<AchievementPage> createState() => _AchievementPageState();
}

class _AchievementPageState extends State<AchievementPage> {
  final _fs = FirebaseFirestore.instance;

  String _filter = 'all'; // all / achieved / unachieved

  int _asInt(Map<String, dynamic> data, List<String> keys, {int fallback = 0}) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
    }
    return fallback;
  }

  bool _asBool(
    Map<String, dynamic> data,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      if (v is bool) return v;
      if (v is String) {
        final t = v.toLowerCase().trim();
        if (t == 'true') return true;
        if (t == 'false') return false;
      }
    }
    return fallback;
  }

  String _asString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('成就')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('請先登入才能查看成就', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/login'),
                  child: const Text('前往登入'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('成就'), actions: [_filterMenu()]),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _fs.collection('users').doc(user.uid).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snap.data!;
          final data = doc.data() ?? <String, dynamic>{};

          final points = _asInt(data, ['points', 'userPoints', 'rewardPoints']);
          final ordersCount = _asInt(data, [
            'ordersCount',
            'orderCount',
            'totalOrders',
          ]);
          final lotteryWins = _asInt(data, [
            'lotteryWins',
            'wins',
            'lotteryWinCount',
          ]);
          final checkins = _asInt(data, [
            'checkins',
            'checkinCount',
            'dailyCheckins',
          ]);
          final referrals = _asInt(data, [
            'referrals',
            'referralCount',
            'inviteCount',
          ]);
          final isVip = _asBool(data, ['isVip', 'vip', 'vipMember']);
          final displayName = _asString(data, [
            'displayName',
            'name',
          ], fallback: '會員');

          final achievements = _buildAchievements(
            points: points,
            ordersCount: ordersCount,
            lotteryWins: lotteryWins,
            checkins: checkins,
            referrals: referrals,
            isVip: isVip,
          );

          final filtered = achievements.where((a) {
            if (_filter == 'achieved') return a.achieved;
            if (_filter == 'unachieved') return !a.achieved;
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(displayName, achievements),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: Text('沒有符合條件的成就')),
                )
              else
                ...filtered.map((a) => _achievementCard(a)).toList(),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _filterMenu() {
    String label;
    switch (_filter) {
      case 'achieved':
        label = '已達成';
        break;
      case 'unachieved':
        label = '未達成';
        break;
      default:
        label = '全部';
    }

    return PopupMenuButton<String>(
      tooltip: '篩選',
      onSelected: (v) => setState(() => _filter = v),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'all', child: Text('全部')),
        PopupMenuItem(value: 'achieved', child: Text('已達成')),
        PopupMenuItem(value: 'unachieved', child: Text('未達成')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.filter_list),
            const SizedBox(width: 6),
            Text(label),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _header(String name, List<_Achievement> achievements) {
    final achievedCount = achievements.where((e) => e.achieved).length;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.emoji_events)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name 的成就',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已達成 $achievedCount / ${achievements.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            _pill(
              '${(achievedCount / (achievements.isEmpty ? 1 : achievements.length) * 100).toStringAsFixed(0)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        // ✅ FIX: withOpacity -> withValues(alpha: ...)
        color: Colors.black.withValues(alpha: 0.06),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  List<_Achievement> _buildAchievements({
    required int points,
    required int ordersCount,
    required int lotteryWins,
    required int checkins,
    required int referrals,
    required bool isVip,
  }) {
    // 你可以依照你 Firestore 真正欄位/邏輯，調整 target 與對應值
    return [
      _Achievement.progress(
        id: 'points_100',
        title: '積分新手',
        description: '累積 100 積分',
        icon: Icons.stars,
        current: points,
        target: 100,
      ),
      _Achievement.progress(
        id: 'points_500',
        title: '積分達人',
        description: '累積 500 積分',
        icon: Icons.star_rate,
        current: points,
        target: 500,
      ),
      _Achievement.progress(
        id: 'orders_1',
        title: '第一筆訂單',
        description: '完成 1 筆訂單',
        icon: Icons.shopping_bag,
        current: ordersCount,
        target: 1,
      ),
      _Achievement.progress(
        id: 'orders_10',
        title: '回購玩家',
        description: '完成 10 筆訂單',
        icon: Icons.shopping_cart,
        current: ordersCount,
        target: 10,
      ),
      _Achievement.progress(
        id: 'lottery_1',
        title: '中獎一次',
        description: '抽獎中獎 1 次',
        icon: Icons.casino,
        current: lotteryWins,
        target: 1,
      ),
      _Achievement.progress(
        id: 'checkin_7',
        title: '連續簽到',
        description: '累積簽到 7 次',
        icon: Icons.event_available,
        current: checkins,
        target: 7,
      ),
      _Achievement.progress(
        id: 'ref_1',
        title: '邀請好友',
        description: '成功邀請 1 位好友',
        icon: Icons.person_add_alt_1,
        current: referrals,
        target: 1,
      ),
      _Achievement.boolean(
        id: 'vip',
        title: 'VIP 會員',
        description: '成為 VIP',
        icon: Icons.workspace_premium,
        achieved: isVip,
      ),
    ];
  }

  Widget _achievementCard(_Achievement a) {
    final progress = a.target > 0
        ? (a.current / a.target).clamp(0.0, 1.0)
        : (a.achieved ? 1.0 : 0.0);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(a.icon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (a.achieved)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                // ✅ FIX: withOpacity -> withValues(alpha: ...)
                                color: Colors.green.withValues(alpha: 0.12),
                              ),
                              child: const Text(
                                '已達成',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.description,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  a.target > 0
                      ? '${a.current} / ${a.target}'
                      : (a.achieved ? '完成' : '未完成'),
                  style: const TextStyle(color: Colors.grey),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showAchievementDetail(a),
                  child: const Text('詳情'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAchievementDetail(_Achievement a) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(a.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.description),
            const SizedBox(height: 10),
            Text(
              a.target > 0
                  ? '進度：${a.current} / ${a.target}'
                  : '狀態：${a.achieved ? '完成' : '未完成'}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }
}

class _Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  final int current;
  final int target;
  final bool achieved;

  const _Achievement._({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.current,
    required this.target,
    required this.achieved,
  });

  factory _Achievement.progress({
    required String id,
    required String title,
    required String description,
    required IconData icon,
    required int current,
    required int target,
  }) {
    final achieved = target > 0 ? (current >= target) : false;
    return _Achievement._(
      id: id,
      title: title,
      description: description,
      icon: icon,
      current: current,
      target: target,
      achieved: achieved,
    );
  }

  factory _Achievement.boolean({
    required String id,
    required String title,
    required String description,
    required IconData icon,
    required bool achieved,
  }) {
    return _Achievement._(
      id: id,
      title: title,
      description: description,
      icon: icon,
      current: achieved ? 1 : 0,
      target: 1,
      achieved: achieved,
    );
  }
}

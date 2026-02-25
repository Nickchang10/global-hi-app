import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ BadgeGalleryPage（徽章牆｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// - ✅ 修正 withOpacity deprecated：全部改為 withValues(alpha: ...)
/// - 支援：
///   - 顯示「全部徽章」（內建示範清單）
///   - 顯示「我的徽章」（Firestore：users/{uid}/badges）
class BadgeGalleryPage extends StatefulWidget {
  const BadgeGalleryPage({super.key});

  @override
  State<BadgeGalleryPage> createState() => _BadgeGalleryPageState();
}

class _BadgeGalleryPageState extends State<BadgeGalleryPage>
    with SingleTickerProviderStateMixin {
  final _fs = FirebaseFirestore.instance;

  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // -------------------------
  // Demo badges（你可換成 Firestore 全徽章）
  // -------------------------
  final List<_BadgeDef> _allBadges = const [
    _BadgeDef(
      id: 'first_login',
      title: '初次登入',
      desc: '完成第一次登入',
      icon: Icons.verified_user,
    ),
    _BadgeDef(
      id: 'first_order',
      title: '第一筆訂單',
      desc: '完成第一次購買',
      icon: Icons.shopping_bag,
    ),
    _BadgeDef(
      id: 'mission_10',
      title: '任務達人',
      desc: '完成 10 次任務',
      icon: Icons.task_alt,
    ),
    _BadgeDef(
      id: 'share_friend',
      title: '分享高手',
      desc: '分享給朋友一次',
      icon: Icons.share,
    ),
    _BadgeDef(
      id: 'sos_ready',
      title: 'SOS 準備就緒',
      desc: '完成 SOS 設定',
      icon: Icons.sos,
    ),
    _BadgeDef(
      id: 'health_check',
      title: '健康守護',
      desc: '完成一次健康量測',
      icon: Icons.favorite,
    ),
  ];

  // -------------------------
  // Firestore stream（我的徽章）
  // users/{uid}/badges/{badgeId}
  // 欄位建議：
  // - earnedAt (Timestamp)
  // - title/desc/icon 可選（若你想覆蓋預設）
  // -------------------------
  Stream<List<_UserBadge>> _myBadgesStream() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      return const Stream<List<_UserBadge>>.empty();
    }

    return _fs
        .collection('users')
        .doc(uid)
        .collection('badges')
        .orderBy('earnedAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) {
                final data = d.data();
                return _UserBadge(
                  id: d.id,
                  earnedAt: (data['earnedAt'] as Timestamp?)?.toDate(),
                );
              })
              .toList(growable: false);
        });
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('徽章牆'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '全部徽章'),
            Tab(text: '我的徽章'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_allBadgesView(cs), _myBadgesView(cs)],
      ),
    );
  }

  // -------------------------
  // 全部徽章
  // -------------------------
  Widget _allBadgesView(ColorScheme cs) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: _allBadges.length,
      itemBuilder: (context, i) {
        final b = _allBadges[i];
        return _badgeCard(
          cs,
          title: b.title,
          desc: b.desc,
          icon: b.icon,
          earned: null,
          onTap: () => _showBadgeDetail(
            title: b.title,
            desc: b.desc,
            icon: b.icon,
            earnedAt: null,
          ),
        );
      },
    );
  }

  // -------------------------
  // 我的徽章（對照全部徽章）
  // -------------------------
  Widget _myBadgesView(ColorScheme cs) {
    final uid = _uid;
    if (uid == null) {
      return Center(
        child: Text(
          '請先登入才能查看我的徽章',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    return StreamBuilder<List<_UserBadge>>(
      stream: _myBadgesStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final mine = snap.data ?? <_UserBadge>[];
        final mineSet = mine.map((e) => e.id).toSet();

        if (mine.isEmpty) {
          return Center(
            child: Text(
              '你目前尚未獲得徽章\n完成任務/活動後就會出現在這裡',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: _allBadges.length,
          itemBuilder: (context, i) {
            final def = _allBadges[i];
            final earned = mineSet.contains(def.id)
                ? mine.firstWhere((x) => x.id == def.id).earnedAt
                : null;

            return _badgeCard(
              cs,
              title: def.title,
              desc: def.desc,
              icon: def.icon,
              earned: earned,
              onTap: () => _showBadgeDetail(
                title: def.title,
                desc: def.desc,
                icon: def.icon,
                earnedAt: earned,
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------
  // Card UI
  // -------------------------
  Widget _badgeCard(
    ColorScheme cs, {
    required String title,
    required String desc,
    required IconData icon,
    required DateTime? earned,
    required VoidCallback onTap,
  }) {
    final earnedOk = earned != null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.surface,
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
              // ✅ 這裡就是你報錯那種 withOpacity 改成 withValues
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: (earnedOk ? cs.primary : cs.outline)
                        .withValues(alpha: 0.12),
                    child: Icon(
                      icon,
                      color: earnedOk ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  _earnedChip(cs, earned),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    earnedOk ? Icons.lock_open : Icons.lock,
                    size: 16,
                    color: earnedOk ? Colors.green : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    earnedOk ? '已獲得' : '未獲得',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: earnedOk ? Colors.green : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _earnedChip(ColorScheme cs, DateTime? earned) {
    final text = earned == null
        ? '未獲得'
        : '獲得 ${earned.year}/${earned.month.toString().padLeft(2, '0')}/${earned.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _showBadgeDetail({
    required String title,
    required String desc,
    required IconData icon,
    required DateTime? earnedAt,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 28, child: Icon(icon, size: 30)),
              const SizedBox(height: 12),
              Text(desc),
              const SizedBox(height: 12),
              Text(
                earnedAt == null
                    ? '尚未獲得'
                    : '獲得時間：${earnedAt.year}/${earnedAt.month.toString().padLeft(2, '0')}/${earnedAt.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }
}

// -------------------------
// Models
// -------------------------
class _BadgeDef {
  final String id;
  final String title;
  final String desc;
  final IconData icon;

  const _BadgeDef({
    required this.id,
    required this.title,
    required this.desc,
    required this.icon,
  });
}

class _UserBadge {
  final String id;
  final DateTime? earnedAt;

  const _UserBadge({required this.id, required this.earnedAt});
}

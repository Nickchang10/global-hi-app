import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ BadgeWallPage（徽章牆｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正：
/// - ✅ unnecessary_brace_in_string_interps：單純變數插值改用 $var（不寫 ${var}）
/// - ✅ UI：全部徽章 / 我的徽章
/// - ✅ Firestore（可選）：
///    - 全部徽章定義：badges/{badgeId}
///      欄位：title, desc, iconKey（String，可選）
///    - 我的徽章：users/{uid}/badges/{badgeId}
///      欄位：earnedAt (Timestamp，可選)
///
/// 若 badges collection 不存在 / rules 未就緒：會自動回退使用內建示範徽章清單，不會噴錯
class BadgeWallPage extends StatefulWidget {
  const BadgeWallPage({super.key});

  @override
  State<BadgeWallPage> createState() => _BadgeWallPageState();
}

class _BadgeWallPageState extends State<BadgeWallPage>
    with SingleTickerProviderStateMixin {
  final _fs = FirebaseFirestore.instance;
  late final TabController _tab;

  bool _loadingDefs = true;
  String? _defsError;

  List<_BadgeDef> _defs = <_BadgeDef>[];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadDefinitions();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // -------------------------
  // Fallback badge definitions
  // -------------------------
  static const List<_BadgeDef> _fallbackDefs = [
    _BadgeDef(
      id: 'first_login',
      title: '初次登入',
      desc: '完成第一次登入',
      iconKey: 'verified_user',
    ),
    _BadgeDef(
      id: 'first_order',
      title: '第一筆訂單',
      desc: '完成第一次購買',
      iconKey: 'shopping_bag',
    ),
    _BadgeDef(
      id: 'mission_10',
      title: '任務達人',
      desc: '完成 10 次任務',
      iconKey: 'task_alt',
    ),
    _BadgeDef(
      id: 'share_friend',
      title: '分享高手',
      desc: '分享給朋友一次',
      iconKey: 'share',
    ),
    _BadgeDef(
      id: 'sos_ready',
      title: 'SOS 準備就緒',
      desc: '完成 SOS 設定',
      iconKey: 'sos',
    ),
    _BadgeDef(
      id: 'health_check',
      title: '健康守護',
      desc: '完成一次健康量測',
      iconKey: 'favorite',
    ),
  ];

  // -------------------------
  // Load badge definitions
  // -------------------------
  Future<void> _loadDefinitions() async {
    setState(() {
      _loadingDefs = true;
      _defsError = null;
    });

    try {
      final snap = await _fs.collection('badges').limit(300).get();
      final list = snap.docs
          .map((d) => _BadgeDef.fromDoc(d.id, d.data()))
          .where((b) => b.id.trim().isNotEmpty)
          .toList(growable: false);

      if (!mounted) return;

      setState(() {
        _defs = list.isEmpty ? _fallbackDefs : list;
        _loadingDefs = false;
        _defsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _defs = _fallbackDefs;
        _loadingDefs = false;
        _defsError = '徽章定義載入失敗，已使用內建徽章（$e）';
      });
    }
  }

  // -------------------------
  // My badges stream
  // users/{uid}/badges
  // -------------------------
  Stream<Map<String, DateTime?>> _myBadgesStream() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      return Stream.value(<String, DateTime?>{});
    }

    return _fs
        .collection('users')
        .doc(uid)
        .collection('badges')
        .snapshots()
        .map((snap) {
          final map = <String, DateTime?>{};
          for (final d in snap.docs) {
            final data = d.data();
            final ts = data['earnedAt'];
            map[d.id] = (ts is Timestamp) ? ts.toDate() : null;
          }
          return map;
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
        actions: [
          IconButton(
            tooltip: '重新載入徽章定義',
            onPressed: _loadDefinitions,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '全部徽章'),
            Tab(text: '我的徽章'),
          ],
        ),
      ),
      body: _loadingDefs
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_defsError != null) _warnBar(cs, _defsError!),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [_allBadgesTab(cs), _myBadgesTab(cs)],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _warnBar(ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // -------------------------
  // Tabs
  // -------------------------
  Widget _allBadgesTab(ColorScheme cs) {
    return StreamBuilder<Map<String, DateTime?>>(
      stream: _myBadgesStream(),
      builder: (context, snap) {
        final mine = snap.data ?? <String, DateTime?>{};
        final earnedCount = mine.keys.length;
        final total = _defs.length;

        return Column(
          children: [
            _summaryHeader(
              cs,
              title: '全部徽章',
              subtitle: '已獲得 $earnedCount / $total',
            ),
            const Divider(height: 1),
            Expanded(child: _grid(cs, mine, mode: _WallMode.all)),
          ],
        );
      },
    );
  }

  Widget _myBadgesTab(ColorScheme cs) {
    final uid = _uid;
    if (uid == null) {
      return Center(
        child: Text(
          '請先登入才能查看我的徽章',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    return StreamBuilder<Map<String, DateTime?>>(
      stream: _myBadgesStream(),
      builder: (context, snap) {
        final mine = snap.data ?? <String, DateTime?>{};
        final earnedCount = mine.keys.length;

        return Column(
          children: [
            _summaryHeader(
              cs,
              title: '我的徽章',
              subtitle: earnedCount == 0 ? '尚未獲得徽章' : '已獲得 $earnedCount 枚',
            ),
            const Divider(height: 1),
            Expanded(child: _grid(cs, mine, mode: _WallMode.mine)),
          ],
        );
      },
    );
  }

  Widget _summaryHeader(
    ColorScheme cs, {
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.32),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            child: Icon(Icons.emoji_events, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------
  // Grid
  // -------------------------
  Widget _grid(
    ColorScheme cs,
    Map<String, DateTime?> mine, {
    required _WallMode mode,
  }) {
    final items = mode == _WallMode.mine
        ? _defs.where((b) => mine.containsKey(b.id)).toList(growable: false)
        : _defs;

    if (items.isEmpty) {
      return Center(
        child: Text(
          mode == _WallMode.mine ? '你目前尚未獲得徽章\n完成任務/活動後就會出現在這裡' : '目前沒有徽章',
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
      itemCount: items.length,
      itemBuilder: (context, i) {
        final b = items[i];
        final earnedAt = mine[b.id];
        final earned = mine.containsKey(b.id);

        return _badgeCard(
          cs,
          def: b,
          earned: earned,
          earnedAt: earnedAt,
          onTap: () => _openDetail(cs, b, earned: earned, earnedAt: earnedAt),
        );
      },
    );
  }

  Widget _badgeCard(
    ColorScheme cs, {
    required _BadgeDef def,
    required bool earned,
    required DateTime? earnedAt,
    required VoidCallback onTap,
  }) {
    final icon = _iconFromKey(def.iconKey);
    final title = def.title.isEmpty ? '(未命名徽章)' : def.title;
    final desc = def.desc.isEmpty ? '（無描述）' : def.desc;

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
              offset: const Offset(0, 2),
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
                    backgroundColor: (earned ? cs.primary : cs.outline)
                        .withValues(alpha: 0.12),
                    child: Icon(
                      icon,
                      color: earned ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  _earnedChip(cs, earned, earnedAt),
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
                    earned ? Icons.lock_open : Icons.lock,
                    size: 16,
                    color: earned ? Colors.green : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    earned ? '已獲得' : '未獲得',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: earned ? Colors.green : cs.onSurfaceVariant,
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

  Widget _earnedChip(ColorScheme cs, bool earned, DateTime? earnedAt) {
    final text = earned
        ? (earnedAt == null ? '已獲得' : '獲得 ${_ymd(earnedAt)}')
        : '未獲得';

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

  Future<void> _openDetail(
    ColorScheme cs,
    _BadgeDef def, {
    required bool earned,
    required DateTime? earnedAt,
  }) async {
    final icon = _iconFromKey(def.iconKey);
    final title = def.title.isEmpty ? '(未命名徽章)' : def.title;
    final desc = def.desc.isEmpty ? '（無描述）' : def.desc;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: (earned ? cs.primary : cs.outline).withValues(
                  alpha: 0.12,
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: earned ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(desc),
              const SizedBox(height: 12),
              Text(
                earned
                    ? (earnedAt == null
                          ? '狀態：已獲得'
                          : '狀態：已獲得（${_ymd(earnedAt)}）')
                    : '狀態：未獲得',
                style: TextStyle(color: cs.onSurfaceVariant),
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

  // -------------------------
  // Utilities
  // -------------------------
  String _ymd(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  IconData _iconFromKey(String key) {
    switch (key.trim()) {
      case 'verified_user':
        return Icons.verified_user;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'task_alt':
        return Icons.task_alt;
      case 'share':
        return Icons.share;
      case 'sos':
        return Icons.sos;
      case 'favorite':
        return Icons.favorite;
      case 'emoji_events':
        return Icons.emoji_events;
      default:
        return Icons.emoji_events;
    }
  }
}

enum _WallMode { all, mine }

// -------------------------
// Models
// -------------------------
class _BadgeDef {
  final String id;
  final String title;
  final String desc;
  final String iconKey;

  const _BadgeDef({
    required this.id,
    required this.title,
    required this.desc,
    required this.iconKey,
  });

  factory _BadgeDef.fromDoc(String id, Map<String, dynamic> data) {
    return _BadgeDef(
      id: id,
      title: (data['title'] ?? data['name'] ?? '').toString(),
      desc: (data['desc'] ?? data['description'] ?? '').toString(),
      iconKey: (data['iconKey'] ?? data['icon'] ?? 'emoji_events').toString(),
    );
  }
}

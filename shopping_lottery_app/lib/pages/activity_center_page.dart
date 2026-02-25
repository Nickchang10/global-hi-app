import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ ActivityCenterPage（活動中心｜完整版｜已移除 FirestoreMockService.userPoints）
/// ------------------------------------------------------------
/// - 會員積分：讀取 users/{uid}.points
/// - 活動列表：預設讀 campaigns（若沒有資料則讀 auto_campaigns）
/// - 不依賴任何 mock service，避免 undefined_getter
/// ------------------------------------------------------------
class ActivityCenterPage extends StatefulWidget {
  const ActivityCenterPage({super.key});

  @override
  State<ActivityCenterPage> createState() => _ActivityCenterPageState();
}

class _ActivityCenterPageState extends State<ActivityCenterPage> {
  final _fs = FirebaseFirestore.instance;
  final _df = DateFormat('yyyy/MM/dd');

  bool _showOnlyActive = true;

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  double _asDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  bool _asBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is String) {
      final t = v.toLowerCase().trim();
      if (t == 'true') return true;
      if (t == 'false') return false;
    }
    return fallback;
  }

  DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  /// 嘗試讀 campaigns，若空則再讀 auto_campaigns（避免你專案命名不一致）
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _activitiesStream() async* {
    final q1 = _fs
        .collection('campaigns')
        .orderBy('createdAt', descending: true)
        .limit(50);

    await for (final snap1 in q1.snapshots()) {
      if (snap1.docs.isNotEmpty) {
        yield snap1.docs;
      } else {
        // fallback to auto_campaigns
        final q2 = _fs
            .collection('auto_campaigns')
            .orderBy('createdAt', descending: true)
            .limit(50);
        await for (final snap2 in q2.snapshots()) {
          yield snap2.docs;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('活動中心')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  '請先登入才能查看活動中心',
                  style: TextStyle(color: Colors.grey),
                ),
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
      appBar: AppBar(
        title: const Text('活動中心'),
        actions: [
          Row(
            children: [
              const Text('只看啟用', style: TextStyle(fontSize: 12)),
              Switch(
                value: _showOnlyActive,
                onChanged: (v) => setState(() => _showOnlyActive = v),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _userHeader(uid: user.uid),
          const Divider(height: 1),
          Expanded(child: _activityList()),
        ],
      ),
    );
  }

  Widget _userHeader({required String uid}) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _fs.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _headerCard(
            name: '讀取失敗',
            subtitle: snap.error.toString(),
            points: 0,
          );
        }
        if (!snap.hasData) {
          return _headerLoading();
        }

        final d = snap.data!.data() ?? <String, dynamic>{};
        final name = (d['displayName'] ?? d['name'] ?? d['email'] ?? '會員')
            .toString();
        final points = _asInt(
          d['points'] ?? d['userPoints'] ?? d['rewardPoints'],
        );

        return _headerCard(
          name: name,
          subtitle: '可用積分：$points',
          points: points,
        );
      },
    );
  }

  // ✅ FIX: 整段改成 const constructors（解 prefer_const_constructors 175–195）
  Widget _headerLoading() {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(child: Icon(Icons.emoji_events)),
              SizedBox(width: 12),
              Expanded(child: Text('載入會員資料中…')),
              SizedBox(width: 12),
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard({
    required String name,
    required String subtitle,
    required int points,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
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
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  // ✅ FIX: withOpacity -> withValues(alpha: ...)
                  color: Colors.black.withValues(alpha: 0.06),
                ),
                child: Text(
                  'Points $points',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityList() {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _activitiesStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('讀取活動失敗：${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!;
        if (docs.isEmpty) {
          return const Center(child: Text('目前沒有活動'));
        }

        final items = docs
            .map(
              (doc) => _ActivityItem.fromDoc(
                doc,
                asBool: _asBool,
                asInt: _asInt,
                asDouble: _asDouble,
                asDate: _asDate,
              ),
            )
            .where((a) => !_showOnlyActive || a.isActive)
            .toList();

        if (items.isEmpty) {
          return const Center(child: Text('沒有符合條件的活動'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _activityCard(items[i]),
        );
      },
    );
  }

  Widget _activityCard(_ActivityItem a) {
    final dateText = _formatRange(a.startAt, a.endAt);

    return Card(
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(child: Icon(a.icon)),
        title: Text(
          a.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (a.subtitle.isNotEmpty) a.subtitle,
            if (dateText.isNotEmpty) dateText,
          ].join('  •  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _pill(
              a.isActive ? '啟用' : '停用',
              a.isActive ? Colors.green : Colors.grey,
            ),
            if (a.rewardPoints > 0) ...[
              const SizedBox(height: 6),
              _pill('+${a.rewardPoints} 點', Colors.blue),
            ],
          ],
        ),
        onTap: () => _showActivityDetail(a),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        // ✅ FIX: withOpacity -> withValues(alpha: ...)
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _formatRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    if (start != null && end != null) {
      return '${_df.format(start)} ~ ${_df.format(end)}';
    }
    if (start != null) return '開始：${_df.format(start)}';
    return '結束：${_df.format(end!)}';
  }

  Future<void> _showActivityDetail(_ActivityItem a) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(a.title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a.subtitle.isNotEmpty) Text(a.subtitle),
                const SizedBox(height: 10),
                Text('狀態：${a.isActive ? '啟用' : '停用'}'),
                if (a.rewardPoints > 0) Text('獎勵：+${a.rewardPoints} 點'),
                if (a.ctr != null) Text('CTR：${a.ctr!.toStringAsFixed(1)}%'),
                if (a.cvr != null) Text('CVR：${a.cvr!.toStringAsFixed(1)}%'),
                if (a.startAt != null || a.endAt != null)
                  Text('期間：${_formatRange(a.startAt, a.endAt)}'),
                const SizedBox(height: 10),
                const Text(
                  '原始資料',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  a.rawDebug,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
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

class _ActivityItem {
  final String id;
  final String title;
  final String subtitle;
  final bool isActive;

  final int rewardPoints;
  final double? ctr;
  final double? cvr;

  final DateTime? startAt;
  final DateTime? endAt;

  final IconData icon;

  final String rawDebug;

  _ActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.rewardPoints,
    required this.ctr,
    required this.cvr,
    required this.startAt,
    required this.endAt,
    required this.icon,
    required this.rawDebug,
  });

  static _ActivityItem fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool Function(dynamic v, {bool fallback}) asBool,
    required int Function(dynamic v, {int fallback}) asInt,
    required double Function(dynamic v, {double fallback}) asDouble,
    required DateTime? Function(dynamic v) asDate,
  }) {
    final d = doc.data();

    final title = (d['title'] ?? d['name'] ?? d['campaignName'] ?? '未命名活動')
        .toString();
    final subtitle = (d['subtitle'] ?? d['description'] ?? d['desc'] ?? '')
        .toString();

    final isActive = asBool(
      d['isActive'] ?? d['enabled'] ?? d['active'],
      fallback: true,
    );

    // 常見獎勵欄位：rewardPoints / points / bonusPoints
    final rewardPoints = asInt(
      d['rewardPoints'] ?? d['points'] ?? d['bonusPoints'],
      fallback: 0,
    );

    // 指標欄位：ctr/cvr（可能是 0~1 或 0~100）
    double? ctr;
    if (d.containsKey('ctr')) {
      final v = asDouble(d['ctr'], fallback: 0);
      ctr = v <= 1.0 ? v * 100 : v;
    }
    double? cvr;
    if (d.containsKey('cvr')) {
      final v = asDouble(d['cvr'], fallback: 0);
      cvr = v <= 1.0 ? v * 100 : v;
    }

    final startAt = asDate(d['startAt'] ?? d['startDate'] ?? d['startsAt']);
    final endAt = asDate(d['endAt'] ?? d['endDate'] ?? d['endsAt']);

    final type = (d['type'] ?? d['campaignType'] ?? '')
        .toString()
        .toLowerCase();
    final icon = _iconByType(type);

    final raw = d.toString();

    return _ActivityItem(
      id: doc.id,
      title: title,
      subtitle: subtitle,
      isActive: isActive,
      rewardPoints: rewardPoints,
      ctr: ctr,
      cvr: cvr,
      startAt: startAt,
      endAt: endAt,
      icon: icon,
      rawDebug: raw,
    );
  }

  static IconData _iconByType(String type) {
    switch (type) {
      case 'coupon':
        return Icons.card_giftcard;
      case 'lottery':
        return Icons.casino;
      case 'checkin':
        return Icons.event_available;
      case 'referral':
        return Icons.person_add_alt_1;
      case 'campaign':
        return Icons.campaign;
      default:
        return Icons.local_activity;
    }
  }
}

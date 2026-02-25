import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// ✅ ActivityPage（活動頁｜完整版｜已修正 GoogleFonts.notoSansTc）
/// ------------------------------------------------------------
/// - 修正：不再呼叫 GoogleFonts.notoSansTc（不存在）
/// - 改用：GoogleFonts.getFont('Noto Sans TC')（相容性高）
/// - 資料：Firestore 讀 campaigns；若空 fallback auto_campaigns
/// - 顯示：標題/描述/活動期間/獎勵點數/啟用狀態
/// - 會員點數：讀 users/{uid}.points（可選顯示）
/// ------------------------------------------------------------
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  final _fs = FirebaseFirestore.instance;
  final _df = DateFormat('yyyy/MM/dd');

  bool _onlyActive = true;
  String _typeFilter = 'all'; // all/coupon/lottery/checkin/referral/campaign

  TextStyle _tc(TextStyle base) {
    // ✅ 取代 GoogleFonts.notoSansTc / notoSansTC
    // getFont 在 google_fonts 多數版本都可用，穩定
    return GoogleFonts.getFont('Noto Sans TC', textStyle: base);
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
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

    final titleStyle = _tc(
      const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    );
    final itemTitleStyle = _tc(
      const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    );
    final itemSubStyle = _tc(const TextStyle(fontSize: 13, color: Colors.grey));

    return Scaffold(
      appBar: AppBar(
        title: Text('活動', style: titleStyle),
        actions: [
          Row(
            children: [
              Text('只看啟用', style: _tc(const TextStyle(fontSize: 12))),
              Switch(
                value: _onlyActive,
                onChanged: (v) => setState(() => _onlyActive = v),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (user != null) _userPointsHeader(user.uid),
          _filterBar(),
          const Divider(height: 1),
          Expanded(
            child:
                StreamBuilder<
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>
                >(
                  stream: _activitiesStream(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text('讀取失敗：${snap.error}', style: itemSubStyle),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!;
                    if (docs.isEmpty) {
                      return Center(child: Text('目前沒有活動', style: itemSubStyle));
                    }

                    final items = docs
                        .map(
                          (d) => _ActivityItem.fromDoc(
                            d,
                            asInt: _asInt,
                            asBool: _asBool,
                            asDate: _asDate,
                          ),
                        )
                        .where((a) => !_onlyActive || a.isActive)
                        .where(
                          (a) => _typeFilter == 'all' || a.type == _typeFilter,
                        )
                        .toList();

                    if (items.isEmpty) {
                      return Center(
                        child: Text('沒有符合條件的活動', style: itemSubStyle),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final a = items[i];
                        return Card(
                          elevation: 1,
                          child: ListTile(
                            leading: CircleAvatar(child: Icon(a.icon)),
                            title: Text(
                              a.title,
                              style: itemTitleStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if (a.subtitle.isNotEmpty) a.subtitle,
                                if (_formatRange(a.startAt, a.endAt).isNotEmpty)
                                  _formatRange(a.startAt, a.endAt),
                              ].join('  •  '),
                              style: itemSubStyle,
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
                            onTap: () => _showDetail(a),
                          ),
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _userPointsHeader(String uid) {
    final textStyle = _tc(
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _fs.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        int points = 0;
        String name = '會員';

        if (snap.hasData && snap.data!.exists) {
          final d = snap.data!.data() ?? {};
          name = (d['displayName'] ?? d['name'] ?? d['email'] ?? '會員')
              .toString();
          points = _asInt(d['points'] ?? d['userPoints'] ?? d['rewardPoints']);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.emoji_events)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$name • 目前積分 $points',
                      style: textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _pill('Points $points', Colors.black87),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filterBar() {
    final chipStyle = _tc(
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip('全部', 'all', chipStyle),
          _chip('優惠券', 'coupon', chipStyle),
          _chip('抽獎', 'lottery', chipStyle),
          _chip('簽到', 'checkin', chipStyle),
          _chip('邀請', 'referral', chipStyle),
          _chip('活動', 'campaign', chipStyle),
        ],
      ),
    );
  }

  Widget _chip(String label, String key, TextStyle style) {
    final selected = _typeFilter == key;
    return ChoiceChip(
      selected: selected,
      label: Text(label, style: style),
      onSelected: (_) => setState(() => _typeFilter = key),
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
        style: _tc(
          TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
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

  Future<void> _showDetail(_ActivityItem a) async {
    final titleStyle = _tc(
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
    final bodyStyle = _tc(const TextStyle(fontSize: 13));

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(a.title, style: titleStyle),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: DefaultTextStyle(
              style: bodyStyle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (a.subtitle.isNotEmpty) Text(a.subtitle),
                  const SizedBox(height: 10),
                  Text('類型：${a.type}'),
                  Text('狀態：${a.isActive ? '啟用' : '停用'}'),
                  if (a.rewardPoints > 0) Text('獎勵：+${a.rewardPoints} 點'),
                  if (a.startAt != null || a.endAt != null)
                    Text('期間：${_formatRange(a.startAt, a.endAt)}'),
                  const SizedBox(height: 12),
                  const Text(
                    '原始資料',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.rawDebug,
                    style: _tc(
                      const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
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
  final String type; // coupon/lottery/checkin/referral/campaign/unknown
  final bool isActive;
  final int rewardPoints;
  final DateTime? startAt;
  final DateTime? endAt;
  final IconData icon;
  final String rawDebug;

  _ActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.isActive,
    required this.rewardPoints,
    required this.startAt,
    required this.endAt,
    required this.icon,
    required this.rawDebug,
  });

  static _ActivityItem fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required int Function(dynamic v, {int fallback}) asInt,
    required bool Function(dynamic v, {bool fallback}) asBool,
    required DateTime? Function(dynamic v) asDate,
  }) {
    final d = doc.data();

    final title = (d['title'] ?? d['name'] ?? d['campaignName'] ?? '未命名活動')
        .toString();
    final subtitle = (d['subtitle'] ?? d['description'] ?? d['desc'] ?? '')
        .toString();

    final typeRaw = (d['type'] ?? d['campaignType'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final type = typeRaw.isEmpty ? 'campaign' : typeRaw;

    final isActive = asBool(
      d['isActive'] ?? d['enabled'] ?? d['active'],
      fallback: true,
    );
    final rewardPoints = asInt(
      d['rewardPoints'] ?? d['points'] ?? d['bonusPoints'],
      fallback: 0,
    );

    final startAt = asDate(d['startAt'] ?? d['startDate'] ?? d['startsAt']);
    final endAt = asDate(d['endAt'] ?? d['endDate'] ?? d['endsAt']);

    return _ActivityItem(
      id: doc.id,
      title: title,
      subtitle: subtitle,
      type: type,
      isActive: isActive,
      rewardPoints: rewardPoints,
      startAt: startAt,
      endAt: endAt,
      icon: _iconByType(type),
      rawDebug: d.toString(),
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

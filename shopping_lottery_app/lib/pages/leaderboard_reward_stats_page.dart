// lib/pages/leaderboard_reward_stats_page.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ LeaderboardRewardStatsPage（排行榜獎勵統計｜完整版）
/// ------------------------------------------------------------
/// ✅ 修正重點：
/// - 移除未使用的 _s / _asNum / _asDate（修正 unused_element）
/// - 不依賴 fl_chart / MockService
/// - 直接用 FirebaseAuth + Firestore 統計
///
/// Firestore 建議結構
/// - users/{uid}/leaderboard_reward_history/{historyId}
///   - seasonId: String (optional)
///   - seasonName: String (optional)
///   - rank: num (optional)
///   - rewardTitle: String (optional)
///   - rewardType: String (optional)  // coupon / points / gift / ...
///   - rewardValue: num (optional)
///   - claimed: bool (optional)
///   - claimedAt: Timestamp (optional)
///   - createdAt: Timestamp (optional)
///
/// ⚠️ 為了避免欄位/索引不存在：
/// - 查詢使用 orderBy(documentId)（安全）
/// - 時間範圍用 client-side 過濾 createdAt / claimedAt
/// ------------------------------------------------------------
class LeaderboardRewardStatsPage extends StatefulWidget {
  final String? uid;
  const LeaderboardRewardStatsPage({super.key, this.uid});

  @override
  State<LeaderboardRewardStatsPage> createState() =>
      _LeaderboardRewardStatsPageState();
}

class _LeaderboardRewardStatsPageState
    extends State<LeaderboardRewardStatsPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  String _range = '30d'; // 7d / 30d / 90d
  bool _useClaimedTime = true; // true=用 claimedAt 做趨勢；false=用 createdAt

  User? get _user => _auth.currentUser;

  int _days() => _range == '90d'
      ? 90
      : _range == '7d'
      ? 7
      : 30;

  DateTime _startTime() => DateTime.now().subtract(Duration(days: _days() - 1));

  String _yyyymmdd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y$m$dd';
  }

  /// ✅ 只保留一個 _fmtDate
  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y/$m/$dd';
  }

  DateTime _parseYmd(String yyyymmdd) {
    if (yyyymmdd.length != 8) return DateTime.now();
    final y = int.tryParse(yyyymmdd.substring(0, 4)) ?? DateTime.now().year;
    final m = int.tryParse(yyyymmdd.substring(4, 6)) ?? DateTime.now().month;
    final d = int.tryParse(yyyymmdd.substring(6, 8)) ?? DateTime.now().day;
    return DateTime(y, m, d);
  }

  CollectionReference<Map<String, dynamic>> _histRef(String uid) =>
      _fs.collection('users').doc(uid).collection('leaderboard_reward_history');

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid ?? _user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('獎勵統計'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _range,
              items: const [
                DropdownMenuItem(value: '7d', child: Text('近7天')),
                DropdownMenuItem(value: '30d', child: Text('近30天')),
                DropdownMenuItem(value: '90d', child: Text('近90天')),
              ],
              onChanged: (v) => setState(() => _range = v ?? '30d'),
            ),
          ),
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: uid == null ? _needLogin(context) : _body(uid),
    );
  }

  Widget _needLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能查看獎勵統計',
                    style: TextStyle(fontWeight: FontWeight.w900),
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
        ),
      ),
    );
  }

  Widget _body(String uid) {
    // ✅ 安全排序：docId（避免 createdAt 不存在）
    final stream = _histRef(
      uid,
    ).orderBy(FieldPath.documentId, descending: true).limit(600).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return _error('讀取失敗：${snap.error}');
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) return _empty('尚無獎勵資料');

        final start = _startTime();
        final records = docs.map(_RewardRec.fromDoc).toList();

        // client-side 篩選近 N 天（用 claimedAt / createdAt）
        final filtered = records.where((r) {
          final t = _useClaimedTime
              ? (r.claimedAt ?? r.createdAt)
              : (r.createdAt ?? r.claimedAt);
          if (t == null) return true; // 沒時間欄位：保留，避免整頁變空
          final floor = DateTime(start.year, start.month, start.day);
          return !t.isBefore(floor);
        }).toList();

        // KPI
        final total = filtered.length;
        final claimed = filtered.where((e) => e.claimed).length;
        final pending = total - claimed;

        final typeCount = <String, int>{};
        final seasonCount = <String, int>{};

        num sumPoints = 0;
        num sumCoupon = 0;

        for (final r in filtered) {
          final type = r.rewardType.trim().isEmpty
              ? 'unknown'
              : r.rewardType.trim();
          typeCount[type] = (typeCount[type] ?? 0) + 1;

          final seasonKey = r.seasonName.trim().isNotEmpty
              ? r.seasonName.trim()
              : (r.seasonId.trim().isNotEmpty ? r.seasonId.trim() : '未分類賽季');
          seasonCount[seasonKey] = (seasonCount[seasonKey] ?? 0) + 1;

          if (type == 'points') sumPoints += r.rewardValue;
          if (type == 'coupon') sumCoupon += r.rewardValue;
        }

        final trend = _buildTrend(filtered, start, useClaimed: _useClaimedTime);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('範圍設定'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _useClaimedTime
                            ? '趨勢依據：領取時間（claimedAt）'
                            : '趨勢依據：發放時間（createdAt）',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Switch(
                      value: _useClaimedTime,
                      onChanged: (v) => setState(() => _useClaimedTime = v),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            _sectionTitle('核心指標'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _kpiCard('總獎勵筆數', '$total', Icons.inventory_2_outlined),
                _kpiCard('已領取', '$claimed', Icons.check_circle_outline),
                _kpiCard('待領取', '$pending', Icons.hourglass_empty),
                _kpiCard('點數總額', '${sumPoints.toInt()}', Icons.stars_outlined),
                _kpiCard(
                  '券面總額',
                  '${sumCoupon.toInt()}',
                  Icons.card_giftcard_outlined,
                ),
              ],
            ),

            const SizedBox(height: 16),
            _sectionTitle('領取率'),
            const SizedBox(height: 8),
            _rateCard(claimed: claimed, total: max(1, total)),

            const SizedBox(height: 16),
            _sectionTitle('近${_days()}天趨勢（以列顯示）'),
            const SizedBox(height: 8),
            _trendList(trend),

            const SizedBox(height: 16),
            _sectionTitle('類型分佈'),
            const SizedBox(height: 8),
            _breakdownCard(typeCount, total),

            const SizedBox(height: 16),
            _sectionTitle('賽季分佈（Top 8）'),
            const SizedBox(height: 8),
            _breakdownCard(_topN(seasonCount, 8), total),

            const SizedBox(height: 16),
            _sectionTitle('最近紀錄（Top 20）'),
            const SizedBox(height: 8),
            ...filtered.take(20).map(_recTile),

            const SizedBox(height: 24),
            const Text(
              '註：此頁已移除 fl_chart，並移除未使用的 private helper（避免 unused_element），確保能編譯。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  Map<String, int> _buildTrend(
    List<_RewardRec> recs,
    DateTime start, {
    required bool useClaimed,
  }) {
    final map = <String, int>{};

    // 初始化近 N 天
    final floor = DateTime(start.year, start.month, start.day);
    for (int i = 0; i < _days(); i++) {
      final d = floor.add(Duration(days: i));
      map[_yyyymmdd(d)] = 0;
    }

    for (final r in recs) {
      final t = useClaimed
          ? (r.claimedAt ?? r.createdAt)
          : (r.createdAt ?? r.claimedAt);
      if (t == null) continue;
      final day = DateTime(t.year, t.month, t.day);
      if (day.isBefore(floor)) continue;
      final key = _yyyymmdd(day);
      if (!map.containsKey(key)) continue;
      map[key] = (map[key] ?? 0) + 1;
    }

    return map;
  }

  Map<String, int> _topN(Map<String, int> src, int n) {
    final entries = src.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final out = <String, int>{};
    for (final e in entries.take(n)) {
      out[e.key] = e.value;
    }
    return out;
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon) {
    return Container(
      width: 170,
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueGrey),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _rateCard({required int claimed, required int total}) {
    final rate = (claimed / total * 100);
    final v = (claimed / total).clamp(0.0, 1.0);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '領取率：${rate.toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: v),
            const SizedBox(height: 8),
            Text(
              '已領取 $claimed / 總計 $total',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendList(Map<String, int> trend) {
    final keys = trend.keys.toList()..sort(); // asc
    final values = keys.map((k) => trend[k] ?? 0).toList();
    final maxV = values.isEmpty ? 1 : max(1, values.reduce(max));

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (int i = 0; i < keys.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(_fmtDate(_parseYmd(keys[i]))),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (values[i] / maxV).clamp(0.0, 1.0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 28, child: Text(values[i].toString())),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownCard(Map<String, int> map, int total) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final safeTotal = max(1, total);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${(e.value / safeTotal * 100).toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 36,
                      child: Text(
                        e.value.toString(),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _recTile(_RewardRec r) {
    final status = r.claimed ? '已領取' : '待領取';
    final time = _useClaimedTime
        ? (r.claimedAt ?? r.createdAt)
        : (r.createdAt ?? r.claimedAt);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            r.claimed
                ? Icons.check_circle_outline
                : Icons.card_giftcard_outlined,
          ),
        ),
        title: Text(
          r.rewardTitle.isEmpty ? '獎勵' : r.rewardTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          [
            if (r.seasonName.isNotEmpty) '賽季：${r.seasonName}',
            if (r.rank > 0) '名次：第 ${r.rank} 名',
            if (r.rewardType.isNotEmpty) '類型：${r.rewardType}',
            if (r.rewardValue != 0) '數值：${r.rewardValue}',
            if (time != null) '時間：${_fmtDate(time)}',
            '狀態：$status',
          ].join('  •  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _empty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.query_stats_outlined,
                    size: 56,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _error(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(text, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardRec {
  final String id;

  final String seasonId;
  final String seasonName;
  final int rank;

  final String rewardTitle;
  final String rewardType;
  final num rewardValue;

  final bool claimed;
  final DateTime? createdAt;
  final DateTime? claimedAt;

  _RewardRec({
    required this.id,
    required this.seasonId,
    required this.seasonName,
    required this.rank,
    required this.rewardTitle,
    required this.rewardType,
    required this.rewardValue,
    required this.claimed,
    required this.createdAt,
    required this.claimedAt,
  });

  static _RewardRec fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();

    String s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

    num asNum(dynamic v, {num fallback = 0}) {
      if (v == null) return fallback;
      if (v is num) return v;
      if (v is String) return num.tryParse(v) ?? fallback;
      return fallback;
    }

    DateTime? asDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return _RewardRec(
      id: doc.id,
      seasonId: s(d['seasonId']).trim(),
      seasonName: s(d['seasonName']).trim(),
      rank: asNum(d['rank'], fallback: 0).toInt(),
      rewardTitle: s(d['rewardTitle']).trim(),
      rewardType: s(d['rewardType']).trim(),
      rewardValue: asNum(d['rewardValue'], fallback: 0),
      claimed: (d['claimed'] ?? false) == true,
      createdAt: asDate(d['createdAt']),
      claimedAt: asDate(d['claimedAt']),
    );
  }
}

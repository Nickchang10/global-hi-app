import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ LeaderboardRewardHistoryPage（排行榜獎勵領取紀錄｜完整版）
/// ------------------------------------------------------------
/// 修正重點：
/// - ✅ 移除 GoogleFonts.notoSansTc（避免 undefined_method）
/// - ✅ 不依賴任何 MockService
/// - ✅ 直接用 FirebaseAuth + Firestore 讀取紀錄
///
/// Firestore 建議結構（你可依現有欄位調整）
/// - users/{uid}/leaderboard_reward_history/{historyId}
///   - seasonId: String (optional)
///   - seasonName: String (optional)
///   - rank: num (optional)
///   - rewardTitle: String (optional)     // e.g. "100元折扣券"
///   - rewardValue: num (optional)        // e.g. 100
///   - rewardType: String (optional)      // e.g. "coupon" / "points"
///   - claimed: bool (optional)           // default false
///   - claimedAt: Timestamp (optional)
///   - createdAt: Timestamp (optional)
///   - note: String (optional)
///
/// ✅ 為了避免索引/欄位不存在 runtime error：
/// - 使用 orderBy(FieldPath.documentId) 作為安全排序 fallback
/// ------------------------------------------------------------
class LeaderboardRewardHistoryPage extends StatefulWidget {
  final String? uid;
  const LeaderboardRewardHistoryPage({super.key, this.uid});

  @override
  State<LeaderboardRewardHistoryPage> createState() =>
      _LeaderboardRewardHistoryPageState();
}

class _LeaderboardRewardHistoryPageState
    extends State<LeaderboardRewardHistoryPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _busy = false;
  String _filter = 'all'; // all / pending / claimed

  User? get _user => _auth.currentUser;

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  DateTime? _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  CollectionReference<Map<String, dynamic>> _histRef(String uid) =>
      _fs.collection('users').doc(uid).collection('leaderboard_reward_history');

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid ?? _user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('排行榜獎勵紀錄'),
        actions: [
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
                    '請先登入才能查看獎勵紀錄',
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
    // ✅ 安全排序：用 documentId（避免 createdAt 欄位不存在）
    final stream = _histRef(
      uid,
    ).orderBy(FieldPath.documentId, descending: true).limit(300).snapshots();

    return Column(
      children: [
        _filterBar(),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _error('讀取獎勵紀錄失敗：${snap.error}');
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;
              if (docs.isEmpty) return _empty('尚無獎勵紀錄');

              // client-side filter（避免索引問題）
              final filtered = docs.where((doc) {
                final d = doc.data();
                final claimed = (d['claimed'] ?? false) == true;
                if (_filter == 'claimed') return claimed;
                if (_filter == 'pending') return !claimed;
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return _empty(_filter == 'claimed' ? '沒有已領取獎勵' : '沒有待領取獎勵');
              }

              // client-side sort：若有 createdAt 就用 createdAt desc；否則維持 docId desc
              filtered.sort((a, b) {
                final ta = _asDate(a.data()['createdAt']);
                final tb = _asDate(b.data()['createdAt']);
                if (ta == null && tb == null) return 0;
                if (ta == null) return 1;
                if (tb == null) return -1;
                return tb.compareTo(ta);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (context, i) => _tile(uid, filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: _filter == 'all',
            onSelected: (_) => setState(() => _filter = 'all'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('待領取'),
            selected: _filter == 'pending',
            onSelected: (_) => setState(() => _filter = 'pending'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('已領取'),
            selected: _filter == 'claimed',
            onSelected: (_) => setState(() => _filter = 'claimed'),
          ),
        ],
      ),
    );
  }

  Widget _tile(String uid, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final claimed = (d['claimed'] ?? false) == true;

    final seasonName = _s(d['seasonName'], _s(d['seasonId'], '')).trim();
    final rank = _asNum(d['rank'], fallback: 0).toInt();

    final rewardTitle = _s(d['rewardTitle'], '獎勵').trim();
    final rewardType = _s(d['rewardType'], '').trim();
    final rewardValue = _asNum(d['rewardValue'], fallback: 0);

    final createdAt = _asDate(d['createdAt']);
    final claimedAt = _asDate(d['claimedAt']);

    final subtitleLines = <String>[
      if (seasonName.isNotEmpty) '賽季：$seasonName',
      if (rank > 0) '名次：第 $rank 名',
      if (rewardType.isNotEmpty) '類型：$rewardType',
      if (rewardValue != 0) '數值：$rewardValue',
      if (createdAt != null) '發放：${_fmtDateTime(createdAt)}',
      if (claimed && claimedAt != null) '領取：${_fmtDateTime(claimedAt)}',
      'ID：${doc.id}',
    ];

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            claimed ? Icons.check_circle_outline : Icons.card_giftcard_outlined,
          ),
        ),
        title: Text(
          rewardTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          subtitleLines.join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: claimed
            ? const Text(
                '已領取',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w900,
                ),
              )
            : FilledButton.tonal(
                onPressed: _busy ? null : () => _claim(uid, doc),
                child: const Text('標記領取'),
              ),
        onTap: () => _showDetail(uid, doc),
      ),
    );
  }

  Future<void> _showDetail(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final d = doc.data();
    final claimed = (d['claimed'] ?? false) == true;

    final seasonName = _s(d['seasonName'], _s(d['seasonId'], '')).trim();
    final rank = _asNum(d['rank'], fallback: 0).toInt();
    final rewardTitle = _s(d['rewardTitle'], '獎勵').trim();
    final rewardType = _s(d['rewardType'], '').trim();
    final rewardValue = _asNum(d['rewardValue'], fallback: 0);
    final note = _s(d['note'], '').trim();

    final createdAt = _asDate(d['createdAt']);
    final claimedAt = _asDate(d['claimedAt']);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(rewardTitle),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (seasonName.isNotEmpty) Text('賽季：$seasonName'),
              if (rank > 0) Text('名次：第 $rank 名'),
              if (rewardType.isNotEmpty) Text('類型：$rewardType'),
              if (rewardValue != 0) Text('數值：$rewardValue'),
              if (createdAt != null) Text('發放：${_fmtDateTime(createdAt)}'),
              Text('狀態：${claimed ? "已領取" : "待領取"}'),
              if (claimedAt != null) Text('領取：${_fmtDateTime(claimedAt)}'),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('備註：$note'),
              ],
              const SizedBox(height: 8),
              Text('ID：${doc.id}', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          if (!claimed)
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _claim(uid, doc);
                    },
              child: const Text('標記領取'),
            ),
        ],
      ),
    );
  }

  Future<void> _claim(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _histRef(uid).doc(doc.id).set({
        'claimed': true,
        'claimedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已標記為領取')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 更新失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                    Icons.history_outlined,
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ FriendLeaderboardPage（好友排行榜｜完整版｜移除 SocialService 型別依賴）
/// ------------------------------------------------------------
/// 修正重點：
/// - 完全不使用 SocialService（避免 non_type_as_type_argument）
/// - 改用 Firestore 直接讀取：
///   - users/{uid}
///     - points: num（可選，預設 0）
///     - displayName / name / email（可選）
///   - users/{uid}/friends/{friendUid}
///     - friendUid: String（可選，沒有就用 doc.id）
///     - status: accepted / pending（可選，沒有就視為 accepted）
///
/// ⚠️ 為了避免 whereIn 限制 / 索引問題：
/// - 這裡用「讀好友清單 → 逐筆讀 users doc」方式產生榜單（穩定可編譯）
/// ------------------------------------------------------------
class FriendLeaderboardPage extends StatefulWidget {
  final String? uid;

  const FriendLeaderboardPage({super.key, this.uid});

  @override
  State<FriendLeaderboardPage> createState() => _FriendLeaderboardPageState();
}

class _FriendLeaderboardPageState extends State<FriendLeaderboardPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _keyword = '';

  User? get _user => _auth.currentUser;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  CollectionReference<Map<String, dynamic>> _friendsRef(String uid) =>
      _fs.collection('users').doc(uid).collection('friends');

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _fs.collection('users').doc(uid);

  @override
  Widget build(BuildContext context) {
    final effectiveUid = widget.uid ?? _user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('好友排行榜'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: effectiveUid == null ? _needLogin(context) : _body(effectiveUid),
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
                    '請先登入才能查看好友排行榜',
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
    return Column(
      children: [
        _topBar(),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _friendsRef(uid).limit(500).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return _error('讀取好友清單失敗：${snap.error}');
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // 收集 accepted 好友 uid
              final friendSet = <String>{};
              for (final doc in snap.data!.docs) {
                final d = doc.data();
                final status = _s(d['status']).toLowerCase().trim();
                final accepted =
                    status.isEmpty ||
                    status == 'accepted' ||
                    status == 'friend';
                if (!accepted) continue;

                final friendUid = _s(d['friendUid'], doc.id).trim();
                if (friendUid.isNotEmpty) friendSet.add(friendUid);
              }

              // 也把自己加入榜單
              friendSet.add(uid);

              return FutureBuilder<List<_LeaderboardRow>>(
                future: _loadLeaderboard(friendSet),
                builder: (context, fb) {
                  if (fb.hasError) return _error('讀取排行榜失敗：${fb.error}');
                  if (!fb.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final rows = fb.data!;
                  if (rows.isEmpty) return _empty('目前沒有資料');

                  // 搜尋過濾
                  final key = _keyword.toLowerCase();
                  final filtered = key.isEmpty
                      ? rows
                      : rows.where((r) {
                          final name = r.displayName.toLowerCase();
                          final email = r.email.toLowerCase();
                          final id = r.uid.toLowerCase();
                          return name.contains(key) ||
                              email.contains(key) ||
                              id.contains(key);
                        }).toList();

                  if (filtered.isEmpty) return _empty('沒有符合搜尋條件的好友');

                  // 計算自己的名次（在未搜尋的全榜）
                  final myIndex = rows.indexWhere((r) => r.uid == uid);
                  final myRank = myIndex >= 0 ? (myIndex + 1) : null;

                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (myRank != null)
                        _myRankCard(rows[myIndex], myRank, rows.length),
                      const SizedBox(height: 10),
                      for (int i = 0; i < filtered.length; i++)
                        _rankTile(
                          row: filtered[i],
                          rank: _rankOf(rows, filtered[i].uid),
                          isMe: filtered[i].uid == uid,
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        '註：排行榜以 users/{uid}.points 排序（預設 0）。\n若好友很多，建議改用後端聚合或 Cloud Functions 產生 leaderboard。',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋好友（姓名/Email/UID）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _keyword = v.trim()),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: '清除搜尋',
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _keyword = '');
            },
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }

  Future<List<_LeaderboardRow>> _loadLeaderboard(Set<String> uids) async {
    // 避免同時過多請求，這裡簡單做分批
    final list = uids.toList();
    final results = <_LeaderboardRow>[];

    // 每批 25
    const batchSize = 25;
    for (int i = 0; i < list.length; i += batchSize) {
      final chunk = list.sublist(i, (i + batchSize).clamp(0, list.length));
      final snaps = await Future.wait(chunk.map((id) => _userRef(id).get()));
      for (final s in snaps) {
        final data = s.data() ?? const <String, dynamic>{};
        final uid = s.id;
        final points = _asNum(data['points'], fallback: 0);
        final displayName = _s(data['displayName'], _s(data['name'], '未命名'));
        final email = _s(data['email'], '');
        results.add(
          _LeaderboardRow(
            uid: uid,
            points: points,
            displayName: displayName.trim().isEmpty
                ? '未命名'
                : displayName.trim(),
            email: email.trim(),
          ),
        );
      }
    }

    // sort：points desc，tie → displayName asc
    results.sort((a, b) {
      final c = b.points.compareTo(a.points);
      if (c != 0) return c;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return results;
  }

  int _rankOf(List<_LeaderboardRow> all, String uid) {
    final i = all.indexWhere((r) => r.uid == uid);
    return i >= 0 ? (i + 1) : 0;
  }

  Widget _myRankCard(_LeaderboardRow me, int rank, int total) {
    return Card(
      elevation: 1,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.emoji_events_outlined)),
        title: const Text(
          '我的名次',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('第 $rank 名 / 共 $total 人'),
        trailing: Text(
          '${me.points}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
    );
  }

  Widget _rankTile({
    required _LeaderboardRow row,
    required int rank,
    required bool isMe,
  }) {
    final medal = rank == 1
        ? '🥇'
        : rank == 2
        ? '🥈'
        : rank == 3
        ? '🥉'
        : '';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(medal.isNotEmpty ? medal : rank.toString()),
        ),
        title: Text(
          row.displayName + (isMe ? '（我）' : ''),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: isMe ? Colors.blue : null,
          ),
        ),
        subtitle: Text(
          [if (row.email.isNotEmpty) row.email, 'UID：${row.uid}'].join('\n'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${row.points}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        onTap: () => _showUserDialog(row, rank),
      ),
    );
  }

  Future<void> _showUserDialog(_LeaderboardRow row, int rank) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('第 $rank 名：${row.displayName}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('UID：${row.uid}'),
              if (row.email.isNotEmpty) Text('Email：${row.email}'),
              const SizedBox(height: 8),
              Text(
                '積分：${row.points}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
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
                    Icons.leaderboard_outlined,
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

class _LeaderboardRow {
  final String uid;
  final num points;
  final String displayName;
  final String email;

  _LeaderboardRow({
    required this.uid,
    required this.points,
    required this.displayName,
    required this.email,
  });
}

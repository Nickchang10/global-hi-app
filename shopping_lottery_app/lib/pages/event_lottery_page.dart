import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ EventLotteryPage（活動抽獎頁｜完整版｜修正 curly_braces_in_flow_control_structures）
/// ------------------------------------------------------------
/// ✅ 所有 if 單行語句都改成 { ... } 區塊（避免 linter 警告）
/// ✅ 不使用任何 `target:` 命名參數（避免你的編譯錯誤）
/// ✅ 不依賴 FirestoreMockService
///
/// Firestore 建議結構（可依你現有欄位調整）
/// - lotteries/{lotteryId}
///   - title: String
///   - description: String
///   - isActive: bool
///   - startAt: Timestamp (optional)
///   - endAt: Timestamp (optional)
///   - maxEntriesPerUser: num (optional, default 1)
///   - prizes: List<Map> (optional)
///       e.g. [ { "name": "100元折扣券", "weight": 10 }, { "name": "銘謝惠顧", "weight": 90 } ]
///
/// - lotteries/{lotteryId}/entries/{entryId}
///   - uid: String
///   - orderId: String (optional)
///   - createdAt: Timestamp
///   - result: Map (optional)  { name: "...", win: true/false }
///
/// - users/{uid}
///   - points: num (optional)
/// ------------------------------------------------------------
class EventLotteryPage extends StatefulWidget {
  final String? orderId;
  final String? lotteryId;

  const EventLotteryPage({super.key, this.orderId, this.lotteryId});

  @override
  State<EventLotteryPage> createState() => _EventLotteryPageState();
}

class _EventLotteryPageState extends State<EventLotteryPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _busy = false;

  User? get _user => _auth.currentUser;

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) {
      return fallback;
    }
    if (v is num) {
      return v;
    }
    if (v is String) {
      return num.tryParse(v) ?? fallback;
    }
    return fallback;
  }

  DateTime? _asDate(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is Timestamp) {
      return v.toDate();
    }
    if (v is DateTime) {
      return v;
    }
    return null;
  }

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) {
      return '';
    }
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  CollectionReference<Map<String, dynamic>> get _lotteriesRef =>
      _fs.collection('lotteries');

  DocumentReference<Map<String, dynamic>> _lotteryRef(String id) =>
      _lotteriesRef.doc(id);

  CollectionReference<Map<String, dynamic>> _entriesRef(String lotteryId) =>
      _lotteryRef(lotteryId).collection('entries');

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('活動抽獎'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: user == null
          ? _needLogin()
          : (widget.lotteryId != null && widget.lotteryId!.trim().isNotEmpty)
          ? _lotteryDetail(lotteryId: widget.lotteryId!.trim(), uid: user.uid)
          : _lotteryList(uid: user.uid),
    );
  }

  Widget _needLogin() {
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
                    '請先登入才能參加抽獎',
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

  // ---------------------------
  // 抽獎列表（沒有指定 lotteryId 時）
  // ---------------------------
  Widget _lotteryList({required String uid}) {
    final q = _lotteriesRef
        .where('isActive', isEqualTo: true)
        .limit(100)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q,
      builder: (context, snap) {
        if (snap.hasError) {
          return _error('讀取抽獎活動失敗：${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _empty('目前沒有進行中的抽獎活動');
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (widget.orderId != null && widget.orderId!.trim().isNotEmpty)
              Card(
                elevation: 1,
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text(
                    '本次訂單抽獎',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text('orderId：${widget.orderId}'),
                ),
              ),
            const SizedBox(height: 10),
            for (final doc in docs) _lotteryTile(uid: uid, doc: doc),
          ],
        );
      },
    );
  }

  Widget _lotteryTile({
    required String uid,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final d = doc.data();
    final title = _s(d['title'], _s(d['name'], '抽獎活動'));
    final desc = _s(d['description'], _s(d['desc'], '')).trim();
    final startAt = _asDate(d['startAt']);
    final endAt = _asDate(d['endAt']);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.casino_outlined)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          [
            if (desc.isNotEmpty) desc,
            if (startAt != null || endAt != null)
              '期間：${_fmtDateTime(startAt)} ~ ${_fmtDateTime(endAt)}',
            'ID：${doc.id}',
          ].where((e) => e.trim().isNotEmpty).join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  EventLotteryPage(lotteryId: doc.id, orderId: widget.orderId),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------
  // 抽獎詳情 + 參加/抽獎
  // ---------------------------
  Widget _lotteryDetail({required String lotteryId, required String uid}) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _lotteryRef(lotteryId).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _error('讀取活動失敗：${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data!.data();
        if (data == null) {
          return _error('找不到活動：$lotteryId');
        }

        final title = _s(data['title'], _s(data['name'], '抽獎活動'));
        final desc = _s(data['description'], _s(data['desc'], '')).trim();

        final isActive = (data['isActive'] ?? false) == true;
        final startAt = _asDate(data['startAt']);
        final endAt = _asDate(data['endAt']);
        final maxEntries = _asNum(
          data['maxEntriesPerUser'],
          fallback: 1,
        ).toInt();

        final now = DateTime.now();
        final inTime =
            (startAt == null || !now.isBefore(startAt)) &&
            (endAt == null || !now.isAfter(endAt));

        final canJoin = isActive && inTime;

        final prizesRaw = (data['prizes'] is List)
            ? (data['prizes'] as List)
            : const [];
        final prizes = prizesRaw
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(desc.isEmpty ? '（無描述）' : desc),
                    const SizedBox(height: 12),
                    _infoRow(
                      '活動狀態',
                      canJoin ? '進行中' : '未開放/已結束',
                      valueColor: canJoin ? Colors.green : Colors.grey,
                    ),
                    _infoRow('活動ID', lotteryId),
                    if (startAt != null || endAt != null)
                      _infoRow(
                        '期間',
                        '${_fmtDateTime(startAt)} ~ ${_fmtDateTime(endAt)}',
                      ),
                    _infoRow('每人可參加次數', maxEntries.toString()),
                    if (widget.orderId != null &&
                        widget.orderId!.trim().isNotEmpty)
                      _infoRow('本次訂單', widget.orderId!.trim()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (prizes.isNotEmpty) ...[
              const Text('獎項列表', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                child: Column(
                  children: [
                    for (final p in prizes)
                      ListTile(
                        leading: const Icon(Icons.card_giftcard_outlined),
                        title: Text(_s(p['name'], '獎項')),
                        subtitle: Text(
                          '權重：${_asNum(p['weight'], fallback: 1)}',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _myEntries(uid: uid, lotteryId: lotteryId, maxEntries: maxEntries),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: (!canJoin || _busy)
                  ? null
                  : () => _joinAndDraw(
                      uid: uid,
                      lotteryId: lotteryId,
                      maxEntries: maxEntries,
                      prizes: prizes,
                    ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('參加抽獎'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
            const SizedBox(height: 8),
            const Text(
              '提醒：這裡的中獎結果為「示範版」用客戶端隨機抽取。\n若要正式抽獎，建議改用 Cloud Functions / 後端生成結果。',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w800, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // 我的參加紀錄（本活動）
  // ---------------------------
  Widget _myEntries({
    required String uid,
    required String lotteryId,
    required int maxEntries,
  }) {
    final q = _entriesRef(
      lotteryId,
    ).where('uid', isEqualTo: uid).limit(50).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q,
      builder: (context, snap) {
        if (snap.hasError) {
          return _error('讀取參加紀錄失敗：${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        final used = docs.length;

        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的參加紀錄（$used / $maxEntries）',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                if (docs.isEmpty)
                  const Text('尚未參加', style: TextStyle(color: Colors.grey))
                else
                  ...docs.map((e) {
                    final d = e.data();
                    final createdAt = _asDate(d['createdAt']);
                    final orderId = _s(d['orderId']).trim();
                    final result = (d['result'] is Map)
                        ? (d['result'] as Map)
                        : null;
                    final resultName = result == null
                        ? ''
                        : _s(result['name']).trim();
                    final win = result == null
                        ? false
                        : (result['win'] == true);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            win ? Icons.emoji_events_outlined : Icons.history,
                            size: 18,
                            color: win ? Colors.orange : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              [
                                '時間：${_fmtDateTime(createdAt)}',
                                if (orderId.isNotEmpty) '訂單：$orderId',
                                if (resultName.isNotEmpty)
                                  '結果：$resultName${win ? '（中獎）' : ''}',
                              ].join('  •  '),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------
  // 參加抽獎（寫 entry）+ 示範抽獎（寫 result）
  // ---------------------------
  Future<void> _joinAndDraw({
    required String uid,
    required String lotteryId,
    required int maxEntries,
    required List<Map<String, dynamic>> prizes,
  }) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);

    try {
      // 1) 先查目前參加次數
      final existing = await _entriesRef(
        lotteryId,
      ).where('uid', isEqualTo: uid).limit(200).get();

      if (existing.size >= maxEntries) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已達本活動可參加次數上限')));
        return;
      }

      // 2) 建 entryId（若有 orderId：用 uid_orderId 確保一筆）
      final orderId = (widget.orderId ?? '').trim();
      final entryId = orderId.isNotEmpty
          ? '${uid}_$orderId'
          : '${uid}_${DateTime.now().millisecondsSinceEpoch}';

      final entryRef = _entriesRef(lotteryId).doc(entryId);

      // 若已存在（同訂單重複點），直接顯示已有
      final existDoc = await entryRef.get();
      if (existDoc.exists) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('你已使用這筆訂單參加過了')));
        return;
      }

      // 3) 寫入 entry（先不寫 result）
      await entryRef.set({
        'uid': uid,
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4) 示範抽獎：客戶端隨機
      final result = _drawClientSide(prizes);

      await entryRef.set({'result': result}, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      await _showResultDialog(result);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('抽獎失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Map<String, dynamic> _drawClientSide(List<Map<String, dynamic>> prizes) {
    // 沒有 prizes 就一律銘謝惠顧（示範）
    if (prizes.isEmpty) {
      return {'name': '銘謝惠顧', 'win': false};
    }

    // 以 weight 做加權抽取
    final pool = <Map<String, dynamic>>[];
    for (final p in prizes) {
      final name = _s(p['name'], '獎項');
      final w = _asNum(p['weight'], fallback: 1).toInt().clamp(1, 100000);
      pool.add({'name': name, 'weight': w});
    }

    final total = pool.fold<int>(0, (s, e) => s + (e['weight'] as int));
    final r = Random().nextInt(max(total, 1));
    int acc = 0;
    for (final p in pool) {
      acc += (p['weight'] as int);
      if (r < acc) {
        final name = _s(p['name'], '獎項');
        final win = name != '銘謝惠顧';
        return {'name': name, 'win': win};
      }
    }
    return {'name': '銘謝惠顧', 'win': false};
  }

  Future<void> _showResultDialog(Map<String, dynamic> result) async {
    final name = _s(result['name'], '結果');
    final win = result['win'] == true;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(win ? '🎉 恭喜中獎！' : '結果'),
        content: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          if (win)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('太好了'),
            ),
        ],
      ),
    );
  }

  // ---------------------------
  // UI helper
  // ---------------------------
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
                    Icons.casino_outlined,
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

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ LotteryDebugPage（抽獎 Debug 工具頁｜完整版｜不使用 target:）
/// ------------------------------------------------------------
/// 目的：
/// - 讓你在 App 內快速建立 Demo 抽獎、加入票券、抽出得獎者、重置狀態
/// - 完全不依賴任何不存在的 named parameter（例如 target）
///
/// Firestore 結構（建議/可自動建立）：
/// - lotteries/{lotteryId}
///   - title: String
///   - isActive: bool
///   - createdAt: Timestamp
///   - drawn: bool
///   - winnerUid: String?
///   - winnerTickets: num?
///   - totalEntries: num
/// - lotteries/{lotteryId}/entries/{uid}
///   - uid: String
///   - tickets: num
///   - createdAt: Timestamp
/// ------------------------------------------------------------
class LotteryDebugPage extends StatefulWidget {
  const LotteryDebugPage({super.key});

  @override
  State<LotteryDebugPage> createState() => _LotteryDebugPageState();
}

class _LotteryDebugPageState extends State<LotteryDebugPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _busy = false;

  // 你可以改成你常用的測試抽獎 ID
  final TextEditingController _lotteryIdCtrl = TextEditingController(
    text: 'debug_lottery_001',
  );

  final TextEditingController _titleCtrl = TextEditingController(
    text: 'Debug 抽獎活動',
  );

  final TextEditingController _ticketsCtrl = TextEditingController(text: '1');

  User? get _user => _auth.currentUser;

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  DocumentReference<Map<String, dynamic>> _lotteryRef(String id) =>
      _fs.collection('lotteries').doc(id);

  CollectionReference<Map<String, dynamic>> _entriesRef(String id) =>
      _lotteryRef(id).collection('entries');

  @override
  void dispose() {
    _lotteryIdCtrl.dispose();
    _titleCtrl.dispose();
    _ticketsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lottery Debug'),
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
                    '請先登入才能使用抽獎 Debug',
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
    final lotteryId = _lotteryIdCtrl.text.trim().isEmpty
        ? 'debug_lottery_001'
        : _lotteryIdCtrl.text.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('目前登入'),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(
              _user?.displayName?.trim().isNotEmpty == true
                  ? _user!.displayName!.trim()
                  : (_user?.email ?? uid),
            ),
            subtitle: Text('UID：$uid'),
          ),
        ),

        const SizedBox(height: 16),
        _sectionTitle('抽獎設定'),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _lotteryIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'lotteryId（文件ID）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'title（活動名稱）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ticketsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '加入票數（tickets）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _createOrUpdateLottery(lotteryId),
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('建立/更新抽獎'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => _joinLottery(lotteryId, uid),
                      icon: const Icon(Icons.confirmation_num_outlined),
                      label: const Text('我加入抽獎'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _drawWinner(lotteryId),
                      icon: const Icon(Icons.casino_outlined),
                      label: const Text('抽出得獎者'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _resetLottery(lotteryId),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('重置抽獎'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        _sectionTitle('抽獎狀態'),
        const SizedBox(height: 8),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _lotteryRef(lotteryId).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return _error('讀取 lotteries/$lotteryId 失敗：${snap.error}');
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snap.data!.data();
            if (data == null) {
              return _empty('此 lotteryId 尚未建立：$lotteryId');
            }

            final title = _s(data['title'], '');
            final isActive = (data['isActive'] ?? false) == true;
            final drawn = (data['drawn'] ?? false) == true;
            final winnerUid = _s(data['winnerUid'], '');
            final winnerTickets = _asNum(
              data['winnerTickets'],
              fallback: 0,
            ).toInt();
            final totalEntries = _asNum(
              data['totalEntries'],
              fallback: 0,
            ).toInt();

            return Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? '（未命名抽獎）' : title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('isActive：$isActive'),
                    Text('drawn：$drawn'),
                    Text('totalEntries：$totalEntries'),
                    const SizedBox(height: 6),
                    Text(
                      winnerUid.isEmpty
                          ? 'winner：尚未抽出'
                          : 'winnerUid：$winnerUid（tickets=$winnerTickets）',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: winnerUid.isEmpty ? Colors.grey : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 16),
        _sectionTitle('參與名單（entries）'),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _entriesRef(lotteryId)
              .orderBy(FieldPath.documentId, descending: false)
              .limit(300)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return _error('讀取 entries 失敗：${snap.error}');
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return _empty('目前沒有參與者');
            }

            return Column(
              children: [
                for (final d in docs)
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text('UID：${d.id}'),
                      subtitle: Text(
                        'tickets：${_asNum(d.data()['tickets'], fallback: 0).toInt()}',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),
        const Text(
          '註：此頁面已移除任何 target: 參數使用，確保可編譯。你可用它驗證 lotteries/entries 寫入與抽獎邏輯。',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }

  Widget _empty(String text) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _error(String text) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Future<void> _createOrUpdateLottery(String lotteryId) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final title = _titleCtrl.text.trim().isEmpty
          ? 'Debug 抽獎活動'
          : _titleCtrl.text.trim();

      await _lotteryRef(lotteryId).set({
        'title': title,
        'isActive': true,
        'drawn': false,
        'winnerUid': FieldValue.delete(),
        'winnerTickets': FieldValue.delete(),
        'totalEntries': FieldValue.increment(0),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已建立/更新抽獎')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 建立/更新失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinLottery(String lotteryId, String uid) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final tickets = _asNum(
        _ticketsCtrl.text.trim(),
        fallback: 1,
      ).toInt().clamp(1, 999999);

      await _fs.runTransaction((tx) async {
        final lotRef = _lotteryRef(lotteryId);
        final entryRef = _entriesRef(lotteryId).doc(uid);

        final lotSnap = await tx.get(lotRef);
        if (!lotSnap.exists) {
          tx.set(lotRef, {
            'title': 'Debug 抽獎活動',
            'isActive': true,
            'drawn': false,
            'totalEntries': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        final entrySnap = await tx.get(entryRef);
        if (entrySnap.exists) {
          final cur = entrySnap.data()?['tickets'];
          final curNum = (cur is num) ? cur : 0;
          tx.set(entryRef, {
            'uid': uid,
            'tickets': curNum + tickets,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          tx.set(entryRef, {
            'uid': uid,
            'tickets': tickets,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          tx.set(lotRef, {
            'totalEntries': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已加入抽獎（票券已累加）')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 加入失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _drawWinner(String lotteryId) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final entriesSnap = await _entriesRef(lotteryId).limit(500).get();
      if (entriesSnap.docs.isEmpty) {
        throw '沒有參與者，無法抽獎';
      }

      final pool = <Map<String, dynamic>>[];
      for (final d in entriesSnap.docs) {
        final data = d.data();
        final uid = d.id;
        final tickets = _asNum(data['tickets'], fallback: 0).toInt();
        if (tickets <= 0) continue;
        pool.add({'uid': uid, 'tickets': tickets});
      }
      if (pool.isEmpty) {
        throw '所有參與者 tickets 皆為 0，無法抽獎';
      }

      final total = pool.fold<int>(0, (s, e) => s + (e['tickets'] as int));
      final r = Random().nextInt(total);

      int acc = 0;
      String winnerUid = pool.first['uid'] as String;
      int winnerTickets = pool.first['tickets'] as int;

      for (final e in pool) {
        acc += e['tickets'] as int;
        if (r < acc) {
          winnerUid = e['uid'] as String;
          winnerTickets = e['tickets'] as int;
          break;
        }
      }

      await _lotteryRef(lotteryId).set({
        'drawn': true,
        'winnerUid': winnerUid,
        'winnerTickets': winnerTickets,
        'drawnAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('🎉 抽獎完成！winnerUid=$winnerUid')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 抽獎失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetLottery(String lotteryId) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final entriesSnap = await _entriesRef(lotteryId).limit(500).get();
      final batch = _fs.batch();
      for (final d in entriesSnap.docs) {
        batch.delete(d.reference);
      }

      batch.set(_lotteryRef(lotteryId), {
        'drawn': false,
        'winnerUid': FieldValue.delete(),
        'winnerTickets': FieldValue.delete(),
        'totalEntries': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已重置抽獎/清空 entries')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 重置失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

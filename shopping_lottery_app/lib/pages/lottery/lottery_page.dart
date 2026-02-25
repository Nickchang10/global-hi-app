// lib/pages/lottery/lottery_page.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LotteryPage extends StatefulWidget {
  const LotteryPage({super.key});

  @override
  State<LotteryPage> createState() => _LotteryPageState();
}

class _LotteryPageState extends State<LotteryPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _drawing = false;

  String? get _uid => _auth.currentUser?.uid;

  Stream<DocumentSnapshot<Map<String, dynamic>>?> _activeEvent() {
    return _db
        .collection('lottery_events')
        .where('enabled', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((qs) => qs.docs.isEmpty ? null : qs.docs.first);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myEntries(
    String uid,
    String eventId,
  ) {
    // 若你 rules 不允許 orderBy，改成不 orderBy（但建議保留）
    return _db
        .collection('lottery_entries')
        .where('uid', isEqualTo: uid)
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  int _maxEntries(Map<String, dynamic> e) {
    final v = e['maxEntriesPerUser'];
    if (v is int && v > 0) return v;
    return 1;
  }

  Map<String, dynamic> _pickPrize(Map<String, dynamic> event) {
    final raw = event['prizes'];
    final prizes = (raw is List)
        ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];

    if (prizes.isEmpty) return {'title': '未中獎', 'win': false};

    int sum = 0;
    final weights = <int>[];

    for (final p in prizes) {
      final w = (p['weight'] is int)
          ? p['weight'] as int
          : int.tryParse('${p['weight']}') ?? 1;
      final ww = w <= 0 ? 1 : w;
      weights.add(ww);
      sum += ww;
    }

    final r = Random().nextInt(sum);
    int acc = 0;
    for (var i = 0; i < prizes.length; i++) {
      acc += weights[i];
      if (r < acc) {
        final title = (prizes[i]['title'] ?? prizes[i]['name'] ?? '獎項')
            .toString();
        final win = (prizes[i]['win'] is bool)
            ? prizes[i]['win'] as bool
            : (title != '未中獎' && title.toLowerCase() != 'none');
        return {'title': title, 'win': win};
      }
    }
    return {'title': '未中獎', 'win': false};
  }

  Future<void> _draw(
    DocumentSnapshot<Map<String, dynamic>> eventSnap,
    int usedCount,
  ) async {
    final uid = _uid;
    if (uid == null) {
      _toast('請先登入');
      return;
    }

    final event = eventSnap.data() ?? <String, dynamic>{};
    final max = _maxEntries(event);
    final remaining = max - usedCount;

    if (remaining <= 0) {
      _toast('抽獎次數已用完');
      return;
    }

    setState(() => _drawing = true);
    try {
      final picked = _pickPrize(event);
      final prizeTitle = (picked['title'] ?? '未中獎').toString();
      final win = (picked['win'] == true);

      await _db.collection('lottery_entries').doc().set({
        'uid': uid,
        'eventId': eventSnap.id,
        'eventTitle': (event['title'] ?? event['name'] ?? '抽獎活動').toString(),
        'prizeTitle': prizeTitle,
        'win': win,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(win ? '恭喜中獎！' : '再接再厲'),
          content: Text('你抽到：$prizeTitle'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('確定'),
            ),
          ],
        ),
      );
    } catch (e) {
      _toast('抽獎失敗：$e');
    } finally {
      if (mounted) setState(() => _drawing = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      appBar: AppBar(title: const Text('抽獎')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
        stream: _activeEvent(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取抽獎活動失敗：${snap.error}'));
          }

          final eventSnap = snap.data;
          if (eventSnap == null) {
            return const Center(child: Text('目前沒有啟用中的抽獎活動'));
          }

          final event = eventSnap.data() ?? <String, dynamic>{};
          final title = (event['title'] ?? event['name'] ?? '抽獎活動').toString();
          final max = _maxEntries(event);

          if (uid == null) {
            return const Center(child: Text('請先登入'));
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _myEntries(uid, eventSnap.id),
            builder: (context, entriesSnap) {
              if (entriesSnap.hasError) {
                return Center(child: Text('讀取抽獎紀錄失敗：${entriesSnap.error}'));
              }

              final used = entriesSnap.data?.size ?? 0;
              final remaining = max - used;
              final entries = entriesSnap.data?.docs ?? const [];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '剩餘抽獎次數：$remaining / $max',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: (_drawing || remaining <= 0)
                                  ? null
                                  : () => _draw(eventSnap, used),
                              icon: _drawing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.casino_outlined),
                              label: const Text('立即抽獎'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '我的抽獎紀錄',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  if (entries.isEmpty)
                    const Text('尚無紀錄')
                  else
                    ...entries.map((d) {
                      final m = d.data();
                      final prize = (m['prizeTitle'] ?? '').toString();
                      final win = m['win'] == true;
                      return Card(
                        child: ListTile(
                          title: Text(prize.isEmpty ? '（無獎項）' : prize),
                          trailing: Text(
                            win ? '中獎' : '未中',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: win ? Colors.green : Colors.grey,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

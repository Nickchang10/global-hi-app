// lib/pages/points_mission_page.dart
//
// ✅ PointsMissionPage（點數任務中心｜最終完整版｜已修正 lint）
// ------------------------------------------------------------
// ✅ 修正重點：
// - ✅ curly_braces_in_flow_control_structures：所有 if 單行語句一律加上 { }
// - ✅ 不依賴 FirestoreMockService
// - ✅ FirebaseAuth + Firestore：
//   - 任務：points_missions
//   - 使用者任務完成紀錄：users/{uid}/points_mission_logs/{missionId}
//   - 點數：users/{uid}.points
//
// 建議資料結構：
// points_missions/{mid}:
//   - title: String
//   - desc: String
//   - points: num
//   - isActive: bool
//   - sort: num
//   - cooldownHours: num (optional, default 24)  // 每幾小時可再做一次
//   - updatedAt, createdAt
//
// users/{uid}:
//   - points: num
//
// users/{uid}/points_mission_logs/{mid}:
//   - missionId: String
//   - title: String
//   - points: num
//   - status: "completed"
//   - completedAt: Timestamp
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PointsMissionPage extends StatefulWidget {
  const PointsMissionPage({super.key});

  static const routeName = '/points_missions';

  @override
  State<PointsMissionPage> createState() => _PointsMissionPageState();
}

class _PointsMissionPageState extends State<PointsMissionPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _busy = false;

  User? get _user => _auth.currentUser;

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _fs.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _missionsRef() =>
      _fs.collection('points_missions');

  DocumentReference<Map<String, dynamic>> _logRef(String uid, String mid) => _fs
      .collection('users')
      .doc(uid)
      .collection('points_mission_logs')
      .doc(mid);

  void _goLogin() {
    Navigator.of(context, rootNavigator: true).pushNamed('/login');
  }

  Future<void> _seedDemoMissions() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);

    try {
      final batch = _fs.batch();

      final demo = <Map<String, dynamic>>[
        {
          'id': 'm1',
          'title': '每日登入',
          'desc': '每天打開 App 一次即可獲得點數（示範）。',
          'points': 10,
          'isActive': true,
          'sort': 10,
          'cooldownHours': 24,
        },
        {
          'id': 'm2',
          'title': '完成一筆下單',
          'desc': '完成付款並建立訂單即可獲得點數（示範）。',
          'points': 50,
          'isActive': true,
          'sort': 20,
          'cooldownHours': 24,
        },
        {
          'id': 'm3',
          'title': '分享商品',
          'desc': '分享任一商品到社群即可獲得點數（示範）。',
          'points': 15,
          'isActive': true,
          'sort': 30,
          'cooldownHours': 6,
        },
        {
          'id': 'm4',
          'title': '填寫個人資料',
          'desc': '補齊姓名/電話等資料即可獲得點數（示範）。',
          'points': 30,
          'isActive': true,
          'sort': 40,
          'cooldownHours': 999999, // 幾乎只能做一次
        },
      ];

      for (final m in demo) {
        final id = _s(m['id']);
        batch.set(_missionsRef().doc(id), {
          ...m,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ 已建立示範任務：${demo.length} 筆')));
      setState(() {});
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 建立示範任務失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _completeMission({
    required String uid,
    required String mid,
    required Map<String, dynamic> mission,
  }) async {
    if (_busy) {
      return;
    }

    final title = _s(mission['title'], '任務');
    final points = _asNum(mission['points'], fallback: 0);
    final isActive = (mission['isActive'] ?? true) == true;
    final cooldownHours = _asNum(
      mission['cooldownHours'],
      fallback: 24,
    ).toInt();

    if (!isActive) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此任務目前未開放')));
      return;
    }
    if (points <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('任務點數設定不正確（points <= 0）')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('完成任務'),
        content: Text('是否完成「$title」並領取 $points 點？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('領取'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    setState(() => _busy = true);

    try {
      final userDoc = _userRef(uid);
      final logDoc = _logRef(uid, mid);

      await _fs.runTransaction((tx) async {
        final userSnap = await tx.get(userDoc);
        final logSnap = await tx.get(logDoc);

        // 冷卻判斷：已完成且未過 cooldownHours -> 不可再領
        final now = DateTime.now();

        if (logSnap.exists) {
          final data = logSnap.data() ?? <String, dynamic>{};
          final ts = data['completedAt'];
          DateTime? last;
          if (ts is Timestamp) {
            last = ts.toDate();
          }
          if (last != null && cooldownHours > 0 && cooldownHours < 999999) {
            final next = last.add(Duration(hours: cooldownHours));
            if (now.isBefore(next)) {
              throw Exception('冷卻中，下一次可領取：${next.toLocal()}');
            }
          }
          if (cooldownHours >= 999999 && last != null) {
            throw Exception('此任務只能完成一次');
          }
        }

        final currentPoints = _asNum(userSnap.data()?['points'], fallback: 0);

        tx.set(userDoc, {
          'points': currentPoints + points,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.set(logDoc, {
          'missionId': mid,
          'title': title,
          'points': points,
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ 已領取 $points 點：$title')));
      setState(() {});
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 領取失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('點數任務中心'),
        actions: [
          IconButton(
            tooltip: '建立示範任務',
            onPressed: _busy ? null : _seedDemoMissions,
            icon: const Icon(Icons.auto_awesome),
          ),
          IconButton(
            tooltip: '重新整理',
            onPressed: _busy ? null : () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: u == null ? _needLogin() : _content(u.uid),
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
                    '請先登入才能查看點數任務',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _goLogin, child: const Text('前往登入')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(String uid) {
    final userStream = _userRef(uid).snapshots();

    Query<Map<String, dynamic>> q = _missionsRef();
    q = q.where('isActive', isEqualTo: true).orderBy('sort');

    final missionsStream = q.snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, uSnap) {
        if (uSnap.hasError) {
          return _errorBox('讀取使用者點數失敗：${uSnap.error}');
        }
        if (!uSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = uSnap.data!.data() ?? <String, dynamic>{};
        final points = _asNum(userData['points'], fallback: 0);

        return Column(
          children: [
            _top(points: points),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: missionsStream,
                builder: (context, mSnap) {
                  if (mSnap.hasError) {
                    return _errorBox('讀取任務失敗：${mSnap.error}');
                  }
                  if (!mSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = mSnap.data!.docs;
                  if (docs.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [_empty('目前沒有任務（可按右上角建立示範任務）')],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final m = doc.data();
                      final mid = doc.id;

                      final title = _s(m['title'], '任務');
                      final desc = _s(m['desc'], '');
                      final p = _asNum(m['points'], fallback: 0).toInt();
                      final cooldown = _asNum(
                        m['cooldownHours'],
                        fallback: 24,
                      ).toInt();

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.task_alt),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
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
                                      desc.isEmpty ? '—' : desc,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _chip('獎勵', '$p 點'),
                                        _chip(
                                          '冷卻',
                                          cooldown >= 999999
                                              ? '一次性'
                                              : '${cooldown}h',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    StreamBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>
                                    >(
                                      stream: _logRef(uid, mid).snapshots(),
                                      builder: (context, lSnap) {
                                        final log = lSnap.data?.data();
                                        final status = _s(log?['status'], '');
                                        final completedAt = log?['completedAt'];

                                        DateTime? last;
                                        if (completedAt is Timestamp) {
                                          last = completedAt.toDate();
                                        }

                                        final now = DateTime.now();
                                        bool cooling = false;
                                        String? coolingText;

                                        if (last != null) {
                                          if (cooldown >= 999999) {
                                            cooling = true;
                                            coolingText = '已完成（一次性）';
                                          } else {
                                            final next = last.add(
                                              Duration(hours: cooldown),
                                            );
                                            if (now.isBefore(next)) {
                                              cooling = true;
                                              coolingText =
                                                  '冷卻中（下次：${next.toLocal()}）';
                                            }
                                          }
                                        }

                                        final canClaim = !_busy && !cooling;

                                        return Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                cooling
                                                    ? (coolingText ?? '冷卻中')
                                                    : (status == 'completed'
                                                          ? '可再次領取'
                                                          : '尚未完成'),
                                                style: TextStyle(
                                                  color: cooling
                                                      ? Colors.orange
                                                      : Colors.blueGrey,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            FilledButton(
                                              onPressed: canClaim
                                                  ? () => _completeMission(
                                                      uid: uid,
                                                      mid: mid,
                                                      mission: m,
                                                    )
                                                  : null,
                                              child: Text(
                                                cooling ? '冷卻中' : '領取',
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _top({required num points}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 0,
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.stars_outlined, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '目前點數：$points',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              if (_busy) ...[
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text('$k：$v', style: const TextStyle(fontSize: 12)),
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

  Widget _errorBox(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

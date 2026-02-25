import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _drawing = false;

  String? get _uid => _auth.currentUser?.uid;

  // =========================
  // Firestore paths
  // =========================
  DocumentReference<Map<String, dynamic>> _dailyRef(String uid) =>
      _db.collection('users').doc(uid).collection('meta').doc('tasks_daily');

  DocumentReference<Map<String, dynamic>> _pointsRef(String uid) =>
      _db.collection('users').doc(uid).collection('meta').doc('points');

  // =========================
  // 今日 key（yyyyMMdd）
  // =========================
  String _todayKey() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}';
  }

  // =========================
  // 任務定義（正式版：狀態寫入 Firestore）
  // =========================
  final _tasks = const <_TaskDef>[
    _TaskDef(
      id: 'checkin_daily',
      title: '每日簽到',
      subtitle: '完成可獲得 +50 積分',
      rewardPoints: 50,
      rewardLabel: '+50',
      type: _TaskType.checkin,
    ),
    _TaskDef(
      id: 'lottery_draw',
      title: '完成一次抽獎',
      subtitle: '獲得一次抽獎機會',
      rewardPoints: 0,
      rewardLabel: '+1 抽獎',
      type: _TaskType.lottery,
    ),
    _TaskDef(
      id: 'share_product',
      title: '分享商品給朋友',
      subtitle: '分享成功 +20 積分',
      rewardPoints: 20,
      rewardLabel: '+20',
      type: _TaskType.share,
    ),
  ];

  // =========================
  // Streams
  // =========================
  Stream<DocumentSnapshot<Map<String, dynamic>>> _dailyStream(String uid) {
    return _dailyRef(uid).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>?> _activeLotteryEventStream() {
    return _db
        .collection('lottery_events')
        .where('enabled', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((qs) => qs.docs.isEmpty ? null : qs.docs.first);
  }

  Stream<int> _usedEntriesCountStream(String uid, String eventId) {
    return _db
        .collection('lottery_entries')
        .where('uid', isEqualTo: uid)
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((qs) => qs.size);
  }

  // =========================
  // Daily done map（自動每日重置）
  // =========================
  Map<String, bool> _doneMap(DocumentSnapshot<Map<String, dynamic>> dailySnap) {
    final data = dailySnap.data() ?? <String, dynamic>{};
    final today = _todayKey();

    if ((data['date'] ?? '') != today) {
      // 日期不一致視為新的一天（UI 當成全未完成）
      return {};
    }

    final m = data['done'];
    if (m is Map) {
      return m.map((k, v) => MapEntry(k.toString(), v == true));
    }
    return {};
  }

  // =========================
  // 設定任務完成 + 加點數（Transaction）
  // =========================
  Future<void> _completeTask(_TaskDef t) async {
    final uid = _uid;
    if (uid == null) {
      _toast('請先登入');
      return;
    }

    final today = _todayKey();
    final dailyRef = _dailyRef(uid);
    final pointsRef = _pointsRef(uid);

    await _db.runTransaction((tx) async {
      final dailySnap = await tx.get(dailyRef);
      final data = dailySnap.data() ?? <String, dynamic>{};

      Map<String, dynamic> doneMap;
      if ((data['date'] ?? '') != today) {
        doneMap = <String, dynamic>{};
      } else {
        doneMap = Map<String, dynamic>.from(data['done'] as Map? ?? {});
      }

      // 已完成就不重複加點
      if (doneMap[t.id] == true) return;

      doneMap[t.id] = true;

      tx.set(dailyRef, {
        'date': today,
        'done': doneMap,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (t.rewardPoints > 0) {
        final ptsSnap = await tx.get(pointsRef);
        final current = (ptsSnap.data()?['points'] is int)
            ? (ptsSnap.data()?['points'] as int)
            : 0;

        tx.set(pointsRef, {
          'points': current + t.rewardPoints,
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    });

    _toast('任務完成 ✅ ${t.title}');
  }

  // =========================
  // Lottery helpers
  // =========================
  int _maxEntriesPerUser(Map<String, dynamic> e) {
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

  Future<void> _drawLottery({
    required DocumentSnapshot<Map<String, dynamic>> eventSnap,
    required int usedCount,
  }) async {
    final uid = _uid;
    if (uid == null) {
      _toast('請先登入');
      return;
    }

    final event = eventSnap.data() ?? <String, dynamic>{};
    final max = _maxEntriesPerUser(event);
    final remaining = max - usedCount;

    if (remaining <= 0) {
      _toast('你的抽獎次數已用完');
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

      // ✅ 抽獎成功後：自動完成「完成一次抽獎」任務（不加點數）
      final lotteryTask = _tasks.firstWhere((t) => t.id == 'lottery_draw');
      await _completeTask(lotteryTask);

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
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                try {
                  Navigator.of(context).pushNamed('/lotterys');
                } catch (_) {
                  _toast('尚未設定 /lotterys 路由');
                }
              },
              child: const Text('查看抽獎'),
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

  // =========================
  // Share（正式流程：確認完成才給獎）
  // =========================
  Future<void> _shareAndComplete(_TaskDef t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('分享商品'),
        content: const Text('請完成分享後按「我已分享」領取獎勵。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('我已分享'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _completeTask(t);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('請先登入後使用任務功能')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _dailyStream(uid),
      builder: (context, dailySnap) {
        final done = dailySnap.hasData
            ? _doneMap(dailySnap.data!)
            : <String, bool>{};

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
          stream: _activeLotteryEventStream(),
          builder: (context, eventSnap) {
            final activeEvent = eventSnap.data;

            final usedCountStream = (activeEvent == null)
                ? Stream<int>.value(0)
                : _usedEntriesCountStream(uid, activeEvent.id);

            return StreamBuilder<int>(
              stream: usedCountStream,
              builder: (context, usedSnap) {
                final usedEntries = usedSnap.data ?? 0;

                final total = _tasks.length;
                final doneCount = _tasks
                    .where((t) => done[t.id] == true)
                    .length;
                final progress = total == 0 ? 0.0 : doneCount / total;

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('任務'),
                    actions: [
                      IconButton(
                        tooltip: '重新整理',
                        onPressed: () => _toast('已同步'),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SummaryCard(
                        progress: progress,
                        doneCount: doneCount,
                        totalCount: total,
                      ),
                      const SizedBox(height: 12),

                      _LotteryCard(
                        eventSnap: activeEvent,
                        usedEntries: usedEntries,
                        drawing: _drawing,
                        onDraw: (activeEvent == null)
                            ? null
                            : () => _drawLottery(
                                eventSnap: activeEvent,
                                usedCount: usedEntries,
                              ),
                        onOpen: () {
                          try {
                            Navigator.of(context).pushNamed('/lotterys');
                          } catch (_) {
                            _toast('尚未設定 /lotterys 路由');
                          }
                        },
                      ),

                      const SizedBox(height: 12),
                      const Text(
                        '今日任務',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),

                      ..._tasks.map((t) {
                        final isDone = done[t.id] == true;

                        final noEventDisable =
                            (t.type == _TaskType.lottery &&
                            activeEvent == null);

                        final actionText = isDone
                            ? '已完成'
                            : noEventDisable
                            ? '無活動'
                            : '去完成';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TaskCard(
                            title: t.title,
                            subtitle: t.subtitle,
                            rewardLabel: t.rewardLabel,
                            done: isDone,
                            actionText: actionText,
                            enabled: !isDone && !noEventDisable,
                            onAction: () async {
                              if (isDone) return;

                              if (t.type == _TaskType.checkin) {
                                await _completeTask(t);
                              } else if (t.type == _TaskType.share) {
                                await _shareAndComplete(t);
                              } else if (t.type == _TaskType.lottery) {
                                if (activeEvent == null) {
                                  _toast('目前沒有啟用中的抽獎活動');
                                  return;
                                }
                                await _drawLottery(
                                  eventSnap: activeEvent,
                                  usedCount: usedEntries,
                                );
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// =========================
// Models + Widgets
// =========================

enum _TaskType { checkin, lottery, share }

class _TaskDef {
  final String id;
  final String title;
  final String subtitle;
  final int rewardPoints;
  final String rewardLabel;
  final _TaskType type;

  const _TaskDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.rewardPoints,
    required this.rewardLabel,
    required this.type,
  });
}

class _SummaryCard extends StatelessWidget {
  final double progress;
  final int doneCount;
  final int totalCount;

  const _SummaryCard({
    required this.progress,
    required this.doneCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress.clamp(0, 1) * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0, 1),
                      strokeWidth: 6,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '$pct%',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日進度',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '已完成 $doneCount / $totalCount 項',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LotteryCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>>? eventSnap;
  final int usedEntries;
  final bool drawing;
  final VoidCallback? onDraw;
  final VoidCallback onOpen;

  const _LotteryCard({
    required this.eventSnap,
    required this.usedEntries,
    required this.drawing,
    required this.onDraw,
    required this.onOpen,
  });

  int _maxEntries(Map<String, dynamic> e) {
    final v = e['maxEntriesPerUser'];
    if (v is int && v > 0) return v;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    if (eventSnap == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.card_giftcard_outlined),
          title: const Text(
            '目前沒有啟用中的抽獎活動',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          trailing: TextButton(onPressed: () {}, child: const Text('')),
        ),
      );
    }

    final e = eventSnap!.data() ?? <String, dynamic>{};
    final title = (e['title'] ?? e['name'] ?? '抽獎活動').toString();
    final max = _maxEntries(e);
    final remaining = max - usedEntries;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(onPressed: onOpen, child: const Text('查看')),
              ],
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
                onPressed: (drawing || remaining <= 0) ? null : onDraw,
                icon: drawing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.casino_outlined),
                label: const Text('立即抽獎'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String rewardLabel;
  final bool done;
  final String actionText;
  final bool enabled;
  final VoidCallback onAction;

  const _TaskCard({
    required this.title,
    required this.subtitle,
    required this.rewardLabel,
    required this.done,
    required this.actionText,
    required this.enabled,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: done
            ? const Text('已完成', style: TextStyle(fontWeight: FontWeight.w800))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rewardLabel.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        rewardLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: enabled ? onAction : null,
                    child: Text(actionText),
                  ),
                ],
              ),
      ),
    );
  }
}

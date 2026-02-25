// lib/pages/daily_mission_page.dart
//
// ✅ DailyMissionPage（最終完整版｜可直接使用｜已修正 deprecated withOpacity）
// - 修正：withOpacity deprecated → 改用 withValues(alpha: ...)
// - 功能：每日任務清單、完成任務、累積今日點數、寫入 Firestore、推送通知到 NotificationService（若有）
//
// Firestore 建議資料：
// users/{uid}/daily_missions/{yyyyMMdd}
//   - completedIds: [String]
//   - claimedPoints: int
//   - updatedAt: serverTimestamp
// users/{uid}
//   - points_total: int (可選)
//
// 依賴：firebase_auth / cloud_firestore / provider / notification_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';

class DailyMissionPage extends StatefulWidget {
  const DailyMissionPage({super.key});

  @override
  State<DailyMissionPage> createState() => _DailyMissionPageState();
}

class _DailyMissionPageState extends State<DailyMissionPage> {
  final List<_Mission> _missions = const [
    _Mission(
      id: 'login',
      title: '每日登入',
      desc: '每天開啟 App 並登入一次即可完成',
      points: 10,
      icon: Icons.login,
    ),
    _Mission(
      id: 'watch_live',
      title: '觀看直播 3 分鐘',
      desc: '進入任一直播間停留滿 3 分鐘（示範）',
      points: 15,
      icon: Icons.live_tv,
    ),
    _Mission(
      id: 'post',
      title: '發佈一則貼文',
      desc: '到互動中心社群發佈貼文（示範）',
      points: 20,
      icon: Icons.edit_note,
    ),
    _Mission(
      id: 'share',
      title: '分享商品/貼文',
      desc: '分享任一商品或貼文連結（示範）',
      points: 10,
      icon: Icons.share,
    ),
    _Mission(
      id: 'purchase',
      title: '完成一筆訂單',
      desc: '完成結帳付款（示範）',
      points: 30,
      icon: Icons.shopping_bag,
    ),
  ];

  bool _loading = true;
  bool _saving = false;

  Set<String> _completed = <String>{};
  int _claimedPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  DocumentReference<Map<String, dynamic>> _todayRef(String uid) {
    final key = _dateKey(DateTime.now());
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_missions')
        .doc(key);
  }

  Future<void> _loadToday() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _completed = <String>{};
        _claimedPoints = 0;
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final doc = await _todayRef(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      final completedIds = (data['completedIds'] is List)
          ? (data['completedIds'] as List).map((e) => e.toString()).toSet()
          : <String>{};

      final claimed = _asInt(data['claimedPoints'], fallback: 0);

      if (!mounted) return;
      setState(() {
        _completed = completedIds;
        _claimedPoints = claimed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('讀取失敗：$e');
    }
  }

  Future<void> _completeMission(_Mission m) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('請先登入');
      Navigator.of(context, rootNavigator: true).pushNamed('/login');
      return;
    }
    if (_completed.contains(m.id)) return;

    setState(() => _saving = true);

    try {
      final uid = user.uid;
      final todayDoc = _todayRef(uid);

      final batch = FirebaseFirestore.instance.batch();

      batch.set(todayDoc, {
        'completedIds': FieldValue.arrayUnion([m.id]),
        'claimedPoints': FieldValue.increment(m.points),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'points_total': FieldValue.increment(m.points),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _completed.add(m.id);
        _claimedPoints += m.points;
        _saving = false;
      });

      try {
        context.read<NotificationService>().addNotification(
          type: '任務',
          title: '任務完成',
          message: '已完成「${m.title}」＋${m.points} 點',
        );
      } catch (_) {}

      _toast('完成「${m.title}」＋${m.points} 點');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('寫入失敗：$e');
    }
  }

  Future<void> _resetTodayForDemo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重置今日任務'),
        content: const Text('此操作僅供示範，會清空今日完成狀態。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重置'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _todayRef(user.uid).set({
        'completedIds': <String>[],
        'claimedPoints': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _completed = <String>{};
        _claimedPoints = 0;
      });
      _toast('已重置（示範）');
    } catch (e) {
      _toast('重置失敗：$e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('每日任務'),
        actions: [
          IconButton(
            tooltip: '重置（示範）',
            onPressed: user == null ? null : _resetTodayForDemo,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: user == null
          ? _needLogin()
          : RefreshIndicator(
              onRefresh: _loadToday,
              child: _loading ? _loadingView() : _content(),
            ),
    );
  }

  Widget _needLogin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('請先登入才能查看每日任務', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/login'),
              child: const Text('前往登入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingView() {
    return const Center(child: CircularProgressIndicator.adaptive());
  }

  Widget _content() {
    final total = _missions.length;
    final done = _completed.length.clamp(0, total);
    final progress = total == 0 ? 0.0 : (done / total);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _summaryCard(
          done: done,
          total: total,
          progress: progress,
          points: _claimedPoints,
        ),
        const SizedBox(height: 12),
        ..._missions.map(_missionCard).toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _summaryCard({
    required int done,
    required int total,
    required double progress,
    required int points,
  }) {
    final key = _dateKey(DateTime.now());

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.black12,
                  ),
                  Center(
                    child: Text(
                      '$done/$total',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '日期：$key',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '今日已獲得：$points 點',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            if (_saving) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _missionCard(_Mission m) {
    final completed = _completed.contains(m.id);

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: completed
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.blue.withValues(alpha: 0.12),
              child: Icon(
                m.icon,
                color: completed ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '+${m.points} 點',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(m.desc, style: const TextStyle(color: Colors.black87)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: completed
                              ? Colors.grey
                              : Colors.blue,
                        ),
                        onPressed: completed || _saving
                            ? null
                            : () => _completeMission(m),
                        icon: Icon(completed ? Icons.check : Icons.flag),
                        label: Text(completed ? '已完成' : '完成任務'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () {
                          _toast('導覽到任務入口（示範）');
                        },
                        child: const Text('前往'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mission {
  final String id;
  final String title;
  final String desc;
  final int points;
  final IconData icon;

  const _Mission({
    required this.id,
    required this.title,
    required this.desc,
    required this.points,
    required this.icon,
  });
}

// lib/pages/mission_dashboard_page.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ MissionDashboardPage（任務中心｜可編譯完整版）
/// ------------------------------------------------------------
/// 修正重點：
/// - ✅ _parseYmd 有被歷史列表使用（避免 unused_element）
/// - ✅ _asDate 有被使用（顯示 updatedAt / createdAt，避免 unused_element）
/// - ✅ Firestore 欄位一律 _s / _asNum / _asBool / _asDate 保底轉型
/// - ✅ 查詢盡量避免索引：
///    - 任務清單：missions where(isActive==true)
///    - 任務歷史：users/{uid}/mission_logs orderBy(docId)
/// ------------------------------------------------------------
class MissionDashboardPage extends StatefulWidget {
  const MissionDashboardPage({super.key});

  @override
  State<MissionDashboardPage> createState() => _MissionDashboardPageState();
}

class _MissionDashboardPageState extends State<MissionDashboardPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  late final TabController _tab;

  bool _busy = false;

  User? get _user => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ----------------- safe parsers -----------------
  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  bool _asBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.trim().toLowerCase();
      if (t == 'true' || t == '1' || t == 'yes') return true;
      if (t == 'false' || t == '0' || t == 'no') return false;
    }
    return fallback;
  }

  /// ✅ 這次會被使用（progress.updatedAt / log.createdAt）
  DateTime? _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  // ----------------- date helpers -----------------
  String _todayKey() {
    final now = DateTime.now();
    return _yyyymmdd(now);
  }

  String _yyyymmdd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y$m$dd';
  }

  /// ✅ 會被歷史列表使用（避免 unused_element）
  DateTime _parseYmd(String yyyymmdd) {
    if (yyyymmdd.length != 8) return DateTime.now();
    final y = int.tryParse(yyyymmdd.substring(0, 4)) ?? DateTime.now().year;
    final m = int.tryParse(yyyymmdd.substring(4, 6)) ?? DateTime.now().month;
    final d = int.tryParse(yyyymmdd.substring(6, 8)) ?? DateTime.now().day;
    return DateTime(y, m, d);
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y/$m/$dd';
  }

  String _fmtTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // ----------------- refs -----------------
  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _fs.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _missionsRef() =>
      _fs.collection('missions');

  DocumentReference<Map<String, dynamic>> _progressRef(
    String uid,
    String progressId,
  ) => _fs
      .collection('users')
      .doc(uid)
      .collection('mission_progress')
      .doc(progressId);

  CollectionReference<Map<String, dynamic>> _logsRef(String uid) =>
      _fs.collection('users').doc(uid).collection('mission_logs');

  // ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    final uid = _user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '任務中心',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '今日任務'),
            Tab(text: '歷史紀錄'),
          ],
        ),
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
                    '請先登入才能查看任務中心',
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
    return TabBarView(
      controller: _tab,
      children: [_todayTab(uid), _historyTab(uid)],
    );
  }

  // ----------------- Today tab -----------------
  Widget _todayTab(String uid) {
    final todayKey = _todayKey();

    final missionsStream = _missionsRef()
        .where('isActive', isEqualTo: true)
        .limit(200)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _userSummary(uid),
        const SizedBox(height: 12),
        _sectionTitle('今日任務（$todayKey）'),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: missionsStream,
          builder: (context, snap) {
            if (snap.hasError) return _error('讀取任務失敗：${snap.error}');
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = [...snap.data!.docs];
            if (docs.isEmpty) {
              final demo = _demoMissions();
              return Column(
                children: demo
                    .map((m) => _missionCard(uid, todayKey, m))
                    .toList(),
              );
            }

            final list = docs
                .map((d) => _MissionTemplate.fromDoc(d))
                .where((m) => (m.type.isEmpty ? 'daily' : m.type) == 'daily')
                .toList();

            if (list.isEmpty) {
              final demo = _demoMissions();
              return Column(
                children: demo
                    .map((m) => _missionCard(uid, todayKey, m))
                    .toList(),
              );
            }

            list.sort((a, b) => b.points.compareTo(a.points));

            return Column(
              children: list
                  .map((m) => _missionCard(uid, todayKey, m))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          '註：若 missions collection 沒有資料，會顯示示範任務；加入資料後會自動顯示真實任務。',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _userSummary(String uid) {
    final stream = _userRef(uid).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final points = snap.hasData
            ? _asNum(snap.data!.data()?['points'], fallback: 0).toInt()
            : 0;

        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.emoji_events_outlined)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('我的積分', style: TextStyle(color: Colors.grey)),
                      Text(
                        '$points',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('更新'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _missionCard(String uid, String dateKey, _MissionTemplate m) {
    final progressId = '${dateKey}_${m.id}';
    final progressStream = _progressRef(uid, progressId).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: progressStream,
      builder: (context, snap) {
        final data = snap.data?.data();

        final current = _asNum(data?['current'], fallback: 0).toInt();
        final target = max(
          1,
          _asNum(data?['target'], fallback: m.target).toInt(),
        );
        final completed = _asBool(
          data?['completed'],
          fallback: current >= target,
        );
        final claimed = _asBool(data?['claimed'], fallback: false);

        // ✅ 使用 _asDate：顯示 updatedAt
        final updatedAt = _asDate(data?['updatedAt']);
        final updatedLabel = updatedAt == null
            ? ''
            : '${_fmtDate(updatedAt)} ${_fmtTime(updatedAt)}';

        final ratio = (current / target).clamp(0.0, 1.0);

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(m.icon, color: Colors.blueGrey),
                ),
                const SizedBox(width: 10),
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
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (updatedLabel.isNotEmpty)
                            Text(
                              updatedLabel,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (m.description.isNotEmpty)
                        Text(
                          m.description,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(value: ratio),
                          ),
                          const SizedBox(width: 10),
                          Text('$current/$target'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '+${m.points} pts',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!completed)
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _mockAddProgress(uid, dateKey, m),
                              icon: const Icon(Icons.add),
                              label: const Text('進度+1'),
                            )
                          else if (claimed)
                            const Text(
                              '已領取',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          else
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _claim(
                                      uid: uid,
                                      dateKey: dateKey,
                                      m: m,
                                    ),
                              child: const Text('領取'),
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
      },
    );
  }

  Future<void> _mockAddProgress(
    String uid,
    String dateKey,
    _MissionTemplate m,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);

    final progressId = '${dateKey}_${m.id}';
    final ref = _progressRef(uid, progressId);

    try {
      await _fs.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          tx.set(ref, {
            'missionId': m.id,
            'dateKey': dateKey,
            'current': 1,
            'target': m.target,
            'completed': m.target <= 1,
            'claimed': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }

        final d = snap.data() ?? <String, dynamic>{};
        final cur = _asNum(d['current'], fallback: 0).toInt();
        final target = max(1, _asNum(d['target'], fallback: m.target).toInt());
        final next = min(target, cur + 1);

        tx.set(ref, {
          'current': next,
          'target': target,
          'completed': next >= target,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ ${m.title} 進度 +1（示範）')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 更新進度失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim({
    required String uid,
    required String dateKey,
    required _MissionTemplate m,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);

    final progressId = '${dateKey}_${m.id}';
    final pRef = _progressRef(uid, progressId);
    final uRef = _userRef(uid);

    try {
      await _fs.runTransaction((tx) async {
        final pSnap = await tx.get(pRef);
        final p = pSnap.data() ?? <String, dynamic>{};

        final current = _asNum(p['current'], fallback: 0).toInt();
        final target = max(1, _asNum(p['target'], fallback: m.target).toInt());
        final completed = _asBool(p['completed'], fallback: current >= target);
        final claimed = _asBool(p['claimed'], fallback: false);

        if (!completed) throw '任務尚未完成';
        if (claimed) throw '已領取過';

        tx.set(pRef, {
          'claimed': true,
          'claimedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final uSnap = await tx.get(uRef);
        final u = uSnap.data() ?? <String, dynamic>{};
        final points = _asNum(u['points'], fallback: 0).toInt();

        tx.set(uRef, {
          'points': points + m.points,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final logId =
            '${dateKey}_${DateTime.now().millisecondsSinceEpoch}_${m.id}';
        tx.set(_logsRef(uid).doc(logId), {
          'dateKey': dateKey,
          'missionId': m.id,
          'title': m.title,
          'points': m.points,
          'claimed': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('🎉 已領取：${m.title} +${m.points}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 領取失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<_MissionTemplate> _demoMissions() {
    return [
      _MissionTemplate(
        id: 'demo_checkin',
        title: '每日簽到',
        description: '每天來任務中心打卡一次',
        type: 'daily',
        points: 5,
        target: 1,
        icon: Icons.check_circle_outline,
        isActive: true,
      ),
      _MissionTemplate(
        id: 'demo_view_product',
        title: '瀏覽商品 3 次',
        description: '逛逛商城，完成 3 次瀏覽',
        type: 'daily',
        points: 8,
        target: 3,
        icon: Icons.shopping_bag_outlined,
        isActive: true,
      ),
      _MissionTemplate(
        id: 'demo_share',
        title: '分享一次活動',
        description: '把活動分享給朋友（示範）',
        type: 'daily',
        points: 10,
        target: 1,
        icon: Icons.share_outlined,
        isActive: true,
      ),
    ];
  }

  // ----------------- History tab -----------------
  Widget _historyTab(String uid) {
    final stream = _logsRef(
      uid,
    ).orderBy(FieldPath.documentId, descending: true).limit(120).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return _centerText('讀取失敗：${snap.error}');
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) return _centerText('尚無任務領取紀錄');

        final groups =
            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final d in docs) {
          final data = d.data();
          final dateKey = _s(data['dateKey'], 'unknown');
          groups.putIfAbsent(dateKey, () => []).add(d);
        }

        final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('歷史紀錄'),
            const SizedBox(height: 8),
            for (final k in keys) ...[
              // ✅ 使用 _parseYmd
              _dateHeader(_fmtDate(_parseYmd(k)), k),
              const SizedBox(height: 8),
              ...groups[k]!.map(_logTile),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _dateHeader(String display, String rawKey) {
    return Row(
      children: [
        Expanded(
          child: Text(
            display,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
        Text(rawKey, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _logTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final title = _s(d['title'], '任務');
    final points = _asNum(d['points'], fallback: 0).toInt();
    final claimed = _asBool(d['claimed'], fallback: true);

    // ✅ 使用 _asDate：顯示 createdAt（若有）
    final createdAt = _asDate(d['createdAt']);
    final timeText = createdAt == null
        ? ''
        : '${_fmtDate(createdAt)} ${_fmtTime(createdAt)}';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: claimed
              ? Colors.green.shade50
              : Colors.orange.shade50,
          child: Icon(
            claimed ? Icons.check_circle_outline : Icons.pending_outlined,
            color: claimed ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          [
            'points: +$points',
            if (timeText.isNotEmpty) 'time: $timeText',
            'id: ${doc.id}',
          ].join('  •  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ----------------- common widgets -----------------
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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

  Widget _centerText(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

class _MissionTemplate {
  final String id;
  final String title;
  final String description;
  final String type;
  final int points;
  final int target;
  final bool isActive;
  final IconData icon;

  _MissionTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.points,
    required this.target,
    required this.icon,
    required this.isActive,
  });

  static _MissionTemplate fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();

    String s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();
    num asNum(dynamic v, {num fallback = 0}) {
      if (v == null) return fallback;
      if (v is num) return v;
      if (v is String) return num.tryParse(v) ?? fallback;
      return fallback;
    }

    bool asBool(dynamic v, {bool fallback = false}) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final t = v.trim().toLowerCase();
        if (t == 'true' || t == '1') return true;
        if (t == 'false' || t == '0') return false;
      }
      return fallback;
    }

    IconData pickIcon(String type) {
      switch (type) {
        case 'daily':
          return Icons.today_outlined;
        case 'weekly':
          return Icons.date_range_outlined;
        case 'event':
          return Icons.celebration_outlined;
        default:
          return Icons.flag_outlined;
      }
    }

    final type = s(d['type'], 'daily').trim();

    return _MissionTemplate(
      id: doc.id,
      title: s(d['title'], '任務').trim(),
      description: s(d['description'], '').trim(),
      type: type,
      points: asNum(d['points'], fallback: 0).toInt(),
      target: max(1, asNum(d['target'], fallback: 1).toInt()),
      isActive: asBool(d['isActive'], fallback: true),
      icon: pickIcon(type),
    );
  }
}

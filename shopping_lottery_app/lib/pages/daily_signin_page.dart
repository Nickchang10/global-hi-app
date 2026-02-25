// lib/pages/daily_signin_page.dart
//
// ✅ DailySigninPage（完整版｜可編譯）
// - ✅ 修正：uid 不再 required，若未傳入會自動用 FirebaseAuth.currentUser.uid
// - 每日簽到：Firestore 寫入 signins/{uid}/days/{yyyyMMdd}
// - 顯示今日是否已簽到
// - 提供簽到按鈕（避免重複簽到）
//
// 依賴：cloud_firestore, firebase_auth, flutter/material

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DailySigninPage extends StatefulWidget {
  const DailySigninPage({
    super.key,
    this.uid, // ✅ 不再 required
  });

  /// 可選：外部指定 uid；若不給，頁面會自動抓 FirebaseAuth uid
  final String? uid;

  @override
  State<DailySigninPage> createState() => _DailySigninPageState();
}

class _DailySigninPageState extends State<DailySigninPage> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _signedInToday = false;
  String? _error;

  String? _uidResolved;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _todayKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day'; // yyyyMMdd
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = (widget.uid ?? FirebaseAuth.instance.currentUser?.uid)
          ?.trim();
      if (uid == null || uid.isEmpty) {
        setState(() {
          _uidResolved = null;
          _loading = false;
          _error = '請先登入才能簽到';
        });
        return;
      }

      _uidResolved = uid;
      await _loadTodayState(uid);
    } catch (e) {
      setState(() {
        _error = '初始化失敗：$e';
        _loading = false;
      });
    }
  }

  DocumentReference<Map<String, dynamic>> _todayRef(String uid) {
    final key = _todayKey(DateTime.now());
    return _db.collection('signins').doc(uid).collection('days').doc(key);
  }

  Future<void> _loadTodayState(String uid) async {
    try {
      final snap = await _todayRef(uid).get();
      setState(() {
        _signedInToday = snap.exists;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '讀取簽到狀態失敗：$e';
        _loading = false;
      });
    }
  }

  Future<void> _signin() async {
    final uid = _uidResolved;
    if (uid == null || uid.isEmpty) {
      _snack('請先登入');
      return;
    }
    if (_signedInToday) {
      _snack('你今天已簽到');
      return;
    }

    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      await _todayRef(uid).set({
        'uid': uid,
        'dateKey': _todayKey(now),
        'createdAt': FieldValue.serverTimestamp(),
        'localCreatedAt': now.toIso8601String(),
      }, SetOptions(merge: true));

      setState(() {
        _signedInToday = true;
        _loading = false;
      });
      _snack('簽到成功！');
    } catch (e) {
      setState(() => _loading = false);
      _snack('簽到失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '每日簽到',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _loading ? null : _bootstrap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 46, color: cs.error),
                          const SizedBox(height: 10),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _bootstrap,
                            child: const Text('重試'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _signedInToday
                                ? Icons.verified
                                : Icons.calendar_month_outlined,
                            size: 52,
                            color: _signedInToday
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _signedInToday ? '今日已簽到' : '今日尚未簽到',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _signedInToday ? '明天再來簽到吧！' : '點一下即可完成今日簽到。',
                            style: TextStyle(color: cs.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _signedInToday ? null : _signin,
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(_signedInToday ? '已完成' : '立即簽到'),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _uidResolved == null ? '' : 'uid：$_uidResolved',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

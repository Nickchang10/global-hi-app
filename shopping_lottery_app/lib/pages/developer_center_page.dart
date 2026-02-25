import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ✅ DeveloperCenterPage（開發者中心｜完整版｜移除 FirestoreMockService.userPoints）
/// ------------------------------------------------------------
/// 修正：把不合法的 Icons.locks.privacy_tip_outlined 改為 Icons.privacy_tip_outlined
/// ------------------------------------------------------------
class DeveloperCenterPage extends StatefulWidget {
  const DeveloperCenterPage({super.key});

  @override
  State<DeveloperCenterPage> createState() => _DeveloperCenterPageState();
}

class _DeveloperCenterPageState extends State<DeveloperCenterPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _busy = false;

  User? get _user => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _fs.collection('users').doc(uid);

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Center'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: user == null ? _needLogin(context) : _content(user),
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
                  // ✅ 修正：合法 IconData 常量
                  const Icon(
                    Icons.privacy_tip_outlined,
                    size: 56,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能使用開發者中心',
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

  Widget _content(User user) {
    final uid = user.uid;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('帳號資訊'),
        const SizedBox(height: 8),
        _accountCard(user),

        const SizedBox(height: 16),
        _sectionTitle('積分（Firestore users/{uid}.points）'),
        const SizedBox(height: 8),
        _pointsCard(uid),

        const SizedBox(height: 16),
        _sectionTitle('開發者工具'),
        const SizedBox(height: 8),
        _toolsCard(uid),

        const SizedBox(height: 16),
        _sectionTitle('快捷導航（若你的路由存在）'),
        const SizedBox(height: 8),
        _navCard(),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }

  Widget _accountCard(User user) {
    final uid = user.uid;
    final email = user.email ?? '';
    final name = user.displayName ?? '';

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _kv('UID', uid, copy: true),
            const SizedBox(height: 6),
            _kv('Email', email.isEmpty ? '(無)' : email, copy: email.isNotEmpty),
            const SizedBox(height: 6),
            _kv('Display Name', name.isEmpty ? '(無)' : name),
          ],
        ),
      ),
    );
  }

  Widget _pointsCard(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userRef(uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _errorCard('讀取 points 失敗：${snap.error}');
        if (!snap.hasData) {
          return const Card(
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final data = snap.data!.data() ?? const <String, dynamic>{};
        final points = _asNum(data['points'], fallback: 0);

        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.stars_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '目前積分',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        points.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _busy ? null : () => _incrementPoints(uid, 10),
                  child: const Text('+10'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _busy ? null : () => _incrementPoints(uid, 100),
                  child: const Text('+100'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _toolsCard(String uid) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _resetPoints(uid),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('積分歸零'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _ensureUserDoc(uid),
                    child: const Text('補齊 users/{uid}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _createDemoCoupon,
                    child: const Text('建立 Demo Coupon'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _createDemoMission,
                    child: const Text('建立 Demo Mission'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '以上工具會寫入 Firestore（若規則不允許會失敗）',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navCard() {
    Widget btn(String label, String route, {Object? args}) {
      return Expanded(
        child: OutlinedButton(
          onPressed: () {
            try {
              Navigator.of(context).pushNamed(route, arguments: args);
            } catch (_) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('路由不存在：$route')));
            }
          },
          child: Text(label),
        ),
      );
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                btn('優惠券', '/coupons'),
                const SizedBox(width: 10),
                btn('每日任務', '/daily_mission'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                btn('結帳', '/checkout'),
                const SizedBox(width: 10),
                btn('聊天室', '/chat'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool copy = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(k, style: const TextStyle(color: Colors.grey)),
        ),
        Flexible(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (copy) ...[
          const SizedBox(width: 6),
          IconButton(
            tooltip: '複製',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: v));
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已複製')));
            },
          ),
        ],
      ],
    );
  }

  Widget _errorCard(String text) {
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

  Future<void> _ensureUserDoc(String uid) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _userRef(uid).set({
        'points': FieldValue.increment(0),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已補齊 users/{uid}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _incrementPoints(String uid, num delta) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _userRef(uid).set({
        'points': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ 已加點：+$delta')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 加點失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPoints(String uid) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _userRef(uid).set({
        'points': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已歸零積分')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 歸零失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createDemoCoupon() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final now = DateTime.now();
      final code = 'WELCOME${now.month}${now.day}${now.hour}${now.minute}';

      await _fs.collection('coupons').add({
        'code': code,
        'title': '新手折扣',
        'description': 'Demo coupon（開發者中心建立）',
        'type': 'amount',
        'value': 100,
        'minSpend': 399,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ 已建立 Demo Coupon：$code')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 建立 Coupon 失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createDemoMission() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _fs.collection('daily_missions').add({
        'title': '每日登入',
        'description': '每天登入一次即可領取獎勵（Demo 任務）',
        'points': 10,
        'isActive': true,
        'sort': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已建立 Demo Mission')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 建立 Mission 失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

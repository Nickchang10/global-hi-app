import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ MePage（我的頁｜最終完整版｜移除 FirestoreMockService.init）
/// ------------------------------------------------------------
/// - ✅ 不使用 FirestoreMockService（避免 init 不存在）
/// - ✅ 直接用 FirebaseAuth + Firestore 讀取 users/{uid}
/// - ✅ 首次登入自動補齊 user 文件（merge）
/// - ✅ 修正 lint：use_build_context_synchronously（await 後使用 context 前先 mounted 檢查；dialog pop 用 ctx）
///
/// Firestore 建議結構：
/// - users/{uid}
///   - displayName: String (optional)
///   - email: String (optional)
///   - phone: String (optional)
///   - role: String (optional)
///   - points: num (optional)
///   - createdAt: Timestamp (optional)
///   - updatedAt: Timestamp (optional)
/// ------------------------------------------------------------
class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _booting = true;
  String? _bootError;

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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _booting = true;
      _bootError = null;
    });

    try {
      final u = _user;
      if (u == null) {
        if (!mounted) return;
        setState(() => _booting = false);
        return;
      }

      // ✅ 確保 users/{uid} 文件存在（不覆蓋既有欄位）
      final ref = _userRef(u.uid);
      final snap = await ref.get();

      final base = <String, dynamic>{
        'email': u.email,
        'displayName': u.displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!snap.exists) {
        await ref.set({
          ...base,
          'role': 'user',
          'points': 0,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await ref.set(base, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() => _booting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _booting = false;
        _bootError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _bootstrap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: u == null
          ? _needLogin(context)
          : (_booting
                ? const Center(child: CircularProgressIndicator())
                : (_bootError != null
                      ? _error('初始化失敗：$_bootError')
                      : _body(u.uid))),
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
                    '請先登入才能查看我的頁面',
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userRef(uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _error('讀取使用者資料失敗：${snap.error}');
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data!.data() ?? const <String, dynamic>{};

        final displayName = _s(
          data['displayName'],
          _user?.displayName ?? '',
        ).trim();
        final email = _s(data['email'], _user?.email ?? '').trim();
        final phone = _s(data['phone'], '').trim();
        final role = _s(data['role'], 'user').trim();
        final points = _asNum(data['points'], fallback: 0).toInt();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _profileCard(
              uid: uid,
              displayName: displayName,
              email: email,
              phone: phone,
              role: role,
              points: points,
            ),
            const SizedBox(height: 12),

            _sectionTitle('功能'),
            const SizedBox(height: 8),
            _menuCard(
              children: [
                _navTile(
                  icon: Icons.receipt_long,
                  title: '我的訂單',
                  subtitle: '查看訂單狀態與紀錄',
                  routeName: '/orders',
                ),
                _navTile(
                  icon: Icons.card_giftcard,
                  title: '我的優惠券',
                  subtitle: '查看可用優惠券',
                  routeName: '/coupons',
                ),
                _navTile(
                  icon: Icons.location_on_outlined,
                  title: '地址管理',
                  subtitle: '收件地址/常用地址',
                  routeName: '/addresses',
                ),
              ],
            ),

            const SizedBox(height: 12),
            _sectionTitle('抽獎 / 獎勵'),
            const SizedBox(height: 8),
            _menuCard(
              children: [
                _navTile(
                  icon: Icons.casino_outlined,
                  title: '抽獎活動',
                  subtitle: '參加進行中的抽獎',
                  routeName: '/lottery',
                ),
                _navTile(
                  icon: Icons.history_outlined,
                  title: '獎勵紀錄',
                  subtitle: '排行榜獎勵領取紀錄',
                  routeName: '/leaderboard/reward/history',
                ),
                _navTile(
                  icon: Icons.query_stats_outlined,
                  title: '獎勵統計',
                  subtitle: '領取率/趨勢/分佈',
                  routeName: '/leaderboard/reward/stats',
                ),
              ],
            ),

            const SizedBox(height: 12),
            _sectionTitle('設定'),
            const SizedBox(height: 8),
            _menuCard(
              children: [
                _navTile(
                  icon: Icons.settings_outlined,
                  title: '設定',
                  subtitle: '通知/偏好/帳號',
                  routeName: '/settings',
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text(
                    '登出',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text('退出目前帳號'),
                  onTap: _confirmSignOut,
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Text(
              '註：此頁已移除 FirestoreMockService.init，全部改用 FirebaseAuth + Firestore users/{uid}。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  Widget _profileCard({
    required String uid,
    required String displayName,
    required String email,
    required String phone,
    required String role,
    required int points,
  }) {
    final shownName = displayName.isNotEmpty
        ? displayName
        : (email.isNotEmpty ? email : uid);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(shownName.substring(0, 1).toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shownName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (email.isNotEmpty) email,
                          if (phone.isNotEmpty) phone,
                        ].join('  •  '),
                        style: const TextStyle(color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'UID：$uid',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('點數', style: TextStyle(color: Colors.grey)),
                    Text(
                      points.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _pill('角色', role.isEmpty ? 'user' : role)),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _editProfile(uid, displayName, phone),
                    child: const Text('編輯資料'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('$k：', style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontWeight: FontWeight.w900),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuCard({required List<Widget> children}) {
    return Card(
      elevation: 1,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String routeName,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pushNamed(routeName),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
              child: Row(
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

  Future<void> _editProfile(
    String uid,
    String currentName,
    String currentPhone,
  ) async {
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('編輯資料'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '顯示名稱',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: '電話',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('儲存'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (!mounted) return;

    try {
      await _userRef(uid).set({
        'displayName': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已更新資料')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 更新失敗：$e')));
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('登出'),
        content: const Text('確定要登出嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('登出'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _auth.signOut();
      if (!mounted) return;

      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 登出失敗：$e')));
    }
  }
}

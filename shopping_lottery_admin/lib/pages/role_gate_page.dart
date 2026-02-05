// lib/pages/role_gate_page.dart
//
// ✅ RoleGatePage（完整版｜可編譯｜登入後自動分流｜Admin -> /admin｜Vendor -> /vendor｜支援 vendorId 檢查）
//
// 用途：解決你問的「怎麼廠商後台不是登主後台」
// - 你可以讓所有人都走同一個 LoginPage 登入
// - 登入成功後一律導到 /gate（本頁）
// - 本頁會去 Firestore users/{uid} 讀 role：
//    - role == 'admin'  -> pushReplacementNamed('/admin')
//    - role == 'vendor' -> pushReplacementNamed('/vendor')
//        - 若 vendorId 不存在，顯示錯誤（提示到主後台 VendorsPage 綁定）
//    - 其他/不存在 -> 顯示無權限頁
//
// Firestore users/{uid} 建議欄位：
// - role: 'admin' | 'vendor' | ...
// - vendorId: String（當 role=vendor 必填）
// - email / displayName（可選）
//
// 路由設定建議：
// routes: {
//   '/login': (_) => const LoginPage(afterLoginRoute: '/gate'),
//   '/gate': (_) => const RoleGatePage(),
//   '/admin': (_) => const AdminShellPage(),   // 你現有的主後台入口
//   '/vendor': (_) => const VendorShellPage(), // 你現有的廠商後台入口
// }
//
// 依賴：firebase_auth, cloud_firestore, flutter/material.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RoleGatePage extends StatefulWidget {
  const RoleGatePage({
    super.key,
    this.usersCollection = 'users',
    this.adminRoute = '/admin',
    this.vendorRoute = '/vendor',
    this.loginRoute = '/login',
  });

  final String usersCollection;

  final String adminRoute;
  final String vendorRoute;
  final String loginRoute;

  @override
  State<RoleGatePage> createState() => _RoleGatePageState();
}

class _RoleGatePageState extends State<RoleGatePage> {
  final _db = FirebaseFirestore.instance;

  Future<_RoleResult>? _future;
  String? _lastUid;

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<_RoleResult> _resolve(User user) async {
    final doc = await _db.collection(widget.usersCollection).doc(user.uid).get();
    final data = doc.data() ?? <String, dynamic>{};

    final role = _s(data['role']).toLowerCase();
    final vendorId = _s(data['vendorId']);

    return _RoleResult(
      uid: user.uid,
      email: user.email,
      role: role.isEmpty ? 'unknown' : role,
      vendorId: vendorId,
      raw: data,
      hasUserDoc: doc.exists,
    );
  }

  void _go(String route) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
    });
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, widget.loginRoute, (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登出失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (user == null) {
          // 尚未登入 -> 回 login
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('尚未登入', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        const SizedBox(height: 10),
                        Text('請先登入後再進入後台。', style: TextStyle(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, widget.loginRoute),
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

        // 每次 uid 變更就重算
        if (_future == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _future = _resolve(user);
        }

        return FutureBuilder<_RoleResult>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (snap.hasError) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('分流中...'),
                  actions: [
                    IconButton(
                      tooltip: '重新讀取',
                      onPressed: () => setState(() => _future = _resolve(user)),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                body: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('讀取角色失敗', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                              const SizedBox(height: 10),
                              Text('${snap.error}', style: TextStyle(color: cs.error)),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () => setState(() => _future = _resolve(user)),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('重試'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _signOut,
                                    icon: const Icon(Icons.logout),
                                    label: const Text('登出'),
                                  ),
                                ],
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

            final r = snap.data!;
            final role = r.role;

            // ✅ 自動導頁（pushReplacementNamed）
            if (role == 'admin') {
              _go(widget.adminRoute);
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (role == 'vendor') {
              if (r.vendorId.isEmpty) {
                // vendor 但沒 vendorId -> 顯示錯誤（避免進 vendor 後台炸掉）
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('廠商後台'),
                    actions: [
                      IconButton(
                        tooltip: '重新讀取',
                        onPressed: () => setState(() => _future = _resolve(user)),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  body: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('此帳號尚未綁定廠商', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                const SizedBox(height: 10),
                                Text(
                                  '你的 users/{uid}.role = vendor，但 vendorId 為空。\n'
                                  '請到主後台 VendorsPage 綁定：users/{uid}.vendorId -> vendors/{vendorId}。',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 12),
                                _KeyValue(label: 'uid', value: r.uid),
                                _KeyValue(label: 'email', value: r.email ?? '-'),
                                _KeyValue(label: 'role', value: r.role),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => setState(() => _future = _resolve(user)),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('我已綁定，重新檢查'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _signOut,
                                      icon: const Icon(Icons.logout),
                                      label: const Text('登出'),
                                    ),
                                  ],
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

              _go(widget.vendorRoute);
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // 其他 / unknown
            return Scaffold(
              appBar: AppBar(
                title: const Text('權限不足'),
                actions: [
                  IconButton(
                    tooltip: '重新讀取',
                    onPressed: () => setState(() => _future = _resolve(user)),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('此帳號沒有後台權限', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                            const SizedBox(height: 10),
                            Text(
                              r.hasUserDoc
                                  ? 'users/{uid}.role = "${r.role}"，未被允許進入後台。'
                                  : '找不到 users/{uid} 文件。請先建立 users 文件並設定 role。',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            _KeyValue(label: 'uid', value: r.uid),
                            _KeyValue(label: 'email', value: r.email ?? '-'),
                            _KeyValue(label: 'role', value: r.role),
                            if (r.vendorId.isNotEmpty) _KeyValue(label: 'vendorId', value: r.vendorId),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => setState(() => _future = _resolve(user)),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('重試'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _signOut,
                                  icon: const Icon(Icons.logout),
                                  label: const Text('登出'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '提示：請在 users/{uid} 設定 role=admin 或 role=vendor（vendor 需有 vendorId）。',
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------
// Models / UI helpers
// ------------------------------------------------------------
class _RoleResult {
  final String uid;
  final String? email;
  final String role;
  final String vendorId;
  final Map<String, dynamic> raw;
  final bool hasUserDoc;

  const _RoleResult({
    required this.uid,
    required this.email,
    required this.role,
    required this.vendorId,
    required this.raw,
    required this.hasUserDoc,
  });
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
          IconButton(
            tooltip: '複製',
            onPressed: value.trim().isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: value.trim()));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製')));
                  },
            icon: const Icon(Icons.copy, size: 18),
          ),
        ],
      ),
    );
  }
}

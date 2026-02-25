// lib/pages/vendor/vendor_gate.dart
//
// ✅ VendorGate（可編譯完整版｜不依賴 admin_shell_page.dart import）
// ------------------------------------------------------------
// - 目的：登入後只要進到 /vendor_gate，就會依 users/{uid}.role 分流
//   - role == 'vendor' -> 進 /vendor
//   - role == 'admin'  -> 進 /admin（避免 admin 誤進 vendor gate）
//   - 其他/找不到 users doc -> 顯示無權限
// - vendor 需 vendorId，不然顯示提示（請到主後台綁定）
//
// 依賴：firebase_auth, cloud_firestore, flutter/material.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorGate extends StatefulWidget {
  const VendorGate({
    super.key,
    this.usersCollection = 'users',
    this.vendorRoute = '/vendor',
    this.adminRoute = '/admin',
    this.loginRoute = '/login',
  });

  final String usersCollection;
  final String vendorRoute;
  final String adminRoute;
  final String loginRoute;

  @override
  State<VendorGate> createState() => _VendorGateState();
}

/// 有些地方可能用 VendorGatePage 當路由頁名，做一個 alias 避免你要全專案改 class 名
class VendorGatePage extends VendorGate {
  const VendorGatePage({super.key});
}

class _VendorGateState extends State<VendorGate> {
  final _db = FirebaseFirestore.instance;

  Future<_GateResult>? _future;
  String? _lastUid;

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<_GateResult> _load(User user) async {
    final doc = await _db
        .collection(widget.usersCollection)
        .doc(user.uid)
        .get();
    final data = doc.data() ?? <String, dynamic>{};

    final role = _s(data['role']).toLowerCase();
    final vendorId = _s(data['vendorId']);

    return _GateResult(
      uid: user.uid,
      email: user.email,
      hasDoc: doc.exists,
      role: role.isEmpty ? 'unknown' : role,
      vendorId: vendorId,
      raw: data,
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
      Navigator.pushNamedAndRemoveUntil(
        context,
        widget.loginRoute,
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登出失敗：$e')));
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          // 未登入 -> 回登入頁
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
                        const Text(
                          '尚未登入',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '請先登入後再進入廠商後台。',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            widget.loginRoute,
                          ),
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

        // uid 變更就重新讀
        if (_future == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _future = _load(user);
        }

        return FutureBuilder<_GateResult>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snap.hasError) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('廠商入口'),
                  actions: [
                    IconButton(
                      tooltip: '重試',
                      onPressed: () => setState(() => _future = _load(user)),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '讀取角色失敗：${snap.error}',
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                ),
              );
            }

            final r = snap.data!;
            final role = r.role;

            // ✅ admin 走 admin（避免 admin 進 vendor gate）
            if (role == 'admin') {
              _go(widget.adminRoute);
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // ✅ vendor 才能走 vendor
            if (role == 'vendor') {
              if (r.vendorId.isEmpty) {
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('廠商後台'),
                    actions: [
                      IconButton(
                        tooltip: '重新讀取',
                        onPressed: () => setState(() => _future = _load(user)),
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
                                const Text(
                                  '此帳號尚未綁定廠商',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'users/{uid}.role = vendor，但 vendorId 為空。\n'
                                  '請到主後台 Vendors 管理綁定 users/{uid}.vendorId -> vendors/{vendorId}。',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 14),
                                _kv('uid', r.uid),
                                _kv('email', r.email ?? '-'),
                                _kv('role', r.role),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () =>
                                          setState(() => _future = _load(user)),
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
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // 其他角色 / 沒文件
            return Scaffold(
              appBar: AppBar(
                title: const Text('無權限'),
                actions: [
                  IconButton(
                    tooltip: '重新讀取',
                    onPressed: () => setState(() => _future = _load(user)),
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
                            const Text(
                              '此帳號沒有廠商後台權限',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              r.hasDoc
                                  ? 'users/{uid}.role = "${r.role}"，不允許進入廠商後台。'
                                  : '找不到 users/{uid} 文件。請先建立 users 文件並設定 role。',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            _kv('uid', r.uid),
                            _kv('email', r.email ?? '-'),
                            _kv('role', r.role),
                            if (r.vendorId.isNotEmpty)
                              _kv('vendorId', r.vendorId),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
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
          },
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              k,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _GateResult {
  final String uid;
  final String? email;
  final bool hasDoc;
  final String role;
  final String vendorId;
  final Map<String, dynamic> raw;

  const _GateResult({
    required this.uid,
    required this.email,
    required this.hasDoc,
    required this.role,
    required this.vendorId,
    required this.raw,
  });
}

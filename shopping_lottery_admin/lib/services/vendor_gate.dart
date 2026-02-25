// lib/services/vendor_gate.dart
//
// ✅ VendorGate（修改後完整版｜可編譯｜修正 vendorId named parameter 不存在）
// ------------------------------------------------------------
// 用途：登入後判斷 users/{uid}.role
// - admin  -> 導到 /admin（可配置）
// - vendor -> 導到 /vendor（可配置），並用 Navigator arguments 帶入 vendorId
// - 其他   -> 顯示無權限頁
//
// ✅ 修正重點：
// 不再呼叫「不存在 vendorId named parameter」的建構式
// 改用：Navigator.pushReplacementNamed(route, arguments: {'vendorId': xxx})
//
// Firestore users/{uid} 建議：
// - role: 'admin' | 'vendor'
// - vendorId: String（role=vendor 必填）
//
// 依賴：firebase_auth, cloud_firestore, flutter/material.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorGate extends StatefulWidget {
  const VendorGate({
    super.key,
    this.usersCollection = 'users',
    this.loginRoute = '/login',
    this.adminRoute = '/admin',
    this.vendorRoute = '/vendor',
    this.requireVendorId = true,
  });

  final String usersCollection;
  final String loginRoute;
  final String adminRoute;
  final String vendorRoute;

  /// role=vendor 時是否強制要求 vendorId
  final bool requireVendorId;

  @override
  State<VendorGate> createState() => _VendorGateState();
}

class _VendorGateState extends State<VendorGate> {
  final _db = FirebaseFirestore.instance;

  Future<_GateRoleResult>? _future;
  String? _lastUid;

  bool _navigated = false;

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<_GateRoleResult> _resolve(User user) async {
    final doc = await _db
        .collection(widget.usersCollection)
        .doc(user.uid)
        .get();
    final data = doc.data() ?? <String, dynamic>{};

    final role = _s(data['role']).toLowerCase();
    final vendorId = _s(data['vendorId']);

    return _GateRoleResult(
      uid: user.uid,
      email: user.email,
      role: role.isEmpty ? 'unknown' : role,
      vendorId: vendorId,
      hasUserDoc: doc.exists,
      raw: data,
    );
  }

  void _go(String route, {Object? arguments}) {
    if (!mounted) return;
    if (_navigated) return;
    _navigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route, arguments: arguments);
    });
  }

  void _goVendor(String vendorId) {
    // ✅ 用 arguments 傳 vendorId（避免 vendorId named parameter 不存在）
    _go(widget.vendorRoute, arguments: {'vendorId': vendorId});
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
          _navigated = false;
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

        // uid 變更 -> 重算
        if (_future == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _navigated = false;
          _future = _resolve(user);
        }

        return FutureBuilder<_GateRoleResult>(
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
                              const Text(
                                '讀取角色失敗',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${snap.error}',
                                style: TextStyle(color: cs.error),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () => setState(
                                      () => _future = _resolve(user),
                                    ),
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

            // ✅ admin：導到主後台
            if (role == 'admin') {
              _go(widget.adminRoute);
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // ✅ vendor：檢查 vendorId
            if (role == 'vendor') {
              if (widget.requireVendorId && r.vendorId.isEmpty) {
                return Scaffold(
                  appBar: AppBar(title: const Text('廠商後台')),
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
                                  '你的 users/{uid}.role = vendor，但 vendorId 為空。\n'
                                  '請到主後台 VendorsPage 綁定：users/{uid}.vendorId -> vendors/{vendorId}。',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 12),
                                _KeyValue(label: 'uid', value: r.uid),
                                _KeyValue(
                                  label: 'email',
                                  value: r.email ?? '-',
                                ),
                                _KeyValue(label: 'role', value: r.role),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => setState(
                                        () => _future = _resolve(user),
                                      ),
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

              // ✅ vendor：導到 vendor route，並用 arguments 帶 vendorId（避免 vendorId named parameter）
              _goVendor(r.vendorId);
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // 其他 / unknown
            return Scaffold(
              appBar: AppBar(title: const Text('權限不足')),
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
                              '此帳號沒有後台權限',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
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
                            if (r.vendorId.isNotEmpty)
                              _KeyValue(label: 'vendorId', value: r.vendorId),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: () =>
                                      setState(() => _future = _resolve(user)),
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
          },
        );
      },
    );
  }
}

class _GateRoleResult {
  final String uid;
  final String? email;
  final String role;
  final String vendorId;
  final bool hasUserDoc;
  final Map<String, dynamic> raw;

  const _GateRoleResult({
    required this.uid,
    required this.email,
    required this.role,
    required this.vendorId,
    required this.hasUserDoc,
    required this.raw,
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
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

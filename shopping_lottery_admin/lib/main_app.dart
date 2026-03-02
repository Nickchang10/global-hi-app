import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:osmile_admin/services/auth_service.dart';

import 'pages/admin/admin_shell_page.dart';
import 'pages/auth/login_page.dart';

class AdminBootstrap extends StatelessWidget {
  const AdminBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AdminApp();
  }
}

class _AdminApp extends StatelessWidget {
  const _AdminApp();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Osmile Admin',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        routes: {
          '/login': (_) => const LoginPage(),

          // 主後台（slash + hyphen 都支援）
          '/admin': (_) => const AdminRouteGate(),
          '/admin/products': (_) => const AdminRouteGate(),
          '/admin/orders': (_) => const AdminRouteGate(),
          '/admin/campaigns': (_) => const AdminRouteGate(),

          '/admin-products': (_) => const AdminRouteGate(),
          '/admin-orders': (_) => const AdminRouteGate(),
          '/admin-campaigns': (_) => const AdminRouteGate(),
        },
        home: const AdminRouteGate(),
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => UnknownRoutePage(settings: settings),
          settings: settings,
        ),
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => UnknownRoutePage(settings: settings),
          settings: settings,
        ),
      ),
    );
  }
}

/// ✅ 統一的 Admin 入口守門（加入「角色快取秒過」）
class AdminRouteGate extends StatelessWidget {
  const AdminRouteGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;

        if (snap.connectionState == ConnectionState.waiting) {
          return const _GateLoadingPage(title: 'AuthGate 檢查中…');
        }

        if (user == null) {
          // 登出/未登入時清快取，避免殘留
          RoleCache.clear();
          return const LoginPage();
        }

        // ✅ 先看快取：有結果就秒過，不再顯示 RoleGate loading
        final cached = RoleCache.peek(user.uid);
        if (cached != null) {
          return cached.isAdmin
              ? const AdminShellPage()
              : _AccessDeniedPage(
                  title: '無管理員權限',
                  message:
                      '你的帳號沒有 admin 權限。\n\n偵測結果：role=${cached.role ?? "(null)"} / admin=${cached.isAdmin} / source=${cached.source}',
                );
        }

        // 沒快取才進 RoleGate 跑一次查詢
        return RoleGate(user: user);
      },
    );
  }
}

/// ✅ RoleGate（修正：用全域 RoleCache，換路由也不再重新查）
class RoleGate extends StatefulWidget {
  const RoleGate({super.key, required this.user});
  final User user;

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  Future<_ResolvedRole>? _future;

  @override
  void initState() {
    super.initState();
    _future = RoleCache.resolve(widget.user, _resolveRole);
  }

  @override
  void didUpdateWidget(covariant RoleGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _future = RoleCache.resolve(widget.user, _resolveRole);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResolvedRole>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _GateLoadingPage(title: 'RoleGate 判斷權限中…');
        }
        if (snap.hasError) {
          return _AccessDeniedPage(
            title: '權限判斷失敗',
            message: snap.error.toString(),
          );
        }

        final role = snap.data ?? const _ResolvedRole.none();
        if (role.isAdmin) return const AdminShellPage();

        return _AccessDeniedPage(
          title: '無管理員權限',
          message:
              '你的帳號沒有 admin 權限。\n\n偵測結果：role=${role.role ?? "(null)"} / admin=${role.isAdmin} / source=${role.source}',
        );
      },
    );
  }

  Future<_ResolvedRole> _resolveRole(User u) async {
    // 1) custom claims（不要每次強制 refresh）
    try {
      final token = await u.getIdTokenResult().timeout(
        const Duration(seconds: 8),
      );
      final claims = token.claims ?? const <String, dynamic>{};

      final adminFlag = claims['admin'];
      final role = claims['role'];

      final isAdminClaim =
          adminFlag == true ||
          (role is String &&
              (role == 'admin' ||
                  role == 'super_admin' ||
                  role == 'superadmin'));

      if (isAdminClaim) {
        return _ResolvedRole(
          isAdmin: true,
          role: role?.toString() ?? 'admin',
          source: 'custom_claims',
        );
      }
    } catch (_) {
      // ignore → fallback to firestore
    }

    // 2) Firestore users/{uid}
    try {
      final fs = FirebaseFirestore.instance;
      final doc = await fs
          .collection('users')
          .doc(u.uid)
          .get()
          .timeout(const Duration(seconds: 8));
      final data = doc.data();

      final role = (data?['role'] ?? data?['userRole'] ?? '').toString();
      final isAdminField =
          (data?['isAdmin'] == true) ||
          (data?['admin'] == true) ||
          role == 'admin' ||
          role == 'super_admin' ||
          role == 'superadmin';

      return _ResolvedRole(
        isAdmin: isAdminField,
        role: role.isEmpty ? null : role,
        source: 'firestore_users',
      );
    } catch (e) {
      return _ResolvedRole(
        isAdmin: false,
        role: null,
        source: 'firestore_error: $e',
      );
    }
  }
}

class _ResolvedRole {
  final bool isAdmin;
  final String? role;
  final String source;

  const _ResolvedRole({
    required this.isAdmin,
    required this.role,
    required this.source,
  });

  const _ResolvedRole.none() : isAdmin = false, role = null, source = 'none';
}

/// ✅ 全域角色快取：同一個 uid 只查一次，換路由也不再轉圈
class RoleCache {
  static final Map<String, _ResolvedRole> _resolved = {};
  static final Map<String, Future<_ResolvedRole>> _futures = {};

  static _ResolvedRole? peek(String uid) => _resolved[uid];

  static Future<_ResolvedRole> resolve(
    User user,
    Future<_ResolvedRole> Function(User) loader,
  ) {
    final cached = _resolved[user.uid];
    if (cached != null) return Future.value(cached);

    return _futures.putIfAbsent(user.uid, () async {
      final r = await loader(user);
      _resolved[user.uid] = r;
      return r;
    });
  }

  static void clear([String? uid]) {
    if (uid == null) {
      _resolved.clear();
      _futures.clear();
    } else {
      _resolved.remove(uid);
      _futures.remove(uid);
    }
  }
}

class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({super.key, required this.settings});
  final RouteSettings settings;

  @override
  Widget build(BuildContext context) {
    final name = settings.name ?? '(null)';
    final args = settings.arguments;

    return Scaffold(
      appBar: AppBar(title: const Text('UnknownRoute')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route, size: 46),
                    const SizedBox(height: 10),
                    Text(
                      '找不到路由：$name',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      'arguments: ${args == null ? "(null)" : args.toString()}',
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/admin', (_) => false),
                      icon: const Icon(Icons.dashboard),
                      label: const Text('回管理後台'),
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

class _GateLoadingPage extends StatelessWidget {
  const _GateLoadingPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _AccessDeniedPage extends StatelessWidget {
  const _AccessDeniedPage({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Access Denied')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, size: 46, color: cs.error),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    SelectableText(message),
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

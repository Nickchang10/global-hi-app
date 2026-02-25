// lib/main_app.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ✅ 依你的專案實際路徑調整
import 'pages/admin/admin_shell_page.dart';
import 'pages/auth/login_page.dart';

/// ✅ AdminBootstrap（最終可編譯版）
/// - 不再依賴 firebase_options.dart（避免你目前 flutterfire configure 失敗就全案爆）
/// - Mobile: Firebase.initializeApp() 走原生設定檔（google-services.json / plist）
/// - Web: 用 --dart-define 提供 FirebaseOptions（沒提供會顯示 FatalInitPage）
class AdminBootstrap extends StatefulWidget {
  const AdminBootstrap({super.key});

  @override
  State<AdminBootstrap> createState() => _AdminBootstrapState();
}

class _AdminBootstrapState extends State<AdminBootstrap> {
  late final Future<void> _init;

  @override
  void initState() {
    super.initState();
    _init = _ensureFirebase();
  }

  FirebaseOptions _webOptionsFromDefines() {
    // 你可用：
    // flutter run -d chrome --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... ...
    return FirebaseOptions(
      apiKey: const String.fromEnvironment(
        'FIREBASE_API_KEY',
        defaultValue: '',
      ),
      appId: const String.fromEnvironment('FIREBASE_APP_ID', defaultValue: ''),
      messagingSenderId: const String.fromEnvironment(
        'FIREBASE_SENDER_ID',
        defaultValue: '',
      ),
      projectId: const String.fromEnvironment(
        'FIREBASE_PROJECT_ID',
        defaultValue: '',
      ),
      authDomain: const String.fromEnvironment(
        'FIREBASE_AUTH_DOMAIN',
        defaultValue: '',
      ),
      storageBucket: const String.fromEnvironment(
        'FIREBASE_STORAGE_BUCKET',
        defaultValue: '',
      ),
      measurementId: const String.fromEnvironment(
        'FIREBASE_MEASUREMENT_ID',
        defaultValue: '',
      ),
    );
  }

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isNotEmpty) return;

    if (kIsWeb) {
      final opt = _webOptionsFromDefines();
      if (opt.apiKey.isEmpty || opt.appId.isEmpty || opt.projectId.isEmpty) {
        throw Exception(
          'Web FirebaseOptions 未設定。\n'
          '請先成功執行 flutterfire configure 產生 firebase_options.dart，\n'
          '或使用 --dart-define 提供：\n'
          'FIREBASE_API_KEY / FIREBASE_APP_ID / FIREBASE_PROJECT_ID / FIREBASE_SENDER_ID（至少）',
        );
      }
      await Firebase.initializeApp(options: opt);
      return;
    }

    // ✅ Android / iOS：使用原生設定檔
    await Firebase.initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _FatalInitPage(error: snap.error.toString()),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _InitLoadingPage(),
          );
        }
        return const _AdminApp();
      },
    );
  }
}

class _AdminApp extends StatelessWidget {
  const _AdminApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Osmile Admin',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      routes: {
        '/bootstrap': (_) => const _BootstrapOkPage(),
        '/login': (_) => const LoginPage(),
        '/admin': (_) => const AdminShellPage(),
      },
      home: const AuthGate(),
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => UnknownRoutePage(settings: settings),
        );
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => UnknownRoutePage(settings: settings),
        );
      },
    );
  }
}

/// ✅ AuthGate：未登入 -> LoginPage；已登入 -> RoleGate
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;
        if (snap.connectionState == ConnectionState.waiting) {
          return const _GateLoadingPage(title: 'AuthGate 檢查中…');
        }
        if (user == null) {
          return const LoginPage();
        }
        return RoleGate(user: user);
      },
    );
  }
}

/// ✅ RoleGate：判斷是否為 admin（支援 custom claims + Firestore users/{uid}）
class RoleGate extends StatelessWidget {
  const RoleGate({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResolvedRole>(
      future: _resolveRole(user),
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
        if (role.isAdmin) {
          return const AdminShellPage();
        }

        return _AccessDeniedPage(
          title: '無管理員權限',
          message:
              '你的帳號沒有 admin 權限。\n\n偵測結果：role=${role.role ?? "(null)"} / admin=${role.isAdmin}',
        );
      },
    );
  }

  Future<_ResolvedRole> _resolveRole(User u) async {
    // 1) custom claims
    try {
      final token = await u.getIdTokenResult(true);
      final claims = token.claims ?? const <String, dynamic>{};

      final dynamic adminFlag = claims['admin'];
      final dynamic role = claims['role'];

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
    } catch (_) {}

    // 2) Firestore users/{uid}
    final fs = FirebaseFirestore.instance;
    final doc = await fs.collection('users').doc(u.uid).get();
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

/// ✅ UnknownRoute：避免 crash
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
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('返回'),
                        ),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil('/admin', (_) => false),
                          icon: const Icon(Icons.dashboard),
                          label: const Text('回管理後台'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/bootstrap'),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Bootstrap'),
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
}

class _BootstrapOkPage extends StatelessWidget {
  const _BootstrapOkPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Osmile Bootstrap')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AdminBootstrap 啟動成功',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '你現在可以把前台/後台 routes 接回來。\n'
                      'pushNamed 到尚未建立的路由會顯示 UnknownRoute，不會 crash。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/admin', (_) => false),
                        child: const Text('進入後台'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Bootstrap OK'),
        ),
      ),
    );
  }
}

class _InitLoadingPage extends StatelessWidget {
  const _InitLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 3),
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
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (!context.mounted) return;
                            Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil('/login', (_) => false);
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('登出'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/bootstrap'),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('回 Bootstrap'),
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
}

class _FatalInitPage extends StatelessWidget {
  const _FatalInitPage({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber, size: 46),
                      const SizedBox(height: 10),
                      const Text(
                        'Firebase 初始化失敗',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(error),
                      const SizedBox(height: 12),
                      Text(
                        kIsWeb
                            ? 'Web 需要 FirebaseOptions：請 flutterfire configure 或用 --dart-define 提供'
                            : '請確認 firebase_core 與原生設定檔是否正確（google-services.json / plist）',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

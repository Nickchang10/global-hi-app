// lib/main_admin.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ✅ Firebase 若你有用，打開下面兩行
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

import 'services/auth/auth_service.dart';
import 'services/notification_service.dart';

// ✅ 依你的專案實際頁面調整（這裡先用佔位）
// import 'pages/admin/admin_gate.dart';
// import 'pages/admin/admin_shell_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 若你後台有初始化 Firebase，請打開
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        /// ✅ FIX: AuthService 不是 ChangeNotifier → 用 Provider
        Provider<AuthService>(create: (_) => AuthService()),

        /// ✅ NotificationService 是 ChangeNotifier → 用 ChangeNotifierProvider
        ChangeNotifierProvider<NotificationService>(
          create: (_) => NotificationService(),
        ),

        // 你其他 Provider 照放（例）
        // ChangeNotifierProvider<AdminModeController>(create: (_) => AdminModeController()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Osmile Admin',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),

        /// ✅ 這裡換成你的實際後台入口
        /// 例如：home: const AdminGate(),
        home: const _AdminBootstrapPage(),
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// ✅ 佔位入口頁：確保 Provider/AuthService 有正常工作（可刪）
/// ------------------------------------------------------------------
class _AdminBootstrapPage extends StatelessWidget {
  const _AdminBootstrapPage();

  @override
  Widget build(BuildContext context) {
    // ✅ Provider<AuthService> 仍然可以用 watch/read
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Bootstrap'),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已登出')));
                }
              },
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: Center(
        child: user == null
            ? _LoginPanel(
                onLogin: (email, pw) async {
                  try {
                    await auth.signInWithEmailAndPassword(
                      email: email,
                      password: pw,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('登入成功')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('登入失敗：$e')));
                    }
                  }
                },
              )
            : Text('Signed in as: ${user.email ?? user.uid}'),
      ),
    );
  }
}

class _LoginPanel extends StatefulWidget {
  final Future<void> Function(String email, String password) onLogin;
  const _LoginPanel({required this.onLogin});

  @override
  State<_LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<_LoginPanel> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    final email = _email.text.trim();
    final pw = _pw.text;
    if (email.isEmpty || pw.isEmpty) return;

    setState(() => _loading = true);
    try {
      await widget.onLogin(email, pw);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pw,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _loading ? null : _doLogin,
                child: _loading
                    ? const CircularProgressIndicator.adaptive()
                    : const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

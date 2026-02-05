// lib/main_admin.dart
//
// ✅ Osmile Admin 後台主程式（完整版）
// 可直接 run Web / App，用於測試完整 Admin 後台流程。
// 與 vendor 後台獨立運作，可部署在不同路由或執行環境。
// ------------------------------------------------------------

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/admin_gate.dart';
import 'pages/admin_shell_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "YOUR_API_KEY_HERE",
      authDomain: "YOUR_PROJECT.firebaseapp.com",
      projectId: "YOUR_PROJECT_ID",
      storageBucket: "YOUR_PROJECT.appspot.com",
      messagingSenderId: "YOUR_SENDER_ID",
      appId: "YOUR_APP_ID",
    ),
  );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Osmile Admin 後台',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (_) => const _AdminEntryPage(),
        '/admin': (_) => const AdminGate(),
      },
    );
  }
}

/// ------------------------------------------------------------
/// 登入檢查頁
/// ------------------------------------------------------------
class _AdminEntryPage extends StatefulWidget {
  const _AdminEntryPage();

  @override
  State<_AdminEntryPage> createState() => _AdminEntryPageState();
}

class _AdminEntryPageState extends State<_AdminEntryPage> {
  final _auth = FirebaseAuth.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final user = _auth.currentUser;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (user != null) {
      Navigator.pushReplacementNamed(context, '/admin');
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin 後台登入')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(20),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('請登入以進入主後台',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('使用測試管理員登入'),
                    onPressed: _loginTestAdmin,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '登入後會自動導向 AdminShellPage，\n'
                    '請確認 users/{uid}.role == "admin"。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 測試帳號登入
  Future<void> _loginTestAdmin() async {
    try {
      const email = "admin@test.com";
      const password = "123456";

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/admin');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('登入失敗：$e')));
    }
  }
}

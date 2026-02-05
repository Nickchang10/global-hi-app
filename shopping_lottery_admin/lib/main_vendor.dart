// lib/main_vendor.dart
//
// ✅ Osmile Vendor 後台主程式（最終整合完整版｜可編譯｜使用 flutterfire 的 firebase_options.dart）
// ------------------------------------------------------------
// 你要做的事：
// 1) 在「SHOPPING_LOTTERY_ADMIN 專案根目錄」執行 flutterfire configure
// 2) 確保 lib/firebase_options.dart 存在
// 3) 用此檔案啟動：flutter run -t lib/main_vendor.dart
//
// 路由設計：
// - '/'            : Entry（登入/導向）
// - '/vendor'      : VendorGate（檢查 role/vendorId，再導到 VendorShellPage）
// - '/vendor/*'    : （可選）tab-route 同步：dashboard/products/orders
//
// 注意：
// - 若你尚未在 VendorShellPage 開啟 enableRouteSync，可以只使用 '/vendor' 即可。
// - 若你要開啟 enableRouteSync（tab ↔ route 同步），就把 VendorShellPage(enableRouteSync:true) 打開，
//   並保留本檔對應 routes。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

// ✅ 你的 Vendor Gate（你專案裡是在 services/）
import 'services/vendor_gate.dart';

// ✅ 若你要使用 /vendor/dashboard 這類 routeSync，這裡直接引用 VendorShellPage
// （即使你不用，也可保留不影響編譯）
import 'pages/vendor_shell_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 初始化 Firebase（使用 flutterfire 產生的 firebase_options.dart）
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ✅ 用來確認是不是同一個 Firebase 專案
    if (kDebugMode) {
      debugPrint('✅ Vendor Firebase projectId = ${Firebase.app().options.projectId}');
    }
  } catch (e) {
    runApp(_FirebaseInitErrorApp(error: e.toString()));
    return;
  }

  runApp(const VendorApp());
}

class VendorApp extends StatelessWidget {
  const VendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Osmile Vendor 後台',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        // Entry：未登入顯示登入按鈕；已登入導向 /vendor
        '/': (_) => const _EntryPage(),

        // Gate：依你既有 services/vendor_gate.dart 進行 role/vendorId 檢查並導頁
        '/vendor': (_) => const VendorGate(),

        // ------------------------------------------------------------
        // （可選）Route Sync：若你要把 tab 映射為路由，可保留以下 routes
        // 前提：VendorShellPage(enableRouteSync:true) 且 routes 有註冊
        // ------------------------------------------------------------
        '/vendor/dashboard': (_) => const VendorShellPage(
              initialTab: VendorTab.dashboard,
              enableRouteSync: true,
              routeBase: '/vendor',
            ),
        '/vendor/products': (_) => const VendorShellPage(
              initialTab: VendorTab.products,
              enableRouteSync: true,
              routeBase: '/vendor',
            ),
        '/vendor/orders': (_) => const VendorShellPage(
              initialTab: VendorTab.orders,
              enableRouteSync: true,
              routeBase: '/vendor',
            ),
      },
    );
  }
}

/// ------------------------------------------------------------
/// 登入檢查頁（若已登入則進入 VendorGate）
class _EntryPage extends StatefulWidget {
  const _EntryPage();

  @override
  State<_EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<_EntryPage> {
  final _auth = FirebaseAuth.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final user = _auth.currentUser;

    // 給 UI 一點點時間避免閃屏（可移除）
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    if (user != null) {
      Navigator.pushReplacementNamed(context, '/vendor');
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Vendor 後台登入')),
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
                  const Text(
                    '請登入以進入廠商後台',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 18),

                  // ✅ 測試帳密登入（可改成你自己的登入頁）
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('使用測試帳號登入'),
                    onPressed: _loginTestAccount,
                  ),

                  const SizedBox(height: 10),
                  Text(
                    '登入後會自動檢查 users/{uid} 角色與 vendorId。\n'
                    '成功則導向 VendorGate / VendorShellPage。\n\n'
                    '提示：若你已有正式登入頁，可把這裡替換成 Email/Password / Google / Apple 登入。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),

                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新檢查登入狀態'),
                    onPressed: () => _checkAuth(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ------------------------------------------------------------
  /// 測試帳號登入（Firebase Email/Password）
  Future<void> _loginTestAccount() async {
    try {
      const email = "vendor@test.com";
      const password = "123456";

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/vendor');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登入失敗：$e')));
    }
  }
}

/// ------------------------------------------------------------
/// Firebase 初始化失敗顯示頁（避免黑屏）
class _FirebaseInitErrorApp extends StatelessWidget {
  const _FirebaseInitErrorApp({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Firebase 初始化失敗（Vendor）',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      Text(error),
                      const SizedBox(height: 12),
                      const Text(
                        '請確認：\n'
                        '1) 你在「SHOPPING_LOTTERY_ADMIN 專案根目錄」執行 flutterfire configure\n'
                        '2) lib/firebase_options.dart 存在\n'
                        '3) 你選到正確 Firebase 專案（例如 global-hi-app）\n'
                        '4) pubspec.yaml 有 firebase_core / firebase_auth / cloud_firestore\n'
                        '5) Android/iOS/Web 的 Firebase 設定檔已正確生成/加入\n',
                        style: TextStyle(fontSize: 12),
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

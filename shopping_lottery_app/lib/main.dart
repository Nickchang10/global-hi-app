// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'pages/main_navigation_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Web 必須帶 options，否則 options != null 會爆
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const OsmileApp());
}

class OsmileApp extends StatelessWidget {
  const OsmileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ 不要再用 home:（避免你之前 "/" 跟 routes 衝突）
      initialRoute: '/',

      routes: {
        // Root：預設首頁 tab
        '/': (_) => const MainNavigationPage(initialTabRoute: '/home'),

        // ✅ 底導 tab route：都導回 MainNavigationPage，並指定要開哪個 tab
        '/home': (_) => const MainNavigationPage(initialTabRoute: '/home'),
        '/shop': (_) => const MainNavigationPage(initialTabRoute: '/shop'),
        '/support': (_) => const MainNavigationPage(initialTabRoute: '/support'),
        '/me': (_) => const MainNavigationPage(initialTabRoute: '/me'),
        '/tasks': (_) => const MainNavigationPage(initialTabRoute: '/tasks'),
        '/interact': (_) => const MainNavigationPage(initialTabRoute: '/interact'),
        '/interaction': (_) => const MainNavigationPage(initialTabRoute: '/interact'),

        // ✅ 抽獎統一 /lotterys（也兼容 /lottery）
        '/lotterys': (_) => const MainNavigationPage(initialTabRoute: '/lotterys'),
        '/lottery': (_) => const MainNavigationPage(initialTabRoute: '/lotterys'),
      },

      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Unknown route')),
          body: Center(child: Text('尚未註冊路由：${settings.name}')),
        ),
      ),
    );
  }
}

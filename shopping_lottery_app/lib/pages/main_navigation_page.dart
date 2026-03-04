import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'main_nav_scope.dart';
import 'member_page.dart';

// ✅ 商店頁（你已經接上 ProductsPage 才用這個 import）
import 'products/products_page.dart';

// ✅ 任務頁：你如果已有真實任務頁，改 import + class
import 'tasks/tasks_page.dart';

// ✅ Store Page
import '../store_page/pages/home_page.dart' as store_home;

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  static const String _cfgCol = 'app_config';
  static const String _cfgDoc = 'home_layout';

  int _index = 0;
  Object? _lastJumpArgs;

  void _jumpTo(int index, Object? args) {
    setState(() {
      _index = index;
      _lastJumpArgs = args;
    });
  }

  Future<bool> _onWillPop(List<_TabSpec> tabs) async {
    // Android/Browser back：先回首頁 tab
    if (_index != 0 && tabs.isNotEmpty) {
      _jumpTo(0, null);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection(_cfgCol).doc(_cfgDoc);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final tabIds = _parseFooterTabs(data?['footerTabs']);

        final tabs = _buildTabsByIds(tabIds);
        final routes = _buildRouteToIndex(tabs);

        // 若後台改了 footerTabs 導致 index 越界，安全修正
        if (tabs.isNotEmpty && _index >= tabs.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index = 0);
          });
        }

        final safeIndex = (tabs.isEmpty) ? 0 : _index.clamp(0, tabs.length - 1);

        return MainNavScope(
          currentIndex: safeIndex,
          onJump: _jumpTo,
          routeToIndex: routes,
          child: WillPopScope(
            onWillPop: () => _onWillPop(tabs),
            child: Scaffold(
              body: tabs.isEmpty
                  ? const _EmptyTabsFallback()
                  : IndexedStack(
                      index: safeIndex,
                      children: tabs
                          .map(
                            (t) => KeyedSubtree(
                              key: ValueKey(t.id),
                              child: t.buildPage(_lastJumpArgs),
                            ),
                          )
                          .toList(),
                    ),
              bottomNavigationBar: tabs.isEmpty
                  ? null
                  : NavigationBar(
                      selectedIndex: safeIndex,
                      onDestinationSelected: (i) => _jumpTo(i, null),
                      destinations: tabs
                          .map(
                            (t) => NavigationDestination(
                              icon: Icon(t.icon),
                              label: t.label,
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
        );
      },
    );
  }

  // =========================
  // 後台 footerTabs 解析
  // =========================
  List<String> _parseFooterTabs(dynamic raw) {
    // ✅ 預設（互動先不要 → 預設不含 interact）
    const fallback = ['home', 'shop', 'storeapp', 'task', 'mine'];

    if (raw is! List) return fallback;

    final out = <String>[];
    for (final e in raw) {
      final s = e.toString().trim().toLowerCase();
      if (s.isEmpty) continue;
      out.add(_normalizeTabId(s));
    }

    // 去重 + 過濾支援 id
    final seen = <String>{};
    final filtered = <String>[];
    for (final id in out) {
      if (!_supportedTabIds.contains(id)) continue;
      if (seen.add(id)) filtered.add(id);
    }

    if (filtered.isEmpty) return fallback;

    // ✅ 一定要有 home 且放第一個
    filtered.remove('home');
    filtered.insert(0, 'home');

    // ✅ NavigationBar 建議最多 5 個，超過就截斷（避免 UI 擠爆）
    if (filtered.length > 5) {
      return filtered.take(5).toList();
    }
    return filtered;
  }

  String _normalizeTabId(String raw) {
    switch (raw) {
      case 'homepage':
      case 'index':
      case 'home':
        return 'home';
      case 'shop':
      case 'store':
      case 'storeapp':
      case 'products':
        return 'shop';
      case 'task':
      case 'tasks':
        return 'task';
      case 'interact':
      case 'interaction':
        return 'interact';
      case 'me':
      case 'mine':
      case 'member':
      case 'profile':
      case 'support': // 你 HomePage 也會用 /support
        return 'mine';
      default:
        return raw;
    }
  }

  static const Set<String> _supportedTabIds = {
    'home',
    'shop',
    'task',
    'interact',
    'mine',
    'storeapp',
  };

  // =========================
  // Tab Spec（id → label/icon/page/routes）
  // =========================
  List<_TabSpec> _buildTabsByIds(List<String> ids) {
    final specs = <_TabSpec>[];

    for (final id in ids) {
      switch (id) {
        case 'home':
          specs.add(
            _TabSpec(
              id: 'home',
              label: '首頁',
              icon: Icons.home_outlined,
              routes: const ['/home', '/'],
              pageBuilder: (_) => const HomePage(),
            ),
          );
          break;

        case 'shop':
          specs.add(
            _TabSpec(
              id: 'shop',
              label: '商店',
              icon: Icons.storefront_outlined,
              routes: const ['/shop', '/products', '/store'],
              pageBuilder: (_) => const ProductsPage(),
            ),
          );
          break;

        case 'task':
          specs.add(
            _TabSpec(
              id: 'task',
              label: '任務',
              icon: Icons.task_alt_outlined,
              routes: const ['/task', '/tasks'],
              pageBuilder: (_) => const TasksPage(),
            ),
          );
          break;

        case 'interact':
          specs.add(
            _TabSpec(
              id: 'interact',
              label: '互動',
              icon: Icons.forum_outlined,
              routes: const ['/interact', '/interaction'],
              pageBuilder: (args) =>
                  _DisabledTabPlaceholder(title: '互動（暫不啟用）', args: args),
            ),
          );
          break;

        case 'mine':
          specs.add(
            _TabSpec(
              id: 'mine',
              label: '會員',
              icon: Icons.person_outline,
              routes: const ['/me', '/mine', '/member', '/support'],
              pageBuilder: (_) => const MemberPage(),
            ),
          );
          break;

        case 'storeapp':
          specs.add(
            _TabSpec(
              id: 'storeapp',
              label: '抽獎',
              icon: Icons.card_giftcard_outlined,
              routes: const ['/storeapp', '/lottery-shop'],
              pageBuilder: (_) => const store_home.HomePage(),
            ),
          );
          break;
      }
    }

    return specs;
  }

  Map<String, int> _buildRouteToIndex(List<_TabSpec> tabs) {
    final map = <String, int>{};
    for (var i = 0; i < tabs.length; i++) {
      for (final r in tabs[i].routes) {
        map[r] = i;
      }
    }
    return map;
  }
}

class _TabSpec {
  final String id;
  final String label;
  final IconData icon;
  final List<String> routes;
  final Widget Function(Object? args) pageBuilder;

  const _TabSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.routes,
    required this.pageBuilder,
  });

  Widget buildPage(Object? args) => pageBuilder(args);
}

class _EmptyTabsFallback extends StatelessWidget {
  const _EmptyTabsFallback();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('底部導覽設定為空（請到 app_config/home_layout 設定 footerTabs）'),
      ),
    );
  }
}

class _DisabledTabPlaceholder extends StatelessWidget {
  final String title;
  final Object? args;

  const _DisabledTabPlaceholder({required this.title, this.args});

  @override
  Widget build(BuildContext context) {
    final argText = args == null ? '' : '\n\nargs: $args';
    return Scaffold(
      appBar: AppBar(title: const Text('Tab')),
      body: Center(child: Text('$title$argText', textAlign: TextAlign.center)),
    );
  }
}

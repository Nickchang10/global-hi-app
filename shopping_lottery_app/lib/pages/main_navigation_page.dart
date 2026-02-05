import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'main_nav_scope.dart';

/// ✅ MainNavigationPage：全 app 唯一渲染 bottomNavigationBar 的地方
/// ✅ bottom nav 設定由 Firestore 控制：app_config/bottom_nav
class MainNavigationPage extends StatefulWidget {
  /// 你可以用 route 進來指定預設 tab（例如 /shop）
  final String? initialTabRoute;

  const MainNavigationPage({super.key, this.initialTabRoute});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  final _docRef =
      FirebaseFirestore.instance.collection('app_config').doc('bottom_nav');

  int _index = 0;

  StreamSubscription? _sub;
  List<_NavCfgItem> _lastNav = const [];

  @override
  void initState() {
    super.initState();

    _sub = _docRef.snapshots().listen((snap) {
      final cfg = snap.data();
      final nav = _parseNav(cfg);

      if (nav.isEmpty) return;

      // 若目前 index 超出範圍，回到 0
      if (_index >= nav.length) {
        if (!mounted) return;
        setState(() => _index = 0);
      }

      _lastNav = nav;

      // 初次進來：如果有指定 initialTabRoute，就切過去
      final initRoute = widget.initialTabRoute;
      if (initRoute != null && initRoute.trim().isNotEmpty) {
        final normalized = _normRoute(initRoute);
        final idx = nav.indexWhere((e) => _normRoute(e.route ?? '') == normalized);
        if (idx >= 0 && idx != _index) {
          if (!mounted) return;
          setState(() => _index = idx);
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // -----------------------
  // route normalize（避免後台寫 /lottery 但前台 tab 是 /lotterys）
  // -----------------------
  String _normRoute(String raw) {
    final r = raw.trim();
    if (r.isEmpty || r == '/' || r == '/home') return '/home';
    if (r == '/lottery') return '/lotterys';
    if (r == '/interaction') return '/interact';
    return r;
  }

  // -----------------------
  // Firestore nav parsing
  // -----------------------
  List<_NavCfgItem> _parseNav(Map<String, dynamic>? cfg) {
    final fallback = _fallbackNav();

    if (cfg == null) return fallback;

    final enabled = (cfg['enabled'] as bool?) ?? true;
    if (!enabled) return const [];

    final raw = cfg['items'];
    if (raw is! List) return fallback;

    final items = <_NavCfgItem>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);

      final isEnabled = (m['enabled'] as bool?) ?? true;
      if (!isEnabled) continue;

      final label = (m['label'] ?? '').toString().trim();
      final route = (m['route'] ?? '').toString().trim();
      final iconKey = (m['iconKey'] ?? 'home').toString().trim();
      final order = (m['order'] as int?) ?? 999;

      if (label.isEmpty) continue;

      items.add(_NavCfgItem(
        label: label,
        route: route.isEmpty ? null : _normRoute(route),
        icon: _iconFromKey(iconKey),
        order: order,
      ));
    }

    items.sort((a, b) => a.order.compareTo(b.order));
    if (items.length < 2) return fallback;

    return items;
  }

  List<_NavCfgItem> _fallbackNav() => const [
        _NavCfgItem(label: '首頁', route: '/home', icon: Icons.home_outlined, order: 0),
        _NavCfgItem(label: '商城', route: '/shop', icon: Icons.store_outlined, order: 1),
        _NavCfgItem(label: '支援', route: '/support', icon: Icons.support_agent_outlined, order: 2),
        _NavCfgItem(label: '我的', route: '/me', icon: Icons.person_outline, order: 3),
      ];

  // -----------------------
  // Tab pages mapping
  // -----------------------
  Widget _buildTabBody(String? route) {
    switch (_normRoute(route ?? '')) {
      case '/home':
        return const HomePage();

      case '/shop':
        return const ShopTabPage();

      case '/support':
        return const SupportTabPage();

      case '/me':
        return const MeTabPage();

      // 若你的後台也可能放這個 tab
      case '/lotterys':
        return const LotteryTabPage();

      case '/tasks':
        return const TasksTabPage();

      case '/interact':
        return const InteractTabPage();

      default:
        return _RoutePlaceholder(title: '未對應頁面', route: route);
    }
  }

  bool _jumpToTab(String route, {Object? args}) {
    final nav = _lastNav;
    if (nav.isEmpty) return false;

    final normalized = _normRoute(route);
    final idx = nav.indexWhere((e) => _normRoute(e.route ?? '') == normalized);
    if (idx < 0) return false;

    if (!mounted) return true;
    setState(() => _index = idx);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _docRef.snapshots(),
      builder: (context, snap) {
        final cfg = snap.data?.data();
        final nav = _parseNav(cfg);

        // 後台關閉底導：直接顯示首頁
        if (nav.isEmpty) {
          return const HomePage();
        }

        final safeIndex = _index.clamp(0, nav.length - 1);

        // 同步 index
        if (safeIndex != _index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index = safeIndex);
          });
        }

        final currentRoute = nav[safeIndex].route ?? '/home';

        return MainNavScope(
          currentRoute: currentRoute,
          jumpTo: _jumpToTab,
          child: Scaffold(
            body: IndexedStack(
              index: safeIndex,
              children: nav.map((e) => _buildTabBody(e.route)).toList(),
            ),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: safeIndex,
              onTap: (i) => setState(() => _index = i),
              items: nav
                  .map(
                    (e) => BottomNavigationBarItem(
                      icon: Icon(e.icon),
                      label: e.label,
                    ),
                  )
                  .toList(),
            ),

            // 你目前畫面上那個 debug banner（如果你不要，可以把這段整段刪掉）
            floatingActionButton: kDebugMode
                ? _BottomNavDebugBadge(
                    navCount: nav.length,
                    index: safeIndex,
                    cfgKeys: (cfg ?? {}).keys.toList(),
                    docPath: 'app_config/bottom_nav',
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _NavCfgItem {
  final String label;
  final String? route;
  final IconData icon;
  final int order;

  const _NavCfgItem({
    required this.label,
    required this.route,
    required this.icon,
    required this.order,
  });
}

IconData _iconFromKey(String key) {
  switch (key) {
    case 'home':
      return Icons.home_outlined;
    case 'store':
      return Icons.store_outlined;
    case 'shopping_cart':
      return Icons.shopping_cart_outlined;
    case 'shopping_bag':
      return Icons.shopping_bag_outlined;
    case 'task':
      return Icons.emoji_events_outlined;
    case 'group':
      return Icons.group_outlined;
    case 'forum':
      return Icons.forum_outlined;
    case 'person':
      return Icons.person_outline;
    case 'notifications':
      return Icons.notifications_outlined;
    case 'support':
      return Icons.support_agent_outlined;
    case 'settings':
      return Icons.settings_outlined;
    default:
      return Icons.circle_outlined;
  }
}

class _RoutePlaceholder extends StatelessWidget {
  final String title;
  final String? route;

  const _RoutePlaceholder({required this.title, required this.route});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '此 route 尚未對應到實際頁面：\n${route ?? '(null)'}\n\n'
            '請在 MainNavigationPage._buildTabBody() 補上對應頁面。',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// =====================================================
// ✅ ShopTabPage（商城頁）
// ✅ 重點：ChoiceChip(showCheckmark:false) 拿掉 ✓
// =====================================================

class ShopTabPage extends StatefulWidget {
  const ShopTabPage({super.key});

  @override
  State<ShopTabPage> createState() => _ShopTabPageState();
}

class _ShopTabPageState extends State<ShopTabPage> {
  String _query = '';
  String? _categoryId; // null = 全部

  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _baseProductsQuery() {
    var q = FirebaseFirestore.instance.collection('products') as Query<Map<String, dynamic>>;

    // 你若有上架狀態，可以自行加：q = q.where('enabled', isEqualTo: true);

    if (_categoryId != null && _categoryId!.trim().isNotEmpty) {
      // 你的欄位如果不是 categoryId，請改成你實際的欄位
      q = q.where('categoryId', isEqualTo: _categoryId);
    }

    // 先用 updatedAt 排序（沒有也不會 crash，只是可能要移除）
    // 若你 DB 沒有 updatedAt，請把下面 orderBy 移掉
    q = q.orderBy('updatedAt', descending: true);

    return q.limit(200);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyClientSearch(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final kw = _query.trim().toLowerCase();
    if (kw.isEmpty) return docs;

    bool hit(Map<String, dynamic> m) {
      final name = (m['name'] ?? '').toString().toLowerCase();
      final desc = (m['desc'] ?? m['description'] ?? '').toString().toLowerCase();
      final tag = (m['categoryKey'] ?? m['categoryName'] ?? '').toString().toLowerCase();
      return name.contains(kw) || desc.contains(kw) || tag.contains(kw);
    }

    return docs.where((d) => hit(d.data())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final catsRef = FirebaseFirestore.instance.collection('categories');

    return Scaffold(
      appBar: AppBar(
        title: const Text('商城'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜尋
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: '搜尋商品…',
                isDense: true,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),

          // 分類 chips
          SizedBox(
            height: 46,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: catsRef.orderBy('order', descending: false).snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? const [];

                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('全部'),
                        selected: _categoryId == null,
                        showCheckmark: false, // ✅✅✅ 拿掉勾勾
                        onSelected: (_) => setState(() => _categoryId = null),
                      ),
                    ),
                    ...docs.map((d) {
                      final m = d.data();
                      final label = (m['name'] ?? m['label'] ?? d.id).toString();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _categoryId == d.id,
                          showCheckmark: false, // ✅✅✅ 拿掉勾勾
                          onSelected: (_) => setState(() => _categoryId = d.id),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // 商品列表
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseProductsQuery().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('讀取商品失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rawDocs = snap.data!.docs;
                final docs = _applyClientSearch(rawDocs);

                if (docs.isEmpty) {
                  return const Center(child: Text('沒有符合的商品'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final m = d.data();

                    final name = (m['name'] ?? '').toString();
                    final priceRaw = m['price'];
                    final price = (priceRaw is num) ? priceRaw : num.tryParse(priceRaw.toString()) ?? 0;

                    // 你資料可能是 images:[] 或 imageUrl 或 image
                    String img = '';
                    final images = m['images'];
                    if (images is List && images.isNotEmpty) {
                      img = (images.first ?? '').toString();
                    } else {
                      img = (m['imageUrl'] ?? m['image'] ?? '').toString();
                    }

                    final tag = (m['categoryKey'] ?? m['categoryName'] ?? '').toString();

                    return InkWell(
                      onTap: () {
                        // 你若有商品詳情頁可改成 pushNamed
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('點擊：$name')),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: _ShopNetImage(url: img),
                                    ),
                                    if (tag.trim().isNotEmpty)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.55),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            tag,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                              child: Text(
                                'NT\$${price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopNetImage extends StatelessWidget {
  final String url;

  const _ShopNetImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final u = url.trim();
    if (u.isEmpty) {
      return Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: Colors.black38),
      );
    }

    return Image.network(
      u,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.black12,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

// =====================================================
// 其他 tabs（你可用你自己的頁面取代）
// =====================================================

class SupportTabPage extends StatelessWidget {
  const SupportTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('支援（請換成你的 SupportPage）')),
    );
  }
}

class MeTabPage extends StatelessWidget {
  const MeTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('我的（請換成你的 MePage）')),
    );
  }
}

class LotteryTabPage extends StatelessWidget {
  const LotteryTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('抽獎（請換成你的 LotteryPage）')),
    );
  }
}

class TasksTabPage extends StatelessWidget {
  const TasksTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('任務（請換成你的 TasksPage）')),
    );
  }
}

class InteractTabPage extends StatelessWidget {
  const InteractTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('互動（請換成你的 InteractPage）')),
    );
  }
}

// =====================================================
// Debug Badge（你不想要就整段刪掉）
// =====================================================

class _BottomNavDebugBadge extends StatelessWidget {
  final int navCount;
  final int index;
  final List<String> cfgKeys;
  final String docPath;

  const _BottomNavDebugBadge({
    required this.navCount,
    required this.index,
    required this.cfgKeys,
    required this.docPath,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.70),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'BottomNav: REMOTE (Firestore) | items=$navCount | index=$index\n'
          'doc=$docPath | cfg.keys=$cfgKeys',
          style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.2),
        ),
      ),
    );
  }
}

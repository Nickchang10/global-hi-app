// lib/pages/home_page.dart
// =====================================================
// ✅ HomePage（首頁最終整合完整版｜可編譯｜Firestore 後台控制版）
// -----------------------------------------------------
// ✅ 修正重點：HomePage 不再放 bottomNavigationBar
// ✅ 重要：當 HomePage 要導到 /shop /me /lotterys… 這些「底導 tab」時
//         會優先透過 MainNavScope「切換 tab」，而不是 push 新頁
// ✅ 抽獎 route 統一：/lotterys（與後台底導一致）
// =====================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ✅ 新增：讓 HomePage 可以切換底部導覽 tab（真正串接）
import 'main_nav_scope.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _brand = Colors.blueAccent;

  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  Timer? _timer;
  Duration _taskCountdown = const Duration(hours: 1, minutes: 33, seconds: 3);

  // =========================
  // Mock data（模板｜Firestore 無資料時 fallback）
  // =========================

  final List<Map<String, dynamic>> _bannersFallback = [
    {
      'title': 'Osmile S5 健康錶 限時特惠',
      'subtitle': 'SOS 一鍵求助 / 24 小時心率血氧監測',
      'image':
          'https://images.unsplash.com/photo-1526401485004-2aa7f3b7b990?auto=format&fit=crop&w=1200&q=80',
      'primaryText': '立即購買',
      'secondaryText': '今日抽獎',
      'primaryRoute': '/shop',
      // ✅ 修正：與後台底導一致（後台是 /lotterys）
      'secondaryRoute': '/lotterys',
    },
    {
      'title': '雙 12 促銷活動',
      'subtitle': '指定商品滿額贈抽獎機會',
      'image':
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80',
      'primaryText': '去看看',
      'secondaryText': '領券',
      'primaryRoute': '/shop',
      'secondaryRoute': '/coupons',
    },
  ];

  /// ✅ 修正：限時活動點開導到 /activity_detail（不再誤開通知中心）
  final List<Map<String, dynamic>> _pushItems = [
    {
      'title': '限時活動',
      'message': '今晚 9 點抽獎加碼一次！',
      'time': DateTime.now().subtract(const Duration(minutes: 12)),
      'unread': true,
      'route': '/activity_detail',
      'args': {
        'title': '限時活動',
        'subtitle': '今晚 9 點抽獎加碼一次！',
        'content': '活動期間完成簽到 / 抽獎任務即可獲得加碼抽獎機會（示範內容）。',
      },
    },
    {
      'title': '任務提醒',
      'message': '完成簽到即可獲得 +50 積分',
      'time': DateTime.now().subtract(const Duration(hours: 3)),
      'unread': false,
      'route': '/notifications',
    },
  ];

  final List<Map<String, dynamic>> _promos = [
    {
      'name': 'Osmile S5 健康錶',
      'price': 3990,
      'tag': '限時特價',
      'image':
          'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=800&q=80',
    },
    {
      'name': 'Osmile 充電座',
      'price': 490,
      'tag': '熱賣配件',
      'image':
          'https://images.unsplash.com/photo-1580915411954-282cb1c96f32?auto=format&fit=crop&w=800&q=80',
    },
  ];

  final List<Map<String, dynamic>> _videos = [
    {
      'title': '如何使用 Osmile S5 監測血氧',
      'duration': '02:10',
      'thumb':
          'https://images.unsplash.com/photo-1519824145371-296894a0daa9?auto=format&fit=crop&w=900&q=80',
    },
    {
      'title': '每日三分鐘伸展，提升循環',
      'duration': '03:05',
      'thumb':
          'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=900&q=80',
    },
  ];

  final List<Map<String, dynamic>> _healthMetrics = [
    {
      'key': 'steps',
      'label': '步數',
      'value': '4,820',
      'unit': '步',
      'icon': Icons.directions_walk,
    },
    {
      'key': 'sleep',
      'label': '睡眠',
      'value': '7.1',
      'unit': '小時',
      'icon': Icons.bedtime_outlined,
    },
    {
      'key': 'hr',
      'label': '心率',
      'value': '76',
      'unit': 'bpm',
      'icon': Icons.favorite_border,
    },
    {
      'key': 'bp',
      'label': '血壓',
      'value': '118/76',
      'unit': '',
      'icon': Icons.monitor_heart_outlined,
    },
  ];

  final List<Map<String, dynamic>> _healthArticles = [
    {
      'title': '冬季如何預防感冒',
      'desc': '保持睡眠與補充水分，勤洗手，補充維他命 C。',
      'image':
          'https://images.unsplash.com/photo-1473773508845-188df298d2d1?auto=format&fit=crop&w=400&q=80',
    },
    {
      'title': '長者健康：每天走路三十分鐘的好處',
      'desc': '促進血液循環，維持心肺功能。',
      'image':
          'https://images.unsplash.com/photo-1520975958225-7d63de373ca7?auto=format&fit=crop&w=400&q=80',
    },
  ];

  final List<Map<String, dynamic>> _featuredHot = [
    {
      'name': 'Osmile S5 健康錶',
      'price': 3990,
      'badge': '精選',
      'image':
          'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=900&q=80',
    },
    {
      'name': 'Osmile 充電座',
      'price': 490,
      'badge': '熱門',
      'image':
          'https://images.unsplash.com/photo-1580915411954-282cb1c96f32?auto=format&fit=crop&w=900&q=80',
    },
    {
      'name': '推薦商品 1',
      'price': 999,
      'badge': '熱門',
      'image':
          'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?auto=format&fit=crop&w=900&q=80',
    },
  ];

  // =========================
  // lifecycle
  // =========================
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_taskCountdown.inSeconds > 0) {
          _taskCountdown -= const Duration(seconds: 1);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // =========================
  // helpers
  // =========================
  String _fmtMoney(num v) => _moneyFmt.format(v);

  String _fmtCountdown(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  bool get _hasUnreadPush => _pushItems.any((e) => e['unread'] == true);

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ✅ 更完整的 route normalize：補 /、去尾斜線、alias
  String _normRoute(String raw) {
    var r = raw.trim();
    if (r.isEmpty || r == '/' || r == '/home') return '/home';

    // 支援後台可能寫成 "shop" / "me"
    if (!r.startsWith('/')) r = '/$r';

    // 去尾斜線
    while (r.endsWith('/') && r.length > 1) {
      r = r.substring(0, r.length - 1);
    }

    r = r.toLowerCase();

    // alias
    if (r == '/lottery') r = '/lotterys';
    if (r == '/interaction') r = '/interact';

    return r;
  }

  // ✅ 關鍵修正：先嘗試切換 tab（MainNavScope），切不到才 pushNamed
  void _safeNav(String routeName, {Object? args, bool replace = false}) {
    final r = _normRoute(routeName);

    // 1) 若在 MainNavigationPage 範圍內，優先「切 tab」
    final scope = MainNavScope.maybeOf(context);
    if (scope != null) {
      final jumped = scope.jumpTo(r, args: args);
      if (jumped) return;
    }

    // 2) 切不到 tab 才走 Navigator（例如 /coupons /notifications /lottery/draw…）
    try {
      if (replace) {
        Navigator.of(context).pushReplacementNamed(r, arguments: args);
      } else {
        Navigator.of(context).pushNamed(r, arguments: args);
      }
    } catch (_) {
      _toast('尚未設定路由：$r');
    }
  }

  void _openPush(Map<String, dynamic>? push) {
    if (push == null) return;
    final route = (push['route'] ?? '/notifications').toString();
    final args = push['args'];
    _safeNav(route, args: args);
  }

  // =========================
  // Firestore config parsing
  // =========================
  static const _configPathCollection = 'app_config';
  static const _configPathDoc = 'home_layout';

  List<_ModuleCfg> _defaultModules() => const [
    _ModuleCfg(id: 'push', label: '活動推播', enabled: true),
    _ModuleCfg(id: 'task', label: '任務卡', enabled: true),
    _ModuleCfg(id: 'flash_sale', label: '限時促銷', enabled: true),
    _ModuleCfg(id: 'videos', label: '健康影片', enabled: true),
    _ModuleCfg(id: 'health', label: '健康資訊', enabled: true),
    _ModuleCfg(id: 'articles', label: '健康文章', enabled: true),
    _ModuleCfg(id: 'featured', label: '精選熱門', enabled: true),
  ];

  List<String> _defaultFooterTabs() => const [
    'home',
    'shop',
    'task',
    'interact',
    'mine',
  ];

  String _normalizeModuleId(String raw) {
    final id = raw.trim().toLowerCase();
    switch (id) {
      case 'campaigns':
      case 'campaign':
      case 'activity':
      case 'activities':
      case 'push':
      case 'notification':
      case 'notifications':
        return 'push';
      case 'task':
      case 'tasks':
        return 'task';
      case 'flashsale':
      case 'flash_sale':
      case 'promo':
      case 'promos':
      case 'promotion':
      case 'promotions':
        return 'flash_sale';
      case 'video':
      case 'videos':
      case 'health_videos':
        return 'videos';
      case 'health':
      case 'health_info':
      case 'metrics':
        return 'health';
      case 'article':
      case 'articles':
      case 'health_articles':
        return 'articles';
      case 'featured':
      case 'featured_hot':
      case 'hot':
      case 'recommend':
      case 'recommends':
        return 'featured';
      case 'banner':
      case 'banners':
        return 'banner';
      default:
        return id;
    }
  }

  List<_ModuleCfg> _parseModules(dynamic raw) {
    if (raw is! List) return _defaultModules();

    final list = <_ModuleCfg>[];
    for (final e in raw) {
      if (e is Map) {
        final idRaw = (e['id'] ?? '').toString();
        final id = _normalizeModuleId(idRaw);
        final label = (e['label'] ?? id).toString();
        final enabled = (e['enabled'] is bool) ? e['enabled'] as bool : true;
        if (_supportedModuleIds.contains(id)) {
          list.add(_ModuleCfg(id: id, label: label, enabled: enabled));
        }
      } else if (e is String) {
        final id = _normalizeModuleId(e);
        if (_supportedModuleIds.contains(id)) {
          list.add(_ModuleCfg(id: id, label: id, enabled: true));
        }
      }
    }
    return list.isEmpty ? _defaultModules() : list;
  }

  List<String> _parseFooterTabs(dynamic raw) {
    if (raw is! List) return _defaultFooterTabs();
    final tabs = raw
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    if (tabs.isEmpty) return _defaultFooterTabs();
    if (!tabs.contains('home')) tabs.insert(0, 'home');
    return tabs;
  }

  List<Map<String, dynamic>> _parseBanners(dynamic raw) {
    if (raw is! List) return _bannersFallback;

    final out = <Map<String, dynamic>>[];

    if (raw.isNotEmpty && raw.first is String) {
      final urls = raw
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (urls.isEmpty) return _bannersFallback;

      for (var i = 0; i < urls.length; i++) {
        final base = (i < _bannersFallback.length)
            ? Map<String, dynamic>.from(_bannersFallback[i])
            : <String, dynamic>{};
        base['image'] = urls[i];
        base['title'] ??= 'Osmile 推薦';
        base['subtitle'] ??= '後台可控制橫幅內容';
        base['primaryText'] ??= '立即購買';
        base['secondaryText'] ??= '今日抽獎';
        base['primaryRoute'] ??= '/shop';
        base['secondaryRoute'] ??= '/lotterys'; // ✅ 統一
        out.add(base);
      }
      return out;
    }

    for (final e in raw) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final img = (m['image'] ?? '').toString().trim();
        if (img.isEmpty) continue;
        m['title'] ??= 'Osmile 推薦';
        m['subtitle'] ??= '';
        m['primaryText'] ??= '立即購買';
        m['secondaryText'] ??= '今日抽獎';
        m['primaryRoute'] ??= '/shop';
        m['secondaryRoute'] ??= '/lotterys'; // ✅ 統一
        out.add(m);
      }
    }

    return out.isEmpty ? _bannersFallback : out;
  }

  static const Set<String> _supportedModuleIds = {
    'banner',
    'push',
    'task',
    'flash_sale',
    'videos',
    'health',
    'articles',
    'featured',
  };

  // =========================
  // UI builders per module
  // =========================
  List<Widget> _buildSections({
    required List<_ModuleCfg> modules,
    required List<Map<String, dynamic>> banners,
  }) {
    final topPush = _pushItems.isEmpty ? null : _pushItems.first;

    final builders = <String, List<Widget> Function()>{
      'banner': () => [
        _BannerCarousel(
          banners: banners,
          onPrimary: () {
            final b0 = banners.isNotEmpty ? banners.first : null;
            final route = (b0?['primaryRoute'] ?? '/shop').toString();
            _safeNav(route);
          },
          onSecondary: () {
            final b0 = banners.isNotEmpty ? banners.first : null;
            final route = (b0?['secondaryRoute'] ?? '/lotterys').toString();
            _safeNav(route);
          },
        ),
        const SizedBox(height: 12),
      ],
      'push': () => [
        _SectionHeader(
          title: '活動推播',
          actionText: '查看全部',
          onAction: () => _safeNav('/notifications'),
        ),
        _PushPreviewCard(items: _pushItems, onTap: () => _openPush(topPush)),
        const SizedBox(height: 12),
      ],
      'task': () => [
        _TaskCard(
          countdownText: _fmtCountdown(_taskCountdown),
          onGo: () => _safeNav('/tasks'),
        ),
        const SizedBox(height: 12),
      ],
      'flash_sale': () => [
        _SectionHeader(
          title: '限時促銷',
          actionText: '查看更多',
          onAction: () => _safeNav('/shop'),
        ),
        const SizedBox(height: 8),
        _HorizontalCards(
          itemCount: _promos.length,
          itemBuilder: (i) => _ProductMiniCard(
            name: (_promos[i]['name'] ?? '').toString(),
            price: _promos[i]['price'],
            tag: (_promos[i]['tag'] ?? '').toString(),
            imageUrl: (_promos[i]['image'] ?? '').toString(),
            onTap: () =>
                _toast('促銷商品：${(_promos[i]['name'] ?? '').toString()}（模板）'),
          ),
        ),
        const SizedBox(height: 14),
      ],
      'videos': () => [
        _SectionHeader(
          title: '健康影片',
          actionText: '查看更多',
          onAction: () => _safeNav('/health/videos'),
        ),
        const SizedBox(height: 8),
        _HorizontalCards(
          itemCount: _videos.length,
          itemBuilder: (i) => _VideoCard(
            title: (_videos[i]['title'] ?? '').toString(),
            duration: (_videos[i]['duration'] ?? '').toString(),
            thumbUrl: (_videos[i]['thumb'] ?? '').toString(),
            onTap: () =>
                _toast('播放影片（模板）：${(_videos[i]['title'] ?? '').toString()}'),
          ),
        ),
        const SizedBox(height: 14),
      ],
      'health': () => [
        _SectionHeader(
          title: '健康資訊（Osmile）',
          actionText: '進入健康',
          onAction: () => _safeNav('/health'),
        ),
        const SizedBox(height: 8),
        _HealthSummaryCard(
          metrics: _healthMetrics,
          onMetricTap: (_) => _safeNav('/health'),
          onQuickAction: (action) {
            switch (action) {
              case 'health':
                _safeNav('/health');
                break;
              case 'support':
                _safeNav('/support'); // ✅ 真切 tab
                break;
              case 'map':
                _safeNav('/tracking');
                break;
              case 'sos':
                _toast('SOS（模板）：可在此呼叫 SOSService.triggerSOS()');
                break;
              default:
                _toast('快捷：$action');
            }
          },
        ),
        const SizedBox(height: 10),
      ],
      'articles': () => [
        _HealthArticlesList(
          items: _healthArticles,
          onTap: () => _safeNav('/health/articles'),
        ),
        const SizedBox(height: 14),
      ],
      'featured': () => [
        _SectionHeader(
          title: '精選 & 熱門推薦',
          actionText: '查看更多',
          onAction: () => _safeNav('/shop'),
        ),
        const SizedBox(height: 8),
        _FeaturedGrid(
          items: _featuredHot,
          fmtMoney: _fmtMoney,
          onTapItem: (m) => _toast('推薦商品（模板）：${(m['name'] ?? '').toString()}'),
        ),
        const SizedBox(height: 10),
      ],
    };

    final widgets = <Widget>[...builders['banner']!.call()];

    for (final mod in modules) {
      if (!mod.enabled) continue;
      if (mod.id == 'banner') continue;
      final fn = builders[mod.id];
      if (fn != null) widgets.addAll(fn.call());
    }

    return widgets;
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection(_configPathCollection)
        .doc(_configPathDoc);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        Map<String, dynamic>? cfg;
        if (snap.hasData && snap.data?.data() != null) {
          cfg = snap.data!.data();
        }

        final modules = _parseModules(cfg?['modules']);
        final banners = _parseBanners(cfg?['banners']);

        // footerTabs 仍解析（你可用於分析/紀錄），但 HomePage 不渲染底導
        _parseFooterTabs(cfg?['footerTabs']);

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.6,
            centerTitle: true,
            title: const Text(
              'Osmile 商城',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: IconButton(
                  tooltip: '通知',
                  onPressed: () => _safeNav('/notifications'),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none_rounded),
                      if (_hasUnreadPush)
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.3,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ✅✅✅ 關鍵修正：HomePage 不再放 bottomNavigationBar
          body: RefreshIndicator(
            onRefresh: () async {
              try {
                await docRef.get(
                  const GetOptions(source: Source.serverAndCache),
                );
                if (!mounted) return;
                _toast('已更新首頁（後台設定已同步）');
              } catch (_) {
                if (!mounted) return;
                _toast('更新失敗（請確認 Firebase 初始化 / 權限）');
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              children: [
                if (snap.hasError)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      '讀取後台設定失敗：${snap.error}\n將以模板模式顯示。',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  )
                else if (!snap.hasData)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: const Text(
                      '載入中：正在同步後台版面設定…',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ..._buildSections(modules: modules, banners: banners),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModuleCfg {
  final String id;
  final String label;
  final bool enabled;

  const _ModuleCfg({
    required this.id,
    required this.label,
    required this.enabled,
  });
}

// =====================================================
// Widgets（沿用你原本 UI，不改）
// =====================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionText)),
      ],
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _BannerCarousel({
    required this.banners,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  int _idx = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (v) => setState(() => _idx = v),
            itemBuilder: (_, i) {
              final b = banners[i];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _NetImage(
                        url: (b['image'] ?? '').toString(),
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.black.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (b['title'] ?? '').toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (b['subtitle'] ?? '').toString(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: widget.onPrimary,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orangeAccent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: Text(
                                    (b['primaryText'] ?? '立即購買').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: widget.onSecondary,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: Text(
                                    (b['secondaryText'] ?? '今日抽獎').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _idx ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _idx ? Colors.black87 : Colors.black26,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PushPreviewCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback onTap;

  const _PushPreviewCard({required this.items, required this.onTap});

  String _fmtTime(DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inHours < 1) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours < 24) return '${diff.inHours} 小時前';
    return '${t.month}/${t.day}';
  }

  @override
  Widget build(BuildContext context) {
    final top = items.isEmpty ? null : items.first;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.campaign_outlined,
                color: Colors.orangeAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: top == null
                  ? Text(
                      '目前沒有推播',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (top['title'] ?? '活動').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _fmtTime(
                                top['time'] is DateTime
                                    ? top['time'] as DateTime
                                    : null,
                              ),
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (top['message'] ?? '').toString(),
                          style: TextStyle(color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String countdownText;
  final VoidCallback onGo;

  const _TaskCard({required this.countdownText, required this.onGo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _HomePageState._brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.flag_outlined,
              color: _HomePageState._brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '每日任務：完成簽到 / 抽獎可得 +50 積分',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '剩餘 $countdownText',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onGo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text(
              '去完成',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalCards extends StatelessWidget {
  final int itemCount;
  final Widget Function(int index) itemBuilder;

  const _HorizontalCards({required this.itemCount, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => itemBuilder(i),
      ),
    );
  }
}

class _ProductMiniCard extends StatelessWidget {
  final String name;
  final dynamic price;
  final String tag;
  final String imageUrl;
  final VoidCallback onTap;

  const _ProductMiniCard({
    required this.name,
    required this.price,
    required this.tag,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final p = (price is num)
        ? price as num
        : num.tryParse(price.toString()) ?? 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _NetImage(url: imageUrl, fit: BoxFit.cover),
                    ),
                    if (tag.trim().isNotEmpty)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              moneyFmt.format(p),
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final String title;
  final String duration;
  final String thumbUrl;
  final VoidCallback onTap;

  const _VideoCard({
    required this.title,
    required this.duration,
    required this.thumbUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: _NetImage(url: thumbUrl, fit: BoxFit.cover),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthSummaryCard extends StatelessWidget {
  final List<Map<String, dynamic>> metrics;
  final void Function(String key) onMetricTap;
  final void Function(String action) onQuickAction;

  const _HealthSummaryCard({
    required this.metrics,
    required this.onMetricTap,
    required this.onQuickAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: metrics.map((m) {
              final key = (m['key'] ?? '').toString();
              final label = (m['label'] ?? '').toString();
              final value = (m['value'] ?? '').toString();
              final unit = (m['unit'] ?? '').toString();
              final icon = m['icon'] is IconData
                  ? m['icon'] as IconData
                  : Icons.insights_outlined;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => onMetricTap(key),
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _HomePageState._brand.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _HomePageState._brand.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(icon, color: _HomePageState._brand),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$value${unit.isEmpty ? '' : ' $unit'}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuickActionTile(
                icon: Icons.favorite_outline,
                label: '健康',
                color: Colors.orangeAccent,
                onTap: () => onQuickAction('health'),
              ),
              const SizedBox(width: 10),
              _QuickActionTile(
                icon: Icons.support_agent_outlined,
                label: '客服',
                color: Colors.teal,
                onTap: () => onQuickAction('support'),
              ),
              const SizedBox(width: 10),
              _QuickActionTile(
                icon: Icons.location_on_outlined,
                label: '地圖',
                color: Colors.indigo,
                onTap: () => onQuickAction('map'),
              ),
              const SizedBox(width: 10),
              _QuickActionTile(
                icon: Icons.sos_outlined,
                label: 'SOS',
                color: Colors.redAccent,
                onTap: () => onQuickAction('sos'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthArticlesList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback onTap;

  const _HealthArticlesList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('健康文章', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...items.take(2).map((a) {
              final title = (a['title'] ?? '').toString();
              final desc = (a['desc'] ?? '').toString();
              final image = (a['image'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _NetImage(
                        url: image,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: TextStyle(color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FeaturedGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String Function(num) fmtMoney;
  final void Function(Map<String, dynamic> m) onTapItem;

  const _FeaturedGrid({
    required this.items,
    required this.fmtMoney,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (_, i) {
        final m = items[i];
        final name = (m['name'] ?? '').toString();
        final badge = (m['badge'] ?? '').toString();
        final image = (m['image'] ?? '').toString();
        final pRaw = m['price'];
        final p = (pRaw is num) ? pRaw : num.tryParse(pRaw.toString()) ?? 0;

        return InkWell(
          onTap: () => onTapItem(m),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _NetImage(url: image, fit: BoxFit.cover),
                        ),
                        if (badge.trim().isNotEmpty)
                          Positioned(
                            left: 10,
                            top: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
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
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Text(
                    fmtMoney(p),
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
  }
}

class _NetImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const _NetImage({
    required this.url,
    this.width,
    this.height,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    final u = url.trim();
    if (u.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: Colors.grey),
      );
    }

    return Image.network(
      u,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: (progress.expectedTotalBytes == null)
                  ? null
                  : progress.cumulativeBytesLoaded /
                        (progress.expectedTotalBytes ?? 1),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        );
      },
    );
  }
}

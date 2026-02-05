// lib/pages/shop/shop_home_dynamic_page.dart
//
// ✅ ShopHomeDynamicPage（前台｜動態首頁渲染器｜最終完整版｜可編譯）
// ------------------------------------------------------------
// 來源：
// - 先讀 AppStartupGate 內的 AppConfigScope.home（啟動時已讀 shop_config/home）
// - 同時即時監聽 Firestore shop_config/home，讓後台更新立即生效
//
// Firestore（建議結構）
// shop_config/home
// {
//   enabled: true,
//   title: "Osmile 商城",
//   subtitle: "守護家人更安心",
//   sections: [
//     { "type":"hero", "enabled":true, "title":"新品上市", "subtitle":"..." },
//     { "type":"banners", "enabled":true, "source":"doc", "images":[...] },
//     { "type":"categories", "enabled":true, "style":"chips", "limit":12 },
//     { "type":"products_carousel", "enabled":true, "title":"熱賣商品", "limit":10 },
//     { "type":"products_grid", "enabled":true, "title":"為你推薦", "limit":8 },
//     { "type":"news", "enabled":true, "title":"最新消息", "limit":5 },
//     { "type":"actions", "enabled":true, "items":[
//         {"title":"抽獎活動","route":"/lottery"},
//         {"title":"客服支援","route":"/support"}
//     ]}
//   ]
// }
//
// 依賴：cloud_firestore, flutter
// ⚠️ 注意：你的 Firestore rules 需要允許 read shop_config/home，否則會 permission-denied
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// 你已經有 AppStartupGate + AppConfigScope（上一個檔案）
// 若你的實際路徑不同，請調整此 import
import '../startup/app_startup_gate.dart';

class ShopHomeDynamicPage extends StatefulWidget {
  const ShopHomeDynamicPage({super.key});

  @override
  State<ShopHomeDynamicPage> createState() => _ShopHomeDynamicPageState();
}

class _ShopHomeDynamicPageState extends State<ShopHomeDynamicPage> {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _homeRef =>
      _db.collection('shop_config').doc('home');

  Future<void> _refresh() async {
    // 只是觸發重建 StreamBuilder；真正資料由 snapshots 提供
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scopeHome = _safeMap(AppConfigScope.of(context).home);
    final scopeSystem = _safeMap(AppConfigScope.of(context).system);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _homeRef.snapshots(),
      builder: (context, snap) {
        final fromScope = _mergeHomeDefaults(scopeHome);
        final fromDoc = _mergeHomeDefaults(snap.data?.data());

        // 優先使用即時 doc；若還沒拿到就用 scope
        final home = (snap.hasData && snap.data != null) ? fromDoc : fromScope;

        final enabled = _asBool(home['enabled'], fallback: true);
        if (!enabled) {
          return _BlockedHome(
            title: '商城首頁已關閉',
            message: '目前商城首頁入口暫時停用，請稍後再試。',
            onRetry: _refresh,
          );
        }

        final pageTitle = (home['title'] ?? 'Osmile 商城').toString();
        final subtitle = (home['subtitle'] ?? '').toString();

        final sectionsRaw = home['sections'];
        final sections = _asListMap(sectionsRaw);

        return Scaffold(
          appBar: AppBar(
            title: Text(pageTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              IconButton(
                tooltip: '重新整理',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                if (subtitle.trim().isNotEmpty) ...[
                  _SubtitleBanner(text: subtitle),
                  const SizedBox(height: 10),
                ],

                // 可用 system_settings 控制入口（例：checkoutEnabled / lotteryEnabled）
                _SystemNoticeStrip(system: scopeSystem),

                const SizedBox(height: 10),

                if (snap.hasError) ...[
                  _InlineWarn(
                    title: '首頁設定讀取失敗（已改用啟動快取）',
                    message: snap.error.toString(),
                  ),
                  const SizedBox(height: 10),
                ],

                if (sections.isEmpty) ...[
                  const _InlineEmpty(
                    title: '尚未配置首頁區塊',
                    message: '請到後台設定 shop_config/home.sections。',
                  ),
                ] else ...[
                  for (final s in sections) ..._buildSection(context, s),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // Section renderer
  // ============================================================

  List<Widget> _buildSection(BuildContext context, Map<String, dynamic> raw) {
    final enabled = _asBool(raw['enabled'], fallback: true);
    if (!enabled) return const [];

    final type = (raw['type'] ?? '').toString().trim().toLowerCase();
    switch (type) {
      case 'hero':
        return [_HeroSection(data: raw), const SizedBox(height: 12)];

      case 'banners':
        return [_BannersSection(data: raw), const SizedBox(height: 12)];

      case 'categories':
        return [_CategoriesSection(data: raw), const SizedBox(height: 12)];

      case 'products_grid':
        return [_ProductsGridSection(data: raw), const SizedBox(height: 12)];

      case 'products_carousel':
        return [_ProductsCarouselSection(data: raw), const SizedBox(height: 12)];

      case 'news':
        return [_NewsSection(data: raw), const SizedBox(height: 12)];

      case 'actions':
        return [_ActionsSection(data: raw), const SizedBox(height: 12)];

      case 'spacer':
        final h = _asDouble(raw['height'], fallback: 12).toDouble();
        return [SizedBox(height: h)];

      case 'divider':
        return const [Divider(height: 1), SizedBox(height: 12)];

      case 'text':
        return [_TextSection(data: raw), const SizedBox(height: 12)];

      default:
        return [
          _InlineWarn(
            title: '未知區塊 type',
            message: 'type="$type"（此區塊已略過渲染）',
          ),
          const SizedBox(height: 12),
        ];
    }
  }

  // ============================================================
  // Defaults
  // ============================================================

  Map<String, dynamic> _mergeHomeDefaults(Map<String, dynamic>? raw) {
    final base = <String, dynamic>{
      'enabled': true,
      'title': 'Osmile 商城',
      'subtitle': '',
      'sections': const [],
    };
    return {...base, ..._safeMap(raw)};
  }

  // ============================================================
  // Utils
  // ============================================================

  Map<String, dynamic> _safeMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asListMap(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e is Map)
          .map((e) => (e as Map).map((k, val) => MapEntry(k.toString(), val)))
          .cast<Map<String, dynamic>>()
          .toList();
    }
    return <Map<String, dynamic>>[];
  }
}

bool _asBool(dynamic v, {required bool fallback}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true';
  return fallback;
}

num _asDouble(dynamic v, {required num fallback}) {
  if (v == null) return fallback;
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? fallback;
  return fallback;
}

int _asInt(dynamic v, {required int fallback}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String _asString(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  return v.toString();
}

List<String> _asStringList(dynamic v) {
  if (v is List) {
    return v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
  }
  return <String>[];
}

Map<String, dynamic>? _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return null;
}

// ============================================================
// UI blocks (common)
// ============================================================

class _SubtitleBanner extends StatelessWidget {
  final String text;
  const _SubtitleBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineWarn extends StatelessWidget {
  final String title;
  final String message;
  const _InlineWarn({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.errorContainer.withOpacity(0.25),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: cs.error),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String title;
  final String message;
  const _InlineEmpty({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.view_quilt_outlined, size: 42, color: cs.primary),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _BlockedHome extends StatelessWidget {
  final String title;
  final String message;
  final Future<void> Function() onRetry;

  const _BlockedHome({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('商城')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block_outlined, size: 52, color: cs.primary),
                    const SizedBox(height: 10),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async => onRetry(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新整理'),
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

// ============================================================
// System strip (optional)
// ============================================================

class _SystemNoticeStrip extends StatelessWidget {
  final Map<String, dynamic> system;
  const _SystemNoticeStrip({required this.system});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final checkoutEnabled = _asBool(system['checkoutEnabled'], fallback: true);
    final lotteryEnabled = _asBool(system['lotteryEnabled'], fallback: true);

    if (checkoutEnabled && lotteryEnabled) return const SizedBox.shrink();

    final parts = <String>[];
    if (!checkoutEnabled) parts.add('目前暫停下單');
    if (!lotteryEnabled) parts.add('抽獎功能暫停');

    return Card(
      elevation: 0,
      color: cs.primaryContainer.withOpacity(0.35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.tips_and_updates_outlined, color: cs.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                parts.join(' · '),
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Sections
// ============================================================

class _HeroSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HeroSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final title = _asString(data['title'], fallback: '歡迎來到 Osmile 商城');
    final subtitle = _asString(data['subtitle'], fallback: '');
    final ctaText = _asString(data['ctaText'], fallback: '立即選購');
    final route = _asString(data['route'], fallback: '/shop');

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      _safePushNamed(context, route);
                    },
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(ctaText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 26,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.storefront_outlined, color: cs.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannersSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BannersSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = _asString(data['title'], fallback: '活動 / 推薦');
    final source = _asString(data['source'], fallback: 'doc'); // doc / collection
    final limit = _asInt(data['limit'], fallback: 6);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: title, icon: Icons.photo_library_outlined),
            const SizedBox(height: 10),
            if (source == 'collection')
              _BannerFromCollection(limit: limit)
            else
              _BannerFromDoc(images: _asStringList(data['images'])),
          ],
        ),
      ),
    );
  }
}

class _BannerFromDoc extends StatelessWidget {
  final List<String> images;
  const _BannerFromDoc({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const _InlineEmpty(
        title: '未設定 Banner 圖片',
        message: '請在 sections.banners.images 放入圖片網址，或改用 source="collection"。',
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: PageView.builder(
          itemCount: images.length,
          itemBuilder: (_, i) {
            final url = images[i];
            return Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
              loadingBuilder: (c, w, p) {
                if (p == null) return w;
                return const Center(child: CircularProgressIndicator());
              },
            );
          },
        ),
      ),
    );
  }
}

class _BannerFromCollection extends StatelessWidget {
  final int limit;
  const _BannerFromCollection({required this.limit});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final q = db
        .collection('banners')
        .where('enabled', isEqualTo: true)
        .limit(limit);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return _InlineWarn(title: '讀取 banners 失敗', message: snap.error.toString());
        }

        final docs = snap.data?.docs ?? [];
        final images = <String>[];
        for (final d in docs) {
          final m = d.data();
          final url = _asString(m['imageUrl'], fallback: _asString(m['image'], fallback: ''));
          if (url.trim().isNotEmpty) images.add(url);
        }

        return _BannerFromDoc(images: images);
      },
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CategoriesSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = _asString(data['title'], fallback: '商品分類');
    final style = _asString(data['style'], fallback: 'chips'); // chips / grid
    final limit = _asInt(data['limit'], fallback: 12);

    final db = FirebaseFirestore.instance;
    final q = db.collection('categories').limit(limit);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: title, icon: Icons.category_outlined),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) {
                  return _InlineWarn(title: '讀取 categories 失敗', message: snap.error.toString());
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const _InlineEmpty(title: '沒有分類資料', message: '請先建立 categories。');
                }

                final items = docs.map((d) {
                  final m = d.data();
                  final name = _asString(m['name'], fallback: '未命名');
                  return _CatItem(id: d.id, name: name);
                }).toList();

                if (style == 'grid') {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.5,
                    ),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      return OutlinedButton(
                        onPressed: () => _safePushNamed(context, '/category', args: {'categoryId': it.id}),
                        child: Text(it.name, overflow: TextOverflow.ellipsis),
                      );
                    },
                  );
                }

                // chips
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: items.map((it) {
                    return ActionChip(
                      label: Text(it.name),
                      onPressed: () => _safePushNamed(context, '/category', args: {'categoryId': it.id}),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsCarouselSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProductsCarouselSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = _asString(data['title'], fallback: '推薦商品');
    final limit = _asInt(data['limit'], fallback: 10);
    final categoryId = _asString(data['categoryId'], fallback: '');
    final vendorId = _asString(data['vendorId'], fallback: '');

    final db = FirebaseFirestore.instance;

    Query<Map<String, dynamic>> q = db.collection('products').limit(limit);

    // 可選過濾
    if (categoryId.trim().isNotEmpty) {
      q = q.where('categoryId', isEqualTo: categoryId.trim());
    }
    if (vendorId.trim().isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId.trim());
    }

    // 若你有 published/active 欄位，可在此加 where
    // q = q.where('published', isEqualTo: true);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: title, icon: Icons.local_fire_department_outlined),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) {
                  return _InlineWarn(title: '讀取 products 失敗', message: snap.error.toString());
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const _InlineEmpty(title: '沒有商品', message: '此區塊條件下查無商品。');
                }

                return SizedBox(
                  height: 170,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final m = doc.data();
                      final p = _ProductLite.from(doc.id, m);
                      return _ProductCardMini(product: p);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsGridSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProductsGridSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = _asString(data['title'], fallback: '為你推薦');
    final limit = _asInt(data['limit'], fallback: 8);
    final columns = _asInt(data['columns'], fallback: 2);
    final categoryId = _asString(data['categoryId'], fallback: '');
    final vendorId = _asString(data['vendorId'], fallback: '');

    final db = FirebaseFirestore.instance;

    Query<Map<String, dynamic>> q = db.collection('products').limit(limit);

    if (categoryId.trim().isNotEmpty) {
      q = q.where('categoryId', isEqualTo: categoryId.trim());
    }
    if (vendorId.trim().isNotEmpty) {
      q = q.where('vendorId', isEqualTo: vendorId.trim());
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: title, icon: Icons.grid_view_outlined),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) {
                  return _InlineWarn(title: '讀取 products 失敗', message: snap.error.toString());
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const _InlineEmpty(title: '沒有商品', message: '此區塊條件下查無商品。');
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns.clamp(2, 4),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final m = doc.data();
                    final p = _ProductLite.from(doc.id, m);
                    return _ProductCardGrid(product: p);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NewsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = _asString(data['title'], fallback: '最新消息');
    final limit = _asInt(data['limit'], fallback: 5);

    final db = FirebaseFirestore.instance;

    // 你的 rules：news 只有 published==true 可 read（你前面貼的 rules）
    Query<Map<String, dynamic>> q = db.collection('news').where('published', isEqualTo: true).limit(limit);

    // 若你有 createdAt/updatedAt 可加排序
    // q = q.orderBy('createdAt', descending: true);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: title, icon: Icons.article_outlined),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) {
                  return _InlineWarn(title: '讀取 news 失敗', message: snap.error.toString());
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const _InlineEmpty(title: '尚無最新消息', message: '請在後台新增 news（published=true）。');
                }

                return Column(
                  children: docs.map((d) {
                    final m = d.data();
                    final t = _asString(m['title'], fallback: '未命名');
                    final sub = _asString(m['subtitle'], fallback: _asString(m['summary'], fallback: ''));
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.fiber_new_outlined),
                      title: Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: sub.trim().isEmpty ? null : Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _safePushNamed(context, '/news_detail', args: {'newsId': d.id}),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ActionsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = _asString(data['title'], fallback: '快捷入口');
    final itemsRaw = data['items'];
    final items = <Map<String, dynamic>>[];

    if (itemsRaw is List) {
      for (final e in itemsRaw) {
        final m = _asMap(e);
        if (m != null) items.add(m);
      }
    }

    if (items.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _SectionHeader(title: '快捷入口', icon: Icons.apps_outlined),
              SizedBox(height: 10),
              _InlineEmpty(title: '未設定 actions', message: '請在 sections.actions.items 配置 route。'),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: title, icon: Icons.apps_outlined),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items.map((it) {
                final text = _asString(it['title'], fallback: '未命名');
                final route = _asString(it['route'], fallback: '');
                final iconName = _asString(it['icon'], fallback: '');
                final icon = _iconFromName(iconName) ?? Icons.open_in_new_outlined;

                return FilledButton.tonalIcon(
                  onPressed: route.trim().isEmpty ? null : () => _safePushNamed(context, route, args: it['args']),
                  icon: Icon(icon),
                  label: Text(text),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TextSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = _asString(data['title'], fallback: '');
    final body = _asString(data['body'], fallback: _asString(data['text'], fallback: ''));

    if (title.trim().isEmpty && body.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.trim().isNotEmpty)
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if (body.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(body, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, height: 1.35)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Product UI + Model
// ============================================================

class _ProductLite {
  final String id;
  final String name;
  final double? price;
  final double? salePrice;
  final String imageUrl;

  _ProductLite({
    required this.id,
    required this.name,
    required this.price,
    required this.salePrice,
    required this.imageUrl,
  });

  factory _ProductLite.from(String id, Map<String, dynamic> m) {
    final name = _asString(m['name'], fallback: _asString(m['title'], fallback: '未命名商品'));

    // 常見價格欄位（你可按你的結構再加）
    final price = _numToDouble(m['price']) ??
        _numToDouble(m['priceAmount']) ??
        _numToDouble(m['amount']) ??
        _numToDouble(m['salePrice']);

    final sale = _numToDouble(m['salePrice']) ?? _numToDouble(m['discountPrice']);

    // 圖片欄位容錯
    String img = _asString(m['imageUrl'], fallback: '');
    if (img.trim().isEmpty) img = _asString(m['image'], fallback: '');
    if (img.trim().isEmpty) {
      final images = _asStringList(m['images']);
      if (images.isNotEmpty) img = images.first;
    }
    if (img.trim().isEmpty) {
      final imageUrls = _asStringList(m['imageUrls']);
      if (imageUrls.isNotEmpty) img = imageUrls.first;
    }

    return _ProductLite(
      id: id,
      name: name,
      price: price,
      salePrice: sale,
      imageUrl: img,
    );
  }
}

double? _numToDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    final cleaned = v.replaceAll(',', '').trim();
    return double.tryParse(cleaned);
  }
  return null;
}

class _ProductCardMini extends StatelessWidget {
  final _ProductLite product;
  const _ProductCardMini({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 140,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _safePushNamed(context, '/product', args: {'productId': product.id}),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: product.imageUrl.trim().isEmpty
                        ? Container(
                            color: cs.surfaceContainerHighest,
                            child: const Center(child: Icon(Icons.image_not_supported_outlined)),
                          )
                        : Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: cs.surfaceContainerHighest,
                              child: const Center(child: Icon(Icons.broken_image_outlined)),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                _PriceLine(product: product),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCardGrid extends StatelessWidget {
  final _ProductLite product;
  const _ProductCardGrid({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _safePushNamed(context, '/product', args: {'productId': product.id}),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.imageUrl.trim().isEmpty
                      ? Container(
                          color: cs.surfaceContainerHighest,
                          child: const Center(child: Icon(Icons.image_not_supported_outlined)),
                        )
                      : Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: cs.surfaceContainerHighest,
                            child: const Center(child: Icon(Icons.broken_image_outlined)),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              _PriceLine(product: product),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final _ProductLite product;
  const _PriceLine({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final p = product.price;
    final s = product.salePrice;

    String fmt(double? v) {
      if (v == null) return '—';
      // 不引 intl，避免你專案沒裝
      final n = v.round();
      return '\$${n.toString()}';
    }

    if (s != null && p != null && s < p) {
      return Row(
        children: [
          Text(fmt(s), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Text(
            fmt(p),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Text(
      fmt(p ?? s),
      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900),
    );
  }
}

class _CatItem {
  final String id;
  final String name;
  _CatItem({required this.id, required this.name});
}

// ============================================================
// Navigation helper
// ============================================================

void _safePushNamed(BuildContext context, String route, {dynamic args}) {
  try {
    Navigator.pushNamed(context, route, arguments: args);
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('找不到路由：$route（請在 routes 設定對應頁面）')),
    );
  }
}

IconData? _iconFromName(String name) {
  switch (name.trim().toLowerCase()) {
    case 'lottery':
      return Icons.emoji_events_outlined;
    case 'support':
      return Icons.support_agent_outlined;
    case 'coupon':
      return Icons.confirmation_num_outlined;
    case 'orders':
      return Icons.receipt_long_outlined;
    case 'cart':
      return Icons.shopping_cart_outlined;
    default:
      return null;
  }
}

// lib/pages/shop/shop_home_page.dart
//
// ✅ ShopHomePage（前台商城首頁｜吃 shop_config/home｜完整版｜可編譯）
// ------------------------------------------------------------
// - 讀取來源優先序：
//   1) homeOverride（若你外部直接傳入）
//   2) AppStartupGate 的 AppConfigScope.home（若有包）
//   3) Firestore 直讀 shop_config/home（若沒有包 scope）
//
// - 支援 sections：banner / products / categories / rich_text
// - 支援 layout：carousel / grid / list
// - whereIn 限制：自動分批（10筆一批）
// - 不依賴額外套件（不使用 url_launcher）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../startup/app_startup_gate.dart'; // ✅ 用來讀 AppConfigScope（若你有包）

class ShopHomePage extends StatelessWidget {
  /// 若你想直接注入 home 設定，可用這個（優先於 Scope/Firestore）
  final Map<String, dynamic>? homeOverride;

  const ShopHomePage({super.key, this.homeOverride});

  @override
  Widget build(BuildContext context) {
    final override = homeOverride;
    if (override != null) {
      return _HomeView(home: _mergeHomeDefaults(override));
    }

    final scope = context.dependOnInheritedWidgetOfExactType<AppConfigScope>();
    if (scope != null) {
      return _HomeView(home: _mergeHomeDefaults(scope.home));
    }

    // 沒有 scope：直接讀 Firestore
    final ref = FirebaseFirestore.instance.collection('shop_config').doc('home');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SimpleScaffoldLoading(title: '商城首頁');
        }
        if (snap.hasError) {
          return _SimpleScaffoldError(
            title: '商城首頁',
            message: '讀取失敗：${snap.error}',
            onRetry: () => (context as Element).markNeedsBuild(),
          );
        }

        final raw = snap.data?.data() ?? const <String, dynamic>{};
        final home = _mergeHomeDefaults(raw);
        return _HomeView(home: home);
      },
    );
  }
}

// ============================================================
// Home View (Render)
// ============================================================

class _HomeView extends StatelessWidget {
  final Map<String, dynamic> home;
  const _HomeView({required this.home});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final enabled = home['enabled'] == true;
    final sectionsRaw = home['sections'];

    final sections = <_HomeSection>[];
    if (sectionsRaw is List) {
      for (final e in sectionsRaw) {
        if (e is Map) {
          sections.add(_HomeSection.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('商城首頁', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: !enabled
          ? Center(
              child: Text(
                '商城首頁目前停用（shop_config/home.enabled=false）',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : (sections.isEmpty
              ? Center(
                  child: Text(
                    '尚未設定首頁區塊（sections 為空）',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                  itemCount: sections.length,
                  itemBuilder: (_, i) {
                    final s = sections[i];
                    if (!s.enabled) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SectionRenderer(section: s),
                    );
                  },
                )),
    );
  }
}

class _SectionRenderer extends StatelessWidget {
  final _HomeSection section;
  const _SectionRenderer({required this.section});

  @override
  Widget build(BuildContext context) {
    switch (section.type) {
      case 'banner':
        return _BannerSection(section: section);
      case 'products':
        return _ProductsSection(section: section);
      case 'categories':
        return _CategoriesSection(section: section);
      case 'rich_text':
      default:
        return _RichTextSection(section: section);
    }
  }
}

// ============================================================
// Banner
// ============================================================

class _BannerSection extends StatelessWidget {
  final _HomeSection section;
  const _BannerSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: InkWell(
        onTap: section.linkUrl.trim().isEmpty
            ? null
            : () => _showLinkDialog(context, section.linkUrl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (section.imageUrl.trim().isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  section.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: cs.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Text(
                      '圖片載入失敗',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (section.title.trim().isNotEmpty)
                    Text(
                      section.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  if (section.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      section.subtitle,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (section.linkUrl.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      section.linkUrl,
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('連結', style: TextStyle(fontWeight: FontWeight.w900)),
        content: SelectableText(url),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        ],
      ),
    );
  }
}

// ============================================================
// Rich Text
// ============================================================

class _RichTextSection extends StatelessWidget {
  final _HomeSection section;
  const _RichTextSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (section.title.trim().isNotEmpty)
              Text(section.title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if (section.subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                section.subtitle,
                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ],
            if (section.body.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                section.body,
                style: TextStyle(color: cs.onSurface, height: 1.35, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Products / Categories common fetch (whereIn chunking)
// ============================================================

Future<List<Map<String, dynamic>>> _fetchDocsByIds({
  required String collection,
  required List<String> ids,
}) async {
  final cleaned = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (cleaned.isEmpty) return [];

  // Firestore whereIn 限制：一次最多 10
  const chunkSize = 10;
  final chunks = <List<String>>[];
  for (int i = 0; i < cleaned.length; i += chunkSize) {
    chunks.add(cleaned.sublist(i, (i + chunkSize).clamp(0, cleaned.length)));
  }

  final db = FirebaseFirestore.instance;
  final out = <Map<String, dynamic>>[];

  for (final c in chunks) {
    final qs = await db
        .collection(collection)
        .where(FieldPath.documentId, whereIn: c)
        .get();

    for (final doc in qs.docs) {
      out.add({
        'id': doc.id,
        ...doc.data(),
      });
    }
  }

  // 依原本 ids 順序排序（盡量讓 UI 穩定）
  final index = <String, int>{};
  for (int i = 0; i < cleaned.length; i++) {
    index[cleaned[i]] = i;
  }
  out.sort((a, b) {
    final ia = index[(a['id'] ?? '').toString()] ?? 1 << 30;
    final ib = index[(b['id'] ?? '').toString()] ?? 1 << 30;
    return ia.compareTo(ib);
  });

  return out;
}

String _pickName(Map<String, dynamic> d) {
  final candidates = ['name', 'title', 'displayName'];
  for (final k in candidates) {
    final v = (d[k] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }
  return '未命名';
}

String _pickImage(Map<String, dynamic> d) {
  final candidates = ['imageUrl', 'coverUrl', 'thumbnailUrl', 'photoUrl'];
  for (final k in candidates) {
    final v = (d[k] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }
  return '';
}

String _pickSubtitle(Map<String, dynamic> d) {
  final candidates = ['subtitle', 'summary', 'description', 'brief'];
  for (final k in candidates) {
    final v = (d[k] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }
  return '';
}

String _pickPriceText(Map<String, dynamic> d) {
  final v = d['price'];
  if (v is num) return '\$${v.toStringAsFixed(0)}';
  final s = (v ?? '').toString().trim();
  if (s.isNotEmpty) return s;
  return '';
}

// ============================================================
// Products section
// ============================================================

class _ProductsSection extends StatelessWidget {
  final _HomeSection section;
  const _ProductsSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ids = section.productIds.take(section.limit).toList();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: section.title, subtitle: section.subtitle),
            const SizedBox(height: 10),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchDocsByIds(collection: 'products', ids: ids),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Text(
                    '載入商品失敗：${snap.error}',
                    style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                  );
                }

                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Text(
                    '沒有可顯示的商品（productIds 為空或找不到資料）',
                    style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  );
                }

                return _ItemsLayout(
                  layout: section.layout,
                  items: items,
                  itemBuilder: (d) => _ProductCard(data: d),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Categories section
// ============================================================

class _CategoriesSection extends StatelessWidget {
  final _HomeSection section;
  const _CategoriesSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ids = section.categoryIds.take(section.limit).toList();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: section.title, subtitle: section.subtitle),
            const SizedBox(height: 10),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchDocsByIds(collection: 'categories', ids: ids),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Text(
                    '載入分類失敗：${snap.error}',
                    style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                  );
                }

                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Text(
                    '沒有可顯示的分類（categoryIds 為空或找不到資料）',
                    style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  );
                }

                return _ItemsLayout(
                  layout: section.layout,
                  items: items,
                  itemBuilder: (d) => _CategoryCard(data: d),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Layouts
// ============================================================

class _ItemsLayout extends StatelessWidget {
  final String layout; // carousel/grid/list
  final List<Map<String, dynamic>> items;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  const _ItemsLayout({
    required this.layout,
    required this.items,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    switch (layout) {
      case 'grid':
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (_, i) => itemBuilder(items[i]),
        );
      case 'list':
        return Column(
          children: [
            for (final d in items) ...[
              itemBuilder(d),
              const SizedBox(height: 10),
            ],
          ],
        );
      case 'carousel':
      default:
        return SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(width: 160, child: itemBuilder(items[i])),
          ),
        );
    }
  }
}

// ============================================================
// Cards
// ============================================================

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProductCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _pickName(data);
    final image = _pickImage(data);
    final price = _pickPriceText(data);

    return Card(
      elevation: 0,
      child: InkWell(
        onTap: () {
          // 你若有商品詳情頁路由，可在此導向
          // Navigator.pushNamed(context, '/product', arguments: data['id']);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: image.isEmpty
                  ? Container(
                      color: cs.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Text(
                        'No Image',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: cs.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Text(
                          'Image Error',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  if (price.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      price,
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CategoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _pickName(data);
    final image = _pickImage(data);
    final sub = _pickSubtitle(data);

    return Card(
      elevation: 0,
      child: InkWell(
        onTap: () {
          // 你若有分類頁，可在此導向
          // Navigator.pushNamed(context, '/category', arguments: data['id']);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: image.isEmpty
                  ? Container(
                      color: cs.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Text(
                        'No Image',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: cs.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Text(
                          'Image Error',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Section header
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (title.trim().isEmpty && subtitle.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.trim().isNotEmpty)
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// Model
// ============================================================

class _HomeSection {
  final String id;
  final String type; // banner/products/categories/rich_text
  final bool enabled;

  final String title;
  final String subtitle;

  // banner
  final String imageUrl;
  final String linkUrl;

  // products/categories
  final List<String> productIds;
  final List<String> categoryIds;
  final String layout; // carousel/grid/list
  final int limit;

  // rich_text
  final String body;

  const _HomeSection({
    required this.id,
    required this.type,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.linkUrl,
    required this.productIds,
    required this.categoryIds,
    required this.layout,
    required this.limit,
    required this.body,
  });

  factory _HomeSection.fromMap(Map<String, dynamic> m) {
    return _HomeSection(
      id: (m['id'] ?? '').toString(),
      type: (m['type'] ?? 'rich_text').toString(),
      enabled: m['enabled'] == true,
      title: (m['title'] ?? '').toString(),
      subtitle: (m['subtitle'] ?? '').toString(),
      imageUrl: (m['imageUrl'] ?? '').toString(),
      linkUrl: (m['linkUrl'] ?? '').toString(),
      productIds: _asStringList(m['productIds']),
      categoryIds: _asStringList(m['categoryIds']),
      layout: (m['layout'] ?? 'carousel').toString(),
      limit: _asInt(m['limit'], fallback: 12),
      body: (m['body'] ?? '').toString(),
    );
  }

  static List<String> _asStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static int _asInt(dynamic v, {required int fallback}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}

// ============================================================
// Defaults merge
// ============================================================

Map<String, dynamic> _mergeHomeDefaults(Map<String, dynamic> raw) {
  const defaults = <String, dynamic>{
    'enabled': true,
    'sections': <dynamic>[],
  };
  return <String, dynamic>{
    ...defaults,
    ...raw,
  };
}

// ============================================================
// Simple utility screens
// ============================================================

class _SimpleScaffoldLoading extends StatelessWidget {
  final String title;
  const _SimpleScaffoldLoading({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: Center(
        child: CircularProgressIndicator(color: cs.primary),
      ),
    );
  }
}

class _SimpleScaffoldError extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _SimpleScaffoldError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 46, color: cs.error),
                  const SizedBox(height: 10),
                  Text('載入失敗', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

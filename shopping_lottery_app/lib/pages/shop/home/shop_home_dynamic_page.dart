import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ✅ ShopHomeDynamicPage（商城首頁｜動態版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - ✅ AppStartupGate 直接內嵌
/// - ✅ withOpacity -> withValues(alpha: ...)
/// - ✅ _pushNamedSafe 改同步（避免 use_build_context_synchronously）
/// ------------------------------------------------------------
class ShopHomeDynamicPage extends StatefulWidget {
  const ShopHomeDynamicPage({super.key});

  @override
  State<ShopHomeDynamicPage> createState() => _ShopHomeDynamicPageState();
}

class _ShopHomeDynamicPageState extends State<ShopHomeDynamicPage> {
  final _fs = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return AppStartupGate(
      title: 'Osmile Shop',
      initializer: () async {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('商城'),
          actions: [
            IconButton(
              tooltip: '搜尋',
              onPressed: () => _pushNamedSafe(context, '/search'),
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: '購物車',
              onPressed: () => _pushNamedSafe(context, '/cart'),
              icon: const Icon(Icons.shopping_cart_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _bannerSection(),
              const SizedBox(height: 12),
              _quickActions(),
              const SizedBox(height: 12),
              _homeBlocksSection(),
              const SizedBox(height: 12),
              _productGridSection(),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Shop Home • Dynamic',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Banner ----------------

  Widget _bannerSection() {
    final q = _fs
        .collection('banners')
        .where('isActive', isEqualTo: true)
        .orderBy('sort', descending: false)
        .limit(6);

    return SizedBox(
      height: 170,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return _cardError('Banner 讀取失敗：${snap.error}');
          if (!snap.hasData) return _cardLoading(height: 170);

          final docs = snap.data!.docs;
          if (docs.isEmpty) return _bannerFallback();

          return PageView.builder(
            itemCount: docs.length,
            controller: PageController(viewportFraction: 0.92),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final title = (d['title'] ?? '活動').toString();
              final url = (d['imageUrl'] ?? '').toString();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (url.isNotEmpty)
                        Image.network(url, fit: BoxFit.cover)
                      else
                        Container(color: Colors.grey.shade300),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
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
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _bannerFallback() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.blueAccent.withValues(alpha: 0.08),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(
              Icons.campaign_outlined,
              size: 34,
              color: Colors.blueAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '尚未設定 Banner（請建立 banners collection）',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Quick Actions ----------------

  Widget _quickActions() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _quickBtn(
              Icons.card_giftcard,
              '優惠券',
              () => _pushNamedSafe(context, '/coupons'),
            ),
            _quickBtn(
              Icons.casino,
              '抽獎',
              () => _pushNamedSafe(context, '/lottery'),
            ),
            _quickBtn(
              Icons.redeem,
              '點數商城',
              () => _pushNamedSafe(context, '/points_mall'),
            ),
            _quickBtn(
              Icons.support_agent,
              '客服',
              () => _pushNamedSafe(context, '/support'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.blueAccent),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Home Blocks ----------------

  Widget _homeBlocksSection() {
    final q = _fs
        .collection('home_blocks')
        .where('isActive', isEqualTo: true)
        .orderBy('sort', descending: false)
        .limit(12);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _cardError('區塊讀取失敗：${snap.error}');
        if (!snap.hasData) return _cardLoading(height: 140);

        final docs = snap.data!.docs;
        if (docs.isEmpty) return _blocksFallback();

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '精選入口',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [for (final doc in docs) _blockTile(doc.data())],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _blocksFallback() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '精選入口',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              '尚未設定 home_blocks（請建立 home_blocks collection）',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blockTile(Map<String, dynamic> d) {
    final title = (d['title'] ?? '入口').toString();
    final subtitle = (d['subtitle'] ?? '').toString();
    final route = (d['route'] ?? '').toString();

    return SizedBox(
      width: 160,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: route.isEmpty ? null : () => _pushNamedSafe(context, route),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.blueAccent.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.grid_view_rounded, color: Colors.blueAccent),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Products ----------------

  Widget _productGridSection() {
    final q = _fs
        .collection('products')
        .where('isActive', isEqualTo: true)
        .orderBy('homePinned', descending: true)
        .limit(8);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _cardError('商品讀取失敗：${snap.error}');
        if (!snap.hasData) return _cardLoading(height: 280);

        final docs = snap.data!.docs;
        if (docs.isEmpty) return _productsFallback();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '推薦商品',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, i) =>
                  _productCard(docs[i].id, docs[i].data()),
            ),
          ],
        );
      },
    );
  }

  Widget _productsFallback() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '推薦商品',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              '尚未設定 products（請建立 products collection）',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productCard(String id, Map<String, dynamic> d) {
    final name = (d['name'] ?? '商品').toString();
    final imageUrl = (d['imageUrl'] ?? '').toString();
    final price = (d['price'] ?? 0);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _pushNamedSafe(context, '/product/$id'),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Container(
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'NT\$ $price',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Utils ----------------

  void _pushNamedSafe(BuildContext context, String route) {
    try {
      Navigator.of(context).pushNamed(route);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('路由未註冊：$route')));
    }
  }

  Widget _cardLoading({required double height}) {
    return SizedBox(
      height: height,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _cardError(String msg) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }
}

/// ✅ AppStartupGate（直接內嵌）
/// ------------------------------------------------------------
class AppStartupGate extends StatefulWidget {
  const AppStartupGate({
    super.key,
    required this.child,
    this.initializer,
    this.splash,
    this.backgroundColor = const Color(0xFFF6F8FB),
    this.title = 'Osmile',
  });

  final Widget child;
  final Future<void> Function()? initializer;
  final Widget? splash;
  final Color backgroundColor;
  final String title;

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.initializer != null) {
        await widget.initializer!.call();
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return widget.splash ?? _defaultSplash();
    if (_error != null) return _errorView(_error!);
    return widget.child;
  }

  Widget _defaultSplash() {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    size: 44,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('初始化中…', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 14),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView(Object e) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 28),
                      SizedBox(width: 8),
                      Text(
                        '初始化失敗',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(e.toString()),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _boot,
                      child: const Text('重試'),
                    ),
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

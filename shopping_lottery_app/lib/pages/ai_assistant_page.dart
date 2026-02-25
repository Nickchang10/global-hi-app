import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ✅ AIAssistantPage（AI 購物助理｜完整版｜已移除 FirestoreMockService.getMockProducts）
/// ------------------------------------------------------------
/// - 資料來源：Firestore collection('products')
/// - 不依賴任何 MockService
/// - 以簡單規則/關鍵字做「推薦」：
///   - 會從 name/description/tags/categoryId 做關鍵字匹配
///   - 預設只推薦 isActive=true 的商品
///
/// ✅ Lint:
/// - prefer_const_constructors：已把可 const 的 widget 做成 const tree（尤其 _introCard）
/// - deprecated_member_use (withOpacity)：全面改用 withValues(alpha: ...)
class AIAssistantPage extends StatefulWidget {
  const AIAssistantPage({super.key});

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage> {
  final _fs = FirebaseFirestore.instance;

  final _input = TextEditingController();
  final _scroll = ScrollController();

  bool _loading = true;
  String? _error;

  List<ProductDoc> _allProducts = [];
  List<ProductDoc> _recommended = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 先嘗試用 updatedAt 排序（最常見）
      final snap = await _fs
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .limit(200)
          .get();

      _allProducts = snap.docs.map((d) => ProductDoc.fromDoc(d)).toList();
      _recommended = _allProducts.take(8).toList();

      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    } catch (e) {
      // fallback：若 updatedAt 不存在（索引/欄位），用 createdAt 或不排序
      try {
        final snap = await _fs
            .collection('products')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(200)
            .get();

        _allProducts = snap.docs.map((d) => ProductDoc.fromDoc(d)).toList();
        _recommended = _allProducts.take(8).toList();

        if (!mounted) {
          return;
        }
        setState(() {
          _loading = false;
          _error = null;
        });
      } catch (e2) {
        // 最後 fallback：不 orderBy（只抓前 200）
        try {
          final snap = await _fs
              .collection('products')
              .where('isActive', isEqualTo: true)
              .limit(200)
              .get();

          _allProducts = snap.docs.map((d) => ProductDoc.fromDoc(d)).toList();
          _recommended = _allProducts.take(8).toList();

          if (!mounted) {
            return;
          }
          setState(() {
            _loading = false;
            _error = '部分欄位排序不可用，已改用無排序載入。原錯誤：$e';
          });
        } catch (e3) {
          if (!mounted) {
            return;
          }
          setState(() {
            _loading = false;
            _error = e3.toString();
          });
        }
      }
    }
  }

  void _onInputChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _recommend(v);
    });
  }

  void _recommend(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _recommended = _allProducts.take(8).toList());
      return;
    }

    final tokens = q
        .split(RegExp(r'\s+|,|，|、|/|\|'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final scored = <_Scored<ProductDoc>>[];

    for (final p in _allProducts) {
      final hay = [
        p.name,
        p.description,
        p.categoryId,
        ...p.tags,
      ].join(' ').toLowerCase();

      int score = 0;
      for (final t in tokens) {
        if (hay.contains(t)) {
          score += 3;
        }
      }

      if (q.contains('長輩') || q.contains('老人')) {
        if (hay.contains('sos') ||
            hay.contains('照護') ||
            hay.contains('定位') ||
            hay.contains('手錶')) {
          score += 2;
        }
      }
      if (q.contains('小孩') || q.contains('兒童') || q.contains('學生')) {
        if (hay.contains('sos') || hay.contains('定位') || hay.contains('防走失')) {
          score += 2;
        }
      }
      if (q.contains('sos') || q.contains('求救')) {
        if (hay.contains('sos') || hay.contains('求救')) {
          score += 2;
        }
      }
      if (q.contains('便宜') || q.contains('預算') || q.contains('省')) {
        score += (p.price <= 0)
            ? 0
            : (p.price < 2000 ? 2 : (p.price < 5000 ? 1 : 0));
      }

      if (score > 0) {
        scored.add(_Scored(p, score));
      }
    }

    scored.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      return b.item.price.compareTo(a.item.price);
    });

    final top = scored.take(12).map((e) => e.item).toList();

    setState(() {
      _recommended = top.isEmpty ? _allProducts.take(8).toList() : top;
    });

    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 購物助理'),
        actions: [
          IconButton(
            tooltip: '重新載入商品',
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null && _allProducts.isEmpty)
          ? Center(child: Text('載入失敗：$_error'))
          : Column(
              children: [
                _introCard(),
                _inputBar(),
                if (_error != null) _warnBar(_error!),
                const Divider(height: 1),
                Expanded(child: _resultList()),
              ],
            ),
    );
  }

  /// ✅ prefer_const_constructors：整段 const tree（你那個 lint 就會消失）
  Widget _introCard() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(child: Icon(Icons.smart_toy)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '描述你的需求，我會從商品資料中推薦最適合的選項。\n例：要給長輩用、要 SOS、需要定位、預算 3000 內。',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              onChanged: _onInputChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '輸入需求（例如：給長輩、要 SOS、預算 3000）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '清除',
            onPressed: () {
              _input.clear();
              _recommend('');
            },
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }

  Widget _warnBar(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        ),
        child: const Text(
          '⚠️ 部分欄位排序不可用，已使用 fallback 載入。',
          style: TextStyle(color: Colors.brown),
        ),
      ),
    );
  }

  Widget _resultList() {
    if (_recommended.isEmpty) {
      return const Center(child: Text('目前沒有可推薦的商品'));
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: _recommended.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _productCard(_recommended[i]),
    );
  }

  Widget _productCard(ProductDoc p) {
    return Card(
      elevation: 1,
      child: ListTile(
        leading: _thumb(p.imageUrl),
        title: Text(
          p.name.isEmpty ? '(未命名商品)' : p.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          p.description.isEmpty ? '（無描述）' : p.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'NT\$ ${p.price}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              p.categoryId.isEmpty ? '' : p.categoryId,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        onTap: () => _showProductDetail(p),
      ),
    );
  }

  Widget _thumb(String url) {
    if (url.trim().isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 56,
          height: 56,
          color: Colors.black.withValues(alpha: 0.05),
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }

  Future<void> _showProductDetail(ProductDoc p) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(p.name.isEmpty ? '(未命名商品)' : p.name),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.imageUrl.trim().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    p.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 180),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                '價格：NT\$ ${p.price}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (p.categoryId.trim().isNotEmpty) Text('類別：${p.categoryId}'),
              const SizedBox(height: 10),
              Text(p.description.isEmpty ? '（無描述）' : p.description),
              if (p.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.tags.map((t) => Chip(label: Text(t))).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }
}

/// ✅ 商品資料 Model（避免 Map 到處散）
class ProductDoc {
  final String id;
  final String name;
  final String description;
  final num price;
  final String imageUrl;
  final bool isActive;
  final String categoryId;
  final List<String> tags;

  ProductDoc({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isActive,
    required this.categoryId,
    required this.tags,
  });

  static num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  static bool _asBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is String) {
      final t = v.toLowerCase().trim();
      if (t == 'true') return true;
      if (t == 'false') return false;
    }
    return fallback;
  }

  static List<String> _asStringList(dynamic v) {
    if (v == null) return <String>[];
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    if (v is String && v.trim().isNotEmpty) return [v.trim()];
    return <String>[];
  }

  factory ProductDoc.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return ProductDoc(
      id: doc.id,
      name: (d['name'] ?? d['title'] ?? '').toString(),
      description: (d['description'] ?? d['desc'] ?? '').toString(),
      price: _asNum(d['price'] ?? d['amount'] ?? 0),
      imageUrl: (d['imageUrl'] ?? d['coverUrl'] ?? d['image'] ?? '').toString(),
      isActive: _asBool(d['isActive'] ?? d['active'], fallback: true),
      categoryId: (d['categoryId'] ?? d['category'] ?? '').toString(),
      tags: _asStringList(d['tags']),
    );
  }
}

class _Scored<T> {
  final T item;
  final int score;
  _Scored(this.item, this.score);
}

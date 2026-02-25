import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ✅ AIRecommendationPage（AI 推薦中心｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正/強化：
/// - ✅ withOpacity -> withValues(alpha: ...)（解 deprecated_member_use）
/// - ✅ if 單行語句一律加大括號（解 curly_braces_in_flow_control_structures）
/// - ✅ Firestore products 載入：updatedAt -> createdAt -> no orderBy fallback
/// - ✅ prefer_const_constructors：_introCard() 整段 const（一次解你 324~346 那段）
/// - ✅ unnecessary_const：避免在 const context 內重複寫 const
///
/// Firestore products 欄位建議：
/// - name (String)
/// - description (String)
/// - price (num)
/// - imageUrl (String)
/// - isActive (bool)
/// - categoryId (String)
/// - tags (List<String>) 可選
/// - updatedAt / createdAt (Timestamp) 可選
class AIRecommendationPage extends StatefulWidget {
  const AIRecommendationPage({super.key});

  @override
  State<AIRecommendationPage> createState() => _AIRecommendationPageState();
}

class _AIRecommendationPageState extends State<AIRecommendationPage> {
  final _fs = FirebaseFirestore.instance;

  final _input = TextEditingController();
  final _scroll = ScrollController();

  Timer? _debounce;

  bool _loading = true;
  String? _error;

  List<ProductDoc> _allProducts = <ProductDoc>[];
  List<ProductDoc> _recommended = <ProductDoc>[];

  // 情境/條件
  bool _needForElder = false;
  bool _needForKids = false;
  bool _needSOS = false;
  bool _needLocation = false;

  // 預算（0 表示不限制）
  int _budget = 0;

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

  // -------------------------
  // Firestore load (fallback)
  // -------------------------
  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) updatedAt（最常見）
      final snap = await _fs
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .limit(250)
          .get();

      _allProducts = snap.docs.map(ProductDoc.fromDoc).toList();
      _recomputeRecommendations();

      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      return;
    } catch (e1) {
      try {
        // 2) createdAt
        final snap = await _fs
            .collection('products')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(250)
            .get();

        _allProducts = snap.docs.map(ProductDoc.fromDoc).toList();
        _recomputeRecommendations();

        if (!mounted) {
          return;
        }
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      } catch (_) {
        try {
          // 3) no orderBy
          final snap = await _fs
              .collection('products')
              .where('isActive', isEqualTo: true)
              .limit(250)
              .get();

          _allProducts = snap.docs.map(ProductDoc.fromDoc).toList();
          _recomputeRecommendations();

          if (!mounted) {
            return;
          }
          setState(() {
            _loading = false;
            _error = '部分欄位排序不可用，已改用無排序載入。原錯誤：$e1';
          });
          return;
        } catch (e3) {
          if (!mounted) {
            return;
          }
          setState(() {
            _loading = false;
            _error = e3.toString();
          });
          return;
        }
      }
    }
  }

  // -------------------------
  // Input + Debounce
  // -------------------------
  void _onInputChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _recomputeRecommendations();
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _recomputeRecommendations() {
    if (_allProducts.isEmpty) {
      _recommended = <ProductDoc>[];
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final q = _input.text.trim().toLowerCase();

    final tokens = q
        .split(RegExp(r'\s+|,|，|、|/|\|'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    final scored = <_Scored<ProductDoc>>[];

    for (final p in _allProducts) {
      // 預算過濾（0 = 不限制）
      if (_budget > 0 && p.price > 0 && p.price > _budget) {
        continue;
      }

      final hay = <String>[
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

      if (_needForElder) {
        if (hay.contains('長輩') ||
            hay.contains('老人') ||
            hay.contains('照護') ||
            hay.contains('健康') ||
            hay.contains('心率') ||
            hay.contains('血氧') ||
            hay.contains('定位') ||
            hay.contains('sos') ||
            hay.contains('手錶')) {
          score += 3;
        }
      }

      if (_needForKids) {
        if (hay.contains('兒童') ||
            hay.contains('小孩') ||
            hay.contains('學生') ||
            hay.contains('防走失') ||
            hay.contains('定位') ||
            hay.contains('sos') ||
            hay.contains('手錶')) {
          score += 3;
        }
      }

      if (_needSOS) {
        if (hay.contains('sos') || hay.contains('求救') || hay.contains('緊急')) {
          score += 3;
        }
      }

      if (_needLocation) {
        if (hay.contains('定位') ||
            hay.contains('gps') ||
            hay.contains('追蹤') ||
            hay.contains('地圖') ||
            hay.contains('防走失')) {
          score += 3;
        }
      }

      if (tokens.isEmpty &&
          !_needForElder &&
          !_needForKids &&
          !_needSOS &&
          !_needLocation) {
        score += 1;
      }

      if (score > 0) {
        final price = p.price;
        if (price > 0) {
          if (price <= 2000) {
            score += 1;
          } else if (price <= 6000) {
            score += 2;
          } else if (price <= 12000) {
            score += 1;
          }
        }
        scored.add(_Scored<ProductDoc>(p, score));
      }
    }

    scored.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) {
        return s;
      }
      return a.item.price.compareTo(b.item.price); // 同分：價格較低優先
    });

    final top = scored.take(20).map((e) => e.item).toList(growable: false);
    _recommended = top.isEmpty ? _allProducts.take(12).toList() : top;

    if (mounted) {
      setState(() {});
    }
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 推薦中心'),
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
                _filters(cs),
                _inputBar(),
                if (_error != null) _warnBar(_error!),
                const Divider(height: 1),
                Expanded(child: _resultList(cs)),
              ],
            ),
    );
  }

  /// ✅ prefer_const_constructors + unnecessary_const 一次處理：
  /// - 最外層改成 const Padding
  /// - 內層不重複寫 const（避免 unnecessary_const）
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
              CircleAvatar(child: Icon(Icons.auto_awesome)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '選擇情境、輸入需求或設定預算，我會從商品資料中推薦更適合的選項。\n'
                  '例：要給長輩、要 SOS、需要定位、預算 3000 內。',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                selected: _needForElder,
                label: const Text('長輩'),
                onSelected: (v) {
                  setState(() => _needForElder = v);
                  _recomputeRecommendations();
                },
              ),
              FilterChip(
                selected: _needForKids,
                label: const Text('孩童'),
                onSelected: (v) {
                  setState(() => _needForKids = v);
                  _recomputeRecommendations();
                },
              ),
              FilterChip(
                selected: _needSOS,
                label: const Text('需要 SOS'),
                onSelected: (v) {
                  setState(() => _needSOS = v);
                  _recomputeRecommendations();
                },
              ),
              FilterChip(
                selected: _needLocation,
                label: const Text('需要定位'),
                onSelected: (v) {
                  setState(() => _needLocation = v);
                  _recomputeRecommendations();
                },
              ),
              ActionChip(
                label: const Text('清除條件'),
                avatar: const Icon(Icons.restart_alt, size: 18),
                onPressed: () {
                  setState(() {
                    _needForElder = false;
                    _needForKids = false;
                    _needSOS = false;
                    _needLocation = false;
                    _budget = 0;
                    _input.clear();
                  });
                  _recomputeRecommendations();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _budget <= 0 ? '預算：不限制' : '預算：NT\$ $_budget 以內',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  DropdownButton<int>(
                    value: _budget,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('不限制')),
                      DropdownMenuItem(value: 2000, child: Text('2000')),
                      DropdownMenuItem(value: 3000, child: Text('3000')),
                      DropdownMenuItem(value: 5000, child: Text('5000')),
                      DropdownMenuItem(value: 8000, child: Text('8000')),
                      DropdownMenuItem(value: 12000, child: Text('12000')),
                    ],
                    onChanged: (v) {
                      if (v == null) {
                        return;
                      }
                      setState(() => _budget = v);
                      _recomputeRecommendations();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
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
                hintText: '輸入需求（例如：要 SOS、定位、長輩用、預算 3000）',
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
              _recomputeRecommendations();
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
        child: Text(text, style: const TextStyle(color: Colors.brown)),
      ),
    );
  }

  Widget _resultList(ColorScheme cs) {
    if (_recommended.isEmpty) {
      return const Center(child: Text('目前沒有可推薦的商品'));
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: _recommended.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _productCard(cs, _recommended[i]),
    );
  }

  Widget _productCard(ColorScheme cs, ProductDoc p) {
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              p.description.isEmpty ? '（無描述）' : p.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _pill(cs, p.categoryId.isEmpty ? '未分類' : p.categoryId),
                if (p.tags.isNotEmpty) _pill(cs, 'tags ${p.tags.length}'),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'NT\$ ${p.price}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              p.isActive ? '上架' : '下架',
              style: TextStyle(
                color: p.isActive ? Colors.green : Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showProductDetail(p),
      ),
    );
  }

  Widget _pill(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(p.name.isEmpty ? '(未命名商品)' : p.name),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.imageUrl.trim().isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        p.imageUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(height: 180),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    '價格：NT\$ ${p.price}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  if (p.categoryId.trim().isNotEmpty) ...[
                    Text('類別：${p.categoryId}'),
                    const SizedBox(height: 6),
                  ],
                  Text(p.description.isEmpty ? '（無描述）' : p.description),
                  if (p.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: p.tags
                          .map((t) => Chip(label: Text(t)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }
}

/// ✅ Product model
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
    if (v is String && v.trim().isNotEmpty) return <String>[v.trim()];
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

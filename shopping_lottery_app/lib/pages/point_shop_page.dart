// lib/pages/point_shop_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ PointShopPage（點數商城｜最終完整版｜已修正 lint: curly_braces_in_flow_control_structures）
/// ------------------------------------------------------------
/// ✅ 修正重點：
/// - ✅ 移除 FirestoreMockService 依賴
/// - ✅ Firestore：users/{uid}.points、point_products、users/{uid}/point_redemptions
/// - ✅ 兌換：transaction 扣點 + 扣庫存(可選) + 寫入兌換紀錄
/// - ✅ lint：所有 if 單行語句改成 { } 區塊
class PointShopPage extends StatefulWidget {
  const PointShopPage({super.key});

  @override
  State<PointShopPage> createState() => _PointShopPageState();
}

class _PointShopPageState extends State<PointShopPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  final _search = TextEditingController();
  bool _onlyActive = true;
  bool _busy = false;

  User? get _user => _auth.currentUser;

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _fs.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _productsRef() =>
      _fs.collection('point_products');

  CollectionReference<Map<String, dynamic>> _redeemRef(String uid) =>
      _fs.collection('users').doc(uid).collection('point_redemptions');

  void _goLogin() {
    Navigator.of(context, rootNavigator: true).pushNamed('/login');
  }

  Future<void> _redeem({
    required String uid,
    required num userPoints,
    required String productId,
    required Map<String, dynamic> product,
  }) async {
    if (_busy) {
      return;
    }

    final name = _s(product['name'], '兌換商品');
    final cost = _asNum(product['costPoints'], fallback: 0);
    final stock = _asNum(product['stock'], fallback: 999999999);
    final isActive = (product['isActive'] ?? true) == true;

    if (!isActive) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此商品目前未開放兌換')));
      return;
    }
    if (cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品點數設定不正確（costPoints <= 0）')),
      );
      return;
    }
    if (userPoints < cost) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('點數不足（需要 $cost，目前 $userPoints）')));
      return;
    }
    if (stock <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('庫存不足')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認兌換'),
        content: Text('是否使用 $cost 點兌換「$name」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('兌換'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    setState(() => _busy = true);

    try {
      final userDoc = _userRef(uid);
      final productDoc = _productsRef().doc(productId);
      final redeemDoc = _redeemRef(uid).doc(); // auto id

      await _fs.runTransaction((tx) async {
        final userSnap = await tx.get(userDoc);
        final prodSnap = await tx.get(productDoc);

        final currentPoints = _asNum(userSnap.data()?['points'], fallback: 0);
        final p = prodSnap.data() ?? product;

        final currentStock = _asNum(p['stock'], fallback: 999999999);
        final currentActive = (p['isActive'] ?? true) == true;
        final currentCost = _asNum(p['costPoints'], fallback: cost);

        if (!currentActive) {
          throw Exception('商品已停用');
        }
        if (currentCost <= 0) {
          throw Exception('商品點數不正確');
        }
        if (currentPoints < currentCost) {
          throw Exception('點數不足');
        }
        if (currentStock <= 0) {
          throw Exception('庫存不足');
        }

        // 扣點
        tx.set(userDoc, {
          'points': currentPoints - currentCost,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 扣庫存（若你不想控庫存，移除此段）
        tx.set(productDoc, {
          'stock': currentStock - 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 建立兌換紀錄
        tx.set(redeemDoc, {
          'productId': productId,
          'name': _s(p['name'], name),
          'costPoints': currentCost,
          'qty': 1,
          'status': 'created',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 兌換成功')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('兌換失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('點數商城'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _busy ? null : () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: u == null ? _needLogin() : _content(u.uid),
    );
  }

  Widget _needLogin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能查看點數商城',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _goLogin, child: const Text('前往登入')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(String uid) {
    final userStream = _userRef(uid).snapshots();

    // 產品：可依你需求改排序欄位
    Query<Map<String, dynamic>> q = _productsRef();
    if (_onlyActive) {
      q = q.where('isActive', isEqualTo: true);
    }
    q = q.orderBy(FieldPath.documentId);

    final productStream = q.snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, userSnap) {
        if (userSnap.hasError) {
          return _errorBox('讀取點數失敗：${userSnap.error}');
        }
        if (!userSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnap.data!.data() ?? <String, dynamic>{};
        final points = _asNum(userData['points'], fallback: 0);

        return Column(
          children: [
            _topBar(points: points),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: productStream,
                builder: (context, pSnap) {
                  if (pSnap.hasError) {
                    return _errorBox('讀取商品失敗：${pSnap.error}');
                  }
                  if (!pSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = pSnap.data!.docs;
                  final keyword = _search.text.trim().toLowerCase();

                  final filtered = docs.where((doc) {
                    final d = doc.data();
                    final name = _s(d['name'], '').toLowerCase();
                    final desc = _s(d['description'], '').toLowerCase();
                    final match =
                        keyword.isEmpty ||
                        name.contains(keyword) ||
                        desc.contains(keyword) ||
                        doc.id.toLowerCase().contains(keyword);
                    return match;
                  }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [_empty('目前沒有可兌換商品（或搜尋不到）')],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final doc = filtered[i];
                      final d = doc.data();
                      final name = _s(d['name'], '兌換商品');
                      final cost = _asNum(d['costPoints'], fallback: 0);
                      final stock = _asNum(d['stock'], fallback: 999999999);
                      final imageUrl = _s(d['imageUrl'], '');
                      final desc = _s(d['description'], '');
                      final canRedeem =
                          !_busy && cost > 0 && points >= cost && stock > 0;

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _thumb(imageUrl),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '所需點數：$cost   庫存：${stock >= 999999999 ? "∞" : stock}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        desc,
                                        style: const TextStyle(
                                          color: Colors.blueGrey,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: canRedeem
                                                ? () => _redeem(
                                                    uid: uid,
                                                    userPoints: points,
                                                    productId: doc.id,
                                                    product: d,
                                                  )
                                                : null,
                                            child: Text(
                                              points >= cost ? '兌換' : '點數不足',
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
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _topBar({required num points}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜尋兌換商品（名稱/描述/ID）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('只看啟用'),
                selected: _onlyActive,
                onSelected: (v) => setState(() => _onlyActive = v),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.stars_outlined, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '我的點數：$points',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(String url) {
    if (url.trim().isEmpty) {
      return Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.redeem_outlined, color: Colors.grey),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _empty(String text) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

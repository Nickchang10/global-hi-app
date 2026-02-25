import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ FavoritesPage（我的收藏｜完整版｜移除 FirestoreMockService.fetchProductById）
/// ------------------------------------------------------------
/// 修正重點：
/// - 不使用 FirestoreMockService
/// - 直接從 Firestore 讀收藏與商品：
///   - users/{uid}/favorites/{productId}
///     - productId: String（可選，沒寫就用 doc.id）
///     - createdAt: Timestamp（可選）
///
///   - products/{productId}
///     - title / name: String
///     - imageUrl: String（可選）
///     - price: num（可選）
///     - isActive: bool（可選）
///
/// 注意：為了避免你資料缺欄位導致 runtime error，
/// 本頁不強制 orderBy（純 client-side 顯示）。
/// ------------------------------------------------------------
class FavoritesPage extends StatefulWidget {
  final String? uid;

  const FavoritesPage({super.key, this.uid});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _busy = false;

  User? get _user => _auth.currentUser;

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  CollectionReference<Map<String, dynamic>> _favoritesRef(String uid) =>
      _fs.collection('users').doc(uid).collection('favorites');

  DocumentReference<Map<String, dynamic>> _productRef(String productId) =>
      _fs.collection('products').doc(productId);

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid ?? _user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          if (uid != null)
            IconButton(
              tooltip: '清空收藏',
              onPressed: _busy ? null : () => _clearAll(uid),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: uid == null ? _needLogin(context) : _body(uid),
    );
  }

  Widget _needLogin(BuildContext context) {
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
                    '請先登入才能查看收藏',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/login'),
                    child: const Text('前往登入'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(String uid) {
    final stream = _favoritesRef(uid).limit(300).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return _error('讀取收藏失敗：${snap.error}');
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final favDocs = snap.data!.docs;

        if (favDocs.isEmpty) {
          return _empty('你目前沒有收藏任何商品');
        }

        // client-side sort：若 favorites 有 createdAt，就以 createdAt desc；沒有就照原序
        favDocs.sort((a, b) {
          final ta = a.data()['createdAt'];
          final tb = b.data()['createdAt'];
          DateTime? da;
          DateTime? db;
          if (ta is Timestamp) da = ta.toDate();
          if (tb is Timestamp) db = tb.toDate();
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: favDocs.length,
          itemBuilder: (context, i) {
            final fav = favDocs[i];
            final favData = fav.data();

            // ✅ productId 來源：優先欄位 productId，沒有就用 doc.id
            final productId = _s(favData['productId'], fav.id).trim();
            if (productId.isEmpty) {
              return _badFavTile(fav.id, uid);
            }

            return _favoriteProductTile(
              uid: uid,
              favoriteDocId: fav.id,
              productId: productId,
            );
          },
        );
      },
    );
  }

  Widget _badFavTile(String favDocId, String uid) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.error_outline)),
        title: const Text(
          '收藏資料異常',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('favoriteDocId=$favDocId（缺少 productId）'),
        trailing: IconButton(
          tooltip: '移除此筆',
          onPressed: _busy ? null : () => _removeFavorite(uid, favDocId),
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }

  Widget _favoriteProductTile({
    required String uid,
    required String favoriteDocId,
    required String productId,
  }) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _productRef(productId).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          // ✅ 修正：可 const 的 Card（消除 prefer_const_constructors）
          return const Card(
            elevation: 1,
            margin: EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(child: Icon(Icons.favorite)),
              title: Text('載入商品中…'),
              subtitle: Text('請稍候'),
            ),
          );
        }

        if (snap.hasError) {
          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.warning_amber_outlined),
              ),
              title: const Text(
                '商品讀取失敗',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('productId=$productId\n${snap.error}'),
              trailing: IconButton(
                tooltip: '移除此收藏',
                onPressed: _busy
                    ? null
                    : () => _removeFavorite(uid, favoriteDocId),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          );
        }

        final doc = snap.data;
        final data = doc?.data();

        if (doc == null || !doc.exists || data == null) {
          // 商品不存在：顯示可移除
          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.inventory_2_outlined),
              ),
              title: const Text(
                '商品不存在或已下架',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('productId=$productId'),
              trailing: IconButton(
                tooltip: '移除此收藏',
                onPressed: _busy
                    ? null
                    : () => _removeFavorite(uid, favoriteDocId),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          );
        }

        final title = _s(data['title'], _s(data['name'], '未命名商品'));
        final imageUrl = _s(data['imageUrl']).trim();
        final price = _asNum(data['price'], fallback: 0);
        final isActive = (data['isActive'] ?? true) == true;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: _thumb(imageUrl, title),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              [
                'ID：$productId',
                '價格：$price',
                if (!isActive) '狀態：可能已下架',
              ].join('  •  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '移除收藏',
                  onPressed: _busy
                      ? null
                      : () => _removeFavorite(uid, favoriteDocId),
                  icon: const Icon(Icons.favorite, color: Colors.red),
                ),
              ],
            ),
            onTap: () => _openProduct(productId),
          ),
        );
      },
    );
  }

  Widget _thumb(String imageUrl, String title) {
    if (imageUrl.isEmpty) {
      return CircleAvatar(
        child: Text(title.isNotEmpty ? title.substring(0, 1) : '?'),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          child: Text(title.isNotEmpty ? title.substring(0, 1) : '?'),
        ),
      ),
    );
  }

  void _openProduct(String productId) {
    // ✅ 不強依賴你是否有商品詳情路由：沒有就提示
    try {
      Navigator.of(
        context,
      ).pushNamed('/product', arguments: {'productId': productId});
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('尚未設定 /product 路由（productId=$productId）')),
      );
    }
  }

  Future<void> _removeFavorite(String uid, String favoriteDocId) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _favoritesRef(uid).doc(favoriteDocId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已移除收藏')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('移除失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearAll(String uid) async {
    if (_busy) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空收藏'),
        content: const Text('確定要清空所有收藏嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final snap = await _favoritesRef(uid).limit(500).get();
      final batch = _fs.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已清空收藏')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('清空失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _empty(String text) {
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
                  const Icon(
                    Icons.favorite_border,
                    size: 56,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _error(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(text, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

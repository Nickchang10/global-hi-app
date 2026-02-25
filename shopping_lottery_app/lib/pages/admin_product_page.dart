import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ AdminProductPage（後台商品管理｜前台專案內使用版）
/// ------------------------------------------------------------
/// 修正：移除 FirestoreMockService.addProduct（不存在）
/// 改為：直接對 Firestore collection('products') CRUD
///
/// Firestore: products/{productId}
/// 欄位建議：
/// - name (String)
/// - price (num)
/// - stock (int)
/// - isActive (bool)
/// - categoryId (String)
/// - imageUrl (String)
/// - description (String)
/// - createdAt / updatedAt (Timestamp)
/// ------------------------------------------------------------
class AdminProductPage extends StatefulWidget {
  const AdminProductPage({super.key});

  @override
  State<AdminProductPage> createState() => _AdminProductPageState();
}

class _AdminProductPageState extends State<AdminProductPage> {
  final _fs = FirebaseFirestore.instance;
  final _search = TextEditingController();

  String _query = '';
  bool _onlyActive = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream() {
    // 若你的 products 沒有 updatedAt 索引/欄位，會丟錯；這裡做 fallback：有 error 就改走 createdAt
    return _fs
        .collection('products')
        .orderBy('updatedAt', descending: true)
        .limit(200)
        .snapshots();
  }

  bool _match(ProductDoc p) {
    if (_onlyActive && !p.isActive) return false;
    if (_query.isEmpty) return true;

    final q = _query.toLowerCase();
    return p.name.toLowerCase().contains(q) ||
        p.id.toLowerCase().contains(q) ||
        p.categoryId.toLowerCase().contains(q);
  }

  Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await _fs.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      final role = (data['role'] ?? 'user').toString().toLowerCase();
      return role == 'admin';
    } catch (_) {
      // 如果你沒有 users/role 結構，就先讓他進（避免卡死）
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('商品管理')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('請先登入才能管理商品', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                FilledButton(
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
      );
    }

    return FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (context, snap) {
        final ok = snap.data ?? false;

        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!ok) {
          return Scaffold(
            appBar: AppBar(title: const Text('商品管理')),
            body: const Center(child: Text('你沒有權限（admin）')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('商品管理'),
            actions: [
              Row(
                children: [
                  const Text('只看上架', style: TextStyle(fontSize: 12)),
                  Switch(
                    value: _onlyActive,
                    onChanged: (v) => setState(() => _onlyActive = v),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              _searchBar(),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _productsStream(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      // fallback: 沒有 updatedAt 欄位時常見會拋錯
                      return _fallbackList();
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs;
                    final items = docs
                        .map((d) => ProductDoc.fromDoc(d))
                        .where(_match)
                        .toList();

                    if (items.isEmpty) {
                      return const Center(child: Text('沒有商品'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _productCard(items[i]),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: const Text('新增商品'),
          ),
        );
      },
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋：商品名 / 類別 / ID',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '清除',
            onPressed: () {
              _search.clear();
              setState(() => _query = '');
            },
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }

  Widget _fallbackList() {
    // 若 updatedAt 不存在，就改用 createdAt 排序顯示
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('讀取失敗：${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!.docs
            .map((d) => ProductDoc.fromDoc(d))
            .where(_match)
            .toList();
        if (items.isEmpty) return const Center(child: Text('沒有商品'));
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _productCard(items[i]),
        );
      },
    );
  }

  Widget _productCard(ProductDoc p) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumb(p.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.name.isEmpty ? '(未命名商品)' : p.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _pill(
                        p.isActive ? '上架' : '下架',
                        p.isActive ? Colors.green : Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '價格：${p.price}   庫存：${p.stock}   類別：${p.categoryId.isEmpty ? '-' : p.categoryId}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openEditor(product: p),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('編輯'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _deleteProduct(p),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('刪除'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _toggleActive(p),
                        child: Text(p.isActive ? '設為下架' : '設為上架'),
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
  }

  Widget _thumb(String url) {
    if (url.trim().isEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 64,
          height: 64,
          color: Colors.black.withValues(alpha: 0.05),
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _toggleActive(ProductDoc p) async {
    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出
    try {
      await _fs.collection('products').doc(p.id).set({
        'isActive': !p.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _deleteProduct(ProductDoc p) async {
    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出

    // ✅ Dart 3：不要用 builder: (_) 之後再 Navigator.pop(_, ...)
    // 改用 dialogContext
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除商品'),
        content: Text('確定刪除「${p.name}」嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _fs.collection('products').doc(p.id).delete();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已刪除商品')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  Future<void> _openEditor({ProductDoc? product}) async {
    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminProductEditPage(product: product)),
    );

    if (!mounted) return;
    if (result == 'updated') {
      messenger.showSnackBar(const SnackBar(content: Text('已更新商品')));
    } else if (result == 'created') {
      messenger.showSnackBar(const SnackBar(content: Text('已新增商品')));
    }
  }
}

/// ✅ 編輯/新增 商品頁
class AdminProductEditPage extends StatefulWidget {
  const AdminProductEditPage({super.key, this.product});

  final ProductDoc? product;

  @override
  State<AdminProductEditPage> createState() => _AdminProductEditPageState();
}

class _AdminProductEditPageState extends State<AdminProductEditPage> {
  final _fs = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _categoryId;
  late final TextEditingController _imageUrl;
  late final TextEditingController _description;

  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController(text: (p?.price ?? 0).toString());
    _stock = TextEditingController(text: (p?.stock ?? 0).toString());
    _categoryId = TextEditingController(text: p?.categoryId ?? '');
    _imageUrl = TextEditingController(text: p?.imageUrl ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    _categoryId.dispose();
    _imageUrl.dispose();
    _description.dispose();
    super.dispose();
  }

  num _parseNum(String s) => num.tryParse(s.trim()) ?? 0;
  int _parseInt(String s) => int.tryParse(s.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '編輯商品' : '新增商品'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('儲存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_name, label: '商品名稱', validator: _required),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _price,
                    label: '價格',
                    keyboard: TextInputType.number,
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    _stock,
                    label: '庫存',
                    keyboard: TextInputType.number,
                    validator: _required,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _field(_categoryId, label: '類別 ID（可空）'),
            const SizedBox(height: 10),
            _field(_imageUrl, label: '圖片 URL（可空）'),
            const SizedBox(height: 10),
            _field(_description, label: '描述（可空）', maxLines: 4),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: _saving ? null : (v) => setState(() => _isActive = v),
              title: const Text('上架'),
              subtitle: const Text('關閉則前台不顯示（下架）'),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_isEdit ? '儲存變更' : '建立商品'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) return '此欄位必填';
    return null;
  }

  Widget _field(
    TextEditingController c, {
    required String label,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出
    setState(() => _saving = true);

    try {
      final now = FieldValue.serverTimestamp();
      final id = widget.product?.id ?? _fs.collection('products').doc().id;

      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'price': _parseNum(_price.text),
        'stock': _parseInt(_stock.text),
        'categoryId': _categoryId.text.trim(),
        'imageUrl': _imageUrl.text.trim(),
        'description': _description.text.trim(),
        'isActive': _isActive,
        'updatedAt': now,
        if (!_isEdit) 'createdAt': now,
      };

      await _fs
          .collection('products')
          .doc(id)
          .set(data, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _saving = false);

      // ✅ 回傳結果給上一頁顯示 SnackBar（避免 pop 後用這頁 context）
      Navigator.pop(context, _isEdit ? 'updated' : 'created');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }
}

/// ✅ 商品資料 Model（避免 Map 到處散）
class ProductDoc {
  final String id;
  final String name;
  final num price;
  final int stock;
  final bool isActive;
  final String categoryId;
  final String imageUrl;
  final String description;

  ProductDoc({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.isActive,
    required this.categoryId,
    required this.imageUrl,
    required this.description,
  });

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  factory ProductDoc.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return ProductDoc(
      id: doc.id,
      name: (d['name'] ?? d['title'] ?? '').toString(),
      price: _asNum(d['price'] ?? d['amount'] ?? 0),
      stock: _asInt(d['stock'] ?? d['inventory'] ?? 0),
      isActive: (d['isActive'] ?? d['active'] ?? true) == true,
      categoryId: (d['categoryId'] ?? d['category'] ?? '').toString(),
      imageUrl: (d['imageUrl'] ?? d['coverUrl'] ?? d['image'] ?? '').toString(),
      description: (d['description'] ?? d['desc'] ?? '').toString(),
    );
  }
}

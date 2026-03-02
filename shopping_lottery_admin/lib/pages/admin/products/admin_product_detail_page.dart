// lib/pages/admin/products/admin_product_detail_page.dart
//
// ✅ AdminProductDetailPage（商品詳情｜最終完整版｜可編譯）
// ------------------------------------------------------------
// - Firestore: products/{productId}
// - 顯示：名稱 / 價格 / 狀態 / 庫存 / 分類 / 圖片 / 描述 / tags
// - 操作：上架/下架、調整庫存、快速編輯基本資料、編輯 tags、✅開啟完整編輯頁、✅刪除商品
// - ✅ FIX: withOpacity deprecated → withValues(alpha: 0~1)
// - Web/桌面/手機相容
//
// 路由建議：
// '/admin_product_detail': (_) => const AdminProductDetailPage(),
// Navigator.pushNamed(context, '/admin_product_detail', arguments: {'productId': id});

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Color _withOpacity(Color c, double opacity01) {
  final o = opacity01.clamp(0.0, 1.0).toDouble();
  return c.withValues(alpha: o);
}

class AdminProductDetailPage extends StatefulWidget {
  const AdminProductDetailPage({super.key});

  @override
  State<AdminProductDetailPage> createState() => _AdminProductDetailPageState();
}

class _AdminProductDetailPageState extends State<AdminProductDetailPage> {
  final _db = FirebaseFirestore.instance;

  String? _productId;
  String? _argError;

  final _money = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
  final _df = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_productId != null || _argError != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    String? pid;
    if (args is String) {
      pid = args.trim();
    } else if (args is Map) {
      final v = args['productId'] ?? args['id'];
      if (v != null) pid = v.toString().trim();
    }

    if (pid == null || pid.isEmpty) {
      setState(() {
        _argError =
            '缺少 productId 參數，請用 Navigator.pushNamed(..., arguments: {\'productId\': id})';
      });
      return;
    }

    setState(() => _productId = pid);
  }

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('products').doc(_productId!);

  // ===========================================================
  // Utils
  // ===========================================================
  num _asNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString()) ?? 0;
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  bool _asBool(dynamic v) => v == true;

  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  List<String> _strList(dynamic v) {
    if (v is! List) return const [];
    final out = <String>[];
    for (final x in v) {
      final t = (x ?? '').toString().trim();
      if (t.isNotEmpty) out.add(t);
    }
    return out;
  }

  List<String> _uniqueKeepOrder(List<String> input) {
    final seen = <String>{};
    final out = <String>[];
    for (final u in input) {
      final k = u.trim();
      if (k.isEmpty) continue;
      final key = k.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(k);
    }
    return out;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmText = '確認',
    bool danger = false,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger ? cs.error : null,
              foregroundColor: danger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<String?> _askText({
    required String title,
    required String hint,
    String initial = '',
    String confirmText = '儲存',
    int maxLines = 2,
  }) async {
    final c = TextEditingController(text: initial);
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    c.dispose();
    return res;
  }

  // ===========================================================
  // Actions
  // ===========================================================
  Future<void> _togglePublished(bool current) async {
    final ok = await _confirm(
      title: current ? '下架商品' : '上架商品',
      message: '確定要${current ? '下架' : '上架'}此商品嗎？\nproductId: $_productId',
      confirmText: current ? '下架' : '上架',
      danger: current,
    );
    if (!ok) return;

    try {
      await _ref.update({
        'published': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _snack(current ? '已下架' : '已上架');
    } catch (e) {
      if (!mounted) return;
      _snack('更新失敗：$e');
    }
  }

  Future<void> _editBasic(Map<String, dynamic> d) async {
    final name = _s(d['name'] ?? d['title']);
    final category = _s(d['categoryId'] ?? d['category']);
    final desc = _s(d['description']);
    final price = _asNum(d['price'] ?? d['salePrice']);

    final newName = await _askText(
      title: '編輯名稱（1/4）',
      hint: '商品名稱',
      initial: name,
      confirmText: '下一步',
      maxLines: 2,
    );
    if (newName == null) return;

    final newPriceStr = await _askText(
      title: '編輯價格（2/4）',
      hint: '價格（數字）',
      initial: price.toString(),
      confirmText: '下一步',
      maxLines: 1,
    );
    if (newPriceStr == null) return;
    final newPrice = num.tryParse(newPriceStr.trim()) ?? price;

    final newCategory = await _askText(
      title: '編輯分類（3/4）',
      hint: 'categoryId / category（可留空）',
      initial: category,
      confirmText: '下一步',
      maxLines: 1,
    );
    if (newCategory == null) return;

    final newDesc = await _askText(
      title: '編輯描述（4/4）',
      hint: '商品描述（可留空）',
      initial: desc,
      confirmText: '儲存',
      maxLines: 6,
    );
    if (newDesc == null) return;

    try {
      await _ref.update({
        'name': newName.trim(),
        'price': newPrice,
        'categoryId': newCategory.trim(),
        'description': newDesc.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _snack('基本資料已更新');
    } catch (e) {
      if (!mounted) return;
      _snack('更新失敗：$e');
    }
  }

  Future<void> _editStock(Map<String, dynamic> d) async {
    final stock = _asInt(d['stock'] ?? d['stockQty'] ?? d['inventory'] ?? 0);

    final res = await _askText(
      title: '調整庫存',
      hint: '輸入新的庫存數量（整數）',
      initial: stock.toString(),
      confirmText: '儲存',
      maxLines: 1,
    );
    if (res == null) return;

    final next = int.tryParse(res.trim());
    if (next == null) {
      _snack('庫存必須是整數');
      return;
    }

    try {
      await _ref.update({
        'stock': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _snack('庫存已更新');
    } catch (e) {
      if (!mounted) return;
      _snack('更新失敗：$e');
    }
  }

  Future<void> _editTags(List<String> tags) async {
    final res = await showDialog<List<String>>(
      context: context,
      builder: (_) => _TagsDialog(initial: tags),
    );
    if (res == null) return;

    try {
      await _ref.update({
        'tags': res,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _snack('Tags 已更新');
    } catch (e) {
      if (!mounted) return;
      _snack('更新失敗：$e');
    }
  }

  void _openFullEdit() {
    Navigator.pushNamed(
      context,
      '/admin_product_edit',
      arguments: {'productId': _productId},
    );
  }

  Future<void> _deleteProduct() async {
    final ok = await _confirm(
      title: '刪除商品',
      message: '確定要刪除此商品嗎？\n此動作無法復原。\nproductId: $_productId',
      confirmText: '刪除',
      danger: true,
    );
    if (!ok) return;

    try {
      await _ref.delete();
      if (!mounted) return;
      _snack('已刪除商品');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack('刪除失敗：$e');
    }
  }

  // ===========================================================
  // UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_argError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('商品詳情')),
        body: _ErrorView(
          title: '開啟失敗',
          message: _argError!,
          hint: '請確認你有傳入 productId 參數。',
          onRetry: () => Navigator.pop(context),
          retryText: '返回',
        ),
      );
    }

    if (_productId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '商品詳情：$_productId',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorView(
              title: '讀取失敗',
              message: snap.error.toString(),
              hint: '常見原因：products 權限不足、文件不存在、欄位型別錯誤。',
              onRetry: () => setState(() {}),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snap.data!;
          if (!doc.exists) {
            return _ErrorView(
              title: '商品不存在',
              message: '找不到此 productId 的 products 文件：$_productId',
              hint: '請確認 products/{productId} 是否存在。',
              onRetry: () => Navigator.pop(context),
              retryText: '返回',
            );
          }

          final d = doc.data() ?? <String, dynamic>{};

          final name = _s(d['name'] ?? d['title']);
          final price = _asNum(d['price'] ?? d['salePrice'] ?? 0);
          final published = _asBool(d['published'] ?? d['isPublished']);
          final stock = _asInt(
            d['stock'] ?? d['stockQty'] ?? d['inventory'] ?? 0,
          );

          final category = _s(d['categoryId'] ?? d['category']);
          final desc = _s(d['description']);
          final tags = _strList(d['tags']);

          // ✅ 封面優先 imageUrl，再接 images，並去重
          final imageUrl = _s(d['imageUrl']);
          final images = _strList(d['images'] ?? d['imageUrls']);
          final allImages = _uniqueKeepOrder([
            if (imageUrl.isNotEmpty) imageUrl,
            ...images,
          ]);
          final cover = allImages.isNotEmpty ? allImages.first : '';

          final createdAt = _toDt(d['createdAt']);
          final updatedAt = _toDt(d['updatedAt']);

          final statusColor = published ? cs.primary : cs.error;
          final statusText = published ? '上架中' : '未上架';

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.isEmpty ? '（未命名商品）' : name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _withOpacity(statusColor, 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _withOpacity(statusColor, 0.35),
                              ),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _pill('價格', _money.format(price)),
                          _pill('庫存', '$stock'),
                          _pill('分類', category.isEmpty ? '—' : category),
                        ],
                      ),
                      if (createdAt != null || updatedAt != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          [
                            if (createdAt != null)
                              '建立：${_df.format(createdAt)}',
                            if (updatedAt != null)
                              '更新：${_df.format(updatedAt)}',
                          ].join('  •  '),
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _togglePublished(published),
                            icon: Icon(
                              published
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            label: Text(published ? '下架' : '上架'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _editStock(d),
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('調整庫存'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _editBasic(d),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('快速編輯'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _editTags(tags),
                            icon: const Icon(Icons.sell_outlined),
                            label: const Text('編輯 Tags'),
                          ),
                          FilledButton.icon(
                            onPressed: _openFullEdit,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('完整編輯頁'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _deleteProduct,
                            icon: Icon(Icons.delete_outline, color: cs.error),
                            label: Text(
                              '刪除',
                              style: TextStyle(color: cs.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (cover.isNotEmpty || allImages.isNotEmpty) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '圖片',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (cover.isNotEmpty)
                          _ImageTile(url: cover)
                        else
                          Text(
                            '（無封面）',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        if (allImages.length > 1) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final u in allImages.skip(1).take(10))
                                SizedBox(width: 160, child: _ImageTile(url: u)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '描述',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        desc.isEmpty ? '—' : desc,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tags',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (tags.isEmpty)
                        Text('—', style: TextStyle(color: cs.onSurfaceVariant))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in tags)
                              _Tag(text: t, color: cs.primary),
                          ],
                        ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => _editTags(tags),
                        icon: const Icon(Icons.edit),
                        label: const Text('編輯 Tags'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pill(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
      ),
      child: Text(
        '$k：$v',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TagsDialog extends StatefulWidget {
  final List<String> initial;
  const _TagsDialog({required this.initial});

  @override
  State<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends State<_TagsDialog> {
  late List<String> tags;
  final TextEditingController _add = TextEditingController();

  @override
  void initState() {
    super.initState();
    tags = [...widget.initial]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  void _addTag(String t) {
    final s = t.trim();
    if (s.isEmpty) return;
    if (tags.map((e) => e.toLowerCase()).contains(s.toLowerCase())) return;
    setState(() {
      tags.add(s);
      tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
  }

  void _removeTag(String t) {
    setState(() => tags.removeWhere((e) => e.toLowerCase() == t.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '編輯 Tags',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _add,
                      decoration: InputDecoration(
                        hintText: '新增 Tag（例如：熱賣 / 新品 / 限量）',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (v) {
                        _addTag(v);
                        _add.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      _addTag(_add.text);
                      _add.clear();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('加入'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '目前 Tags',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (tags.isEmpty)
                const Text('（尚無 Tags）', style: TextStyle(color: Colors.black54))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tags)
                      InputChip(label: Text(t), onDeleted: () => _removeTag(t)),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, tags),
          icon: const Icon(Icons.check),
          label: const Text('套用'),
        ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Container(
          color: _withOpacity(cs.primary, 0.06),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Text(
                '圖片載入失敗',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes == null
                      ? null
                      : progress.cumulativeBytesLoaded /
                            (progress.expectedTotalBytes ?? 1),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;
  final VoidCallback onRetry;
  final String retryText;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
    this.retryText = '重試',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(retryText),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _withOpacity(c, 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _withOpacity(c, 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w800),
      ),
    );
  }
}

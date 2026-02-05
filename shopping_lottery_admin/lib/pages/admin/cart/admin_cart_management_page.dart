// lib/pages/admin/cart/admin_cart_management_page.dart
//
// ✅ AdminCartManagementPage（最終完整版｜可編譯｜Firestore 泛型修正）
// ------------------------------------------------------------
// - 後台購物車管理：列出 carts 集合
// - 支援搜尋（userId / userName）
// - 詳情 Dialog：顯示商品明細、總金額、更新時間
// - 管理操作：清空購物車 / 刪除購物車（可選）
// ------------------------------------------------------------
// Firestore 資料結構建議：
// carts/{cartId}
// {
//   userId: "xxx",
//   userName: "王小明",
//   status: "active" | "abandoned",
//   total: 1234,
//   items: [
//     { productId, productName, qty, price }
//   ],
//   updatedAt: Timestamp
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminCartManagementPage extends StatefulWidget {
  const AdminCartManagementPage({super.key});

  @override
  State<AdminCartManagementPage> createState() => _AdminCartManagementPageState();
}

class _AdminCartManagementPageState extends State<AdminCartManagementPage> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  String? _error;

  final TextEditingController _search = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await _db
          .collection('carts')
          .orderBy('updatedAt', descending: true)
          .limit(300)
          .get();

      setState(() {
        _docs = snap.docs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filteredDocs {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _docs;
    return _docs.where((doc) {
      final d = doc.data();
      return (d['userName'] ?? '').toString().toLowerCase().contains(q) ||
          (d['userId'] ?? '').toString().toLowerCase().contains(q) ||
          doc.id.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('購物車管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? _ErrorView(
                  title: '載入失敗',
                  message: _error!,
                  onRetry: _load,
                  hint: '請確認 carts 集合是否存在且欄位型別正確。',
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: '搜尋 cartId / userId / userName',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filteredDocs.isEmpty
                          ? const Center(child: Text('目前沒有購物車資料'))
                          : ListView.builder(
                              itemCount: _filteredDocs.length,
                              itemBuilder: (context, i) {
                                final doc = _filteredDocs[i];
                                final d = doc.data();

                                final user = (d['userName'] ?? '未知使用者').toString();
                                final id = (d['userId'] ?? '').toString();
                                final status = (d['status'] ?? '').toString();
                                final total = d['total'] ?? 0;
                                final items = (d['items'] as List?) ?? [];
                                final updated = _toDateTime(d['updatedAt']);

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: cs.primaryContainer,
                                      child: Text('${items.length}',
                                          style: TextStyle(
                                              color: cs.onPrimaryContainer,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(user, style: const TextStyle(fontWeight: FontWeight.w900)),
                                    subtitle: Text([
                                      if (id.isNotEmpty) 'userId: $id',
                                      if (status.isNotEmpty) '狀態: $status',
                                      if (updated != null) '更新: ${DateFormat('MM/dd HH:mm').format(updated)}',
                                    ].join('  •  ')),
                                    trailing: Text('NT\$${total.toString()}',
                                        style: const TextStyle(fontWeight: FontWeight.w900)),
                                    onTap: () => _showCartDetail(doc),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  // ------------------------------------------------------------
  // 詳細 Dialog
  // ------------------------------------------------------------
  Future<void> _showCartDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    final fmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final items = (d['items'] as List?) ?? [];
    final total = _asNum(d['total']);
    final updated = _toDateTime(d['updatedAt']);
    final updatedText = updated == null ? '' : DateFormat('yyyy/MM/dd HH:mm').format(updated);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('購物車明細（${d['userName'] ?? '未知用戶'}）'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cart ID: ${doc.id}'),
                if ((d['userId'] ?? '').toString().isNotEmpty) Text('User ID: ${d['userId']}'),
                if ((d['status'] ?? '').toString().isNotEmpty) Text('狀態: ${d['status']}'),
                if (updatedText.isNotEmpty) Text('更新時間: $updatedText'),
                const Divider(height: 24),
                Text('商品清單（${items.length}）', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                if (items.isEmpty)
                  const Text('無商品資料')
                else
                  ...items.map((raw) {
                    final item = _asMap(raw);
                    final name = (item['productName'] ?? item['name'] ?? '未命名').toString();
                    final qty = _asInt(item['qty'] ?? item['quantity'] ?? 1);
                    final price = _asNum(item['price'] ?? item['unitPrice'] ?? 0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text('• $name ×$qty')),
                          Text(fmt.format(price * qty)),
                        ],
                      ),
                    );
                  }),
                const Divider(height: 24),
                Text('總金額：${fmt.format(total)}',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
          FilledButton.tonalIcon(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmClearCart(doc);
            },
            icon: const Icon(Icons.remove_shopping_cart),
            label: const Text('清空購物車'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmDeleteCart(doc);
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // 管理操作
  // ------------------------------------------------------------
  Future<void> _confirmClearCart(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await _confirm(
      title: '清空購物車',
      message: '確定要清空此購物車嗎？\nCart: ${doc.id}',
      confirmText: '清空',
    );
    if (ok != true) return;
    try {
      await doc.reference.update({
        'items': [],
        'total': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空購物車')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('清空失敗：$e')));
    }
  }

  Future<void> _confirmDeleteCart(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await _confirm(
      title: '刪除購物車',
      message: '確定要刪除此購物車嗎？\nCart: ${doc.id}',
      confirmText: '刪除',
      isDanger: true,
    );
    if (ok != true) return;
    try {
      await doc.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除購物車')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool isDanger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDanger ? cs.error : null,
              foregroundColor: isDanger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Utils
  // ------------------------------------------------------------
  Map<String, dynamic> _asMap(dynamic v) => (v is Map<String, dynamic>) ? v : {};
  int _asInt(dynamic v) => (v is int) ? v : int.tryParse(v.toString()) ?? 0;
  num _asNum(dynamic v) => (v is num) ? v : num.tryParse(v.toString()) ?? 0;
  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}

// ------------------------------------------------------------
// Error View
// ------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? hint;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Card(
          margin: const EdgeInsets.all(20),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 44, color: cs.error),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
              if (hint != null) ...[
                const SizedBox(height: 8),
                Text(hint!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重試'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

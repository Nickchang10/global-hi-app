// lib/pages/admin/cart/admin_carts_page.dart
//
// ✅ AdminCartsPage（單檔完整版｜可編譯可用｜已修正 unreachable_switch_default）
// ------------------------------------------------------------
// Firestore：carts（collection）
// - docId 建議：uid（或 cartId）
// - 結構示例（可依你現況調整）：
// carts/{uid} {
//   uid: "xxx",
//   updatedAt: Timestamp,
//   createdAt: Timestamp,
//   items: [
//     {
//       productId: "p1",
//       title: "商品A",
//       sku: "SKU001",
//       price: 1990,         // int
//       qty: 2,              // int
//       imageUrl: "...",     // string
//       vendorId: "v1"       // string
//     }
//   ],
//   note: "",
// }
//
// 功能：
// 1) carts 清單（Stream）
// 2) 搜尋（uid / productId / title / sku / vendorId）
// 3) 查看某台購物車 items 詳細
// 4) 編輯 qty / 刪除 item / 清空 carts/items
// 5) 複製 uid / productId
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminCartsPage extends StatefulWidget {
  const AdminCartsPage({super.key});

  @override
  State<AdminCartsPage> createState() => _AdminCartsPageState();
}

class _AdminCartsPageState extends State<AdminCartsPage> {
  final _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col = _db.collection(
    'carts',
  );

  final _search = TextEditingController();
  CartFilter _filter = CartFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final query = _col.orderBy(FieldPath.documentId).limit(300);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '購物車管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              title: '載入失敗',
              message: snap.error.toString(),
              hint: '請確認 Firestore rules 是否允許 admin 讀取 carts。',
              onRetry: () => setState(() {}),
            );
          }

          final docs = snap.data?.docs ?? const [];
          final carts = docs.map((d) => AdminCart.fromDoc(d)).toList();

          carts.sort((a, b) {
            final atA =
                a.updatedAt ??
                a.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final atB =
                b.updatedAt ??
                b.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return atB.compareTo(atA);
          });

          final filtered = _applyFilter(carts, _search.text, _filter);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _HeaderCard(
                total: carts.length,
                showing: filtered.length,
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '搜尋 uid / title / productId / sku / vendorId',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '沒有符合條件的購物車。',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                ...filtered.map(
                  (c) => _CartTile(
                    cart: c,
                    onCopyUid: () => _copy(c.uid),
                    onOpen: () => _openCartDetail(c.uid),
                    onClear: () => _clearCart(c.uid),
                    onDeleteDoc: () => _deleteCartDoc(c.uid),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<AdminCart> _applyFilter(
    List<AdminCart> list,
    String query,
    CartFilter filter,
  ) {
    final q = query.trim().toLowerCase();
    Iterable<AdminCart> out = list;

    if (filter == CartFilter.hasItems) {
      out = out.where((c) => c.items.isNotEmpty);
    } else if (filter == CartFilter.empty) {
      out = out.where((c) => c.items.isEmpty);
    }

    if (q.isNotEmpty) {
      out = out.where((c) {
        if (c.uid.toLowerCase().contains(q)) return true;
        for (final it in c.items) {
          if (it.productId.toLowerCase().contains(q)) return true;
          if (it.title.toLowerCase().contains(q)) return true;
          if (it.sku.toLowerCase().contains(q)) return true;
          if (it.vendorId.toLowerCase().contains(q)) return true;
        }
        return false;
      });
    }

    return out.toList();
  }

  Future<void> _openCartDetail(String uid) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminCartDetailPage(uid: uid)),
    );
  }

  Future<void> _clearCart(String uid) async {
    final ok = await _confirm(
      title: '清空購物車',
      message: '確定要清空該購物車 items？\n\nuid: $uid\n\n此操作無法復原。',
      confirmText: '清空',
      danger: true,
    );
    if (ok != true) return;

    try {
      await _col.doc(uid).set({
        'items': [],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _toast('已清空：$uid');
    } catch (e) {
      _toast('清空失敗：$e');
    }
  }

  Future<void> _deleteCartDoc(String uid) async {
    final ok = await _confirm(
      title: '刪除購物車文件',
      message: '確定刪除 carts/$uid ？\n\n此操作無法復原。',
      confirmText: '刪除',
      danger: true,
    );
    if (ok != true) return;

    try {
      await _col.doc(uid).delete();
      _toast('已刪除：$uid');
    } catch (e) {
      _toast('刪除失敗：$e');
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('已複製：$text');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
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
  }
}

// =========================== Detail Page ===========================

class AdminCartDetailPage extends StatefulWidget {
  final String uid;

  const AdminCartDetailPage({super.key, required this.uid});

  @override
  State<AdminCartDetailPage> createState() => _AdminCartDetailPageState();
}

class _AdminCartDetailPageState extends State<AdminCartDetailPage> {
  final _db = FirebaseFirestore.instance;

  late final DocumentReference<Map<String, dynamic>> _doc = _db
      .collection('carts')
      .doc(widget.uid);

  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '購物車：${widget.uid}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '複製 uid',
            icon: const Icon(Icons.copy),
            onPressed: () => _copy(widget.uid),
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _doc.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              title: '載入失敗',
              message: snap.error.toString(),
              onRetry: () => setState(() {}),
            );
          }

          final data = snap.data?.data();
          if (data == null) {
            return _EmptyView(
              title: '購物車不存在',
              message: 'carts/${widget.uid} 沒有資料（可能已被刪除）。',
            );
          }

          final cart = AdminCart.fromMap(widget.uid, data);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _CartMetaCard(cart: cart),
              const SizedBox(height: 12),
              if (cart.items.isEmpty)
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '此購物車沒有 items。',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                ...cart.items.map(
                  (it) => _CartItemTile(
                    item: it,
                    onCopyProductId: () => _copy(it.productId),
                    onRemove: _saving ? null : () => _removeItem(cart, it),
                    onChangeQty: _saving
                        ? null
                        : (qty) => _updateQty(cart, it, qty),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('清空 items'),
                      onPressed: _saving ? null : () => _clearItems(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? '更新中...' : '同步更新時間'),
                      onPressed: _saving ? null : _touch,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _touch() async {
    setState(() => _saving = true);
    try {
      await _doc.set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _toast('已更新時間');
    } catch (e) {
      _toast('更新失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearItems() async {
    final ok = await _confirm(
      title: '清空 items',
      message: '確定清空 carts/${widget.uid} 的 items？\n\n此操作無法復原。',
      confirmText: '清空',
      danger: true,
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await _doc.set({
        'items': [],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _toast('已清空 items');
    } catch (e) {
      _toast('清空失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeItem(AdminCart cart, AdminCartItem it) async {
    final ok = await _confirm(
      title: '移除商品',
      message: '確定從購物車移除？\n\nproductId: ${it.productId}\n${it.title}',
      confirmText: '移除',
      danger: true,
    );
    if (ok != true) return;

    final next = cart.items.where((e) => e.productId != it.productId).toList();

    setState(() => _saving = true);
    try {
      await _doc.set({
        'items': next.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _toast('已移除');
    } catch (e) {
      _toast('移除失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateQty(AdminCart cart, AdminCartItem it, int qty) async {
    if (qty <= 0) {
      _toast('數量需 > 0');
      return;
    }

    final next = cart.items.map((e) {
      if (e.productId == it.productId) return e.copyWith(qty: qty);
      return e;
    }).toList();

    setState(() => _saving = true);
    try {
      await _doc.set({
        'items': next.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _toast('已更新數量');
    } catch (e) {
      _toast('更新失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('已複製：$text');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
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
  }
}

// =========================== Models ===========================

class AdminCart {
  final String uid;
  final List<AdminCartItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String note;

  AdminCart({
    required this.uid,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    required this.note,
  });

  factory AdminCart.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AdminCart.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  factory AdminCart.fromMap(String uid, Map<String, dynamic> m) {
    DateTime? toDt(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    final rawItems = (m['items'] is List) ? (m['items'] as List) : const [];
    final items = <AdminCartItem>[];
    for (final e in rawItems) {
      if (e is Map<String, dynamic>) {
        items.add(AdminCartItem.fromMap(e));
      } else if (e is Map) {
        items.add(AdminCartItem.fromMap(Map<String, dynamic>.from(e)));
      }
    }

    return AdminCart(
      uid: (m['uid'] ?? uid).toString(),
      items: items,
      createdAt: toDt(m['createdAt']),
      updatedAt: toDt(m['updatedAt']),
      note: (m['note'] ?? '').toString(),
    );
  }
}

class AdminCartItem {
  final String productId;
  final String title;
  final String sku;
  final int price;
  final int qty;
  final String imageUrl;
  final String vendorId;

  AdminCartItem({
    required this.productId,
    required this.title,
    required this.sku,
    required this.price,
    required this.qty,
    required this.imageUrl,
    required this.vendorId,
  });

  AdminCartItem copyWith({
    String? productId,
    String? title,
    String? sku,
    int? price,
    int? qty,
    String? imageUrl,
    String? vendorId,
  }) {
    return AdminCartItem(
      productId: productId ?? this.productId,
      title: title ?? this.title,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      imageUrl: imageUrl ?? this.imageUrl,
      vendorId: vendorId ?? this.vendorId,
    );
  }

  factory AdminCartItem.fromMap(Map<String, dynamic> m) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return AdminCartItem(
      productId: (m['productId'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      sku: (m['sku'] ?? '').toString(),
      price: toInt(m['price']),
      qty: toInt(m['qty']),
      imageUrl: (m['imageUrl'] ?? '').toString(),
      vendorId: (m['vendorId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'title': title,
    'sku': sku,
    'price': price,
    'qty': qty,
    'imageUrl': imageUrl,
    'vendorId': vendorId,
  };
}

// =========================== UI Widgets ===========================

enum CartFilter { all, hasItems, empty }

class _HeaderCard extends StatelessWidget {
  final int total;
  final int showing;
  final CartFilter filter;
  final ValueChanged<CartFilter> onFilterChanged;

  const _HeaderCard({
    required this.total,
    required this.showing,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ 修正：列完 enum 全部 case，就不要 default（避免 unreachable_switch_default）
    String label(CartFilter f) {
      switch (f) {
        case CartFilter.all:
          return '全部';
        case CartFilter.hasItems:
          return '有商品';
        case CartFilter.empty:
          return '空購物車';
      }
    }

    CartFilter? byLabel(String s) {
      for (final f in CartFilter.values) {
        if (label(f) == s) return f;
      }
      return null;
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              child: Icon(
                Icons.shopping_cart_outlined,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '購物車清單',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '共 $total 筆｜目前顯示 $showing 筆',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<String>(
              value: label(filter),
              onChanged: (v) {
                final f = v == null ? null : byLabel(v);
                if (f != null) onFilterChanged(f);
              },
              items: CartFilter.values
                  .map(
                    (f) => DropdownMenuItem(
                      value: label(f),
                      child: Text(label(f)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  final AdminCart cart;
  final VoidCallback onCopyUid;
  final VoidCallback onOpen;
  final VoidCallback onClear;
  final VoidCallback onDeleteDoc;

  const _CartTile({
    required this.cart,
    required this.onCopyUid,
    required this.onOpen,
    required this.onClear,
    required this.onDeleteDoc,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String fmtDt(DateTime? dt) {
      if (dt == null) return '—';
      return DateFormat('yyyy/MM/dd HH:mm').format(dt);
    }

    final totalQty = cart.items.fold<int>(0, (p, e) => p + e.qty);
    final totalAmount = cart.items.fold<int>(
      0,
      (p, e) => p + (e.price * e.qty),
    );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cart.items.isEmpty
              ? Colors.grey.shade200
              : cs.primaryContainer,
          child: Icon(
            cart.items.isEmpty
                ? Icons.remove_shopping_cart_outlined
                : Icons.shopping_cart_outlined,
            color: cart.items.isEmpty
                ? Colors.grey.shade600
                : cs.onPrimaryContainer,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                cart.uid,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cart.items.isEmpty
                    ? Colors.grey.shade200
                    : Colors.green.shade100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                cart.items.isEmpty ? '空' : '${cart.items.length} 項',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: cart.items.isEmpty
                      ? cs.onSurfaceVariant
                      : Colors.green.shade900,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          'qty=$totalQty  •  amount=$totalAmount\n'
          'updatedAt=${fmtDt(cart.updatedAt)}  •  createdAt=${fmtDt(cart.createdAt)}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (v) {
            if (v == 'copy') onCopyUid();
            if (v == 'open') onOpen();
            if (v == 'clear') onClear();
            if (v == 'delete') onDeleteDoc();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  Icon(Icons.copy),
                  SizedBox(width: 10),
                  Text('複製 uid'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.open_in_new),
                  SizedBox(width: 10),
                  Text('查看'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep_outlined),
                  SizedBox(width: 10),
                  Text('清空 items'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: cs.error),
                  const SizedBox(width: 10),
                  const Text(
                    '刪除文件',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

class _CartMetaCard extends StatelessWidget {
  final AdminCart cart;

  const _CartMetaCard({required this.cart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String fmtDt(DateTime? dt) {
      if (dt == null) return '—';
      return DateFormat('yyyy/MM/dd HH:mm').format(dt);
    }

    final totalQty = cart.items.fold<int>(0, (p, e) => p + e.qty);
    final totalAmount = cart.items.fold<int>(
      0,
      (p, e) => p + (e.price * e.qty),
    );

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '購物車概況',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'uid：${cart.uid}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'items：${cart.items.length} 項  •  qty=$totalQty  •  amount=$totalAmount',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'updatedAt：${fmtDt(cart.updatedAt)}',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'createdAt：${fmtDt(cart.createdAt)}',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (cart.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'note：${cart.note}',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final AdminCartItem item;
  final VoidCallback onCopyProductId;
  final VoidCallback? onRemove;
  final ValueChanged<int>? onChangeQty;

  const _CartItemTile({
    required this.item,
    required this.onCopyProductId,
    required this.onRemove,
    required this.onChangeQty,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final amount = item.price * item.qty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Icon(
                Icons.inventory_2_outlined,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title.isEmpty ? '(未命名商品)' : item.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // ✅ 正確顯示 NT$，並避免 $ 被當成字串插值
                      Text(
                        'NT\$ $amount',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'productId=${item.productId}  •  sku=${item.sku.isEmpty ? "—" : item.sku}',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'vendorId=${item.vendorId.isEmpty ? "—" : item.vendorId}  •  price=${item.price}',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: onCopyProductId,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('複製 productId'),
                      ),
                      const SizedBox(width: 10),
                      _QtyStepper(value: item.qty, onChanged: onChangeQty),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: '移除',
              onPressed: onRemove,
              icon: Icon(
                Icons.delete_outline,
                color: onRemove == null ? cs.outline : cs.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;

  const _QtyStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '減少',
          onPressed: (!enabled || value <= 1)
              ? null
              : () => onChanged!(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 34,
          child: Center(
            child: Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        IconButton(
          tooltip: '增加',
          onPressed: !enabled ? null : () => onChanged!(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyView({required this.title, required this.message});

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
                  Icon(Icons.info_outline, size: 44, color: cs.primary),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ✅ 訂單詳情頁面
import 'admin_order_detail_page.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  bool _selectionMode = false;
  final Set<String> _selected = {};

  // 訂單狀態篩選
  static const String _statusAll = 'all';
  static const String _statusPending = 'pending';  // 付款待處理
  static const String _statusPaid = 'paid';  // 已付款
  static const String _statusShipped = 'shipped'; // 已出貨
  String _statusFilterKey = _statusAll;

  // 訂單日期篩選
  DateTime? _fromDate;
  DateTime? _toDate;

  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 訂單的查詢語句，支持狀態篩選和時間篩選
  Query<Map<String, dynamic>> _baseQuery() {
    var query = _db.collection('orders').orderBy('createdAt', descending: true);

    // 篩選狀態
    if (_statusFilterKey != _statusAll) {
      query = query.where('status', isEqualTo: _statusFilterKey);
    }

    // 篩選日期
    if (_fromDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: _fromDate);
    }
    if (_toDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: _toDate);
    }

    return query;
  }

  // ------------------------------------------------------------
  // 訂單卡片
  // ------------------------------------------------------------
  Widget _buildOrderTile(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final orderId = doc.id;
    final customerName = d['customerName'] ?? '未知客戶';
    final status = d['status'] ?? '未知狀態';
    final total = d['total'] ?? 0;
    final createdAt = d['createdAt'] != null
        ? (d['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    final selected = _selected.contains(orderId);

    return ListTile(
      leading: CircleAvatar(child: Text(orderId.substring(0, 2).toUpperCase())),
      title: Text(customerName),
      subtitle: Text('訂單號：$orderId\n狀態：$status'),
      trailing: Text(_moneyFmt.format(total)),
      onTap: () => _openOrderDetailPage(doc),
      selected: selected,
      onLongPress: () {
        setState(() {
          _selectionMode = true;
          _selected.add(orderId);
        });
      },
    );
  }

  // ------------------------------------------------------------
  // 篩選條
  // ------------------------------------------------------------
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋訂單 ID 或 客戶名稱',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _statusFilterKey,
              onChanged: (value) {
                setState(() {
                  _statusFilterKey = value ?? _statusAll;
                });
              },
              items: const [
                DropdownMenuItem(value: _statusAll, child: Text('全部')),
                DropdownMenuItem(value: _statusPending, child: Text('待付款')),
                DropdownMenuItem(value: _statusPaid, child: Text('已付款')),
                DropdownMenuItem(value: _statusShipped, child: Text('已出貨')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // 更新訂單狀態
  // ------------------------------------------------------------
  Future<void> _updateOrderStatus(DocumentSnapshot<Map<String, dynamic>> doc, String newStatus) async {
    try {
      await doc.reference.update({'status': newStatus});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('訂單狀態已更新為：$newStatus')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  // ------------------------------------------------------------
  // 批次操作
  // ------------------------------------------------------------
  Future<void> _confirmBatchDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除選取訂單？'),
        content: Text('共選取 ${_selected.length} 筆，刪除後無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final batch = _db.batch();
    for (final orderId in _selected) {
      batch.delete(_db.collection('orders').doc(orderId));
    }
    await batch.commit();

    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除選取訂單')));
  }

  // ------------------------------------------------------------
  // 訂單詳情頁面
  // ------------------------------------------------------------
  Future<void> _openOrderDetailPage(DocumentSnapshot<Map<String, dynamic>> doc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminOrderDetailPage(doc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _baseQuery();

    return Scaffold(
      appBar: AppBar(
        title: const Text('訂單管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: '批次刪除',
              icon: const Icon(Icons.delete),
              onPressed: _selected.isEmpty ? null : _confirmBatchDelete,
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('新增訂單'),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>( 
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('載入失敗：${snapshot.error}'));
                }

                final data = snapshot.data?.docs ?? [];
                if (data.isEmpty) {
                  return const Center(child: Text('目前沒有訂單資料'));
                }

                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final doc = data[index];
                    return _buildOrderTile(doc);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminOrderDetailPage extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;

  const AdminOrderDetailPage(this.doc, {super.key});

  @override
  Widget build(BuildContext context) {
    final data = doc.data()!;
    final orderId = doc.id;
    final customerName = data['customerName'] ?? '未知客戶';
    final total = data['total'] ?? 0;
    final status = data['status'] ?? '未知狀態';
    final items = data['items'] ?? [];

    return Scaffold(
      appBar: AppBar(title: Text('訂單詳情：$orderId')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('訂單ID: $orderId', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('顧客名稱: $customerName'),
            Text('訂單狀態: $status'),
            Text('總金額: NT\$${total.toString()}'),
            const Divider(height: 24),
            const Text('商品明細:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  return ListTile(
                    title: Text(item['productName']),
                    subtitle: Text('數量: ${item['quantity']}'),
                    trailing: Text('NT\$${item['price']}'),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  } 
}

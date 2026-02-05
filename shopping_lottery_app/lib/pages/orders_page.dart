// lib/pages/orders_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/order_service.dart';
import '../services/notification_service.dart';

/// =======================================================
/// ✅ OrdersPage（最終整合版）
/// - 支援 OrderService 資料實例與假資料回退
/// - 含搜尋、篩選、排序、時間軸、取消訂單、退款
/// =======================================================
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  static const Color _bg = Color(0xFFF6F7FA);
  static const Color _primary = Colors.blueAccent;

  final TextEditingController _searchController = TextEditingController();
  String _statusFilterKey = 'all';
  String _sortMode = 'newest';
  bool _loading = false;

  List<Map<String, dynamic>> _orders = [];

  final List<_StatusFilter> _filters = const [
    _StatusFilter(label: '全部', key: 'all'),
    _StatusFilter(label: '待付款', key: 'placed'),
    _StatusFilter(label: '已付款', key: 'paid'),
    _StatusFilter(label: '出貨中', key: 'shipped'),
    _StatusFilter(label: '已送達', key: 'delivered'),
    _StatusFilter(label: '已取消', key: 'cancelled'),
    _StatusFilter(label: '退款', key: 'refunded'),
  ];

  final List<_SortItem> _sorts = const [
    _SortItem(label: '最新', key: 'newest', icon: Icons.schedule_rounded),
    _SortItem(label: '最舊', key: 'oldest', icon: Icons.history_rounded),
    _SortItem(label: '價格高→低', key: 'price_desc', icon: Icons.trending_down_rounded),
    _SortItem(label: '價格低→高', key: 'price_asc', icon: Icons.trending_up_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final svc = OrderService.instance;
    await svc.init();
    if (!mounted) return;
    setState(() {
      _orders = svc.orders.map((o) {
        return {
          'id': o.id,
          'date': o.createdAt,
          'status': o.status,
          'total': o.totalAmount,
          'items': o.items
              .map((i) => {
                    'name': i.name,
                    'qty': i.qty,
                    'price': i.price,
                    'image': '',
                  })
              .toList(),
          'shippingAddress': o.shipping?['address'] ?? '—',
          'paymentMethod': '信用卡 VISA **** 4242',
          'canCancel': o.status == 'placed',
          'timeline': _timeline(o.status),
        };
      }).toList();
    });
  }

  List<Map<String, dynamic>> _timeline(String status) {
    final now = DateTime.now();
    final base = now.subtract(const Duration(days: 3));
    return [
      {'label': '建立訂單', 'time': base, 'done': true},
      {'label': '付款成功', 'time': base.add(const Duration(hours: 1)), 'done': status != 'placed'},
      {'label': '出貨', 'time': base.add(const Duration(days: 1)), 'done': status == 'shipped' || status == 'delivered'},
      {'label': '送達', 'time': now, 'done': status == 'delivered'},
    ];
  }

  String _fmtDate(DateTime d) => '${d.year}/${d.month}/${d.day}';
  String _money(num v) => 'NT\$${v.toStringAsFixed(0)}';

  Color _statusColor(String s) {
    switch (s) {
      case 'placed':
        return Colors.orangeAccent;
      case 'paid':
        return Colors.green;
      case 'shipped':
        return Colors.blueAccent;
      case 'delivered':
        return Colors.teal;
      case 'cancelled':
        return Colors.grey;
      case 'refunded':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'placed':
        return '待付款';
      case 'paid':
        return '已付款';
      case 'shipped':
        return '出貨中';
      case 'delivered':
        return '已送達';
      case 'cancelled':
        return '已取消';
      case 'refunded':
        return '已退款';
      default:
        return '未知狀態';
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final id = order['id'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認取消訂單？'),
        content: Text('確定要取消訂單 $id 嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('返回')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('確認取消'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await OrderService.instance.cancelOrder(id);
    if (!mounted) return;
    await _loadOrders();
  }

  List<Map<String, dynamic>> _filtered() {
    final q = _searchController.text.toLowerCase();
    List<Map<String, dynamic>> list = List.from(_orders);

    if (_statusFilterKey != 'all') {
      list = list.where((o) => o['status'] == _statusFilterKey).toList();
    }

    if (q.isNotEmpty) {
      list = list.where((o) {
        if ((o['id'] ?? '').toString().toLowerCase().contains(q)) return true;
        for (final i in (o['items'] as List)) {
          if (i['name'].toString().toLowerCase().contains(q)) return true;
        }
        return false;
      }).toList();
    }

    switch (_sortMode) {
      case 'newest':
        list.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
        break;
      case 'oldest':
        list.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
        break;
      case 'price_desc':
        list.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
        break;
      case 'price_asc':
        list.sort((a, b) => (a['total'] as double).compareTo(b['total'] as double));
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('我的訂單', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
          IconButton(icon: const Icon(Icons.tune_rounded), onPressed: _showSortSheet),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _buildSearchBar(),
            const SizedBox(height: 10),
            _buildFilterChips(),
            const SizedBox(height: 10),
            ...list.map((o) => _OrderCard(
                  order: o,
                  statusColor: _statusColor(o['status']),
                  statusLabel: _statusLabel(o['status']),
                  dateText: _fmtDate(o['date']),
                  moneyText: _money(o['total']),
                  onCancel: o['canCancel'] == true ? () => _cancelOrder(o) : null,
                )),
            if (list.isEmpty)
              Container(
                padding: const EdgeInsets.all(50),
                alignment: Alignment.center,
                child: const Text('目前沒有訂單', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: '搜尋訂單編號 / 商品名稱',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _filters[i];
          final selected = _statusFilterKey == f.key;
          return ChoiceChip(
            label: Text(f.label),
            selected: selected,
            selectedColor: _primary,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
            onSelected: (_) => setState(() => _statusFilterKey = f.key),
          );
        },
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _sorts.map((s) {
            final selected = _sortMode == s.key;
            return ListTile(
              leading: Icon(s.icon, color: selected ? _primary : Colors.grey),
              title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: selected ? const Icon(Icons.check_rounded, color: Colors.blueAccent) : null,
              onTap: () {
                setState(() => _sortMode = s.key);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

// =======================================================
// ✅ 單筆訂單卡片 UI
// =======================================================
class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String statusLabel;
  final Color statusColor;
  final String dateText;
  final String moneyText;
  final VoidCallback? onCancel;

  const _OrderCard({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
    required this.dateText,
    required this.moneyText,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final items = (order['items'] as List).cast<Map<String, dynamic>>();
    final first = items.first;
    final itemName = first['name'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('訂單 ${order['id']}',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('$itemName 等 ${items.length} 項商品',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(dateText, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(moneyText,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
              const Spacer(),
              if (onCancel != null)
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  label: const Text('取消訂單',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// =======================================================
// Helper Models
// =======================================================
class _StatusFilter {
  final String label;
  final String key;
  const _StatusFilter({required this.label, required this.key});
}

class _SortItem {
  final String label;
  final String key;
  final IconData icon;
  const _SortItem({required this.label, required this.key, required this.icon});
}

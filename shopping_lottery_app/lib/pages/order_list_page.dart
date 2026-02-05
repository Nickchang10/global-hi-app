// lib/pages/order_list_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/order_service.dart';
import '../services/cart_service.dart';
import '../services/notification_service.dart';
import 'shop_page.dart';
import 'support_page.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  static const _brand = Colors.blueAccent;
  static const _accent = Colors.orangeAccent;
  static const _bg = Color(0xFFF6F7F9);

  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      _orders = await OrderService.instance.getUserOrders(userId: 'demo_user');
    } catch (_) {
      // 若 OrderService 未實作 getUserOrders，改用 mock
      _orders = _mockOrders();
    }
    setState(() => _loading = false);
  }

  // 模擬假資料 (若無 Service)
  List<Map<String, dynamic>> _mockOrders() {
    return [
      {
        'id': 'ORD20251215001',
        'date': DateTime.now().subtract(const Duration(days: 1)),
        'status': '已出貨',
        'total': 2780.0,
        'method': '信用卡付款',
        'items': [
          {'name': 'Osmile S5 健康錶', 'qty': 1, 'price': 3990.0},
          {'name': 'Osmile 充電座', 'qty': 1, 'price': 490.0},
        ],
      },
      {
        'id': 'ORD20251213003',
        'date': DateTime.now().subtract(const Duration(days: 3)),
        'status': '已送達',
        'total': 1750.0,
        'method': 'LINE Pay',
        'items': [
          {'name': '藍牙耳機', 'qty': 1, 'price': 1750.0},
        ],
      },
      {
        'id': 'ORD20251210006',
        'date': DateTime.now().subtract(const Duration(days: 6)),
        'status': '已完成',
        'total': 2590.0,
        'method': 'Apple Pay',
        'items': [
          {'name': '健身鞋', 'qty': 1, 'price': 2590.0},
        ],
      },
    ];
  }

  String _formatDate(DateTime date) =>
      DateFormat('yyyy/MM/dd HH:mm').format(date);

  Color _statusColor(String s) {
    switch (s) {
      case '已出貨':
        return Colors.orangeAccent;
      case '已送達':
        return Colors.blueAccent;
      case '已完成':
        return Colors.green;
      case '已付款':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('我的訂單', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          )
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: _orders.length,
                    itemBuilder: (_, i) => _buildOrderCard(_orders[i]),
                  ),
      ),
    );
  }

  // ---------------------- 訂單卡片 ----------------------
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final statusColor = _statusColor(order['status']);
    final items = (order['items'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text('訂單編號：${order['id']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  order['status'],
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('日期：${_formatDate(order['date'])}',
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const Divider(height: 18),

          // 商品清單
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item['name'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text('x${item['qty']}',
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12)),
                  const SizedBox(width: 8),
                  Text('NT\$${item['price'].toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 20),

          // 總金額與付款方式
          Row(
            children: [
              Expanded(
                child: Text('付款方式：${order['method']}',
                    style: const TextStyle(fontSize: 12)),
              ),
              Text('總計 NT\$${order['total'].toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _accent)),
            ],
          ),
          const SizedBox(height: 12),

          // 功能按鈕
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long, size: 16),
                label: const Text('明細', style: TextStyle(fontSize: 12)),
                onPressed: () => _showOrderDetail(order),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              if (order['status'] == '已完成')
                ElevatedButton.icon(
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: const Text('評價', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showReviewDialog(order),
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                  label: const Text('再次購買', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _buyAgain(order),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------- 加入購物車 ----------------------
  Future<void> _buyAgain(Map<String, dynamic> order) async {
    try {
      for (final item in order['items']) {
        await CartService.instance.addItem(item['name'], item['price']);
      }
      NotificationService.instance.addNotification(
        type: 'cart',
        title: '已加入購物車',
        message: '訂單商品已重新加入購物車。',
        icon: Icons.shopping_cart_outlined,
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已將商品加入購物車')));
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('加入購物車失敗')));
    }
  }

  // ---------------------- 空狀態 ----------------------
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('目前沒有訂單記錄',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('前往商城選購好物吧！',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const ShopPage())),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('前往商城'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------- 訂單明細 Dialog ----------------------
  void _showOrderDetail(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('訂單明細', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ...(order['items'] as List)
                  .map<Widget>((item) => ListTile(
                        dense: true,
                        title: Text(item['name'],
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        trailing:
                            Text('NT\$${item['price'].toStringAsFixed(0)}'),
                        subtitle: Text('數量：${item['qty']}'),
                      ))
                  .toList(),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('付款方式', style: TextStyle(color: Colors.black54)),
                  Text(order['method'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('總金額', style: TextStyle(color: Colors.black54)),
                  Text('NT\$${order['total'].toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: _accent)),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('關閉'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------- 評價 Dialog ----------------------
  void _showReviewDialog(Map<String, dynamic> order) {
    final controller = TextEditingController();
    int rating = 5;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: const Text('留下評價'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      Icons.star,
                      color: i < rating ? Colors.amber : Colors.grey.shade400,
                    ),
                    onPressed: () => setStateDialog(() => rating = i + 1),
                  );
                }),
              ),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '寫下您對本次購買的感想',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('感謝您的評價！')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              child: const Text('送出'),
            ),
          ],
        );
      }),
    );
  }
}

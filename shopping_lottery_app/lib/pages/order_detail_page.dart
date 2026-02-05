// lib/pages/order_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/order_service.dart';

class OrderDetailPage extends StatelessWidget {
  final String orderId;

  const OrderDetailPage({Key? key, required this.orderId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = context.watch<OrderService>();
    final order = service.getById(orderId);

    if (order == null) {
      return Scaffold(appBar: AppBar(title: const Text('訂單詳細')), body: const Center(child: Text('找不到訂單')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('訂單詳細')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('訂單：${order.id}', style: const TextStyle(fontWeight: FontWeight.bold))),
                          Text(order.status, style: const TextStyle(color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...order.items.map((it) => ListTile(
                            title: Text(it.name),
                            subtitle: Text('數量: ${it.qty}'),
                            trailing: Text('NT\$${it.price.toStringAsFixed(0)}'),
                          )),
                      const Divider(),
                      ListTile(
                        title: const Text('總計'),
                        trailing: Text('NT\$${order.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Action buttons
              if (order.status == 'placed' || order.status == 'processing')
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await service.cancelOrder(order.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消訂單')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('取消失敗：$e')));
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('取消訂單'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              if (order.status == 'delivered' || order.status == 'completed')
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await service.refundOrder(order.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已申請退款')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('退款失敗：$e')));
                    }
                  },
                  icon: const Icon(Icons.replay_outlined),
                  label: const Text('申請退款'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('回上頁'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

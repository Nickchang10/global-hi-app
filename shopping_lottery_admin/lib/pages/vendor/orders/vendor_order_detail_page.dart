// lib/pages/vendor/orders/vendor_order_detail_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VendorOrderDetailPage extends StatelessWidget {
  final String orderId;

  const VendorOrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('orders').doc(orderId);

    return Scaffold(
      appBar: AppBar(title: const Text('訂單明細')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }
          final doc = snap.data;
          if (doc == null || !doc.exists) {
            return const Center(child: Text('找不到此訂單'));
          }

          final data = doc.data() ?? {};
          final status = (data['status'] ?? '').toString();
          final createdAt = data['createdAt'];
          final total = data['total'];
          final buyerName = (data['buyerName'] ?? data['userName'] ?? '')
              .toString();
          final buyerPhone = (data['buyerPhone'] ?? data['phone'] ?? '')
              .toString();
          final items = (data['items'] is List)
              ? List<Map<String, dynamic>>.from(data['items'])
              : <Map<String, dynamic>>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _kv('訂單編號', orderId),
              _kv('狀態', status.isEmpty ? '-' : status),
              _kv('建立時間', _fmtTs(createdAt)),
              _kv('買家', buyerName.isEmpty ? '-' : buyerName),
              _kv('電話', buyerPhone.isEmpty ? '-' : buyerPhone),
              _kv('總金額', total == null ? '-' : total.toString()),
              const SizedBox(height: 16),
              const Text(
                '商品明細',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Text('（無商品項目）')
              else
                ...items.map((it) {
                  final name = (it['name'] ?? it['title'] ?? '').toString();
                  final qty = it['qty'] ?? it['quantity'] ?? 0;
                  final price = it['price'];
                  return Card(
                    child: ListTile(
                      title: Text(name.isEmpty ? '未命名商品' : name),
                      subtitle: Text('數量：$qty'),
                      trailing: Text(price == null ? '-' : price.toString()),
                    ),
                  );
                }),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(k, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  String _fmtTs(dynamic v) {
    if (v == null) return '-';
    if (v is Timestamp) {
      final dt = v.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return v.toString();
  }
}

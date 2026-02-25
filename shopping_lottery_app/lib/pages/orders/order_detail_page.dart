import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrderDetailPage extends StatelessWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    final s = v.toString().replaceAll(',', '').trim();
    return int.tryParse(s) ?? (double.tryParse(s)?.round() ?? 0);
  }

  String _statusText(String s) {
    final v = s.trim().toLowerCase();
    switch (v) {
      case 'created':
        return '已建立';
      case 'pending':
        return '待處理';
      case 'unpaid':
        return '未付款';
      case 'paid':
        return '已付款';
      case 'shipping':
      case 'shipped':
        return '配送中';
      case 'delivered':
        return '已送達';
      case 'cancelled':
        return '已取消';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('orders').doc(orderId);

    return Scaffold(
      appBar: AppBar(title: const Text('訂單詳情')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取訂單失敗：\n${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('找不到訂單'));
          }

          final m = snap.data!.data() ?? <String, dynamic>{};

          final statusRaw = (m['status'] ?? 'created').toString();
          final status = _statusText(statusRaw);

          // 兼容 total/subtotal
          final subtotal = _toInt(m['subtotal'] ?? 0);
          final shippingFee = _toInt(m['shippingFee'] ?? m['shipping'] ?? 0);
          final discount = _toInt(m['discount'] ?? 0);
          final total = _toInt(
            m['total'] ?? (subtotal + shippingFee - discount),
          );

          final receiverName = (m['receiverName'] ?? '').toString();
          final receiverPhone = (m['receiverPhone'] ?? '').toString();
          final receiverAddress = (m['receiverAddress'] ?? '').toString();

          // ✅ 這裡改成讀「訂單文件的 items list」
          final items = (m['items'] is List)
              ? (m['items'] as List)
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList()
              : <Map<String, dynamic>>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '訂單號：$orderId',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '狀態：$status',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '總計：NT\$ $total',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: orderId),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已複製訂單號')),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('複製'),
                        ),
                      ),
                      const Divider(),
                      const Text(
                        '收件資訊',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text('姓名：${receiverName.isEmpty ? '—' : receiverName}'),
                      Text('電話：${receiverPhone.isEmpty ? '—' : receiverPhone}'),
                      Text(
                        '地址：${receiverAddress.isEmpty ? '—' : receiverAddress}',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Text('商品明細', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),

              if (items.isEmpty)
                Text(
                  '（此訂單沒有 items 資料）\n'
                  '如果你之前是把商品存在 orders/{orderId}/items 子集合，請改成在下單時寫入 order.items，或我也可以幫你加 rules 放行子集合。',
                  style: TextStyle(color: Colors.grey.shade700),
                )
              else
                ...items.map((it) {
                  final name =
                      (it['nameSnapshot'] ?? it['title'] ?? it['name'] ?? '商品')
                          .toString();
                  final qty = _toInt(it['qty'] ?? it['quantity'] ?? 1);
                  final price = _toInt(
                    it['priceSnapshot'] ?? it['price'] ?? it['unitPrice'],
                  );
                  final lineTotal = price * (qty <= 0 ? 1 : qty);

                  return Card(
                    child: ListTile(
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('NT\$ $price ・ 數量 $qty'),
                      trailing: Text(
                        'NT\$ $lineTotal',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _moneyRow('小計', subtotal),
                      _moneyRow('運費', shippingFee),
                      _moneyRow('折扣', discount),
                      const Divider(),
                      _moneyRow('總計', total, bold: true),
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

  Widget _moneyRow(String label, int value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('NT\$ $value', style: style),
        ],
      ),
    );
  }
}

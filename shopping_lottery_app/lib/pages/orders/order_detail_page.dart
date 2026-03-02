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

  String _s(dynamic v) => (v ?? '').toString().trim();

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
      case 'canceled':
        return '已取消';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  Map<String, dynamic> _map(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _itemsFrom(dynamic v) {
    if (v is! List) return <Map<String, dynamic>>[];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _fmtTs(dynamic v) {
    if (v is Timestamp) {
      final dt = v.toDate().toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    }
    return '—';
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

  int _unitPriceOf(Map<String, dynamic> it) {
    return _toInt(
      it['unitPriceSnapshot'] ??
          it['priceSnapshot'] ??
          it['unitPrice'] ??
          it['price'] ??
          it['amount'] ??
          0,
    );
  }

  int _qtyOf(Map<String, dynamic> it) {
    final q = _toInt(it['qty'] ?? it['quantity'] ?? 1);
    return q <= 0 ? 1 : q;
  }

  int _lineTotalOf(Map<String, dynamic> it) {
    final lt = _toInt(it['lineTotalSnapshot'] ?? it['lineTotal']);
    if (lt > 0) return lt;
    return _unitPriceOf(it) * _qtyOf(it);
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

          final statusRaw = _s(m['status'] ?? 'created');
          final status = _statusText(statusRaw);

          // ✅ pricing 快照（新）優先，其次 fallback 舊欄位
          final pricing = _map(m['pricing']);
          final subtotal = _toInt(pricing['subTotal'] ?? m['subtotal'] ?? 0);

          // 兼容多種運費欄位：pricing.shippingFee / shippingFee / shipping.fee
          final shippingMap = _map(m['shipping']);
          final shippingFee = _toInt(
            pricing['shippingFee'] ??
                m['shippingFee'] ??
                shippingMap['fee'] ??
                0,
          );

          final discount = _toInt(pricing['discount'] ?? m['discount'] ?? 0);

          final total = _toInt(
            pricing['total'] ??
                m['total'] ??
                (subtotal + shippingFee - discount),
          );

          final receiverName = _s(m['receiverName']);
          final receiverPhone = _s(m['receiverPhone']);
          final receiverAddress = _s(m['receiverAddress']);

          final createdAt = _fmtTs(m['createdAt']);
          final updatedAt = _fmtTs(m['updatedAt']);

          // ✅ items list（你目前下單已寫入 order.items）
          final items = _itemsFrom(m['items']);

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
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '建立時間：$createdAt',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      Text(
                        '更新時間：$updatedAt',
                        style: TextStyle(color: Colors.grey.shade700),
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
                          label: const Text('複製訂單號'),
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
                  '請確認下單時有寫入 orders/{orderId}.items（目前你的 CheckoutSubmitService 已寫入）。',
                  style: TextStyle(color: Colors.grey.shade700),
                )
              else
                ...items.map((it) {
                  final name = _s(
                    it['nameSnapshot'] ?? it['title'] ?? it['name'] ?? '商品',
                  );
                  final qty = _qtyOf(it);
                  final unitPrice = _unitPriceOf(it);
                  final lineTotal = _lineTotalOf(it);

                  final imageUrl = _s(
                    it['imageUrlSnapshot'] ?? it['imageUrl'] ?? it['image'],
                  );

                  Widget? leading;
                  if (imageUrl.isNotEmpty) {
                    leading = ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: Colors.black.withValues(alpha: 0.06),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  }

                  return Card(
                    child: ListTile(
                      leading: leading,
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('NT\$ $unitPrice ・ 數量 $qty'),
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
}

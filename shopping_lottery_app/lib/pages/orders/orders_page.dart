import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    final s = v.toString().replaceAll(',', '').trim();
    return int.tryParse(s) ?? (double.tryParse(s)?.round() ?? 0);
  }

  DateTime _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _statusText(String s) {
    switch (s.trim().toLowerCase()) {
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
        return '已出貨';
      case 'in_transit':
        return '配送中';
      case 'delivered':
        return '已送達';
      case 'cancelled':
        return '已取消';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  Map<String, String> _shippingInfo(Map<String, dynamic> m) {
    // 兼容：可能是根欄位或 shipping map
    final shipping = (m['shipping'] is Map)
        ? Map<String, dynamic>.from(m['shipping'] as Map)
        : <String, dynamic>{};

    String status = (m['shippingStatus'] ?? shipping['shippingStatus'] ?? '')
        .toString();
    String carrier = (m['carrier'] ?? shipping['carrier'] ?? '').toString();
    String tn = (m['trackingNumber'] ?? shipping['trackingNumber'] ?? '')
        .toString();
    String tu = (m['trackingUrl'] ?? shipping['trackingUrl'] ?? '').toString();

    return {
      'status': status.trim(),
      'carrier': carrier.trim(),
      'trackingNumber': tn.trim(),
      'trackingUrl': tu.trim(),
    };
  }

  String _shippingText(String s) {
    switch (s.trim().toLowerCase()) {
      case 'pending':
        return '待出貨';
      case 'packed':
        return '已備貨';
      case 'shipped':
        return '已出貨';
      case 'in_transit':
        return '配送中';
      case 'delivered':
        return '已送達';
      case 'exception':
        return '異常';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('請先登入')));

    // ✅ 對齊 rules：用 uid 查（你的下單 service 也會寫 uid）
    final q = FirebaseFirestore.instance
        .collection('orders')
        .where('uid', isEqualTo: uid)
        .limit(50);

    return Scaffold(
      appBar: AppBar(title: const Text('我的訂單')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取訂單失敗：\n${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs.toList();

          // client 端排序 createdAt desc
          docs.sort((a, b) {
            final da = _toDate(a.data()['createdAt']);
            final db = _toDate(b.data()['createdAt']);
            return db.compareTo(da);
          });

          if (docs.isEmpty) {
            return const Center(child: Text('尚無訂單'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = docs[i];
              final m = d.data();

              final status = _statusText((m['status'] ?? 'created').toString());
              final shipping = _shippingInfo(m);
              final shipText = _shippingText(shipping['status'] ?? '');
              final hasTracking =
                  (shipping['trackingNumber'] ?? '').isNotEmpty ||
                  (shipping['trackingUrl'] ?? '').isNotEmpty;

              final subtotal = _toInt(m['subtotal'] ?? 0);
              final shippingFee = _toInt(m['shippingFee'] ?? 0);
              final discount = _toInt(m['discount'] ?? 0);
              final total = _toInt(
                m['total'] ?? (subtotal + shippingFee - discount),
              );

              final createdAtRaw = m['createdAt'];
              final createdAt = (createdAtRaw is Timestamp)
                  ? createdAtRaw.toDate()
                  : null;

              return Card(
                child: ListTile(
                  title: Text(
                    '訂單 ${d.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    [
                      '訂單：$status',
                      '物流：$shipText',
                      if (createdAt != null) '時間：${createdAt.toString()}',
                      if (hasTracking) '可追蹤',
                    ].join('\n'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    'NT\$ $total',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/order_detail', arguments: {'orderId': d.id}),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// lib/pages/order_complete_page.dart
//
// ✅ OrderCompletePage（完整版・整合抽獎/優惠券/導航）
//
// - 接收 arguments: { orderId } 或 String(orderId)
// - 顯示訂單完成資訊、優惠券、可抽獎按鈕
// - 支援：返回首頁 / 查看訂單 / 前往抽獎
// - 若付款狀態未確認，會提示前往 PaymentStatusPage
//
// 依賴：cloud_firestore, provider, order_enums.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/order_enums.dart';

class OrderCompletePage extends StatelessWidget {
  const OrderCompletePage({super.key});

  String _orderIdFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) return args.trim();
    if (args is Map) {
      final v = args['orderId'] ?? args['id'];
      if (v != null) return v.toString().trim();
    }
    return '';
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  String _s(dynamic v) => (v ?? '').toString().trim();
  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(_s(v)) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _orderIdFromArgs(context);
    if (orderId.isEmpty) {
      return const Scaffold(body: Center(child: Text('缺少 orderId')));
    }

    final ref = FirebaseFirestore.instance.collection('orders').doc(orderId);

    return Scaffold(
      appBar: AppBar(title: const Text('訂單完成')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('找不到訂單資料'));
          }

          final data = snap.data!.data() ?? <String, dynamic>{};
          final payment = _asMap(data['payment']);
          final status = orderStatusFromAny(data['status']);
          final payStatus = paymentStatusFromAny(payment['status']);

          final total = _toNum(data['total']);
          final discount = _toNum(data['discount']);
          final currency = _s(data['currency']).isEmpty ? 'TWD' : _s(data['currency']);
          final isPaidLike = payStatus == PaymentStatus.paid || status == OrderStatus.paid;
          final isCodLike = payStatus == PaymentStatus.cod || status == OrderStatus.codPending;

          final eligibleForLottery = isPaidLike || isCodLike;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 20),
                  Icon(
                    Icons.verified_rounded,
                    color: Colors.green.shade600,
                    size: 72,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '訂單已完成！',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '訂單號：$orderId',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 20),

                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('訂單摘要', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _kv('狀態', status.label),
                          _kv('付款狀態', payStatus.label),
                          _kv('金額', '$currency ${total.toStringAsFixed(0)}'),
                          if (discount > 0) _kv('折扣', '-$currency ${discount.toStringAsFixed(0)}'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (!eligibleForLottery)
                    Card(
                      color: Colors.yellow.shade50,
                      elevation: 1,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          '付款尚未完成，暫不可抽獎。\n請至付款狀態頁確認是否已付款成功。',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    )
                  else
                    Card(
                      color: Colors.blue.shade50,
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('恭喜完成訂單！', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            const Text('你已獲得一次抽獎機會！'),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                '/lottery',
                                arguments: {'orderId': orderId},
                              ),
                              icon: const Icon(Icons.casino_outlined),
                              label: const Text('前往抽獎'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  FilledButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('回首頁'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      '/orders',
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('查看我的訂單'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      '/payment_status',
                      arguments: {'orderId': orderId},
                    ),
                    icon: const Icon(Icons.payment_outlined),
                    label: const Text('查看付款狀態'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: Colors.black54)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

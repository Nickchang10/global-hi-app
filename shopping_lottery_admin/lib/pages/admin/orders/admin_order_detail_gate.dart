// lib/pages/admin/orders/admin_order_detail_gate.dart
import 'package:flutter/material.dart';

/// ✅ AdminOrderDetailGate（乾淨版｜移除 Unnecessary cast）
/// - 從 route arguments 取得 orderId
/// - 支援 arguments：
///   1) String orderId
///   2) {'orderId': 'xxx'}
///   3) {'id': 'xxx'}（容錯）
///
/// 你可以在這裡接你的 AdminOrderDetailPage 或直接顯示明細頁。
class AdminOrderDetailGate extends StatelessWidget {
  const AdminOrderDetailGate({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    String? orderId;

    if (args is String) {
      orderId = args;
    } else if (args is Map<String, dynamic>) {
      // ✅ 不需要 cast，因為 args 已經是 Map<String, dynamic>
      orderId = (args['orderId'] ?? args['id'])?.toString();
    } else if (args is Map) {
      // ✅ 容錯：如果外部傳的是 Map 但不是強型別
      final map = Map<String, dynamic>.from(args);
      orderId = (map['orderId'] ?? map['id'])?.toString();
    }

    if (orderId == null || orderId.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('訂單明細')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('缺少 orderId，無法開啟訂單明細。'),
          ),
        ),
      );
    }

    // ✅ 先用 placeholder（你可換成你的 AdminOrderDetailPage / AdminOrderDetailScreen）
    return Scaffold(
      appBar: AppBar(title: const Text('訂單明細')),
      body: Center(child: Text('Admin order detail: $orderId')),
    );
  }
}

// lib/pages/vendor/orders/vendor_order_detail_gate.dart
//
// ✅ VendorOrderDetailGate（完整最終版）
// ------------------------------------------------------------
// - 確保 Vendor 已登入
// - 支援推播 / Deep Link 開啟
// - 自動導向 VendorOrderDetailPage
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'vendor_order_detail_page.dart';

class VendorOrderDetailGate extends StatefulWidget {
  const VendorOrderDetailGate({super.key});

  @override
  State<VendorOrderDetailGate> createState() => _VendorOrderDetailGateState();
}

class _VendorOrderDetailGateState extends State<VendorOrderDetailGate> {
  String? _orderId;
  bool _checking = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_checking) {
      final args = ModalRoute.of(context)?.settings.arguments;
      String? id;

      if (args is String) id = args.trim();
      if (args is Map) {
        final v = args['orderId'] ?? args['id'];
        if (v is String) id = v.trim();
      }

      setState(() {
        _orderId = id;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '請先登入廠商帳號後再查看訂單詳情。',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_orderId == null || _orderId!.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '找不到訂單編號（orderId）。',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return VendorOrderDetailPage(orderId: _orderId!);
  }
}

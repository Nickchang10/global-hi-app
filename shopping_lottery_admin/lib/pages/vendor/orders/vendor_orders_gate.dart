// lib/pages/vendor/orders/vendor_orders_gate.dart
//
// ✅ VendorOrdersGate（最終完整版｜Vendor 訂單列表守門）
// ------------------------------------------------------------
// - 讀取 users/{uid} 取得 role / vendorId
// - 驗證為 vendor 角色且 vendorId 存在
// - 通過才進入 VendorOrdersPage
//
// 依賴：firebase_auth, cloud_firestore, flutter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'vendor_orders_page.dart';

class VendorOrdersGate extends StatelessWidget {
  const VendorOrdersGate({super.key});

  static Route route(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => const VendorOrdersGate(),
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('未登入')),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(body: Center(child: Text('讀取使用者資料失敗：${snap.error}')));
        }

        final d = snap.data!.data() ?? <String, dynamic>{};
        final role = (d['role'] ?? '').toString();
        final vendorId = (d['vendorId'] ?? '').toString().trim();

        final isVendorRole = role == 'vendor' || role == 'vendor_admin' || role.startsWith('vendor');
        if (!isVendorRole || vendorId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('沒有 Vendor 權限或 vendorId 缺失')),
          );
        }

        return VendorOrdersPage(vendorId: vendorId);
      },
    );
  }
}

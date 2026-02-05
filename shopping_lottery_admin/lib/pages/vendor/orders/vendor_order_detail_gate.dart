// lib/pages/vendor/orders/vendor_order_detail_gate.dart
//
// ✅ VendorOrderDetailGate（最終完整版｜Vendor 訂單詳情 Gate）
// ------------------------------------------------------------
// - 只允許 vendor 角色進入
// - 只允許查看「包含自己 vendorId 的訂單」
//   - orders/{id}.vendorId == vendorId 或
//   - orders/{id}.vendorIds hasAny [vendorId]
// - 通過後進入 VendorOrderDetailPage（僅出貨欄位可編輯）
//
// 依賴：cloud_firestore, firebase_auth, flutter/material
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'vendor_order_detail_page.dart';

class VendorOrderDetailGate extends StatelessWidget {
  final String orderId;

  const VendorOrderDetailGate({
    super.key,
    required this.orderId,
  });

  static Route route(RouteSettings settings) {
    final id = (settings.arguments as String?) ?? '';
    return MaterialPageRoute(
      builder: (_) => VendorOrderDetailGate(orderId: id),
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final oid = orderId.trim();

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('未登入')));
    }
    if (oid.isEmpty) {
      return const Scaffold(body: Center(child: Text('orderId 不可為空')));
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, uSnap) {
        if (uSnap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final u = uSnap.data?.data() ?? {};
        final role = (u['role'] ?? '').toString();
        final vendorId = (u['vendorId'] ?? '').toString();

        if (role != 'vendor' || vendorId.isEmpty) {
          return const Scaffold(body: Center(child: Text('僅 Vendor 可查看此頁')));
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('orders').doc(oid).snapshots(),
          builder: (context, oSnap) {
            if (oSnap.hasError) {
              return const Scaffold(body: Center(child: Text('讀取訂單失敗')));
            }
            if (!oSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!oSnap.data!.exists) {
              return const Scaffold(body: Center(child: Text('訂單不存在')));
            }

            final data = oSnap.data!.data() ?? {};
            final singleVendorId = (data['vendorId'] ?? '').toString();
            final vendorIds = (data['vendorIds'] is List)
                ? (data['vendorIds'] as List).map((e) => e.toString()).toList()
                : <String>[];

            final allowed = singleVendorId == vendorId || vendorIds.contains(vendorId);
            if (!allowed) {
              return const Scaffold(body: Center(child: Text('無權限查看此訂單')));
            }

            // 通過 Gate → 進入詳情頁
            return VendorOrderDetailPage(
              orderId: oid,
              vendorId: vendorId,
            );
          },
        );
      },
    );
  }
}

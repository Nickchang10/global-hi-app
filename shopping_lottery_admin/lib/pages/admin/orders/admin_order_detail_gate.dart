// lib/pages/admin/orders/admin_order_detail_gate.dart
//
// ✅ AdminOrderDetailGate（最終完整版）
// - 檢查 orderId
// - 可加 admin_gate 驗證（這裡先用 users role 驗證，避免你專案不一致）
// - 通過後進入 AdminOrderDetailPage

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_order_detail_page.dart';

class AdminOrderDetailGate extends StatelessWidget {
  final String orderId;

  const AdminOrderDetailGate({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    final id = orderId.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('未登入')));
    }
    if (id.isEmpty) {
      return const Scaffold(body: Center(child: Text('orderId 不可為空')));
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final role = (snap.data?.data()?['role'] ?? '').toString();
        if (role != 'admin') {
          return const Scaffold(body: Center(child: Text('僅 Admin 可查看此頁')));
        }

        return AdminOrderDetailPage(orderId: id);
      },
    );
  }
}

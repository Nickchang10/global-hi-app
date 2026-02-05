// lib/pages/vendor/reports/vendor_sales_report_gate.dart
//
// ✅ VendorSalesReportGate（最終完整版）
// - 只允許 vendor 進入
// - 讀取 users/{uid}.vendorId 後，進入 VendorSalesReportPage
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'vendor_sales_report_page.dart';

class VendorSalesReportGate extends StatelessWidget {
  const VendorSalesReportGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('未登入')));
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final u = snap.data?.data() ?? {};
        final role = (u['role'] ?? '').toString();
        final vendorId = (u['vendorId'] ?? '').toString();

        if (role != 'vendor' || vendorId.isEmpty) {
          return const Scaffold(body: Center(child: Text('僅 Vendor 可使用此頁')));
        }

        return VendorSalesReportPage(vendorId: vendorId);
      },
    );
  }
}

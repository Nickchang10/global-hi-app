// lib/pages/order_detail_page.dart
//
// OrderDetailPage：完整全頁版的訂單詳情畫面
// - 顯示訂單完整資訊（狀態、出貨、買家、商品）
// - 使用新版 OrderDetailPanel（含時間軸、通知、歷史紀錄）
// - 即時同步 Firestore（StreamBuilder）
// - 支援返回上一頁
//
// 依賴：
// - lib/widgets/order_detail_panel.dart
// - lib/services/auth_service.dart
// - lib/services/admin_gate.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../widgets/order_detail_panel.dart';
import '../services/auth_service.dart';
import '../services/admin_gate.dart';

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final String? orderId = args is String
        ? args
        : (args is Map ? args['id']?.toString() : null);

    if (orderId == null || orderId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('訂單詳情')),
        body: const Center(child: Text('無效的訂單 ID')),
      );
    }

    final gate = context.read<AdminGate>();
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final isAdmin = gate.cachedRole == 'admin';
    final vendorId = gate.cachedVendorId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('訂單詳情：$orderId'),
        backgroundColor: Colors.white,
        elevation: 0.6,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('讀取錯誤：${snap.error}'));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('查無此訂單'));
          }

          final data = snap.data!.data() ?? {};
          final order = {'id': orderId, ...data};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 960),
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Card(
                elevation: 1.2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OrderDetailPanel(
                    order: order,
                    isAdmin: isAdmin,
                    vendorId: vendorId,
                    onUpdated: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('訂單資料已更新')),
                      );
                    },
                    onOpenFullPage: null, // 全頁狀態不顯示 "全頁" 按鈕
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

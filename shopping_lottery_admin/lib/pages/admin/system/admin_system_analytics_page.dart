// lib/pages/admin/system/admin_system_analytics_page.dart
//
// ✅ AdminSystemAnalyticsPage（完整版｜可直接使用｜可編譯）
// ------------------------------------------------------------
// Firestore 依賴集合（可依你實際命名微調）：
// - orders  : { totalAmount, createdAt }
// - users   : 使用者集合（文件數）
//
// ❗ 不使用任何圖表套件，確保 Web / App 穩定編譯
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminSystemAnalyticsPage extends StatelessWidget {
  const AdminSystemAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('系統報表分析', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _kpiSection(cs),
          const SizedBox(height: 16),
          _recentOrdersSection(cs),
        ],
      ),
    );
  }

  // =====================================================
  // KPI 區塊
  // =====================================================
  Widget _kpiSection(ColorScheme cs) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, orderSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, userSnap) {
            if (orderSnap.connectionState == ConnectionState.waiting ||
                userSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = orderSnap.data?.docs ?? [];
            final users = userSnap.data?.docs ?? [];

            num totalRevenue = 0;
            num todayRevenue = 0;
            final today = DateTime.now();

            for (final d in orders) {
              final data = d.data();
              final amount = (data['totalAmount'] ?? 0) as num;
              totalRevenue += amount;

              final ts = data['createdAt'];
              if (ts is Timestamp) {
                final dt = ts.toDate();
                if (dt.year == today.year &&
                    dt.month == today.month &&
                    dt.day == today.day) {
                  todayRevenue += amount;
                }
              }
            }

            return GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _kpiCard('訂單數', orders.length.toString(), Icons.shopping_bag, cs),
                _kpiCard(
                  '總營收',
                  NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$')
                      .format(totalRevenue),
                  Icons.attach_money,
                  cs,
                ),
                _kpiCard(
                  '今日營收',
                  NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$')
                      .format(todayRevenue),
                  Icons.today,
                  cs,
                ),
                _kpiCard('會員數', users.length.toString(), Icons.people, cs),
              ],
            );
          },
        );
      },
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, ColorScheme cs) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // 最近訂單
  // =====================================================
  Widget _recentOrdersSection(ColorScheme cs) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近訂單（最新 20 筆）',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('目前沒有訂單資料'),
                  );
                }

                return Column(
                  children: docs.map((d) {
                    final data = d.data();
                    final amount = data['totalAmount'] ?? 0;
                    final ts = data['createdAt'];
                    final dt =
                        ts is Timestamp ? ts.toDate() : DateTime.now();

                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.receipt_long),
                      title: Text('訂單 ${d.id}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        DateFormat('yyyy/MM/dd HH:mm').format(dt),
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      trailing: Text(
                        NumberFormat.currency(
                                locale: 'zh_TW', symbol: 'NT\$')
                            .format(amount),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

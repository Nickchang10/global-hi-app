// lib/pages/admin/dashboard/admin_dashboard_page.dart
//
// ✅ AdminDashboardPage（管理總覽｜完整版｜可編譯）
// -----------------------------------------------------------------------------
// 修正：Undefined class 'DashboardStats'
// - 補上 DashboardStats model
// - 從 Firestore 讀取 app_stats/admin_dashboard 作為後台統計資料來源
// - 沒有統計文件也可正常顯示（顯示提示）
// - 使用 ScaffoldWithDrawer 統一後台框架
//
// Firestore 建議：
// app_stats/admin_dashboard fields (可自行擴充):
//  - totalUsers (num)
//  - totalOrders (num)
//  - totalRevenue (num)
//  - totalProducts (num)
//  - activeCarts (num)
//  - updatedAt (Timestamp)
//
// 路由假設：
// - /admin-dashboard
// - /admin-products
// - /admin-orders
// - /admin-announcements
// - /reports
// - /user-notifications
// -----------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../layouts/scaffold_with_drawer.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _db = FirebaseFirestore.instance;

  Future<DashboardStats> _loadStats() async {
    final doc = await _db.collection('app_stats').doc('admin_dashboard').get();
    if (!doc.exists) {
      return DashboardStats.empty();
    }
    return DashboardStats.fromMap(doc.data() ?? {});
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithDrawer(
      title: '管理總覽',
      currentRoute: '/admin-dashboard',
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<DashboardStats>(
              future: _loadStats(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final stats = snap.data ?? DashboardStats.empty();
                return _statsSection(context, stats);
              },
            ),
            const SizedBox(height: 12),
            _quickLinks(context),
            const SizedBox(height: 20),
            _hintCard(context),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _statsSection(BuildContext context, DashboardStats s) {
    final cs = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    final updatedText = s.updatedAt == null
        ? '尚未建立統計'
        : '更新時間：${DateFormat('yyyy/MM/dd HH:mm').format(s.updatedAt!)}';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '核心指標',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              updatedText,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard(title: '使用者數', value: s.totalUsers.toString()),
                _statCard(title: '訂單數', value: s.totalOrders.toString()),
                _statCard(title: '營收', value: money.format(s.totalRevenue)),
                _statCard(title: '商品數', value: s.totalProducts.toString()),
                _statCard(title: '有效購物車', value: s.activeCarts.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({required String title, required String value}) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickLinks(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快速入口',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _quickTile(
                  context,
                  title: '商品管理',
                  icon: Icons.inventory_2_outlined,
                  color: cs.secondaryContainer,
                  route: '/admin-products',
                ),
                _quickTile(
                  context,
                  title: '訂單管理',
                  icon: Icons.receipt_long_outlined,
                  color: cs.tertiaryContainer,
                  route: '/admin-orders',
                ),
                _quickTile(
                  context,
                  title: '公告管理',
                  icon: Icons.announcement_outlined,
                  color: cs.primaryContainer,
                  route: '/admin-announcements',
                ),
                _quickTile(
                  context,
                  title: '報表統計',
                  icon: Icons.bar_chart_outlined,
                  color: cs.secondaryContainer,
                  route: '/reports',
                ),
                _quickTile(
                  context,
                  title: '通知中心',
                  icon: Icons.notifications_outlined,
                  color: cs.tertiaryContainer,
                  route: '/user-notifications',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return SizedBox(
      width: 170,
      height: 110,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushReplacementNamed(context, route),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hintCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          '提示：\n'
          '• 本頁預設讀取 Firestore：app_stats/admin_dashboard 作為統計來源。\n'
          '• 若你尚未建立該文件，頁面仍可正常顯示（但數字會是 0）。\n'
          '• 建議用 Cloud Function / 排程任務定期回寫統計，避免後台每次都掃描大量集合。',
          style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
        ),
      ),
    );
  }
}

/// ✅ 修正重點：補上 DashboardStats 類別
class DashboardStats {
  final int totalUsers;
  final int totalOrders;
  final num totalRevenue;
  final int totalProducts;
  final int activeCarts;
  final DateTime? updatedAt;

  const DashboardStats({
    required this.totalUsers,
    required this.totalOrders,
    required this.totalRevenue,
    required this.totalProducts,
    required this.activeCarts,
    required this.updatedAt,
  });

  factory DashboardStats.empty() => const DashboardStats(
    totalUsers: 0,
    totalOrders: 0,
    totalRevenue: 0,
    totalProducts: 0,
    activeCarts: 0,
    updatedAt: null,
  );

  factory DashboardStats.fromMap(Map<String, dynamic> map) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '0') ?? 0;
    }

    num toNum(dynamic v) {
      if (v is num) return v;
      return num.tryParse(v?.toString() ?? '0') ?? 0;
    }

    DateTime? toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return DashboardStats(
      totalUsers: toInt(map['totalUsers']),
      totalOrders: toInt(map['totalOrders']),
      totalRevenue: toNum(map['totalRevenue']),
      totalProducts: toInt(map['totalProducts']),
      activeCarts: toInt(map['activeCarts']),
      updatedAt: toDate(map['updatedAt']),
    );
  }
}

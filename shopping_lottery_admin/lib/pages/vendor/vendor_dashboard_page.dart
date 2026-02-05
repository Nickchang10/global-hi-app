// lib/pages/vendor/vendor_dashboard_page.dart
//
// ✅ VendorDashboardPage（完整最終版）
// ------------------------------------------------------------
// - 今日營收 / 訂單數 / 熱銷商品摘要
// - 庫存警示（顯示低於安全庫存的商品）
// - 快捷導覽：商品管理、訂單、報表
// - Firestore 即時更新
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class VendorDashboardPage extends StatefulWidget {
  const VendorDashboardPage({super.key});

  @override
  State<VendorDashboardPage> createState() => _VendorDashboardPageState();
}

class _VendorDashboardPageState extends State<VendorDashboardPage> {
  String? _vendorId;
  bool _loading = true;
  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  @override
  void initState() {
    super.initState();
    _loadVendorId();
  }

  Future<void> _loadVendorId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    _vendorId = snap.data()?['vendorId'];
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_vendorId == null) {
      return const Scaffold(body: Center(child: Text('尚未綁定廠商帳號')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('廠商儀表板', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTodaySummary(),
            const SizedBox(height: 20),
            _buildRevenueTrendChart(),
            const SizedBox(height: 20),
            _buildLowStockAlert(),
            const SizedBox(height: 20),
            _buildTopProducts(),
            const SizedBox(height: 20),
            _buildQuickActions(context),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // 今日摘要
  // =====================================================

  Widget _buildTodaySummary() {
    final todayStart = DateTime.now();
    final startOfDay =
        DateTime(todayStart.year, todayStart.month, todayStart.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendorIds', arrayContains: _vendorId)
          .where('status', whereIn: ['paid', 'shipping', 'completed'])
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        num todayRevenue = 0;
        int todayOrders = 0;

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['createdAt'];
          if (ts is Timestamp) {
            final date = ts.toDate();
            if (date.isAfter(startOfDay)) {
              todayOrders++;
              todayRevenue += (data['finalAmount'] ?? 0) as num;
            }
          }
        }

        return Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: '今日營收',
                value: _moneyFmt.format(todayRevenue),
                color: Colors.green,
                icon: Icons.attach_money_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                title: '今日訂單',
                value: '$todayOrders 筆',
                color: Colors.blue,
                icon: Icons.receipt_long_rounded,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(
      {required String title,
      required String value,
      required Color color,
      required IconData icon}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500)),
                  Text(value,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // 營收折線圖
  // =====================================================

  Widget _buildRevenueTrendChart() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendorIds', arrayContains: _vendorId)
          .where('status', whereIn: ['paid', 'shipping', 'completed'])
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        final Map<String, num> dailyRevenue = {};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['createdAt'];
          if (ts is Timestamp) {
            final day = DateFormat('MM/dd').format(ts.toDate());
            final amt = (data['finalAmount'] ?? 0) as num;
            dailyRevenue[day] = (dailyRevenue[day] ?? 0) + amt;
          }
        }

        final keys = dailyRevenue.keys.toList()..sort();
        final spots = <FlSpot>[];
        for (var i = 0; i < keys.length; i++) {
          spots.add(FlSpot(i.toDouble(), dailyRevenue[keys[i]]!.toDouble()));
        }

        if (spots.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('尚無營收資料'),
            ),
          );
        }

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('近期待營收趨勢',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (v, meta) {
                              if (v.toInt() < 0 ||
                                  v.toInt() >= keys.length) {
                                return const SizedBox.shrink();
                              }
                              return Text(keys[v.toInt()],
                                  style: const TextStyle(fontSize: 10));
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                              show: true, color: Colors.green.withOpacity(0.15)),
                          spots: spots,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // 庫存警示
  // =====================================================

  Widget _buildLowStockAlert() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('vendorId', isEqualTo: _vendorId)
          .where('stock', isLessThan: 5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('庫存警示',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
                    title: Text(data['title'] ?? '-'),
                    subtitle: Text('目前庫存：${data['stock'] ?? 0}'),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // 熱銷商品摘要
  // =====================================================

  Widget _buildTopProducts() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('vendorId', isEqualTo: _vendorId)
          .orderBy('sold', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('尚無銷售紀錄'),
            ),
          );
        }

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('熱銷商品 TOP 5',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    dense: true,
                    leading: data['image'] != null
                        ? Image.network(data['image'],
                            width: 50, height: 50, fit: BoxFit.cover)
                        : const Icon(Icons.image_outlined),
                    title: Text(data['title'] ?? '-'),
                    subtitle: Text('銷售量：${data['sold'] ?? 0}'),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // 快捷功能
  // =====================================================

  Widget _buildQuickActions(BuildContext context) {
    final buttons = [
      _quickButton(
        icon: Icons.store_mall_directory_rounded,
        color: Colors.blue,
        label: '商品管理',
        onTap: () => Navigator.pushNamed(context, '/vendor_products'),
      ),
      _quickButton(
        icon: Icons.receipt_long_rounded,
        color: Colors.green,
        label: '訂單管理',
        onTap: () => Navigator.pushNamed(context, '/vendor_orders'),
      ),
      _quickButton(
        icon: Icons.bar_chart_rounded,
        color: Colors.orange,
        label: '銷售報表',
        onTap: () => Navigator.pushNamed(context, '/vendor_reports'),
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: buttons,
    );
  }

  Widget _quickButton(
      {required IconData icon,
      required Color color,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

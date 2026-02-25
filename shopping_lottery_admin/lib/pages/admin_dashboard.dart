// lib/pages/admin_dashboard_page.dart
//
// ✅ AdminDashboardPage（最終完整版｜Firestore 統計 + fl_chart 圓餅 / 折線圖 + KPI 指標）
// ------------------------------------------------------------
// ✅ 修正：deprecated withOpacity → withValues(alpha: ...)
// ✅ 保留：手動 RefreshIndicator 重新抓 products 統計
//
// Firestore 結構建議：
// products/{productId}
//   - title: String
//   - price: num
//   - isActive: bool
//   - categoryId: String?
//   - createdAt: Timestamp
//
// categories/{categoryId}
//   - name: String
//
// ------------------------------------------------------------
// 依賴：
// - cloud_firestore
// - fl_chart
// - intl
// - flutter_animate
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;

  int totalCount = 0;
  int activeCount = 0;
  int inactiveCount = 0;
  double totalValue = 0.0;

  // 可留作未來顯示（目前不影響編譯）
  Map<String, int> categoryCounts = {};
  Map<String, int> monthlyNewProducts = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final snap = await _db.collection('products').get();

      int active = 0, inactive = 0;
      double totalVal = 0;
      final Map<String, int> catCount = {};
      final Map<String, int> monthly = {};

      for (final doc in snap.docs) {
        final data = doc.data();

        final bool isActive = data['isActive'] == true;
        final num price = (data['price'] is num) ? data['price'] as num : 0;

        final String? cat = (data['categoryId'] ?? '').toString().trim().isEmpty
            ? null
            : (data['categoryId'] as String?);

        final createdAt = data['createdAt'];

        if (isActive) {
          active++;
        } else {
          inactive++;
        }

        totalVal += price.toDouble();

        if (cat != null && cat.isNotEmpty) {
          catCount[cat] = (catCount[cat] ?? 0) + 1;
        }

        if (createdAt is Timestamp) {
          final dt = createdAt.toDate();
          final key = DateFormat('yyyy-MM').format(dt);
          monthly[key] = (monthly[key] ?? 0) + 1;
        }
      }

      if (!mounted) return;
      setState(() {
        totalCount = snap.size;
        activeCount = active;
        inactiveCount = inactive;
        totalValue = totalVal;
        categoryCounts = catCount;
        monthlyNewProducts = monthly;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load stats error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('儀表板分析')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKPISection(cs),
                    const SizedBox(height: 20),
                    _buildPieChartSection(cs),
                    const SizedBox(height: 20),
                    _buildLineChartSection(cs),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ----------------------------
  // KPI Cards
  // ----------------------------
  Widget _buildKPISection(ColorScheme cs) {
    final formatter = NumberFormat('#,###');

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _kpiCard(
          color: cs.primary,
          icon: Icons.shopping_bag_outlined,
          label: '商品總數',
          value: totalCount.toString(),
        ),
        _kpiCard(
          color: Colors.green,
          icon: Icons.check_circle_outline,
          label: '上架中',
          value: activeCount.toString(),
        ),
        _kpiCard(
          color: Colors.redAccent,
          icon: Icons.block_outlined,
          label: '下架',
          value: inactiveCount.toString(),
        ),
        _kpiCard(
          color: Colors.orange,
          icon: Icons.attach_money,
          label: '商品總價值',
          value: 'NT\$ ${formatter.format(totalValue)}',
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).moveY(begin: 12);
  }

  Widget _kpiCard({
    required Color color,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------
  // Pie Chart: 啟用 vs 停用商品
  // ----------------------------
  Widget _buildPieChartSection(ColorScheme cs) {
    final total = activeCount + inactiveCount;
    if (total == 0) {
      return const Center(child: Text('無商品資料'));
    }

    final data = [
      PieChartSectionData(
        value: activeCount.toDouble(),
        color: Colors.green,
        title: '上架',
        radius: 60,
        titleStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: inactiveCount.toDouble(),
        color: Colors.redAccent,
        title: '下架',
        radius: 60,
        titleStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '商品啟用比例',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: data,
                  centerSpaceRadius: 40,
                  sectionsSpace: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).moveY(begin: 20);
  }

  // ----------------------------
  // Line Chart: 每月新增商品數
  // ----------------------------
  Widget _buildLineChartSection(ColorScheme cs) {
    if (monthlyNewProducts.isEmpty) {
      return const Center(child: Text('尚無新增紀錄'));
    }

    final sortedKeys = monthlyNewProducts.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      spots.add(
        FlSpot(i.toDouble(), (monthlyNewProducts[key] ?? 0).toDouble()),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '每月新增商品數',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, horizontalInterval: 1),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= sortedKeys.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              sortedKeys[i].substring(5), // 顯示月份
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, interval: 1),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: cs.primary,
                      belowBarData: BarAreaData(
                        show: true,
                        color: cs.primary.withValues(alpha: 0.2),
                      ),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).moveY(begin: 24);
  }
}

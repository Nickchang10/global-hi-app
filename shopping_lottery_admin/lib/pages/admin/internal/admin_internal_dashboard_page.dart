// lib/pages/admin/internal/admin_internal_dashboard_page.dart
//
// ✅ AdminInternalDashboardPage（完整版｜內部管理儀表板）
// ------------------------------------------------------------
// - Firestore 來源：announcements, approvals, users
// - 顯示：公告統計、待審核數、活躍員工、部門分佈
// - 支援：自動更新、圖表展示（使用 Charts 套件）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminInternalDashboardPage extends StatefulWidget {
  const AdminInternalDashboardPage({super.key});

  @override
  State<AdminInternalDashboardPage> createState() =>
      _AdminInternalDashboardPageState();
}

class _AdminInternalDashboardPageState
    extends State<AdminInternalDashboardPage> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('內部管理儀表板',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder(
        stream: _dashboardData(),
        builder: (context, AsyncSnapshot<_DashboardData> snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('載入失敗：${snap.error}'));
          }
          final data = snap.data;
          if (data == null) return const Center(child: Text('無資料'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _summaryRow(cs, data),
              const SizedBox(height: 16),
              _chartSection(cs, data),
              const SizedBox(height: 16),
              _latestAnnouncements(cs, data.latestAnnouncements),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // Stream 組合 Firestore 數據
  // ============================================================
  Stream<_DashboardData> _dashboardData() async* {
    final annSnap = await _db.collection('announcements').get();
    final appSnap = await _db.collection('approvals').get();
    final userSnap = await _db.collection('users').get();

    // 統計
    final totalAnn = annSnap.size;
    final pinnedAnn =
        annSnap.docs.where((d) => d.data()['pinned'] == true).length;
    final pendingApprovals =
        appSnap.docs.where((d) => d.data()['status'] == 'pending').length;
    final approvedApprovals =
        appSnap.docs.where((d) => d.data()['status'] == 'approved').length;

    // 活躍員工（最近 14 天內 updatedAt）
    final activeUsers = userSnap.docs.where((d) {
      final updatedAt = (d.data()['updatedAt'] as Timestamp?)?.toDate();
      if (updatedAt == null) return false;
      return DateTime.now().difference(updatedAt).inDays <= 14;
    }).length;

    // 部門分佈（users.department）
    final deptCounts = <String, int>{};
    for (final doc in userSnap.docs) {
      final dept = (doc.data()['department'] ?? '未分類').toString();
      deptCounts[dept] = (deptCounts[dept] ?? 0) + 1;
    }

    // 最新公告
    final annList = annSnap.docs
        .map((d) => {
              'id': d.id,
              'title': d.data()['title'] ?? '未命名公告',
              'createdAt':
                  (d.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            })
        .toList()
      ..sort((a, b) =>
          (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

    yield _DashboardData(
      totalAnnouncements: totalAnn,
      pinnedAnnouncements: pinnedAnn,
      pendingApprovals: pendingApprovals,
      approvedApprovals: approvedApprovals,
      activeUsers: activeUsers,
      deptCounts: deptCounts,
      latestAnnouncements: annList.take(5).toList(),
    );
  }

  // ============================================================
  // Summary Cards
  // ============================================================
  Widget _summaryRow(ColorScheme cs, _DashboardData d) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryCard(
          cs,
          icon: Icons.campaign_outlined,
          label: '公告數',
          value: d.totalAnnouncements.toString(),
          color: cs.primary,
        ),
        _summaryCard(
          cs,
          icon: Icons.push_pin,
          label: '置頂公告',
          value: d.pinnedAnnouncements.toString(),
          color: Colors.orange,
        ),
        _summaryCard(
          cs,
          icon: Icons.assignment_late_outlined,
          label: '待審核',
          value: d.pendingApprovals.toString(),
          color: Colors.redAccent,
        ),
        _summaryCard(
          cs,
          icon: Icons.assignment_turned_in_outlined,
          label: '已通過審核',
          value: d.approvedApprovals.toString(),
          color: Colors.green,
        ),
        _summaryCard(
          cs,
          icon: Icons.people_alt_outlined,
          label: '活躍員工',
          value: d.activeUsers.toString(),
          color: cs.primaryContainer,
        ),
      ],
    );
  }

  Widget _summaryCard(ColorScheme cs,
      {required IconData icon,
      required String label,
      required String value,
      required Color color}) {
    return Card(
      elevation: 0,
      color: cs.surface,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: color)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 圖表區
  // ============================================================
  Widget _chartSection(ColorScheme cs, _DashboardData d) {
    final total = d.deptCounts.values.fold<int>(0, (a, b) => a + b);
    final chartData = d.deptCounts.entries.map((e) {
      final percent = total == 0 ? 0.0 : (e.value / total) * 100;
      return PieChartSectionData(
        color: _randomColor(e.key.hashCode),
        value: percent,
        title: '${e.key}\n${percent.toStringAsFixed(1)}%',
        radius: 70,
        titleStyle:
            const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      );
    }).toList();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('部門人數分佈',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            if (chartData.isEmpty)
              const Text('尚無資料')
            else
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sections: chartData,
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 最新公告
  // ============================================================
  Widget _latestAnnouncements(ColorScheme cs, List<Map<String, dynamic>> list) {
    final fmt = DateFormat('yyyy/MM/dd HH:mm');
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('最新公告',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            if (list.isEmpty)
              const Text('目前沒有公告')
            else
              ...list.map((a) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.campaign_outlined),
                    title: Text(a['title'] ?? '未命名'),
                    subtitle: Text(
                      fmt.format(a['createdAt']),
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Utils
  // ============================================================
  Color _randomColor(int seed) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.redAccent,
      Colors.teal,
    ];
    return colors[seed % colors.length];
  }
}

// ============================================================
// 資料模型
// ============================================================

class _DashboardData {
  final int totalAnnouncements;
  final int pinnedAnnouncements;
  final int pendingApprovals;
  final int approvedApprovals;
  final int activeUsers;
  final Map<String, int> deptCounts;
  final List<Map<String, dynamic>> latestAnnouncements;

  _DashboardData({
    required this.totalAnnouncements,
    required this.pinnedAnnouncements,
    required this.pendingApprovals,
    required this.approvedApprovals,
    required this.activeUsers,
    required this.deptCounts,
    required this.latestAnnouncements,
  });
}

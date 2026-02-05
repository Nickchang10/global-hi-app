// lib/pages/admin/system/system_analytics_page.dart
//
// ✅ SystemAnalyticsPage（修正版最終完整版｜可編譯｜更耐用）
// ------------------------------------------------------------
// 功能摘要：
// - 從 Firestore 統計 users / orders / lottery / sos_alerts 集合
// - 日期範圍篩選（DateRangePicker）
// - 折線圖 (fl_chart)：每日新增用戶 / 訂單量
// - 圓餅圖：訂單狀態占比
// - Summary Cards（營運總覽）
// - ✅ 修正：所有 createdAt 範圍查詢一律使用 Timestamp.fromDate
// - ✅ 修正：mounted 防呆、並行載入 Future.wait
// - ✅ 修正：createdAt 欄位缺失/型別錯誤容錯，不會整頁炸掉
// - ✅ 修正：折線圖補齊區間天數（沒有資料的日也顯示 0）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SystemAnalyticsPage extends StatefulWidget {
  const SystemAnalyticsPage({super.key});

  @override
  State<SystemAnalyticsPage> createState() => _SystemAnalyticsPageState();
}

class _SystemAnalyticsPageState extends State<SystemAnalyticsPage> {
  final _db = FirebaseFirestore.instance;

  DateTimeRange? _range;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ===========================================================
  // Data loader
  // ===========================================================
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final defaultStart = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 13)); // 含今天共 14 天
      final defaultEnd =
          DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      final start = _range?.start ?? defaultStart;
      final end = _range?.end ?? defaultEnd;

      final startTs = Timestamp.fromDate(start);
      final endTs = Timestamp.fromDate(end);

      // ✅ 並行載入
      final results = await Future.wait([
        _db
            .collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get(),
        _db
            .collection('orders')
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get(),
        _db
            .collection('lottery')
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get(),
        _db
            .collection('sos_alerts')
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get(),
      ]);

      final usersSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final ordersSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final lotterySnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final sosSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;

      final newUsers = usersSnap.size;
      final totalOrders = ordersSnap.size;

      final completedOrders =
          ordersSnap.docs.where((d) => (d.data()['status'] ?? '') == 'completed').length;

      final totalLottery = lotterySnap.size;
      final sosCount = sosSnap.size;

      // -------------------------------------------------------
      // Daily aggregation (補零)
      // -------------------------------------------------------
      final dailyNewUsers = _initDailyIntMap(start, end);
      final dailyOrders = _initDailyIntMap(start, end);

      for (final doc in usersSnap.docs) {
        final createdAt = _toDateTime(doc.data()['createdAt']);
        if (createdAt == null) continue;
        final dayKey = DateFormat('MM/dd').format(createdAt);
        if (dailyNewUsers.containsKey(dayKey)) {
          dailyNewUsers[dayKey] = (dailyNewUsers[dayKey] ?? 0) + 1;
        }
      }

      for (final doc in ordersSnap.docs) {
        final createdAt = _toDateTime(doc.data()['createdAt']);
        if (createdAt == null) continue;
        final dayKey = DateFormat('MM/dd').format(createdAt);
        if (dailyOrders.containsKey(dayKey)) {
          dailyOrders[dayKey] = (dailyOrders[dayKey] ?? 0) + 1;
        }
      }

      // -------------------------------------------------------
      // Status distribution
      // -------------------------------------------------------
      final statusCount = <String, int>{};
      for (final doc in ordersSnap.docs) {
        final s = (doc.data()['status'] ?? 'unknown').toString();
        statusCount[s] = (statusCount[s] ?? 0) + 1;
      }

      final payload = {
        'rangeStart': start,
        'rangeEnd': end,
        'newUsers': newUsers,
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
        'lottery': totalLottery,
        'sos': sosCount,
        'dailyNewUsers': dailyNewUsers,
        'dailyOrders': dailyOrders,
        'statusCount': statusCount,
      };

      if (!mounted) return;
      setState(() {
        _data = payload;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _data = null;
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ===========================================================
  // UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('系統報表分析', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '選擇日期',
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2023, 1, 1),
                lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
                initialDateRange: _range,
                helpText: '選擇分析區間',
                confirmText: '套用',
                cancelText: '取消',
              );
              if (picked != null) {
                setState(() => _range = picked);
                _loadData();
              }
            },
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? _ErrorView(message: _error!, onRetry: _loadData)
              : (_data == null)
                  ? const Center(child: Text('無資料'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _rangeBar(cs, _data!),
                        const SizedBox(height: 12),
                        _summaryCards(cs, _data!),
                        const SizedBox(height: 16),
                        _lineChartSection(cs, _data!),
                        const SizedBox(height: 16),
                        _pieChartSection(cs, _data!),
                        const SizedBox(height: 24),
                      ],
                    ),
    );
  }

  Widget _rangeBar(ColorScheme cs, Map<String, dynamic> d) {
    final start = d['rangeStart'] as DateTime?;
    final end = d['rangeEnd'] as DateTime?;
    final fmt = DateFormat('yyyy/MM/dd');

    final label = (start == null || end == null)
        ? '區間：近 14 天'
        : '區間：${fmt.format(start)} ～ ${fmt.format(end)}';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2023, 1, 1),
                  lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
                  initialDateRange: _range,
                );
                if (picked != null) {
                  setState(() => _range = picked);
                  _loadData();
                }
              },
              icon: const Icon(Icons.date_range),
              label: const Text('選擇'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // Summary cards
  // ===========================================================
  Widget _summaryCards(ColorScheme cs, Map<String, dynamic> d) {
    final items = [
      _SummaryItem('新註冊用戶', '${d['newUsers']}', Icons.person_add, cs.primary),
      _SummaryItem('總訂單', '${d['totalOrders']}', Icons.shopping_cart, Colors.orange),
      _SummaryItem('完成訂單', '${d['completedOrders']}', Icons.task_alt, Colors.green),
      _SummaryItem('抽獎紀錄', '${d['lottery']}', Icons.card_giftcard, Colors.purple),
      _SummaryItem('SOS 求救', '${d['sos']}', Icons.warning_amber_outlined, Colors.redAccent),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w < 520 ? 2 : (w < 860 ? 3 : 5);

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.1,
          children: items
              .map((it) => _summaryCard(cs, it.label, it.value, it.icon, it.color))
              .toList(),
        );
      },
    );
  }

  Widget _summaryCard(
    ColorScheme cs,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // Line chart
  // ===========================================================
  Widget _lineChartSection(ColorScheme cs, Map<String, dynamic> d) {
    final dailyNewUsers = Map<String, int>.from(d['dailyNewUsers'] as Map);
    final dailyOrders = Map<String, int>.from(d['dailyOrders'] as Map);

    final days = {...dailyNewUsers.keys, ...dailyOrders.keys}.toList()..sort();

    final userSpots = <FlSpot>[];
    final orderSpots = <FlSpot>[];

    for (int i = 0; i < days.length; i++) {
      userSpots.add(
        FlSpot(i.toDouble(), (dailyNewUsers[days[i]] ?? 0).toDouble()),
      );
      orderSpots.add(
        FlSpot(i.toDouble(), (dailyOrders[days[i]] ?? 0).toDouble()),
      );
    }

    final maxY = [
      ...dailyNewUsers.values.map((e) => e.toDouble()),
      ...dailyOrders.values.map((e) => e.toDouble()),
    ].fold<double>(0, (p, n) => p > n ? p : n);

    if (days.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('區間內無資料'),
        ),
      );
    }

    final step = (days.length / 6).ceil().clamp(1, 999);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '每日新增用戶與訂單量',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: (maxY <= 0) ? 3 : (maxY * 1.2),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, _) {
                          if (v == 0) return const Text('0');
                          return Text(v.toInt().toString(), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= days.length) return const SizedBox.shrink();
                          if (i % step != 0 && i != days.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(days[i], style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: userSpots,
                      isCurved: true,
                      color: cs.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: orderSpots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _legendDot(cs.primary, '新用戶'),
                const SizedBox(width: 12),
                _legendDot(Colors.green, '訂單'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ===========================================================
  // Pie chart
  // ===========================================================
  Widget _pieChartSection(ColorScheme cs, Map<String, dynamic> d) {
    final statusCount = Map<String, int>.from(d['statusCount'] as Map);

    if (statusCount.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('區間內沒有訂單資料'),
        ),
      );
    }

    final total = statusCount.values.fold<int>(0, (a, b) => a + b);
    final entries = statusCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final value = e.value.toDouble();
      final percent = total == 0 ? 0.0 : (value / total * 100);

      final color = Colors.primaries[i % Colors.primaries.length];

      sections.add(
        PieChartSectionData(
          color: color,
          value: value,
          radius: 70,
          title: percent < 6 ? '' : '${percent.toStringAsFixed(1)}%',
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('訂單狀態占比', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        borderData: FlBorderData(show: false),
                        centerSpaceRadius: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        final color = Colors.primaries[i % Colors.primaries.length];
                        final percent = total == 0 ? 0.0 : (e.value / total * 100);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(width: 12, height: 12, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '${e.value} (${percent.toStringAsFixed(1)}%)',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // Helpers
  // ===========================================================
  Map<String, int> _initDailyIntMap(DateTime start, DateTime end) {
    final map = <String, int>{};
    final fmt = DateFormat('MM/dd');

    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);

    for (int i = 0; i <= e.difference(s).inDays; i++) {
      final d = s.add(Duration(days: i));
      map[fmt.format(d)] = 0;
    }
    return map;
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    // 一些人會存成 millis
    if (v is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {}
    }
    return null;
  }

  String _friendlyError(Object e) {
    final raw = e.toString();

    // 常見：權限不足
    if (raw.contains('permission-denied')) {
      return '權限不足（permission-denied）。\n'
          '請確認你目前登入帳號在 users/{uid}.role = "admin"（或規則允許的角色）。';
    }

    // 常見：索引缺失（當你加上更多 where/orderBy 時會遇到）
    if (raw.contains('FAILED_PRECONDITION') || raw.contains('requires an index')) {
      return 'Firestore 缺少索引（requires an index）。\n'
          '請依錯誤訊息提供的連結到 Firebase Console 建立 index。';
    }

    // 常見：欄位型別問題
    if (raw.contains('Timestamp') || raw.contains('type')) {
      return '資料欄位型別不一致。\n'
          '請確認 users/orders/lottery/sos_alerts 的 createdAt 為 Timestamp（serverTimestamp）。\n\n原始錯誤：$raw';
    }

    return raw;
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _SummaryItem(this.label, this.value, this.icon, this.color);
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  const Text(
                    '載入分析資料失敗',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

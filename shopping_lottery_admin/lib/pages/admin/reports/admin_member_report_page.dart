// lib/pages/admin/reports/admin_member_report_page.dart
//
// ✅ AdminMemberReportPage（完整版）
// ------------------------------------------------------------
// - 會員總覽：總會員、期間新增、期間活躍（有下單）
// - 期間營收、訂單數、AOV（平均客單）、ARPU（每活躍會員平均營收）
// - 近 N 日新增會員趨勢（fl_chart 折線圖）
// - 會員貢獻排行 Top 10（以期間內訂單 finalAmount 加總）
// - 支援日期區間選擇、快速區間（7/30/90 天）、重新整理
//
// Firestore 需求（可依你實際欄位調整）：
// - users: createdAt(Timestamp), displayName/name/email (任一) , uid(optional)
// - orders: createdAt(Timestamp), status(String), finalAmount(num),
//          userId/uid/customerId (任一), customerName/userName (任一)
//
// ------------------------------------------------------------

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminMemberReportPage extends StatefulWidget {
  const AdminMemberReportPage({super.key});

  @override
  State<AdminMemberReportPage> createState() => _AdminMemberReportPageState();
}

class _AdminMemberReportPageState extends State<AdminMemberReportPage> {
  bool loading = true;
  Object? error;

  /// 報表區間（影響：期間新增會員、期間訂單/營收、排行）
  late DateTimeRange range;

  /// 成長圖顯示天數（預設 14 天）
  int growthDays = 14;

  // ===== 統計結果 =====
  int totalMembers = 0;
  int newMembersInRange = 0;

  int orderCountInRange = 0;
  num revenueInRange = 0;

  int activePurchasersInRange = 0; // 期間內有下單的會員數（以 userKey 去重）

  num get aov => orderCountInRange == 0 ? 0 : (revenueInRange / orderCountInRange);
  num get arpu =>
      activePurchasersInRange == 0 ? 0 : (revenueInRange / activePurchasersInRange);

  /// yyyy-MM-dd -> 新增會員數
  Map<String, int> dailyNewMembers = {};

  /// 會員排行（期間內消費）
  List<_MemberRankRow> topMembers = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    range = DateTimeRange(
      start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // 並行拉取：總會員、區間新增、區間訂單、近 N 日新增會員趨勢
      final results = await Future.wait([
        _fetchTotalMembers(),
        _fetchNewMembersInRange(range),
        _fetchOrdersInRange(range),
        _fetchDailyNewMembers(days: growthDays),
      ]);

      totalMembers = results[0] as int;
      newMembersInRange = results[1] as int;

      final orderAgg = results[2] as _OrderAgg;
      orderCountInRange = orderAgg.orderCount;
      revenueInRange = orderAgg.revenue;
      activePurchasersInRange = orderAgg.uniquePurchasers;
      topMembers = orderAgg.topMembers;

      dailyNewMembers = results[3] as Map<String, int>;

      setState(() => loading = false);
    } catch (e) {
      setState(() {
        loading = false;
        error = e;
      });
    }
  }

  // =========================================================
  // Firestore Fetch
  // =========================================================

  Future<int> _fetchTotalMembers() async {
    // 若 Firestore SDK 支援 count() 可改用聚合查詢；這裡採用相容做法：get().docs.length
    final qs = await FirebaseFirestore.instance.collection('users').get();
    return qs.docs.length;
  }

  Future<int> _fetchNewMembersInRange(DateTimeRange r) async {
    final qs = await FirebaseFirestore.instance
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: r.start)
        .where('createdAt', isLessThanOrEqualTo: r.end)
        .get();
    return qs.docs.length;
  }

  Future<Map<String, int>> _fetchDailyNewMembers({required int days}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final qs = await FirebaseFirestore.instance
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .get();

    final map = <String, int>{};
    for (final doc in qs.docs) {
      final data = doc.data();
      final dt = _asDateTime(data['createdAt']);
      if (dt == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(dt);
      map[key] = (map[key] ?? 0) + 1;
    }

    // 補齊缺天為 0（讓折線圖連續）
    for (int i = 0; i < days; i++) {
      final d = start.add(Duration(days: i));
      final k = DateFormat('yyyy-MM-dd').format(d);
      map[k] = map[k] ?? 0;
    }

    final sortedKeys = map.keys.toList()..sort();
    return {for (final k in sortedKeys) k: map[k] ?? 0};
  }

  Future<_OrderAgg> _fetchOrdersInRange(DateTimeRange r) async {
    // 訂單狀態依你目前報表頁的定義
    Query q = FirebaseFirestore.instance
        .collection('orders')
        .where('status', whereIn: ['paid', 'shipping', 'completed'])
        .where('createdAt', isGreaterThanOrEqualTo: r.start)
        .where('createdAt', isLessThanOrEqualTo: r.end);

    final qs = await q.get();

    num revenue = 0;
    final purchaserSet = <String>{};

    // 會員排行（期間內消費 & 訂單數）
    final memberAgg = <String, _MemberAgg>{};

    for (final doc in qs.docs) {
      final o = doc.data() as Map<String, dynamic>;
      final amount = (o['finalAmount'] ?? 0) as num;
      revenue += amount;

      final userKey = _pickUserKey(o, fallback: doc.id);
      purchaserSet.add(userKey);

      final name = _pickUserName(o, fallback: userKey);

      final current = memberAgg[userKey] ?? _MemberAgg(name: name, revenue: 0, orders: 0);
      memberAgg[userKey] = _MemberAgg(
        name: current.name.isNotEmpty ? current.name : name,
        revenue: current.revenue + amount,
        orders: current.orders + 1,
      );
    }

    final top = memberAgg.entries
        .map((e) => _MemberRankRow(userKey: e.key, name: e.value.name, revenue: e.value.revenue, orders: e.value.orders))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return _OrderAgg(
      orderCount: qs.docs.length,
      revenue: revenue,
      uniquePurchasers: purchaserSet.length,
      topMembers: top.take(10).toList(growable: false),
    );
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('會員報表', style: TextStyle(fontWeight: FontWeight.w900))),
        body: _ErrorView(
          title: '載入失敗',
          message: '$error',
          onRetry: _load,
        ),
      );
    }

    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final fmtInt = NumberFormat.decimalPattern('zh_TW');

    final rangeText =
        '${DateFormat('yyyy/MM/dd').format(range.start)} - ${DateFormat('yyyy/MM/dd').format(range.end)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('會員報表', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '選擇日期區間',
            icon: const Icon(Icons.date_range),
            onPressed: _pickRange,
          ),
          PopupMenuButton<int>(
            tooltip: '快速區間',
            icon: const Icon(Icons.filter_alt),
            onSelected: (days) => _setQuickRange(days),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('最近 7 天')),
              PopupMenuItem(value: 30, child: Text('最近 30 天')),
              PopupMenuItem(value: 90, child: Text('最近 90 天')),
            ],
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderBlock(
              title: '期間：$rangeText',
              subtitle: '成長圖：近 $growthDays 日新增會員',
              onChangeGrowthDays: (v) async {
                setState(() => growthDays = v);
                await _load();
              },
            ),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, c) {
                final crossAxisCount = _crossAxisCountForWidth(c.maxWidth);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.65,
                  children: [
                    _KpiCard(
                      icon: Icons.people,
                      title: '總會員數',
                      value: fmtInt.format(totalMembers),
                      footnote: '全站會員總數',
                    ),
                    _KpiCard(
                      icon: Icons.person_add_alt_1,
                      title: '期間新增會員',
                      value: fmtInt.format(newMembersInRange),
                      footnote: '依 users.createdAt 統計',
                    ),
                    _KpiCard(
                      icon: Icons.shopping_cart_checkout,
                      title: '期間活躍會員',
                      value: fmtInt.format(activePurchasersInRange),
                      footnote: '期間內有下單（去重）',
                    ),
                    _KpiCard(
                      icon: Icons.receipt_long,
                      title: '期間訂單數',
                      value: fmtInt.format(orderCountInRange),
                      footnote: 'paid/shipping/completed',
                    ),
                    _KpiCard(
                      icon: Icons.attach_money,
                      title: '期間營收',
                      value: fmtMoney.format(revenueInRange),
                      footnote: '加總 finalAmount',
                    ),
                    _KpiCard(
                      icon: Icons.equalizer,
                      title: 'AOV / ARPU',
                      value: '${fmtMoney.format(aov)} / ${fmtMoney.format(arpu)}',
                      footnote: '平均客單 / 每活躍會員營收',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),
            _GrowthChartCard(
              title: '新增會員趨勢（近 $growthDays 日）',
              daily: dailyNewMembers,
            ),

            const SizedBox(height: 16),
            _TopMembersCard(
              title: '會員貢獻排行（Top 10）',
              rows: topMembers,
              moneyFmt: fmtMoney,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  int _crossAxisCountForWidth(double w) {
    if (w >= 1200) return 3;
    if (w >= 820) return 3;
    return 2;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      initialDateRange: range,
    );
    if (picked == null) return;

    // end 補到當日 23:59:59
    final normalized = DateTimeRange(
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
    );

    setState(() => range = normalized);
    await _load();
  }

  Future<void> _setQuickRange(int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    setState(() => range = DateTimeRange(start: start, end: end));
    await _load();
  }

  // =========================================================
  // Helpers
  // =========================================================

  DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _pickUserKey(Map<String, dynamic> o, {required String fallback}) {
    final v = o['userId'] ?? o['uid'] ?? o['customerId'] ?? o['buyerId'];
    if (v == null) return fallback;
    return v.toString();
  }

  String _pickUserName(Map<String, dynamic> o, {required String fallback}) {
    final v = o['customerName'] ?? o['userName'] ?? o['buyerName'] ?? o['displayName'];
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }
}

// =========================================================
// Models (local)
// =========================================================

class _OrderAgg {
  final int orderCount;
  final num revenue;
  final int uniquePurchasers;
  final List<_MemberRankRow> topMembers;

  _OrderAgg({
    required this.orderCount,
    required this.revenue,
    required this.uniquePurchasers,
    required this.topMembers,
  });
}

class _MemberAgg {
  final String name;
  final num revenue;
  final int orders;

  _MemberAgg({
    required this.name,
    required this.revenue,
    required this.orders,
  });
}

class _MemberRankRow {
  final String userKey;
  final String name;
  final num revenue;
  final int orders;

  const _MemberRankRow({
    required this.userKey,
    required this.name,
    required this.revenue,
    required this.orders,
  });
}

// =========================================================
// Widgets
// =========================================================

class _HeaderBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final ValueChanged<int> onChangeGrowthDays;

  const _HeaderBlock({
    required this.title,
    required this.subtitle,
    required this.onChangeGrowthDays,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cs.onSurface),
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<int>(
          tooltip: '成長圖天數',
          onSelected: onChangeGrowthDays,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 7, child: Text('近 7 日')),
            PopupMenuItem(value: 14, child: Text('近 14 日')),
            PopupMenuItem(value: 30, child: Text('近 30 日')),
          ],
          child: Row(
            children: [
              Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(width: 6),
              Icon(Icons.expand_more, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String footnote;

  const _KpiCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface)),
                  const SizedBox(height: 6),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: cs.onSurface)),
                  const SizedBox(height: 4),
                  Text(
                    footnote,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrowthChartCard extends StatelessWidget {
  final String title;
  final Map<String, int> daily;

  const _GrowthChartCard({
    required this.title,
    required this.daily,
  });

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('尚無新增會員資料'),
        ),
      );
    }

    final keys = daily.keys.toList()..sort();
    final values = keys.map((k) => daily[k] ?? 0).toList();
    final maxY = math.max(3, (values.isEmpty ? 0 : values.reduce(math.max)) + 1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 14),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY.toDouble(),
                  gridData: FlGridData(show: true, horizontalInterval: 1),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: math.max(1, (keys.length / 6).floor()).toDouble(),
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                          // mm-dd
                          return Text(keys[i].substring(5), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      spots: [
                        for (int i = 0; i < keys.length; i++)
                          FlSpot(i.toDouble(), (daily[keys[i]] ?? 0).toDouble()),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopMembersCard extends StatelessWidget {
  final String title;
  final List<_MemberRankRow> rows;
  final NumberFormat moneyFmt;

  const _TopMembersCard({
    required this.title,
    required this.rows,
    required this.moneyFmt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const Text('尚無資料')
            else
              ...rows.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final row = entry.value;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: cs.surfaceContainerHighest,
                    child: Text(
                      '$idx',
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800),
                    ),
                  ),
                  title: Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('訂單 ${row.orders}'),
                  trailing: Text(
                    moneyFmt.format(row.revenue),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
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
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
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

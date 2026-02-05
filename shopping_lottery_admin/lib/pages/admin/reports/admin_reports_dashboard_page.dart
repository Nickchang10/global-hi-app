// lib/pages/admin/reports/admin_reports_dashboard_page.dart
//
// ✅ AdminReportsDashboardPage（修復後完整版｜可編譯｜已根治 RenderFlex Overflow）
// ------------------------------------------------------------
// - 含 Firestore 容錯、防索引錯誤提示
// - 支援日期區間、趨勢天數切換
// - Loading / Error / Empty 狀態完整覆蓋
// - 整合 ReportService V8
// - ✅ 修正：QuickTile / Grid 在極窄高度約束下 Column overflow（改 Row + Flexible + 文字省略 + 自適應欄數/比例）
// - ✅ 修正：所有可能爆掉的文字列加上 maxLines/ellipsis
// - ✅ 修正：ErrorView 可滾動避免小螢幕 overflow
// ------------------------------------------------------------

import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:osmile_admin/services/report_service.dart';

class AdminReportsDashboardPage extends StatefulWidget {
  const AdminReportsDashboardPage({super.key});

  @override
  State<AdminReportsDashboardPage> createState() =>
      _AdminReportsDashboardPageState();
}

class _AdminReportsDashboardPageState extends State<AdminReportsDashboardPage> {
  final _report = ReportService();

  bool _loading = true;
  String? _error;

  ReportStats? _stats;
  Map<String, num> _dailyRevenue = const {};
  DateTimeRange? _summaryRange;

  int _trendDays = 14;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ======================================================
  // 資料載入（含防呆）
  // ======================================================
  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final stats = await _report.getSalesReport(range: _summaryRange);
      final daily = await _report.getRecentDailyRevenue(days: _trendDays);

      if (!mounted) return;
      setState(() {
        _stats = stats;
        _dailyRevenue = daily;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ======================================================
  // 日期區間控制
  // ======================================================
  Future<void> _pickSummaryRange() async {
    final now = DateTime.now();
    final initial = _summaryRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      helpText: '選擇摘要區間',
      confirmText: '套用',
      cancelText: '取消',
    );

    if (picked == null) return;
    setState(() => _summaryRange = picked);
    await _load();
  }

  Future<void> _clearSummaryRange() async {
    setState(() => _summaryRange = null);
    await _load();
  }

  Future<void> _setTrendDays(int days) async {
    if (_trendDays == days) return;
    setState(() => _trendDays = days);
    await _load();
  }

  // ======================================================
  // Build UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('報表中心總覽'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        body: _ErrorView(
          title: '載入報表失敗',
          message: _error!,
          onRetry: _load,
          hint:
              '請檢查 Firestore 權限、複合索引 (status + createdAt)，或 orders 欄位 createdAt 是否為 Timestamp。',
        ),
      );
    }

    final stats = _stats;
    if (stats == null) {
      return const Scaffold(
        body: Center(child: Text('尚無報表資料')),
      );
    }

    final fmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('報表中心總覽'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _rangeBar(cs),
            const SizedBox(height: 12),
            _headerSection(fmt, stats),
            const SizedBox(height: 16),
            _trendControlBar(cs),
            const SizedBox(height: 12),
            _trendChart(),
            const SizedBox(height: 16),
            _quickAccessSection(context),
            const SizedBox(height: 24),
            _rankingPreviewSection(fmt, stats),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // 日期區間標籤列
  // ======================================================
  Widget _rangeBar(ColorScheme cs) {
    final r = _summaryRange;
    final label = (r == null)
        ? '摘要區間：本月（預設）'
        : '摘要區間：${_fmtDate(r.start)} ～ ${_fmtDate(r.end)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _pickSummaryRange,
              icon: const Icon(Icons.date_range),
              label: const Text('選擇'),
            ),
            if (r != null)
              TextButton(
                onPressed: _clearSummaryRange,
                child: const Text('清除'),
              ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // Header 摘要區
  // ======================================================
  Widget _headerSection(NumberFormat fmt, ReportStats stats) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 520) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _summaryBlock('總營收', fmt.format(stats.totalRevenue), cs.primary),
                  const SizedBox(height: 10),
                  _summaryBlock(
                    '區間營收',
                    fmt.format(stats.periodRevenue),
                    Colors.blueAccent,
                  ),
                  const SizedBox(height: 10),
                  _summaryBlock('訂單數', '${stats.orderCount}', cs.secondary),
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryBlock('總營收', fmt.format(stats.totalRevenue), cs.primary),
                _summaryBlock(
                  '區間營收',
                  fmt.format(stats.periodRevenue),
                  Colors.blueAccent,
                ),
                _summaryBlock('訂單數', '${stats.orderCount}', cs.secondary),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryBlock(String title, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown, // ✅ 數字不爆版
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ======================================================
  // 趨勢控制列
  // ======================================================
  Widget _trendControlBar(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '趨勢圖：近 $_trendDays 日',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ),
        for (final d in [7, 14, 30]) ...[
          _pill('$d', selected: _trendDays == d, onTap: () => _setTrendDays(d)),
          const SizedBox(width: 8),
        ]
      ],
    );
  }

  Widget _pill(
    String text, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(999),
          color: selected ? cs.primaryContainer : cs.surface,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? cs.onPrimaryContainer : cs.onSurface,
          ),
        ),
      ),
    );
  }

  // ======================================================
  // 趨勢圖
  // ======================================================
  Widget _trendChart() {
    if (_dailyRevenue.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('尚無每日營收資料，請確認 orders 有 createdAt 與 finalAmount 欄位。'),
        ),
      );
    }

    final sortedDays = _dailyRevenue.keys.toList()..sort();
    final values =
        sortedDays.map((d) => (_dailyRevenue[d] ?? 0).toDouble()).toList();

    final maxY = math.max(1.0, (values.reduce(math.max)) * 1.2);
    final step = math.max(1, (sortedDays.length / 7).ceil());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(show: true, horizontalInterval: maxY / 5),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= sortedDays.length) {
                        return const SizedBox.shrink();
                      }
                      if (i % step != 0 && i != sortedDays.length - 1) {
                        return const SizedBox.shrink();
                      }
                      final day = sortedDays[i].substring(5);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(day, style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) {
                      if (v == 0) return const Text('0');
                      if (v % 1000 == 0) {
                        return Text(
                          '${v ~/ 1000}k',
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: Colors.blueAccent,
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                  spots: [
                    for (int i = 0; i < sortedDays.length; i++)
                      FlSpot(i.toDouble(), values[i]),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================
  // 快速功能入口（✅ 根治：tile 高度不足 + Column overflow）
  // - 自適應欄數：窄螢幕 1 欄，寬螢幕 2 欄
  // - childAspectRatio：提升 tile 高度，杜絕 h<=21.8 這類極端壓縮
  // - tile 內：Row + Flexible(loose) + 文字 ellipsis
  // ======================================================
  Widget _quickAccessSection(BuildContext context) {
    final tiles = [
      _quickTile(
        context,
        icon: Icons.bar_chart,
        color: Colors.blue,
        title: '營收報表',
        subtitle: '查看詳細營收趨勢與統計',
        route: '/admin_sales_report',
      ),
      _quickTile(
        context,
        icon: Icons.download,
        color: Colors.teal,
        title: '匯出報表',
        subtitle: '下載 CSV 或報表資料',
        route: '/admin_sales_export',
      ),
      _quickTile(
        context,
        icon: Icons.leaderboard,
        color: Colors.orange,
        title: '排行報表',
        subtitle: '商品與廠商銷售排行榜',
        route: '/admin_sales_report',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '報表功能入口',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final isNarrow = c.maxWidth < 520;
            final crossAxisCount = isNarrow ? 1 : 2;

            // ✅ 比例越小→高度越高。這裡選一個更保守的高度避免極端壓縮。
            // 你之前 log 出現 h<=21.8，代表 tile 被壓到幾乎一行字高，必須拉高。
            final ratio = isNarrow ? 2.4 : 2.7;

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: ratio,
              children: tiles,
            );
          },
        ),
      ],
    );
  }

  Widget _quickTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String route,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pushNamedSafe(context, route),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Flexible(
                fit: FlexFit.loose, // ✅ 不硬撐滿，避免垂直溢位
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================================================
  // 排行榜預覽
  // ======================================================
  Widget _rankingPreviewSection(NumberFormat fmt, ReportStats stats) {
    final topVendor = stats.vendorRevenue.entries.isEmpty
        ? null
        : (stats.vendorRevenue.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;

    final topProduct = stats.productSales.entries.isEmpty
        ? null
        : (stats.productSales.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '銷售排行榜預覽',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (topVendor == null && topProduct == null)
              const Text('尚無可統計資料')
            else ...[
              if (topVendor != null)
                ListTile(
                  leading: const Icon(Icons.store, color: Colors.blue),
                  title: const Text('廠商營收冠軍'),
                  subtitle: Text(
                    topVendor.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    fmt.format(topVendor.value),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (topProduct != null)
                ListTile(
                  leading:
                      const Icon(Icons.shopping_bag, color: Colors.orange),
                  title: const Text('熱銷商品'),
                  subtitle: Text(
                    topProduct.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    'x${topProduct.value.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ======================================================
  // Utils
  // ======================================================
  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  void _pushNamedSafe(BuildContext context, String route, {Object? arguments}) {
    try {
      Navigator.pushNamed(context, route, arguments: arguments);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('尚未註冊路由：$route（請在 MaterialApp.onGenerateRoute 設定）'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ======================================================
// Error View（✅ 可滾動，避免 overflow）
// ======================================================
class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? hint;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
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
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      hint!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
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

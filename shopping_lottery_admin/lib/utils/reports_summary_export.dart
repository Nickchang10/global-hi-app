// lib/utils/reports_summary_export.dart
//
// 匯出報表 Summary / Trend / Top 商品 CSV 專用
// 給 ReportsPage 或 DashboardPage 使用

import 'dart:convert';

import '../pages/reports_page.dart'; // 匯入 _ReportsAnalytics, _TrendResult, _TopProduct

class ReportsSummaryExport {
  /// 匯出 Summary（KPI 匯總 + Trend + Top 商品）
  static String buildSummaryCsv(_ReportsAnalytics a) {
    final lines = <String>[];
    lines.add('Osmile Reports Summary');
    lines.add('Generated at,${DateTime.now()}');
    lines.add('');

    // KPI 區段
    lines.add('KPI Summary');
    lines.add('項目,數值');
    lines.add('總訂單數,${a.totalOrders}');
    lines.add('待付款,${a.pendingPayment}');
    lines.add('已付款訂單,${a.paidCount}');
    lines.add('已付款營收,${a.paidRevenue.toStringAsFixed(0)}');
    lines.add('退款數,${a.refundCount}');
    lines.add('退款金額,${a.refundAmount.toStringAsFixed(0)}');
    lines.add('取消數,${a.cancelCount}');
    lines.add('取消金額,${a.cancelAmount.toStringAsFixed(0)}');
    lines.add('');

    // Trend 區段
    lines.add('每日營收趨勢');
    lines.add('日期,營收,已付款筆數');
    for (int i = 0; i < a.trend.labels.length; i++) {
      final label = a.trend.labels[i];
      final rev = a.trend.revenue[i];
      final count = a.trend.paidCounts[i];
      lines.add('$label,${rev.toStringAsFixed(0)},$count');
    }
    lines.add('');

    // Top 商品
    lines.add('Top 商品');
    lines.add('商品名稱,件數,營收');
    for (final it in a.topProducts) {
      final name = _escape(it.name);
      lines.add('$name,${it.qty},${it.revenue.toStringAsFixed(0)}');
    }

    return const LineSplitter().convert(lines.join('\n')).join('\n');
  }

  static String _escape(String s) {
    final t = s.replaceAll('"', '""');
    return '"$t"';
  }
}

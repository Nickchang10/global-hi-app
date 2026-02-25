// lib/utils/reports_summary_export.dart
//
// ✅ Reports Summary Export（修改後完整版｜可編譯）
// ------------------------------------------------------------
// 修正：移除引用不存在的私有型別 `_ReportsAnalytics`
// 改為提供公開可用的 `ReportsAnalytics` + CSV/JSON 匯出工具
//
// 注意：本檔案「只負責產生 CSV/JSON 字串」
// - 下載/存檔（Web / Mobile）請在 UI 層自己做，避免 dart:html / dart:io 造成跨平台編譯炸裂。

import 'dart:convert';

/// 報表統計資料（可跨檔案使用）
///
/// 你可以在報表頁計算好後丟進來：
/// ReportsAnalytics(
///   from: ...,
///   to: ...,
///   totals: {'orders': 10, 'revenue': 9999},
///   breakdowns: {'status:new': 3, 'status:paid': 7},
///   topItems: [ReportsTopItem(id:'p1', name:'xxx', qty: 3, amount: 500)],
/// )
class ReportsAnalytics {
  final DateTime? from;
  final DateTime? to;

  /// 任意總計數字（例如：orders, revenue, customers...）
  final Map<String, num> totals;

  /// 任意分佈（例如：status:new, status:paid, payment:card...）
  final Map<String, num> breakdowns;

  /// Top items（例如：top products）
  final List<ReportsTopItem> topItems;

  const ReportsAnalytics({
    this.from,
    this.to,
    this.totals = const {},
    this.breakdowns = const {},
    this.topItems = const [],
  });

  Map<String, dynamic> toMap() => {
    'from': from?.toIso8601String(),
    'to': to?.toIso8601String(),
    'totals': totals,
    'breakdowns': breakdowns,
    'topItems': topItems.map((e) => e.toMap()).toList(),
  };

  String toJsonString({bool pretty = false}) {
    final m = toMap();
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(m)
        : jsonEncode(m);
  }

  /// 匯出 CSV（summary + breakdown + topItems）
  ///
  /// - 只回傳字串，不做下載/存檔，確保跨平台可編譯
  String toCsv({
    bool includeMeta = true,
    bool includeTotals = true,
    bool includeBreakdowns = true,
    bool includeTopItems = true,
    int topItemsLimit = 200,
  }) {
    final rows = <List<String>>[];

    // --- Meta ---
    if (includeMeta) {
      rows.add(['section', 'key', 'value']);
      rows.add(['meta', 'from', from == null ? '' : from!.toIso8601String()]);
      rows.add(['meta', 'to', to == null ? '' : to!.toIso8601String()]);
      rows.add(['', '', '']); // spacer
    }

    // --- Totals ---
    if (includeTotals) {
      rows.add(['section', 'metric', 'value']);
      if (totals.isEmpty) {
        rows.add(['totals', '(empty)', '0']);
      } else {
        final keys = totals.keys.toList()..sort();
        for (final k in keys) {
          rows.add(['totals', k, _numToString(totals[k])]);
        }
      }
      rows.add(['', '', '']); // spacer
    }

    // --- Breakdowns ---
    if (includeBreakdowns) {
      rows.add(['section', 'dimension', 'value']);
      if (breakdowns.isEmpty) {
        rows.add(['breakdowns', '(empty)', '0']);
      } else {
        final keys = breakdowns.keys.toList()..sort();
        for (final k in keys) {
          rows.add(['breakdowns', k, _numToString(breakdowns[k])]);
        }
      }
      rows.add(['', '', '']); // spacer
    }

    // --- Top Items ---
    if (includeTopItems) {
      rows.add(['section', 'id', 'name', 'qty', 'amount']);
      if (topItems.isEmpty) {
        rows.add(['topItems', '', '(empty)', '0', '0']);
      } else {
        final list = topItems.take(topItemsLimit);
        for (final item in list) {
          rows.add([
            'topItems',
            item.id,
            item.name,
            _numToString(item.qty),
            _numToString(item.amount),
          ]);
        }
      }
    }

    return rows.map((r) => r.map(_csvEscape).join(',')).join('\n');
  }

  static String _numToString(num? v) {
    if (v == null) return '0';
    // 避免 10.0 這種看起來怪
    if (v is int) return '$v';
    final d = v.toDouble();
    if (d == d.roundToDouble()) return '${d.toInt()}';
    return d.toString();
  }

  static String _csvEscape(String s) {
    final v = s.replaceAll('"', '""');
    if (v.contains(',') ||
        v.contains('\n') ||
        v.contains('\r') ||
        v.contains('"')) {
      return '"$v"';
    }
    return v;
  }
}

/// Top item model（例如商品排行）
///
/// qty/amount 你可以自由定義：
/// - qty: 件數
/// - amount: 金額
class ReportsTopItem {
  final String id;
  final String name;
  final num qty;
  final num amount;

  const ReportsTopItem({
    required this.id,
    required this.name,
    this.qty = 0,
    this.amount = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'qty': qty,
    'amount': amount,
  };
}

/// 兼容舊程式碼的匯出入口（如果你原本呼叫的是某個 export 方法）
///
/// ✅ 重點：不再用 `_ReportsAnalytics` 這種 private type
class ReportsSummaryExport {
  const ReportsSummaryExport._();

  static String exportCsv(
    ReportsAnalytics analytics, {
    bool includeMeta = true,
    bool includeTotals = true,
    bool includeBreakdowns = true,
    bool includeTopItems = true,
    int topItemsLimit = 200,
  }) {
    return analytics.toCsv(
      includeMeta: includeMeta,
      includeTotals: includeTotals,
      includeBreakdowns: includeBreakdowns,
      includeTopItems: includeTopItems,
      topItemsLimit: topItemsLimit,
    );
  }

  static String exportJson(ReportsAnalytics analytics, {bool pretty = false}) {
    return analytics.toJsonString(pretty: pretty);
  }
}

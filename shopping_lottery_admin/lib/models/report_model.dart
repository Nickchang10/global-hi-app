// lib/models/report_stats.dart
class ReportStats {
  final double totalRevenue;
  final int orderCount;
  final Map<String, dynamic>? extra;

  ReportStats({required this.totalRevenue, required this.orderCount, this.extra});

  factory ReportStats.fromJson(Map<String, dynamic> json) {
    return ReportStats(
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }
}

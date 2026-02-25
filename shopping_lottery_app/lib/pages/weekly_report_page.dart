import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ✅ WeeklyReportPage（每週報表｜完整版｜可編譯｜已補 const）
/// ------------------------------------------------------------
/// - ✅ 移除 fl_chart 依賴
/// - ✅ withOpacity deprecated → withValues(alpha: ...)
/// - ✅ prefer_const_constructors：可 const 的地方都補上 const
/// ------------------------------------------------------------
class WeeklyReportPage extends StatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  String _weekKey = 'this';
  late DateTime _weekStart; // Monday
  late List<_DayPoint> _data;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  void _rebuild() {
    _weekStart = _calcWeekStart(
      DateTime.now(),
    ).subtract(_offsetForKey(_weekKey));
    _data = _mockWeekData(_weekStart);
    setState(() {});
  }

  Duration _offsetForKey(String key) {
    switch (key) {
      case 'prev':
        return const Duration(days: 7);
      case 'prev2':
        return const Duration(days: 14);
      case 'this':
      default:
        return Duration.zero;
    }
  }

  DateTime _calcWeekStart(DateTime dt) {
    final daysToMon = dt.weekday - DateTime.monday;
    return DateTime(
      dt.year,
      dt.month,
      dt.day,
    ).subtract(Duration(days: daysToMon));
  }

  String _fmtYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  String _fmtMd(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$m/$d';
  }

  List<_DayPoint> _mockWeekData(DateTime weekStart) {
    final r = math.Random(weekStart.millisecondsSinceEpoch);
    return List.generate(7, (i) {
      final date = weekStart.add(Duration(days: i));
      final steps = 4500 + r.nextInt(6500); // 4.5k ~ 11k
      final points = (steps / 100).round() + r.nextInt(20);
      final orders = r.nextInt(3); // 0~2
      final conversions = r.nextInt(6); // 0~5
      return _DayPoint(
        date: date,
        steps: steps,
        points: points,
        orders: orders,
        conversions: conversions,
      );
    });
  }

  int get _sumSteps => _data.fold<int>(0, (s, e) => s + e.steps);
  int get _sumPoints => _data.fold<int>(0, (s, e) => s + e.points);
  int get _sumOrders => _data.fold<int>(0, (s, e) => s + e.orders);
  int get _sumConversions => _data.fold<int>(0, (s, e) => s + e.conversions);

  double get _avgSteps => _data.isEmpty ? 0 : _sumSteps / _data.length;
  double get _avgPoints => _data.isEmpty ? 0 : _sumPoints / _data.length;

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final title = '${_fmtYmd(_weekStart)} ~ ${_fmtYmd(weekEnd)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('每週報表'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _weekKey,
              items: const [
                DropdownMenuItem(value: 'this', child: Text('本週')),
                DropdownMenuItem(value: 'prev', child: Text('上週')),
                DropdownMenuItem(value: 'prev2', child: Text('前週')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _weekKey = v);
                _rebuild();
              },
            ),
          ),
          IconButton(
            tooltip: '重新整理',
            onPressed: _rebuild,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(title),
          const SizedBox(height: 12),
          _kpiGrid(),
          const SizedBox(height: 16),
          _lineTrendCard(),
          const SizedBox(height: 16),
          _barDistCard(),
          const SizedBox(height: 16),
          _tableCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _headerCard(String title) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                '平均步數 ${_avgSteps.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpiCard(
          title: '總步數',
          value: _sumSteps.toString(),
          subtitle: '平均 ${_avgSteps.toStringAsFixed(0)}/日',
          icon: Icons.directions_walk,
        ),
        _kpiCard(
          title: '總積分',
          value: _sumPoints.toString(),
          subtitle: '平均 ${_avgPoints.toStringAsFixed(0)}/日',
          icon: Icons.stars,
        ),
        _kpiCard(
          title: '訂單數',
          value: _sumOrders.toString(),
          subtitle: '本週完成訂單',
          icon: Icons.receipt_long,
        ),
        _kpiCard(
          title: '轉換量',
          value: _sumConversions.toString(),
          subtitle: '活動/任務轉換',
          icon: Icons.auto_graph,
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: 175,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _lineTrendCard() {
    final labels = _data.map((e) => _fmtMd(e.date)).toList();
    final valuesSteps = _data.map((e) => e.steps.toDouble()).toList();
    final valuesPoints = _data.map((e) => e.points.toDouble()).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '7 天趨勢（步數 vs 積分）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: _SimpleLineChart(
                labels: labels,
                series: [
                  _LineSeries(name: '步數', values: valuesSteps),
                  _LineSeries(name: '積分', values: valuesPoints),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 10,
              children: [
                _LegendDot(label: '步數', isHollow: false),
                _LegendDot(label: '積分', isHollow: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _barDistCard() {
    final labels = _data.map((e) => _fmtMd(e.date)).toList();
    final valuesOrders = _data.map((e) => e.orders.toDouble()).toList();
    final valuesConv = _data.map((e) => e.conversions.toDouble()).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '7 天分佈（訂單 vs 轉換）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: _SimpleBarChart(
                labels: labels,
                series: [
                  _BarSeries(name: '訂單', values: valuesOrders),
                  _BarSeries(name: '轉換', values: valuesConv),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 10,
              children: [
                _LegendSquare(label: '訂單', isHollow: false),
                _LegendSquare(label: '轉換', isHollow: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '明細',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('日期')),
                  DataColumn(label: Text('步數')),
                  DataColumn(label: Text('積分')),
                  DataColumn(label: Text('訂單')),
                  DataColumn(label: Text('轉換')),
                ],
                rows: _data
                    .map(
                      (e) => DataRow(
                        cells: [
                          DataCell(Text(_fmtMd(e.date))),
                          DataCell(Text('${e.steps}')),
                          DataCell(Text('${e.points}')),
                          DataCell(Text('${e.orders}')),
                          DataCell(Text('${e.conversions}')),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPoint {
  const _DayPoint({
    required this.date,
    required this.steps,
    required this.points,
    required this.orders,
    required this.conversions,
  });

  final DateTime date;
  final int steps;
  final int points;
  final int orders;
  final int conversions;
}

/// ---------------------------
/// Simple Charts (no packages)
/// ---------------------------

class _LineSeries {
  const _LineSeries({required this.name, required this.values});
  final String name;
  final List<double> values;
}

class _BarSeries {
  const _BarSeries({required this.name, required this.values});
  final String name;
  final List<double> values;
}

class _SimpleLineChart extends StatelessWidget {
  const _SimpleLineChart({required this.labels, required this.series});

  final List<String> labels;
  final List<_LineSeries> series;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(labels: labels, series: series),
      // ✅ 這行通常就是你 301-307 的 prefer_const_constructors
      child: const SizedBox.expand(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.labels, required this.series});

  final List<String> labels;
  final List<_LineSeries> series;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 36.0;
    const padR = 10.0;
    const padT = 12.0;
    const padB = 28.0;

    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    if (w <= 0 || h <= 0) return;

    final all = <double>[];
    for (final s in series) {
      all.addAll(s.values);
    }
    if (all.isEmpty) return;

    final minV = all.reduce(math.min);
    final maxV = all.reduce(math.max);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    final axisPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (int i = 0; i <= 3; i++) {
      final y = padT + (h / 3) * i;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridPaint);
    }

    canvas.drawLine(
      const Offset(padL, padT),
      Offset(padL, padT + h),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padL, padT + h),
      Offset(padL + w, padT + h),
      axisPaint,
    );

    final tp1 = TextPainter(
      text: TextSpan(
        text: maxV.toStringAsFixed(0),
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.6),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp1.paint(canvas, const Offset(2, padT - 2));

    final tp2 = TextPainter(
      text: TextSpan(
        text: minV.toStringAsFixed(0),
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.6),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(2, padT + h - 10));

    final n = labels.length;
    if (n >= 2) {
      for (int i = 0; i < n; i++) {
        if (i % 2 != 0) continue;
        final x = padL + (w / (n - 1)) * i;
        final tpx = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tpx.paint(canvas, Offset(x - tpx.width / 2, padT + h + 6));
      }
    }

    for (int si = 0; si < series.length; si++) {
      final s = series[si];
      final isFirst = si == 0;

      final linePaint = Paint()
        ..color = isFirst ? Colors.green : Colors.orange
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final dotPaint = Paint()
        ..color = isFirst ? Colors.green : Colors.orange
        ..style = PaintingStyle.fill;

      final path = Path();

      for (int i = 0; i < s.values.length; i++) {
        final v = s.values[i];
        final x = (n <= 1) ? (padL + w / 2) : (padL + (w / (n - 1)) * i);
        final y = padT + h - ((v - minV) / span) * h;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, linePaint);

      for (int i = 0; i < s.values.length; i++) {
        final v = s.values[i];
        final x = (n <= 1) ? (padL + w / 2) : (padL + (w / (n - 1)) * i);
        final y = padT + h - ((v - minV) / span) * h;

        if (isFirst) {
          canvas.drawCircle(Offset(x, y), 3.2, dotPaint);
        } else {
          canvas.drawCircle(Offset(x, y), 3.2, Paint()..color = Colors.orange);
          canvas.drawCircle(Offset(x, y), 2.0, Paint()..color = Colors.white);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.labels != labels || oldDelegate.series != series;
  }
}

class _SimpleBarChart extends StatelessWidget {
  const _SimpleBarChart({required this.labels, required this.series});

  final List<String> labels;
  final List<_BarSeries> series;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarChartPainter(labels: labels, series: series),
      child: const SizedBox.expand(),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.labels, required this.series});

  final List<String> labels;
  final List<_BarSeries> series;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 36.0;
    const padR = 10.0;
    const padT = 12.0;
    const padB = 28.0;

    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    if (w <= 0 || h <= 0) return;

    final all = <double>[];
    for (final s in series) {
      all.addAll(s.values);
    }
    final maxV = all.isEmpty ? 1.0 : math.max(1.0, all.reduce(math.max));

    final axisPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (int i = 0; i <= 3; i++) {
      final y = padT + (h / 3) * i;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridPaint);
    }

    canvas.drawLine(
      const Offset(padL, padT),
      Offset(padL, padT + h),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padL, padT + h),
      Offset(padL + w, padT + h),
      axisPaint,
    );

    final n = labels.length;
    for (int i = 0; i < n; i++) {
      if (i % 2 != 0) continue;
      final x = padL + (w / math.max(1, n)) * (i + 0.5);
      final tpx = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpx.paint(canvas, Offset(x - tpx.width / 2, padT + h + 6));
    }

    final tpy = TextPainter(
      text: TextSpan(
        text: maxV.toStringAsFixed(0),
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.6),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpy.paint(canvas, const Offset(2, padT - 2));

    final groupW = w / math.max(1, n);
    final barW = math.min(12.0, groupW / (series.length + 1));
    const gap = 4.0;

    for (int i = 0; i < n; i++) {
      final baseX = padL + groupW * i + groupW / 2;

      for (int si = 0; si < series.length; si++) {
        final v = series[si].values[i];
        final barH = (v / maxV) * h;

        final isFirst = si == 0;
        final color = isFirst ? Colors.blue : Colors.purple;

        final x =
            baseX + (si - (series.length - 1) / 2) * (barW + gap) - barW / 2;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, padT + h - barH, barW, barH),
          const Radius.circular(6),
        );

        if (isFirst) {
          canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.9));
        } else {
          canvas.drawRRect(
            rect,
            Paint()..color = color.withValues(alpha: 0.22),
          );
          canvas.drawRRect(
            rect,
            Paint()
              ..color = color.withValues(alpha: 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.labels != labels || oldDelegate.series != series;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.isHollow});
  final String label;
  final bool isHollow;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHollow ? Colors.white : Colors.green,
            border: Border.all(
              color: isHollow ? Colors.orange : Colors.green,
              width: 2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _LegendSquare extends StatelessWidget {
  const _LegendSquare({required this.label, required this.isHollow});
  final String label;
  final bool isHollow;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isHollow ? Colors.white : Colors.blue,
            border: Border.all(
              color: isHollow ? Colors.purple : Colors.blue,
              width: 2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

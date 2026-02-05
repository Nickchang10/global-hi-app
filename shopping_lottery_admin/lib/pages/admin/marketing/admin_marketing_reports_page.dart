// lib/pages/admin/marketing/admin_marketing_reports_page.dart
//
// ✅ AdminMarketingReportsPage（行銷報表｜最終可編譯完整版・已修正 RenderFlex overflow）
// ------------------------------------------------------------
// - Firestore 集合：coupons / lotteries / segments / auto_campaigns / campaign_logs
// - 報表區間：可選日期起迄（預設近 30 天）
// - KPI：
//   1) 優惠券：總發放/總點擊/總使用、CTR/CVR、Top5 使用率
//   2) 抽獎：總參與/總得獎、轉換率
//   3) 自動派發：總轉換量、Top5 活動
//   4) 日誌：區間內 success / fail / pending 次數 + 每日趨勢圖
// - 圖表：Line（每日事件）/ Bar（Top5）/ Pie（狀態分佈）
// - 匯出：目前區間報表匯出 CSV（file_saver）
// - 容錯：欄位不存在也不會噴錯
//
// ✅ 本次修正：
// - KPI 卡片原本固定 height=92 + padding=12，導致內層 Column 只有 68px 高度，文字一多就溢出。
// - 改為「不固定高度」，並使用 maxLines/ellipsis，徹底消除 RenderFlex overflow。
// ------------------------------------------------------------

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminMarketingReportsPage extends StatefulWidget {
  const AdminMarketingReportsPage({super.key});

  @override
  State<AdminMarketingReportsPage> createState() =>
      _AdminMarketingReportsPageState();
}

class _AdminMarketingReportsPageState extends State<AdminMarketingReportsPage> {
  bool _loading = true;
  bool _exporting = false;

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  // KPI
  int couponCount = 0;
  int activeCoupons = 0;
  num totalIssued = 0;
  num totalClicks = 0;
  num totalUsed = 0;
  num avgCTR = 0;
  num avgCVR = 0;

  int lotteryCount = 0;
  int activeLotteries = 0;
  num totalParticipants = 0;
  num totalWinners = 0;
  num lotteryCVR = 0;

  int segmentCount = 0;

  int autoCampaignCount = 0;
  num totalAutoConversions = 0;

  // Logs KPI
  int logTotal = 0;
  int logSuccess = 0;
  int logFail = 0;
  int logPending = 0;

  // Charts data
  List<_DayPoint> dailyLogPoints = [];
  List<MapEntry<String, double>> topCoupons = [];
  List<MapEntry<String, double>> topAuto = [];

  // Raw docs (optional)
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _logDocs = [];

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------
  DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _s(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    return v.toString();
  }

  num _n(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    final p = num.tryParse(v.toString());
    return p ?? fallback;
  }

  bool _isTrue(dynamic v) => v == true;

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  String _statusNormalize(String s) {
    final v = s.trim().toLowerCase();
    if (v == 'ok') return 'success';
    if (v == 'error') return 'fail';
    if (v.isEmpty) return 'unknown';
    return v;
  }

  // ------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _load();
  }

  // ------------------------------------------------------------
  // Date pickers
  // ------------------------------------------------------------
  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _fromDate = _startOfDay(picked);
        if (_toDate.isBefore(_fromDate)) {
          _toDate = _fromDate;
        }
      } else {
        _toDate = _startOfDay(picked);
        if (_toDate.isBefore(_fromDate)) {
          _fromDate = _toDate;
        }
      }
    });

    await _load();
  }

  // ------------------------------------------------------------
  // Load data
  // ------------------------------------------------------------
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final fs = FirebaseFirestore.instance;

      final from = _startOfDay(_fromDate);
      final to = _endOfDay(_toDate);

      final futures = await Future.wait([
        fs.collection('coupons').get(),
        fs.collection('lotteries').get(),
        fs.collection('segments').get(),
        fs.collection('auto_campaigns').get(),
        fs
            .collection('campaign_logs')
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(from))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
            .orderBy('createdAt', descending: false)
            .limit(2000)
            .get(),
      ]);

      final couponSnap = futures[0] as QuerySnapshot<Map<String, dynamic>>;
      final lotterySnap = futures[1] as QuerySnapshot<Map<String, dynamic>>;
      final segmentSnap = futures[2] as QuerySnapshot<Map<String, dynamic>>;
      final autoSnap = futures[3] as QuerySnapshot<Map<String, dynamic>>;
      final logSnap = futures[4] as QuerySnapshot<Map<String, dynamic>>;

      // -------------------------
      // Coupons KPI
      // -------------------------
      couponCount = couponSnap.size;
      activeCoupons =
          couponSnap.docs.where((d) => _isTrue(d.data()['isActive'])).length;

      totalIssued = 0;
      totalClicks = 0;
      totalUsed = 0;

      for (final doc in couponSnap.docs) {
        final d = doc.data();
        totalIssued += _n(d['issuedCount']);
        totalClicks += _n(d['clickCount']);
        totalUsed += _n(d['usedCount']);
      }

      avgCTR = totalIssued > 0 ? (totalClicks / totalIssued) * 100 : 0;
      avgCVR = totalIssued > 0 ? (totalUsed / totalIssued) * 100 : 0;

      // Top 5 coupons by use rate (used/issued)
      final couponEntries = couponSnap.docs.map((e) {
        final d = e.data();
        final title = _s(d['title'], fallback: '未命名');
        final issued = _n(d['issuedCount']);
        final used = _n(d['usedCount']);
        final rate = issued > 0 ? (used / issued) * 100 : 0.0;
        return MapEntry(title, rate.toDouble());
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topCoupons = couponEntries.take(5).toList();

      // -------------------------
      // Lotteries KPI
      // -------------------------
      lotteryCount = lotterySnap.size;
      activeLotteries = lotterySnap.docs
          .where((d) => _isTrue(d.data()['isActive']))
          .length;

      totalParticipants = 0;
      totalWinners = 0;

      for (final doc in lotterySnap.docs) {
        final d = doc.data();
        final p = (d['participants'] as List?)?.length ?? 0;
        final w = (d['winners'] as List?)?.length ?? 0;
        totalParticipants += p;
        totalWinners += w;
      }

      lotteryCVR =
          totalParticipants > 0 ? (totalWinners / totalParticipants) * 100 : 0;

      // -------------------------
      // Segments KPI
      // -------------------------
      segmentCount = segmentSnap.size;

      // -------------------------
      // Auto campaigns KPI
      // -------------------------
      autoCampaignCount = autoSnap.size;
      totalAutoConversions = 0;
      for (final doc in autoSnap.docs) {
        final d = doc.data();
        totalAutoConversions += _n(d['conversionCount']);
      }

      final autoEntries = autoSnap.docs.map((e) {
        final d = e.data();
        final title = _s(d['title'], fallback: '未命名');
        final conv = _n(d['conversionCount']).toDouble();
        return MapEntry(title, conv);
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topAuto = autoEntries.take(5).toList();

      // -------------------------
      // Logs KPI + daily series
      // -------------------------
      _logDocs = logSnap.docs;
      logTotal = _logDocs.length;
      logSuccess = 0;
      logFail = 0;
      logPending = 0;

      final Map<DateTime, _DayAgg> byDay = {};
      for (final doc in _logDocs) {
        final d = doc.data();
        final dt = _asDateTime(d['createdAt']) ??
            _asDateTime(d['time']) ??
            _asDateTime(d['updatedAt']);
        final day = _startOfDay(dt ?? from);
        final status = _statusNormalize(_s(d['status']));

        byDay.putIfAbsent(day, () => _DayAgg(day));
        byDay[day]!.total++;

        if (status == 'success') {
          logSuccess++;
          byDay[day]!.success++;
        } else if (status == 'fail' || status == 'error') {
          logFail++;
          byDay[day]!.fail++;
        } else if (status == 'pending' || status == 'queued') {
          logPending++;
          byDay[day]!.pending++;
        } else {
          byDay[day]!.other++;
        }
      }

      // ensure every day exists in range (for smooth line)
      final days = <DateTime>[];
      var cur = _startOfDay(from);
      final end = _startOfDay(to);
      while (!cur.isAfter(end)) {
        days.add(cur);
        cur = cur.add(const Duration(days: 1));
      }
      for (final d in days) {
        byDay.putIfAbsent(d, () => _DayAgg(d));
      }

      final sortedDays = byDay.keys.toList()..sort((a, b) => a.compareTo(b));
      dailyLogPoints = sortedDays
          .map((day) {
            final agg = byDay[day]!;
            return _DayPoint(day: day, value: agg.total.toDouble());
          })
          .toList(growable: false);

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('讀取報表失敗：$e')));
    }
  }

  // ------------------------------------------------------------
  // Export CSV
  // ------------------------------------------------------------
  String _csvEscape(String s) {
    final needsQuote = s.contains(',') || s.contains('\n') || s.contains('"');
    final escaped = s.replaceAll('"', '""');
    return needsQuote ? '"$escaped"' : escaped;
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;

    setState(() => _exporting = true);
    try {
      final df = DateFormat('yyyy-MM-dd');
      final dft = DateFormat('yyyy-MM-dd HH:mm:ss');

      final b = StringBuffer();

      // Summary block
      b.writeln('Report Range,${_csvEscape("${df.format(_fromDate)} ~ ${df.format(_toDate)}")}');
      b.writeln('Coupons,${couponCount}');
      b.writeln('Active Coupons,${activeCoupons}');
      b.writeln('Total Issued,${totalIssued}');
      b.writeln('Total Clicks,${totalClicks}');
      b.writeln('Total Used,${totalUsed}');
      b.writeln('Avg CTR(%),${avgCTR.toStringAsFixed(2)}');
      b.writeln('Avg CVR(%),${avgCVR.toStringAsFixed(2)}');
      b.writeln('Lotteries,${lotteryCount}');
      b.writeln('Active Lotteries,${activeLotteries}');
      b.writeln('Total Participants,${totalParticipants}');
      b.writeln('Total Winners,${totalWinners}');
      b.writeln('Lottery CVR(%),${lotteryCVR.toStringAsFixed(2)}');
      b.writeln('Segments,${segmentCount}');
      b.writeln('Auto Campaigns,${autoCampaignCount}');
      b.writeln('Auto Conversions,${totalAutoConversions}');
      b.writeln('Logs Total,${logTotal}');
      b.writeln('Logs Success,${logSuccess}');
      b.writeln('Logs Fail,${logFail}');
      b.writeln('Logs Pending,${logPending}');
      b.writeln('');

      // Daily series
      b.writeln('Daily Logs');
      b.writeln('date,total');
      for (final p in dailyLogPoints) {
        b.writeln('${df.format(p.day)},${p.value.toInt()}');
      }
      b.writeln('');

      // Top coupons
      b.writeln('Top Coupons (Use Rate)');
      b.writeln('title,use_rate');
      for (final e in topCoupons) {
        b.writeln('${_csvEscape(e.key)},${e.value.toStringAsFixed(2)}');
      }
      b.writeln('');

      // Top auto
      b.writeln('Top Auto Campaigns (Conversions)');
      b.writeln('title,conversions');
      for (final e in topAuto) {
        b.writeln('${_csvEscape(e.key)},${e.value.toStringAsFixed(0)}');
      }
      b.writeln('');

      // Raw logs (optional, keep lightweight)
      b.writeln('Campaign Logs (filtered, limited)');
      b.writeln('time,type,status,campaignTitle,campaignId,segmentId,couponId,lotteryId,userId,channel,title,message,docId');

      for (final doc in _logDocs) {
        final d = doc.data();
        final dt = _asDateTime(d['createdAt']) ??
            _asDateTime(d['time']) ??
            _asDateTime(d['updatedAt']);
        final timeText = dt == null ? '' : dft.format(dt);

        final row = <String>[
          timeText,
          _s(d['type']),
          _s(d['status']),
          _s(d['campaignTitle']),
          _s(d['campaignId']),
          _s(d['segmentId']),
          _s(d['couponId']),
          _s(d['lotteryId']),
          _s(d['userId']),
          _s(d['channel']),
          _s(d['title']),
          _s(d['message']),
          doc.id,
        ].map((x) => _csvEscape(x)).join(',');
        b.writeln(row);
      }

      final bytes = Uint8List.fromList(b.toString().codeUnits);
      final name =
          'marketing_report_${DateFormat('yyyyMMdd').format(_fromDate)}_${DateFormat('yyyyMMdd').format(_toDate)}';

      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已匯出 CSV 報表')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd');

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('行銷報表'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          FilledButton.icon(
            onPressed: _exporting ? null : _exportCsv,
            icon: const Icon(Icons.download, size: 18),
            label: Text(_exporting ? '匯出中...' : '匯出 CSV'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _filtersCard(df),
          const SizedBox(height: 14),
          _kpiGrid(),
          const SizedBox(height: 16),
          _buildLineChartDailyLogs(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildPieChartLogStatus()),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBarChart(
                  'Top 5 優惠券使用率（used/issued%）',
                  topCoupons,
                  maxY: 100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBarChart(
            'Top 5 自動派發轉換量（conversionCount）',
            topAuto,
            maxY: _calcMaxY(topAuto),
          ),
          const SizedBox(height: 16),
          _buildNotesCard(),
        ],
      ),
    );
  }

  Widget _filtersCard(DateFormat df) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickDate(isFrom: true),
              icon: const Icon(Icons.date_range, size: 18),
              label: Text('起：${df.format(_fromDate)}'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(isFrom: false),
              icon: const Icon(Icons.date_range, size: 18),
              label: Text('迄：${df.format(_toDate)}'),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                'Logs：$logTotal（success $logSuccess / fail $logFail / pending $logPending）',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w700,
                ),
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
        _kpiCard('優惠券', '$activeCoupons / $couponCount', Icons.local_offer),
        _kpiCard('總發放量', totalIssued.toInt().toString(), Icons.send),
        _kpiCard('總點擊量', totalClicks.toInt().toString(), Icons.touch_app),
        _kpiCard('總使用量', totalUsed.toInt().toString(), Icons.check_circle),
        _kpiCard('平均 CTR', '${avgCTR.toStringAsFixed(1)}%', Icons.ads_click),
        _kpiCard('平均 CVR', '${avgCVR.toStringAsFixed(1)}%', Icons.trending_up),
        _kpiCard('抽獎活動', '$activeLotteries / $lotteryCount', Icons.emoji_events),
        _kpiCard('參與人次', totalParticipants.toInt().toString(), Icons.groups),
        _kpiCard('得獎人次', totalWinners.toInt().toString(), Icons.verified),
        _kpiCard('抽獎轉換率', '${lotteryCVR.toStringAsFixed(1)}%', Icons.percent),
        _kpiCard('受眾分群', segmentCount.toString(), Icons.group_work),
        _kpiCard('自動派發', autoCampaignCount.toString(), Icons.campaign),
        _kpiCard('自動派發轉換', totalAutoConversions.toInt().toString(), Icons.auto_graph),
      ],
    );
  }

  // ✅ 修正版 KPI 卡：移除固定高度，避免 Column overflow
  Widget _kpiCard(String label, String value, IconData icon) {
    return SizedBox(
      width: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.grey.shade300, blurRadius: 4),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min, // ✅ 關鍵：不要強制撐滿
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.blueAccent),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Charts
  // ------------------------------------------------------------
  Widget _buildLineChartDailyLogs() {
    if (dailyLogPoints.isEmpty) {
      return _emptyCard('每日趨勢（Logs）', '目前區間內沒有日誌資料');
    }

    final maxY =
        dailyLogPoints.map((e) => e.value).fold<double>(0, (m, v) => v > m ? v : m);
    final paddedMaxY = (maxY <= 0) ? 10.0 : (maxY * 1.2);

    // use index for x (0..n-1)
    final spots = <FlSpot>[];
    for (int i = 0; i < dailyLogPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailyLogPoints[i].value));
    }

    final df = DateFormat('MM/dd');

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '每日趨勢（Logs Total / Day）',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: paddedMaxY,
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, meta) => Text(v.toInt().toString()),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _calcBottomInterval(dailyLogPoints.length),
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= dailyLogPoints.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            df.format(dailyLogPoints[i].day),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true),
                      barWidth: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calcBottomInterval(int len) {
    if (len <= 7) return 1;
    if (len <= 14) return 2;
    if (len <= 31) return 4;
    return 7;
  }

  Widget _buildPieChartLogStatus() {
    final total = (logSuccess + logFail + logPending);
    if (total <= 0) {
      return _emptyCard('狀態分佈（Logs）', '目前區間內沒有 success/fail/pending 記錄');
    }

    final sections = <PieChartSectionData>[
      PieChartSectionData(
        value: logSuccess.toDouble(),
        title: 'success\n$logSuccess',
        radius: 52,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
      PieChartSectionData(
        value: logFail.toDouble(),
        title: 'fail\n$logFail',
        radius: 52,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
      PieChartSectionData(
        value: logPending.toDouble(),
        title: 'pending\n$logPending',
        radius: 52,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    ];

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '狀態分佈（Logs）',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 28,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calcMaxY(List<MapEntry<String, double>> entries) {
    if (entries.isEmpty) return 10;
    final max = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final padded = max <= 0 ? 10.0 : (max * 1.2);
    return padded;
  }

  Widget _buildBarChart(
    String title,
    List<MapEntry<String, double>> entries, {
    required double maxY,
  }) {
    if (entries.isEmpty) return _emptyCard(title, '無資料');

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, meta) => Text(v.toInt().toString()),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 74,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          final t = entries[i].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              t,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < entries.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: entries[i].value,
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String title, String message) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('備註',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            Text(
              '1) 本頁優惠券/抽獎/自動派發的 counters（issuedCount / usedCount / conversionCount）多為「累計值」。\n'
              '2) 若你要做「區間增量」報表，建議在 campaign_logs 寫入 action（issued/click/used/conversion）並用日誌聚合。\n'
              '3) 若 campaign_logs 數量很大，建議改成：後端每日聚合表（marketing_daily_stats）以提升速度與降低讀取成本。',
              style: TextStyle(color: Colors.grey.shade800, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Models
// ------------------------------------------------------------
class _DayPoint {
  final DateTime day;
  final double value;
  const _DayPoint({required this.day, required this.value});
}

class _DayAgg {
  final DateTime day;
  int total = 0;
  int success = 0;
  int fail = 0;
  int pending = 0;
  int other = 0;

  _DayAgg(this.day);
}

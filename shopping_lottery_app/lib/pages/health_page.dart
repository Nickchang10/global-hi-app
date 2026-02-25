// lib/pages/health_page.dart
//
// ✅ HealthPage（最終完整版｜可直接使用｜已修正 unnecessary_cast）
// - 無額外套件依賴（只用 Flutter SDK）
// - 內建示範健康數據：步數/卡路里/距離/睡眠/心率
// - 下拉刷新會重新產生示範數據
// - ✅ 修正：withOpacity(deprecated) → withValues(alpha: ...)

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final Random _rand = Random();
  Timer? _hrTimer;

  // demo metrics
  int _steps = 0;
  int _calories = 0;
  double _distanceKm = 0;
  double _sleepHours = 0;
  int _heartRate = 0;

  // weekly demo
  late List<int> _weeklySteps; // 7 days
  late List<int> _weeklySleepMin; // 7 days

  @override
  void initState() {
    super.initState();
    _regenDemoData();
    _hrTimer = Timer.periodic(const Duration(seconds: 2), (_) => _tickHR());
  }

  @override
  void dispose() {
    _hrTimer?.cancel();
    super.dispose();
  }

  // ✅ 已修正：移除不必要 cast（unnecessary_cast）
  String _s(num v, {int digits = 0}) {
    if (v is int) return v.toString();
    final d = digits.clamp(0, 6);
    return v.toStringAsFixed(d); // <-- no cast needed
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _regenDemoData());
  }

  void _regenDemoData() {
    _steps = 1500 + _rand.nextInt(12000);
    _calories = 80 + (_steps * (0.035 + _rand.nextDouble() * 0.02)).round();
    _distanceKm = max(0.2, _steps * (0.00072 + _rand.nextDouble() * 0.00012));
    _sleepHours = 5.2 + _rand.nextDouble() * 3.6;
    _heartRate = 58 + _rand.nextInt(42);

    _weeklySteps = List<int>.generate(7, (i) => 2000 + _rand.nextInt(12000));
    _weeklySleepMin = List<int>.generate(
      7,
      (i) => 300 + _rand.nextInt(230), // 5h~8h50m
    );
  }

  void _tickHR() {
    if (!mounted) return;
    setState(() {
      final delta = _rand.nextInt(9) - 4; // -4~+4
      _heartRate = (_heartRate + delta).clamp(45, 150);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('健康中心'),
        actions: [
          IconButton(
            tooltip: '重新產生示範數據',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _regenDemoData()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            _headerSummary(),
            const SizedBox(height: 12),
            _todayCards(),
            const SizedBox(height: 12),
            _heartRateCard(),
            const SizedBox(height: 12),
            _sleepCard(),
            const SizedBox(height: 12),
            _weeklyStepsCard(),
            const SizedBox(height: 12),
            _weeklySleepCard(),
          ],
        ),
      ),
    );
  }

  Widget _headerSummary() {
    final km = _s(_distanceKm, digits: 2);
    final sleep = _s(_sleepHours, digits: 1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.favorite, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日概況',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '距離 $km km · 睡眠 $sleep 小時 · 心率 $_heartRate bpm',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _openSummaryDetail, child: const Text('查看')),
        ],
      ),
    );
  }

  Widget _todayCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _metricCard(
          icon: Icons.directions_walk,
          title: '步數',
          value: _s(_steps),
          unit: 'steps',
          color: Colors.orange,
          onTap: () => _openMetricDetail('步數', '今日步數', '$_steps steps'),
        ),
        _metricCard(
          icon: Icons.local_fire_department,
          title: '熱量',
          value: _s(_calories),
          unit: 'kcal',
          color: Colors.redAccent,
          onTap: () => _openMetricDetail('熱量', '今日消耗熱量', '$_calories kcal'),
        ),
        _metricCard(
          icon: Icons.route,
          title: '距離',
          value: _s(_distanceKm, digits: 2),
          unit: 'km',
          color: Colors.blue,
          onTap: () => _openMetricDetail(
            '距離',
            '今日移動距離',
            '${_s(_distanceKm, digits: 2)} km',
          ),
        ),
        _metricCard(
          icon: Icons.bedtime,
          title: '睡眠',
          value: _s(_sleepHours, digits: 1),
          unit: 'hrs',
          color: Colors.indigo,
          onTap: () => _openMetricDetail(
            '睡眠',
            '昨晚睡眠',
            '${_s(_sleepHours, digits: 1)} 小時',
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: TextStyle(color: Colors.grey.shade700)),
                    AllowingTwoLines(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            value,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              unit,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heartRateCard() {
    final zone = _heartRate < 60
        ? '偏低'
        : (_heartRate < 100 ? '正常' : (_heartRate < 130 ? '偏高' : '高'));

    return _sectionCard(
      title: '心率',
      subtitle: '即時監測（示範）',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_heartRate bpm',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.pink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              zone,
              style: const TextStyle(
                color: Colors.pink,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          _hrBar(_heartRate),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '提示：此頁為示範資料，正式版可改接手錶/HealthKit/Google Fit。',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
      onTap: () => _openMetricDetail('心率', '即時心率', '$_heartRate bpm（$zone）'),
    );
  }

  Widget _sleepCard() {
    final mins = (_sleepHours * 60).round();
    final deep = (mins * (0.18 + _rand.nextDouble() * 0.08)).round();
    final rem = (mins * (0.20 + _rand.nextDouble() * 0.07)).round();
    final light = max(0, mins - deep - rem);

    final hh = mins ~/ 60;
    final mm = mins % 60;
    final label = '${_s(hh)}h ${_s(mm)}m';

    return _sectionCard(
      title: '睡眠分析',
      subtitle: '昨晚（示範）',
      trailing: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          _sleepStackBar(deep: deep, rem: rem, light: light),
          const SizedBox(height: 10),
          Row(
            children: [
              _legendDot('深睡', Colors.indigo),
              const SizedBox(width: 12),
              _legendDot('REM', Colors.teal),
              const SizedBox(width: 12),
              _legendDot('淺睡', Colors.orange),
            ],
          ),
        ],
      ),
      onTap: () => _openMetricDetail(
        '睡眠分析',
        '分段（示範）',
        '深睡 ${deep}m · REM ${rem}m · 淺睡 ${light}m',
      ),
    );
  }

  Widget _weeklyStepsCard() {
    final maxV = _weeklySteps.fold<int>(1, (p, c) => max(p, c));
    final avg = (_weeklySteps.reduce((a, b) => a + b) / 7).round();

    return _sectionCard(
      title: '近 7 天步數',
      subtitle: '趨勢（示範）',
      trailing: Text(
        '平均 ${_s(avg)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final v = _weeklySteps[i];
            final h = (v / maxV) * 100;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _s(v ~/ 1000),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: max(8, h),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _weekDayLabel(i),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
      onTap: () =>
          _openMetricDetail('近 7 天步數', '原始數據（示範）', _weeklySteps.join(', ')),
    );
  }

  Widget _weeklySleepCard() {
    final maxV = _weeklySleepMin.fold<int>(1, (p, c) => max(p, c));
    final avg = (_weeklySleepMin.reduce((a, b) => a + b) / 7).round();

    return _sectionCard(
      title: '近 7 天睡眠',
      subtitle: '分鐘（示範）',
      trailing: Text(
        '平均 ${_s(avg)}m',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final v = _weeklySleepMin[i];
            final h = (v / maxV) * 100;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _s(v ~/ 60),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: max(8, h),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _weekDayLabel(i),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
      onTap: () =>
          _openMetricDetail('近 7 天睡眠', '原始數據（示範）', _weeklySleepMin.join(', ')),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    Widget? trailing,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _hrBar(int hr) {
    final t = ((hr - 45) / (150 - 45)).clamp(0.0, 1.0);

    Color c;
    if (t < 0.25) {
      c = Colors.blue;
    } else if (t < 0.55) {
      c = Colors.green;
    } else if (t < 0.80) {
      c = Colors.orange;
    } else {
      c = Colors.redAccent;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LinearProgressIndicator(
        value: t,
        minHeight: 10,
        backgroundColor: Colors.pink.withValues(alpha: 0.10),
        valueColor: AlwaysStoppedAnimation<Color>(c),
      ),
    );
  }

  Widget _sleepStackBar({
    required int deep,
    required int rem,
    required int light,
  }) {
    final total = max(1, deep + rem + light);
    final deepF = deep / total;
    final remF = rem / total;
    final lightF = light / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            Expanded(
              flex: max(1, (deepF * 1000).round()),
              child: Container(color: Colors.indigo.withValues(alpha: 0.8)),
            ),
            Expanded(
              flex: max(1, (remF * 1000).round()),
              child: Container(color: Colors.teal.withValues(alpha: 0.8)),
            ),
            Expanded(
              flex: max(1, (lightF * 1000).round()),
              child: Container(color: Colors.orange.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      ],
    );
  }

  String _weekDayLabel(int i) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return labels[i % 7];
  }

  void _openSummaryDetail() {
    final km = _s(_distanceKm, digits: 2);
    final sleep = _s(_sleepHours, digits: 1);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '今日概況（示範）',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              _kv('步數', '$_steps steps'),
              _kv('熱量', '$_calories kcal'),
              _kv('距離', '$km km'),
              _kv('睡眠', '$sleep 小時'),
              _kv('心率', '$_heartRate bpm'),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openMetricDetail(String title, String subtitle, String content) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              Text(content),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(k, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// 小工具：避免某些裝置/字體造成 Row 高度不夠時溢位
class AllowingTwoLines extends StatelessWidget {
  final Widget child;
  const AllowingTwoLines({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      child: child,
    );
  }
}

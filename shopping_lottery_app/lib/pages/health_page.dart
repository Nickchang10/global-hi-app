// lib/pages/health_page.dart
// =====================================================
// ✅ HealthPage（Osmile 健康中心｜最終整合完整版）
// - 支援雲端 + 手錶 BLE 雙來源資料
// - 健康摘要卡：步數、睡眠、心率、血壓、積分
// - 功能：同步、分享、SOS、地圖追蹤
// - 相容 Osmile 商城架構
// =====================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// === 服務層整合 ===
import '../services/health_service.dart';
import '../services/tracking_service.dart';
import '../services/sos_service.dart';
import '../services/bluetooth_service.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _fmt = NumberFormat('#,###');
  final String userId = 'demo_user';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);

    // 初始化雲端同步與模擬資料
    Future.microtask(() async {
      await HealthService.instance.syncFromCloud(userId);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1200)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthService>();
    final sos = context.watch<SOSService>();
    final track = context.watch<TrackingService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text("健康中心", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: "同步手錶資料",
            onPressed: () async {
              await health.startLocalSync(userId);
              _toast("正在同步 Osmile 手錶資料...");
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: "分享健康報告",
            onPressed: () => _toast("健康報告已匯出（模板）"),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "步數"),
            Tab(text: "睡眠"),
            Tab(text: "心率"),
            Tab(text: "血壓"),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSummaryCard(context, health, sos, track),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildStepsTab(health.steps),
                _buildSleepTab(health.sleepHours),
                _buildHeartTab(health.heartRate),
                _buildBloodTab(health.bp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 健康摘要卡（整合 SOS / 追蹤 / 積分）
  // =====================================================
  Widget _buildSummaryCard(BuildContext ctx, HealthService h, SOSService s,
      TrackingService t) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.account_circle,
                  size: 42, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("今日健康狀態",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      DateFormat('MM/dd (EEE)', 'zh_TW').format(DateTime.now()),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stars_rounded,
                        size: 16, color: Colors.orangeAccent),
                    SizedBox(width: 4),
                    Text("+120 積分",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orangeAccent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metric("步數", _fmt.format(h.steps), "步", Icons.directions_walk),
              _metric("睡眠", h.sleepHours.toStringAsFixed(1), "小時",
                  Icons.bedtime_outlined),
              _metric("心率", "${h.heartRate}", "bpm", Icons.favorite_border),
              _metric("血壓", h.bp, "", Icons.monitor_heart_outlined),
            ],
          ),
          const Divider(height: 28, thickness: 0.8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionIcon(
                icon: Icons.watch,
                label: h.online ? "已連線" : "連線手錶",
                color: h.online ? Colors.green : Colors.blueAccent,
                onTap: () async {
                  h.online
                      ? await h.stop()
                      : await h.startLocalSync(userId);
                },
              ),
              _actionIcon(
                icon: Icons.map_outlined,
                label: "即時追蹤",
                color: Colors.indigo,
                onTap: () => Navigator.pushNamed(ctx, '/tracking'),
              ),
              _actionIcon(
                icon: Icons.sos_outlined,
                label: s.active ? "已啟動" : "SOS",
                color: s.active ? Colors.redAccent : Colors.orangeAccent,
                onTap: () =>
                    s.active ? s.cancelSOS() : s.triggerSOS(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, String unit, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 24),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text("$value $unit",
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // =====================================================
  // 各分頁內容
  // =====================================================
  Widget _buildStepsTab(int steps) {
    return _MetricTabTemplate(
      title: "今日步數",
      value: "$steps 步",
      trend: _fakeChartData(),
      color: Colors.blueAccent,
      onViewHistory: () => _toast("查看步數歷史（模板）"),
    );
  }

  Widget _buildSleepTab(double hours) {
    return _MetricTabTemplate(
      title: "昨晚睡眠時長",
      value: "${hours.toStringAsFixed(1)} 小時",
      trend: _fakeChartData(),
      color: Colors.indigo,
      onViewHistory: () => _toast("查看睡眠歷史（模板）"),
    );
  }

  Widget _buildHeartTab(int bpm) {
    return _MetricTabTemplate(
      title: "平均心率",
      value: "$bpm bpm",
      trend: _fakeChartData(),
      color: Colors.pinkAccent,
      onViewHistory: () => _toast("查看心率歷史（模板）"),
    );
  }

  Widget _buildBloodTab(String bp) {
    return _MetricTabTemplate(
      title: "血壓狀態",
      value: bp,
      trend: _fakeChartData(),
      color: Colors.redAccent,
      onViewHistory: () => _toast("查看血壓歷史（模板）"),
    );
  }

  List<double> _fakeChartData() =>
      List.generate(7, (_) => 50 + Random().nextDouble() * 100);
}

// =====================================================
// 抽象化圖表模板元件
// =====================================================
class _MetricTabTemplate extends StatelessWidget {
  final String title;
  final String value;
  final List<double> trend;
  final Color color;
  final VoidCallback onViewHistory;

  const _MetricTabTemplate({
    required this.title,
    required this.value,
    required this.trend,
    required this.color,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: CustomPaint(painter: _LineChartPainter(trend, color)),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onViewHistory,
                icon: const Icon(Icons.bar_chart_rounded),
                label: const Text("查看歷史資料"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================
// 簡易折線圖繪製（不依賴外部套件）
// =====================================================
class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _LineChartPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final dx = size.width / (data.length - 1);
    final minY = data.reduce(min);
    final maxY = data.reduce(max);
    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final norm = (data[i] - minY) / (maxY - minY);
      final y = size.height - norm * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.data != data || old.color != color;
}

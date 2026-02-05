import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeeklyReportPage extends StatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  List<int> _checkinData = [];
  List<int> _taskData = [];
  List<int> _lotteryData = [];
  int _totalPoints = 0;
  final List<String> _weekDays = ["一", "二", "三", "四", "五", "六", "日"];

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    final prefs = await SharedPreferences.getInstance();
    // 這裡先模擬資料，可替換為真實後端數據
    setState(() {
      _checkinData = List.generate(7, (_) => Random().nextInt(2)); // 0/1
      _taskData = List.generate(7, (_) => Random().nextInt(5)); // 任務數
      _lotteryData = List.generate(7, (_) => Random().nextInt(3)); // 抽獎次數
      _totalPoints = prefs.getInt('userPoints') ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 每週活躍報表"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F8FF), Color(0xFFE1F5FE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 20),
            _buildSection("📅 每日簽到紀錄", _checkinChart(), Colors.greenAccent),
            _buildSection("🔥 任務完成數", _taskChart(), Colors.deepOrange),
            _buildSection("🎰 抽獎次數", _lotteryChart(), Colors.purpleAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final activeDays =
        _checkinData.where((v) => v > 0).length + _taskData.where((v) => v > 0).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          const Text("🌟 本週活躍總覽",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("📆 活躍天數：$activeDays / 7",
              style:
                  const TextStyle(fontSize: 16, color: Colors.blueAccent)),
          Text("💎 目前總積分：$_totalPoints",
              style:
                  const TextStyle(fontSize: 16, color: Colors.deepOrange)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget chart, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.notoSansTc(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 10),
          SizedBox(height: 180, child: chart),
        ],
      ),
    );
  }

  /// ✅ 簽到圖表
  Widget _checkinChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) => Text(_weekDays[value.toInt()],
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: _checkinData[i].toDouble(),
                color: Colors.green,
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// 🔥 任務圖表
  Widget _taskChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) => Text(_weekDays[value.toInt()],
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: _taskData[i].toDouble(),
                color: Colors.deepOrange,
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// 🎰 抽獎圖表
  Widget _lotteryChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) => Text(_weekDays[value.toInt()],
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: _lotteryData[i].toDouble(),
                color: Colors.purple,
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

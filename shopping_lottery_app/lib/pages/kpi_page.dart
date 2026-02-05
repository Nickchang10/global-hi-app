import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;

/// 📊 Osmile 展覽銷售團隊 KPI 頁面
///
/// 顯示每日新增客戶、銷售量、達成率等資料
class KpiPage extends StatefulWidget {
  const KpiPage({super.key});

  @override
  State<KpiPage> createState() => _KpiPageState();
}

class _KpiPageState extends State<KpiPage> {
  final List<_KpiData> _data = [
    _KpiData("11/24", 32, 6),
    _KpiData("11/25", 40, 9),
    _KpiData("11/26", 35, 7),
    _KpiData("11/27", 25, 5),
    _KpiData("11/28", 50, 12),
  ];

  int _newCustomers = 0;
  int _sales = 0;

  final int targetCustomers = 30;
  final int targetSales = 8;

  @override
  Widget build(BuildContext context) {
    final customerSeries = [
      charts.Series<_KpiData, String>(
        id: '新客戶',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (d, _) => d.date,
        measureFn: (d, _) => d.customers,
        data: _data,
      ),
    ];

    final salesSeries = [
      charts.Series<_KpiData, String>(
        id: '銷售量',
        colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
        domainFn: (d, _) => d.date,
        measureFn: (d, _) => d.sales,
        data: _data,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("📈 展覽銷售團隊 KPI"),
        backgroundColor: const Color(0xFF007BFF),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF007BFF),
        child: const Icon(Icons.add),
        onPressed: _showAddDialog,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTodaySummary(),
          const SizedBox(height: 24),

          // 折線圖：新增客戶
          _buildChartCard(
            title: "📊 每日新增客戶數",
            color: Colors.blue,
            series: customerSeries,
          ),
          const SizedBox(height: 24),

          // 折線圖：銷售量
          _buildChartCard(
            title: "💰 每日銷售手錶數",
            color: Colors.green,
            series: salesSeries,
          ),
        ],
      ),
    );
  }

  /// 今日摘要卡
  Widget _buildTodaySummary() {
    final rateCustomer = (_newCustomers / targetCustomers * 100).clamp(0, 100);
    final rateSales = (_sales / targetSales * 100).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "📅 今日統計",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _progressItem("新增客戶", _newCustomers, targetCustomers,
                  rateCustomer, Colors.blue),
              _progressItem("銷售量", _sales, targetSales, rateSales, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  /// 單一進度項目
  Widget _progressItem(
      String title, int current, int target, double rate, Color color) {
    return Column(
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 60,
              width: 60,
              child: CircularProgressIndicator(
                value: rate / 100,
                color: color,
                backgroundColor: Colors.grey[200],
                strokeWidth: 6,
              ),
            ),
            Text("${rate.toStringAsFixed(0)}%",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Text("$current / $target",
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
      ],
    );
  }

  /// 折線圖區塊
  Widget _buildChartCard({
    required String title,
    required Color color,
    required List<charts.Series<_KpiData, String>> series,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: charts.LineChart(
              series,
              animate: true,
              defaultRenderer: charts.LineRendererConfig(includePoints: true),
              domainAxis: const charts.OrdinalAxisSpec(),
            ),
          ),
        ],
      ),
    );
  }

  /// ➕ 新增今日資料
  void _showAddDialog() {
    final customerCtrl = TextEditingController();
    final salesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("新增今日數據"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: customerCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "新增客戶數"),
            ),
            TextField(
              controller: salesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "銷售量（手錶）"),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("取消"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007BFF)),
            child: const Text("儲存", style: TextStyle(color: Colors.white)),
            onPressed: () {
              setState(() {
                _newCustomers = int.tryParse(customerCtrl.text) ?? 0;
                _sales = int.tryParse(salesCtrl.text) ?? 0;
                _data.add(_KpiData("Today", _newCustomers, _sales));
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _KpiData {
  final String date;
  final int customers;
  final int sales;
  _KpiData(this.date, this.customers, this.sales);
}

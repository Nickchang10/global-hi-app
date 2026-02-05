import 'package:flutter/material.dart';
import '../services/points_service.dart';

class RewardPage extends StatefulWidget {
  const RewardPage({super.key});

  @override
  State<RewardPage> createState() => _RewardPageState();
}

class _RewardPageState extends State<RewardPage> {
  final rewards = [
    {"name": "50 元折價券", "cost": 50},
    {"name": "免運券", "cost": 80},
    {"name": "100 元購物金", "cost": 100},
    {"name": "VIP 限量禮包", "cost": 200},
  ];

  void _redeem(Map<String, dynamic> reward) {
    final ok = PointsService.instance.spendPoints(reward["cost"], reward["name"]);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? "成功兌換 ${reward["name"]}！"
          : "積分不足，無法兌換 ${reward["name"]}"),
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pts = PointsService.instance.points;

    return Scaffold(
      appBar: AppBar(
        title: const Text("兌換中心"),
        backgroundColor: const Color(0xFF007BFF),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFFE8F2FF),
            child: ListTile(
              leading: const Icon(Icons.monetization_on,
                  color: Color(0xFF007BFF)),
              title: Text("目前積分：$pts"),
            ),
          ),
          const SizedBox(height: 10),
          for (final r in rewards)
            Card(
              child: ListTile(
                title: Text(r["name"]),
                subtitle: Text("花費：${r["cost"]} 積分"),
                trailing: ElevatedButton(
                  onPressed: () => _redeem(r),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007BFF),
                      foregroundColor: Colors.white),
                  child: const Text("兌換"),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

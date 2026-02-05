import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/points_provider.dart';

/// 🏪 積分商城頁面
class PointsStorePage extends StatelessWidget {
  const PointsStorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final pointsProvider = Provider.of<PointsProvider>(context);

    // ✅ 加上型別註明 Map<String, dynamic>
    final List<Map<String, dynamic>> rewards = [
      {"name": "Osmile 折價券 NT\$100", "cost": 50},
      {"name": "智慧手錶錶帶乙條", "cost": 80},
      {"name": "限量抽獎資格", "cost": 120},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("積分商城"),
        backgroundColor: Colors.pinkAccent,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.pink.shade50,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text("我的積分",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("${pointsProvider.points}",
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.pinkAccent)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rewards.length,
              itemBuilder: (context, index) {
                final r = rewards[index];
                final int cost = r["cost"] as int; // ✅ 明確轉型
                final String name = r["name"] as String;

                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.card_giftcard,
                        color: Colors.pinkAccent),
                    title: Text(name),
                    subtitle: Text("需要 $cost 積分"),
                    trailing: ElevatedButton(
                      onPressed: () {
                        final success = pointsProvider.redeemPoints(cost);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(success
                              ? "兌換成功！請至會員中心查看"
                              : "積分不足，繼續努力💪"),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent),
                      child: const Text("兌換"),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

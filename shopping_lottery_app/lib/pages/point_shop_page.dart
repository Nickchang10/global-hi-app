import 'package:flutter/material.dart';
import 'package:osmile_shopping_app/services/firestore_mock_service.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';

class PointShopPage extends StatefulWidget {
  const PointShopPage({super.key});

  @override
  State<PointShopPage> createState() => _PointShopPageState();
}

class _PointShopPageState extends State<PointShopPage> {
  final firestore = FirestoreMockService.instance;
  final notify = NotificationService.instance;

  final rewards = [
    {"name": "50 元折價券", "cost": 100},
    {"name": "限量手環", "cost": 300},
    {"name": "ED1000 折 500 優惠券", "cost": 500},
  ];

  @override
  Widget build(BuildContext context) {
    final points = firestore.userPoints;

    return Scaffold(
      appBar: AppBar(
        title: const Text("💎 積分兌換商城"),
        backgroundColor: Colors.indigoAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Text(
              "目前積分：$points",
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const Divider(height: 30),
          ...rewards.map((r) => Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.card_giftcard, color: Colors.indigo),
                  title: Text(r["name"]!),
                  subtitle: Text("需 ${r["cost"]} 積分"),
                  trailing: ElevatedButton(
                    onPressed: points >= r["cost"]!
                        ? () {
                            firestore.addPoints(-r["cost"]!);
                            notify.addNotification(
                              title: "🎁 兌換成功",
                              message: "已兌換 ${r["name"]}！",
                              type: "reward",
                              icon: Icons.redeem,
                            );
                            setState(() {});
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent),
                    child: const Text("兌換"),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

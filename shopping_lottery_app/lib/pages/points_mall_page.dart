import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_mock_service.dart';
import '../services/coupon_service.dart';
import '../services/notification_service.dart';

/// 🏪 積分兌換商城（最終完整版）
///
/// 功能：
/// - 顯示可兌換商品
/// - 折抵優惠券
/// - 自動扣除積分
/// - 自動寫入 orderHistory
/// - 通知整合
class PointsMallPage extends StatelessWidget {
  const PointsMallPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FirestoreMockService>();
    final couponService = context.watch<CouponService>();

    final items = [
      {
        "id": 1,
        "name": "Lumi 2 智慧手環",
        "points": 500,
        "image": "assets/images/lumi2.png",
        "desc": "睡眠追蹤 + 心率監測 + 超長續航。",
      },
      {
        "id": 2,
        "name": "ED1000 智慧手錶",
        "points": 800,
        "image": "assets/images/ed1000.png",
        "desc": "SOS 安全警報 + GPS 定位。",
      },
      {
        "id": 3,
        "name": "健康智慧體重秤",
        "points": 400,
        "image": "assets/images/scale.png",
        "desc": "支援 BMI / 體脂率偵測。",
      },
      {
        "id": 4,
        "name": "Osmile 禮品卡 \$200",
        "points": 300,
        "image": "assets/images/giftcard.png",
        "desc": "購物全館可使用。",
      },
    ];

    final availablePoints = store.userPoints;
    final totalDiscount = couponService.totalAvailableDiscount;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🏪 積分兌換商城"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "查看兌換紀錄",
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.pushNamed(context, '/pointsHistory');
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F9FB),
      body: Column(
        children: [
          // 積分狀態列
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.lightBlueAccent],
              ),
            ),
            child: Column(
              children: [
                Text(
                  "💎 目前積分：$availablePoints",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (totalDiscount > 0)
                  Text(
                    "可用優惠折抵：$totalDiscount 積分",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),

          // 商品清單
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final p = items[i];
                final canRedeem =
                    availablePoints + totalDiscount >= p["points"];

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            p["image"],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.watch, size: 60),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p["name"],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p["desc"],
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "需 ${p["points"]} 積分",
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: canRedeem
                                          ? Colors.blueAccent
                                          : Colors.grey,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: canRedeem
                                        ? () {
                                            _redeemProduct(
                                                context, p, totalDiscount);
                                          }
                                        : null,
                                    child: const Text("兌換"),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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

  /// 🛍️ 執行兌換流程（含紀錄存檔）
  void _redeemProduct(BuildContext context, Map<String, dynamic> product,
      int availableDiscount) {
    final store = FirestoreMockService.instance;
    final coupon = CouponService.instance;
    final notify = NotificationService.instance;

    int required = product["points"];
    int usableDiscount =
        availableDiscount > required ? required : availableDiscount;
    int finalCost = required - usableDiscount;

    if (store.userPoints < finalCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ 積分不足，請再努力賺取積分！")),
      );
      return;
    }

    // 扣除積分
    store.usePoints(finalCost);

    // 使用優惠券（若有）
    if (usableDiscount > 0) {
      coupon.checkExpiry();
    }

    // 🔹 寫入兌換紀錄
    store.orderHistory.add({
      "id": DateTime.now().millisecondsSinceEpoch,
      "items": [
        {
          "name": product["name"],
          "price": product["points"],
          "qty": 1,
          "image": product["image"],
        }
      ],
      "total": finalCost,
      "time": DateTime.now(),
      "status": "已完成",
    });

    // 🔔 發送通知
    notify.addNotification(
      title: "🎉 兌換成功！",
      message: "已使用 $finalCost 積分兌換 ${product["name"]} 🎁",
      type: "redeem",
      icon: Icons.card_giftcard,
    );

    // ✅ 彈出成功提示
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🎁 兌換成功"),
        content: Text("恭喜獲得：${product["name"]}\n花費積分：$finalCost"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("確認"),
          )
        ],
      ),
    );
  }
}

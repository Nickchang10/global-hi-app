import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:osmile_shopping_app/services/firestore_mock_service.dart';
import 'package:osmile_shopping_app/services/notification_service.dart';
import 'package:osmile_shopping_app/services/coupon_service.dart';

/// 💰 等級商城兌換中心
///
/// ✅ 根據會員等級顯示可兌換項目
/// ✅ 消耗積分兌換商品 / 折扣券
/// ✅ 發送通知與動畫提示
class RewardShopPage extends StatelessWidget {
  const RewardShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreMockService.instance;
    final userPoints = firestore.points;
    final level = _getUserLevel(userPoints);

    final rewards = _getRewardsForLevel(level);

    return Scaffold(
      appBar: AppBar(
        title: const Text("🎁 等級商城"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF7F9FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(userPoints, level),
          const SizedBox(height: 20),
          ...rewards.map((item) => _buildRewardCard(context, item)).toList(),
        ],
      ),
    );
  }

  // 頂部資訊卡
  Widget _buildHeader(int points, String level) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("你的等級：$level",
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("可用積分：$points",
                style: const TextStyle(
                    fontSize: 18,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text("選擇下方獎勵進行兌換"),
          ],
        ),
      ),
    );
  }

  // 單項獎勵卡片
  Widget _buildRewardCard(BuildContext context, Map<String, dynamic> item) {
    final firestore = FirestoreMockService.instance;

    final enoughPoints = firestore.points >= (item["cost"] as int);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade100,
              child: Text(item["icon"], style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item["title"],
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(item["desc"],
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: enoughPoints
                  ? () => _redeemReward(context, item)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: enoughPoints ? Colors.blueAccent : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("兌換\n${item["cost"]}P",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // 🪄 兌換邏輯
  void _redeemReward(BuildContext context, Map<String, dynamic> item) {
    final firestore = FirestoreMockService.instance;
    final coupon = CouponService.instance;
    final notify = NotificationService.instance;

    firestore.addPoints(-item["cost"]);

    switch (item["type"]) {
      case "coupon":
        coupon.addCoupon(
          title: item["title"],
          description: item["desc"],
          discount: item["discount"],
        );
        notify.addNotification(
          title: "🎟️ 兌換成功",
          message: "你獲得了 ${item["title"]}！",
        );
        break;

      case "token":
        notify.addNotification(
          title: "💰 兌換完成",
          message: "你獲得了購物代幣：${item["title"]}",
        );
        break;

      case "vip":
        notify.addNotification(
          title: "👑 VIP 權限開啟",
          message: "你現在可參加 VIP 限定直播與活動！",
        );
        break;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🎉 兌換成功"),
        content: Text("你成功兌換了 ${item["title"]}！\n積分已自動扣除。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("太棒了！"),
          ),
        ],
      ),
    );
  }

  // 🧱 不同等級可兌換項目
  List<Map<String, dynamic>> _getRewardsForLevel(String level) {
    switch (level) {
      case "💎 Diamond":
        return [
          {
            "title": "VIP 直播通行證",
            "desc": "限鑽石會員參加之獨家直播",
            "icon": "🎤",
            "type": "vip",
            "cost": 500,
          },
          {
            "title": "滿千折300 優惠券",
            "desc": "全館滿 1000 折 300",
            "icon": "🎟️",
            "type": "coupon",
            "discount": 300,
            "cost": 400,
          },
          {
            "title": "500 積分購物代幣",
            "desc": "直接折抵購物金",
            "icon": "💰",
            "type": "token",
            "cost": 500,
          },
        ];

      case "🥇 Gold":
        return [
          {
            "title": "滿千折200 優惠券",
            "desc": "全館滿 1000 折 200",
            "icon": "🎟️",
            "type": "coupon",
            "discount": 200,
            "cost": 300,
          },
          {
            "title": "會員限定周邊",
            "desc": "兌換限量 Osmile 布袋",
            "icon": "👜",
            "type": "token",
            "cost": 400,
          },
        ];

      case "🥈 Silver":
        return [
          {
            "title": "全館 9 折券",
            "desc": "消費不限金額使用",
            "icon": "💳",
            "type": "coupon",
            "discount": 10,
            "cost": 200,
          },
          {
            "title": "Osmile 貼紙組",
            "desc": "限量小禮品",
            "icon": "🎁",
            "type": "token",
            "cost": 150,
          },
        ];

      default:
        return [
          {
            "title": "Bronze 入門體驗券",
            "desc": "全館 95 折一次使用",
            "icon": "🪙",
            "type": "coupon",
            "discount": 5,
            "cost": 100,
          },
        ];
    }
  }

  // 🧩 Helper：等級判定
  String _getUserLevel(int points) {
    if (points >= 2000) return "💎 Diamond";
    if (points >= 1000) return "🥇 Gold";
    if (points >= 500) return "🥈 Silver";
    return "🥉 Bronze";
  }
}

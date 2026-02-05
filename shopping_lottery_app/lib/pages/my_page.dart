// lib/pages/my_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_mock_service.dart';
import '../services/notification_service.dart';
import '../services/coupon_service.dart';

import 'coupon_page.dart';
import 'order_list_page.dart';
import 'points_ecosystem_with_detail.dart';
import 'points_notification_page.dart';
import '../widgets/points_push_overlay.dart';
import '../utils/haptic_audio_feedback.dart';

/// 📱 Osmile 會員中心（MyPage）
///
/// 功能：
/// - 顯示個人資訊、積分、訂單、優惠券、通知中心
/// - 支援登出與震動 / 動畫提示
class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final store = context.watch<FirestoreMockService>();
    final couponService = CouponService.instance;
    final notifications = context.watch<NotificationService>().notifications;

    final username = auth.currentUser ?? "訪客";
    final userId = auth.currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text("👤 我的帳戶"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "登出",
            onPressed: () {
              auth.logout();
              HapticAudioFeedback.warning();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("您已登出 ✅")),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 👤 個人頭像 + 基本資料
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, color: Colors.white, size: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text("會員代號：$userId",
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 18, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text("積分：${store.userPoints}",
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 🔹 功能選單區塊
          _buildSectionTitle("📦 我的功能"),
          _buildMenuTile(
            context,
            icon: Icons.shopping_bag,
            color: Colors.pinkAccent,
            title: "訂單紀錄",
            subtitle: "查看歷史訂單與再次購買",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderListPage()),
              );
            },
          ),
          _buildMenuTile(
            context,
            icon: Icons.local_activity,
            color: Colors.orangeAccent,
            title: "我的優惠券",
            subtitle: "查看與使用折扣券",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CouponPage()),
              );
            },
          ),
          _buildMenuTile(
            context,
            icon: Icons.star_rate,
            color: Colors.amber,
            title: "積分任務",
            subtitle: "完成任務獲得積分獎勵",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PointsEcosystemPage()),
              );
            },
          ),
          _buildMenuTile(
            context,
            icon: Icons.notifications_active,
            color: Colors.indigo,
            title: "通知中心",
            subtitle: "查看抽獎、積分、商城推播訊息",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PointsNotificationPage()),
              );
            },
          ),

          const SizedBox(height: 20),

          // 🔔 最新通知摘要
          _buildSectionTitle("🔔 最新通知"),
          if (notifications.isEmpty)
            const Text(
              "目前沒有通知訊息",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            )
          else
            Column(
              children: notifications.take(3).map((n) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Icon(n["icon"] ?? Icons.notifications,
                          color: Colors.white),
                    ),
                    title: Text(n["title"] ?? "通知"),
                    subtitle: Text(
                      n["message"] ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // 🎁 一鍵領取隨機優惠券
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.card_giftcard),
              label: const Text("領取隨機優惠券"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                couponService.grantRandomCoupon(source: "會員中心活動");
                HapticAudioFeedback.success();
                PointsPushOverlay.show(
                  context,
                  title: "🎉 優惠券已領取！",
                  message: "已新增至您的優惠券清單。",
                  icon: Icons.local_activity,
                  color: Colors.orangeAccent,
                );
              },
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 🔧 功能小元件：標題
  Widget _buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      );

  // 🔧 功能小元件：功能列
  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

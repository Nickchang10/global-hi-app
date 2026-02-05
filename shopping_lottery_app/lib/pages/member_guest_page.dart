// lib/pages/member_guest_page.dart
// =====================================================
// ✅ MemberGuestPage（未登入狀態｜我的｜精簡版｜最終可編譯）
// -----------------------------------------------------
// - 僅保留一組「註冊 / 登入」按鈕（在藍色區塊）
// - 未登入可逛商城 / 任務 / 互動；需登入功能會導去 /login
// - 高質感 UI、Web/Android/iOS 可用
// =====================================================

import 'package:flutter/material.dart';

class MemberGuestPage extends StatelessWidget {
  const MemberGuestPage({super.key});

  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _brand = Color(0xFF3B82F6);

  void _go(BuildContext context, String route) {
    try {
      Navigator.pushNamed(context, route);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('尚未設定路由：$route'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          children: [
            _header(context),
            const SizedBox(height: 12),
            _benefits(),
            const SizedBox(height: 12),
            _shortcuts(context),
            const SizedBox(height: 14),
            Text(
              '登入後可使用購物車、收藏、通知中心、訂單與會員福利（模板）。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ✅ 頂部頭像 + 登入註冊按鈕
  // =====================================================
  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withOpacity(0.18),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '尚未登入',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '登入後可使用訂單、收藏、購物車與通知等功能',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _go(context, '/register'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '註冊',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _go(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _brand,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '登入',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ✅ 登入後可用功能說明卡片（無按鈕）
  // =====================================================
  Widget _benefits() {
    Widget tile(IconData icon, String title, String sub) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _brand.withOpacity(0.12),
              child: Icon(icon, color: _brand, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '登入後可用',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          tile(Icons.receipt_long_outlined, '訂單管理', '查看訂單狀態、物流與保固'),
          const SizedBox(height: 10),
          tile(Icons.favorite_border, '收藏清單', '保存喜歡的商品與活動'),
          const SizedBox(height: 10),
          tile(Icons.notifications_none_rounded, '通知中心', '付款、出貨、優惠券提醒'),
        ],
      ),
    );
  }

  // =====================================================
  // ✅ 快捷入口（保持不變）
  // =====================================================
  Widget _shortcuts(BuildContext context) {
    Widget item(IconData icon, String title, String sub, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _brand.withOpacity(0.12),
                child: Icon(icon, color: _brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style:
                            const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        item(Icons.storefront_outlined, '先逛逛商城', '未登入可瀏覽商品',
            () => _go(context, '/shop')),
        const SizedBox(height: 10),
        item(Icons.emoji_events_outlined, '看看任務', '未登入可查看活動',
            () => _go(context, '/tasks')),
        const SizedBox(height: 10),
        item(Icons.people_outline, '互動社群', '未登入可瀏覽貼文',
            () => _go(context, '/interaction')),
        const SizedBox(height: 10),
        item(Icons.shopping_cart_outlined, '購物車', '需登入才能使用',
            () => _go(context, '/login')),
        const SizedBox(height: 10),
        item(Icons.favorite_border, '收藏', '需登入才能使用',
            () => _go(context, '/login')),
        const SizedBox(height: 10),
        item(Icons.notifications_none_rounded, '通知', '需登入才能查看',
            () => _go(context, '/login')),
      ],
    );
  }
}

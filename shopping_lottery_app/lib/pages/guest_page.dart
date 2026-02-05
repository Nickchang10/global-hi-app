// lib/pages/guest_page.dart
// ======================================================
// ✅ GuestPage（未登入狀態頁面）
// ------------------------------------------------------
// - 顯示品牌 Logo / 說明文字
// - 提供登入與註冊按鈕
// - 支援 Web + 行動版
// - 與 MemberPage 整合用於未登入狀態
// ======================================================

import 'package:flutter/material.dart';

class GuestPage extends StatelessWidget {
  const GuestPage({super.key});

  static const Color _brand = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ===== LOGO 圖示 =====
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _brand.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: _brand, size: 48),
                  ),
                  const SizedBox(height: 20),

                  // ===== 標題與說明 =====
                  const Text(
                    '歡迎來到 Osmile 商城',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '登入後可享受完整功能：購物、抽獎、健康追蹤與 SOS 安全守護。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ===== 登入按鈕 =====
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '登入',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ===== 註冊按鈕 =====
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _brand,
                        side: BorderSide(color: _brand.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '註冊新帳號',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== 小字或 Demo 體驗 =====
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/shop'),
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('先逛逛商城'),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),

                  const SizedBox(height: 40),
                  Text(
                    'Osmile 為您守護健康與安全',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

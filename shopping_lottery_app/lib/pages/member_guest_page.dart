// lib/pages/member_guest_page.dart
//
// ✅ MemberGuestPage（最終完整版）
// - 修正：withOpacity deprecated → 改用 withValues(alpha: ...)
// - 用於「未登入 / 訪客」狀態的會員頁提示：導向登入、註冊、回商城
// - Web/App 可用（不使用 dart:io）

import 'package:flutter/material.dart';

class MemberGuestPage extends StatelessWidget {
  const MemberGuestPage({super.key});

  static const Color _brand = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topPad = media.padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // 背景漸層
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF6F8FF), Color(0xFFF7F8FA)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SizedBox.expand(),
          ),

          // 裝飾圓（✅ withOpacity -> withValues）
          Positioned(
            top: -120 + topPad,
            right: -80,
            child: _BlurCircle(
              color: _brand.withValues(alpha: 0.18),
              size: 240,
            ),
          ),
          const Positioned(
            bottom: -140,
            left: -90,
            child: _BlurCircle(
              color: Color(0x1A3B82F6), // 0.10 alpha 等效
              size: 260,
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),
                      const _Header(
                        title: '會員中心',
                        subtitle: '登入後可查看訂單、優惠券、抽獎與健康資料',
                      ),
                      const SizedBox(height: 16),

                      // 主卡片
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: _brand.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.lock_outline,
                                size: 34,
                                color: _brand,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '你目前是訪客狀態',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '登入後才能使用會員功能（訂單 / 優惠券 / 抽獎 / 任務等）',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),

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
                                  '前往登入',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/register'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _brand,
                                  side: const BorderSide(color: _brand),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  '註冊新帳號',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            TextButton(
                              onPressed: () {
                                // 回主框架或商城（依你路由）
                                const candidates = <String>[
                                  '/main',
                                  '/shop',
                                  '/home',
                                  '/',
                                ];
                                for (final r in candidates) {
                                  try {
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      r,
                                      (route) => false,
                                    );
                                    return;
                                  } catch (_) {}
                                }
                              },
                              child: Text(
                                '先逛逛商城',
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 功能提示（✅ 改成 const）
                      const _HintCard(
                        icon: Icons.local_offer_outlined,
                        title: '優惠券 / 抽獎',
                        subtitle: '登入後可領券、套用折扣並參與抽獎活動',
                      ),
                      const SizedBox(height: 10),
                      const _HintCard(
                        icon: Icons.support_agent_outlined,
                        title: '客服與支援',
                        subtitle: '可查看工單、常見問題與通知中心',
                      ),
                      const SizedBox(height: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.person_outline, color: Color(0xFF3B82F6)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade700, height: 1.25),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HintCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.blueAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _BlurCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

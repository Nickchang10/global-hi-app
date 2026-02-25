// lib/pages/payment_success_page.dart
//
// ✅ PaymentSuccessPage（最終完整版｜已修正 withOpacity deprecated → withValues(alpha: ...)）
// ------------------------------------------------------------
// - 支付成功頁（可直接 pushNamed 使用）
// - 顯示：成功狀態、金額、訂單編號、付款方式、提示訊息
// - 動作：查看訂單、返回商城/首頁、前往抽獎（可選）
// - Web/App 可用（不使用 dart:io）
//
// ✅ 修正點：第 145 行附近原本 Colors.xxx.withOpacity(0.xx)
//           统一改為 Colors.xxx.withValues(alpha: 0.xx)
//
// 使用方式示例：
// Navigator.pushNamed(context, '/payment_success', arguments: {
//   'orderId': 'ORD123',
//   'amount': 1990,
//   'paymentMethod': '信用卡',
//   'goLotteryRoute': '/lotterys',
// });

import 'package:flutter/material.dart';

class PaymentSuccessPage extends StatelessWidget {
  final String orderId;
  final num amount;
  final String paymentMethod;

  /// 可選：成功後要導去的抽獎頁 route（你也可改成 LotteryPage）
  final String? goLotteryRoute;

  const PaymentSuccessPage({
    super.key,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    this.goLotteryRoute,
  });

  static const Color _brand = Color(0xFF3B82F6);

  /// 支援從路由 arguments 取值
  static Route route(RouteSettings settings) {
    final args = (settings.arguments as Map?)?.cast<String, dynamic>() ?? {};
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => PaymentSuccessPage(
        orderId: (args['orderId'] ?? '').toString(),
        amount: args['amount'] is num
            ? args['amount'] as num
            : num.tryParse('${args['amount']}') ?? 0,
        paymentMethod: (args['paymentMethod'] ?? '—').toString(),
        goLotteryRoute: (args['goLotteryRoute'] ?? args['lotteryRoute'])
            ?.toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeOrderId = orderId.trim().isEmpty ? '—' : orderId.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  _hero(),
                  const SizedBox(height: 14),

                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '付款資訊',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _kv('訂單編號', safeOrderId),
                        const SizedBox(height: 8),
                        _kv(
                          '付款方式',
                          paymentMethod.trim().isEmpty
                              ? '—'
                              : paymentMethod.trim(),
                        ),
                        const SizedBox(height: 8),
                        _kv('付款金額', 'NT\$${amount.toStringAsFixed(0)}'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _brand.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _brand.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: _brand,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '系統已完成付款確認（示範）。\n你可以前往查看訂單明細或繼續逛商城。',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _goOrderDetail(context, safeOrderId),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text(
                            '查看訂單',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brand,
                            side: const BorderSide(color: _brand),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _goHomeOrShop(context),
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text(
                            '回商城',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (goLotteryRoute != null &&
                      goLotteryRoute!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => _tryGo(context, goLotteryRoute!.trim()),
                      icon: const Icon(Icons.emoji_events_outlined),
                      label: const Text(
                        '前往抽獎',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '返回上一頁',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w900,
                      ),
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

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.green,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '付款成功',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  '感謝你的購買！\n我們已收到你的付款資訊（示範）。',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            k,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _goOrderDetail(BuildContext context, String safeOrderId) {
    // 依你專案：order_detail_page.dart 常見路由：/order_detail
    const candidates = <String>[
      '/order_detail',
      '/orders/detail',
      '/orderDetail',
    ];

    for (final r in candidates) {
      try {
        Navigator.pushNamed(context, r, arguments: {'orderId': safeOrderId});
        return;
      } catch (_) {
        // ignore & try next
      }
    }

    // fallback：回到 orders list 或 member
    _goHomeOrShop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('找不到訂單明細路由，已返回商城/首頁（示範）')));
  }

  void _goHomeOrShop(BuildContext context) {
    // 優先回 /main（你主框架），不行就回 /shop /home / /
    const candidates = <String>['/main', '/shop', '/home', '/'];

    for (final r in candidates) {
      try {
        Navigator.pushNamedAndRemoveUntil(context, r, (route) => false);
        return;
      } catch (_) {
        // ignore
      }
    }

    // 最後 fallback：直接 pop
    Navigator.pop(context);
  }

  void _tryGo(BuildContext context, String route) {
    try {
      Navigator.pushNamed(context, route);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('此 route 未註冊：$route')));
    }
  }
}

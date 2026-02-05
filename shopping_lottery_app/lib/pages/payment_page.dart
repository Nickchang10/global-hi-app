// lib/pages/payment_page.dart
// =====================================================
// ✅ PaymentPage（付款頁｜最終整合完整版）
// -----------------------------------------------------
// - 與 CheckoutPage / OrderService / NotificationService / FirestoreMockService 整合
// - 支援：信用卡 / 轉帳 / LINE Pay（模板）/ Apple Pay（模板）
// - 支援：付款倒數、訂單摘要、折價券顯示、付款成功/失敗結果頁（含 confetti）
// - Web 友善：不使用 cached_network_image，不用 dart:io
// - ✅ 參數提供預設值，避免 main.dart routes 直接 const PaymentPage() 編譯失敗
// =====================================================

import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';
import '../services/order_service.dart';
import '../services/firestore_mock_service.dart';

enum PayMethod { card, bank, linePay, applePay }
enum PayResult { success, failed, expired }

class PaymentPage extends StatefulWidget {
  /// ✅ 保持相容：給預設值，避免 routes: '/payment': (_) => const PaymentPage()
  final String orderId;
  final double totalAmount;

  /// 建議從 CheckoutPage 傳入，顯示更完整摘要
  final Map<String, dynamic>? orderSummary;

  /// 折價券資訊（可選）
  final Map<String, dynamic>? coupon;
  final double discount;

  const PaymentPage({
    super.key,
    String? orderId,
    double? totalAmount,
    this.orderSummary,
    this.coupon,
    this.discount = 0,
  })  : orderId = orderId ?? 'demo_order',
        totalAmount = totalAmount ?? 0;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> with TickerProviderStateMixin {
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _brand = Colors.blueAccent;

  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  // 倒數（模板：15 分鐘）
  static const Duration _initialCountdown = Duration(minutes: 15);
  Timer? _timer;
  Duration _left = _initialCountdown;

  // 支付方式
  PayMethod _method = PayMethod.card;

  // 信用卡表單
  final _formKey = GlobalKey<FormState>();
  final _cardNumber = TextEditingController();
  final _cardName = TextEditingController();
  final _cardExp = TextEditingController();
  final _cardCvv = TextEditingController();

  bool _paying = false;

  // confetti 只在結果頁用，但這裡先準備以便導頁時傳遞狀態
  //（結果頁自己會 new controller）
  @override
  void initState() {
    super.initState();
    _startCountdown();
    // 如果 totalAmount 沒帶入（例如你直接點 routes），仍可正常顯示模板
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cardNumber.dispose();
    _cardName.dispose();
    _cardExp.dispose();
    _cardCvv.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left.inSeconds <= 0) {
        _timer?.cancel();
        setState(() => _left = Duration.zero);
        return;
      }
      setState(() => _left -= const Duration(seconds: 1));
    });
  }

  String _fmtMoney(num v) => _moneyFmt.format(v);

  String _fmtLeft(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final mm = two(d.inMinutes.remainder(60));
    final ss = two(d.inSeconds.remainder(60));
    final hh = d.inHours > 0 ? '${two(d.inHours)}:' : '';
    return '$hh$mm:$ss';
  }

  bool get _expired => _left.inSeconds <= 0;

  // =====================================================
  // 解析 orderSummary
  // =====================================================
  List<Map<String, dynamic>> _summaryItems() {
    final s = widget.orderSummary;
    if (s == null) return const [];
    final raw = s['items'];
    if (raw is List) {
      return raw
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }

  double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  double get _subtotal {
    final s = widget.orderSummary;
    if (s != null && s['subtotal'] != null) return _toDouble(s['subtotal']);
    // fallback：用 items 算
    final items = _summaryItems();
    return items.fold(0.0, (sum, it) => sum + _toDouble(it['price']) * max(1, _toInt(it['qty'])));
  }

  double get _shippingFee {
    final s = widget.orderSummary;
    if (s == null) return 0;
    final v = s['shipping'] ?? s['shippingFee'];
    return _toDouble(v);
  }

  double get _discount => widget.discount > 0 ? widget.discount : _toDouble(widget.orderSummary?['discount']);

  double get _total {
    // 以 widget.totalAmount 為準（CheckoutPage 已算好）
    if (widget.totalAmount > 0) return widget.totalAmount;
    final t = _subtotal + _shippingFee - _discount;
    return t < 0 ? 0 : t;
  }

  // =====================================================
  // 付款流程（模板：模擬支付）
  // =====================================================
  Future<void> _pay() async {
    if (_expired) {
      _openStatus(PayResult.expired, message: '付款逾時，請返回重新結帳');
      return;
    }

    // 信用卡才驗證表單
    if (_method == PayMethod.card) {
      final ok = _formKey.currentState?.validate() ?? false;
      if (!ok) return;
    }

    if (_paying) return;
    setState(() => _paying = true);

    try {
      // 模擬處理時間
      await Future.delayed(const Duration(milliseconds: 900));

      // 模擬成功率（正式串金流再改）
      final rng = Random();
      final pass = rng.nextInt(100) >= 10; // 90% 成功

      if (!pass) {
        _pushPaymentNotification(success: false, message: '付款失敗，請稍後重試或更換方式');
        _openStatus(PayResult.failed, message: '付款失敗，請稍後重試或更換付款方式');
        return;
      }

      // ✅ 付款成功後：更新訂單狀態（兼容不同 OrderService 實作）
      await _markOrderPaid();

      // ✅ 回饋：積分/抽獎機會（依你 FirestoreMockService 規則）
      await _applyRewards();

      _pushPaymentNotification(success: true, message: '付款成功，訂單已完成');

      _openStatus(
        PayResult.success,
        message: '付款成功！已完成訂單 ${widget.orderId}',
      );
    } catch (e) {
      _pushPaymentNotification(success: false, message: '付款發生錯誤：$e');
      _openStatus(PayResult.failed, message: '付款發生錯誤：$e');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _markOrderPaid() async {
    try {
      // 常見：OrderService.instance.markPaid(orderId)
      final os = OrderService.instance;
      final dyn = os as dynamic;

      // 依序嘗試不同命名（避免你專案版本差異）
      Future<void> tryCall(Future<void> Function() fn) async {
        try {
          await fn();
        } catch (_) {}
      }

      await tryCall(() async => await dyn.markPaid(widget.orderId));
      await tryCall(() async => await dyn.setPaid(widget.orderId));
      await tryCall(() async => await dyn.updatePaymentStatus(widget.orderId, true));
      await tryCall(() async => await dyn.updateOrder(widget.orderId, {'paid': true, 'status': 'paid'}));
    } catch (_) {
      // 沒有對應方法也不致命（模板期）
    }
  }

  Future<void> _applyRewards() async {
    try {
      await FirestoreMockService.instance.init();
    } catch (_) {}

    final amount = _total;
    final rewardPoints = (amount ~/ 100) * 10;

    try {
      if (rewardPoints > 0) {
        await FirestoreMockService.instance.addPoints(rewardPoints);
        NotificationService.instance.addNotification(
          type: 'shop',
          title: '購物回饋',
          message: '本次消費回饋 +$rewardPoints 積分',
          icon: Icons.card_giftcard,
        );
      }
    } catch (_) {}

    try {
      if (amount >= 500) {
        await FirestoreMockService.instance.addFreeLotteryChance(1);
        NotificationService.instance.addNotification(
          type: 'lottery',
          title: '獲得免費抽獎',
          message: '消費滿 NT\$500，獲得 1 次免費抽獎機會',
          icon: Icons.casino_outlined,
        );
      }
    } catch (_) {}
  }

  void _pushPaymentNotification({required bool success, required String message}) {
    try {
      NotificationService.instance.addNotification(
        type: success ? 'payment' : 'error',
        title: success ? '付款成功' : '付款失敗',
        message: message,
        icon: success ? Icons.check_circle_outline : Icons.error_outline,
      );
    } catch (_) {}
  }

  void _openStatus(PayResult result, {required String message}) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentStatusPage(
          result: result,
          orderId: widget.orderId,
          totalAmount: _total,
          message: message,
          summary: widget.orderSummary,
        ),
      ),
    );
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final items = _summaryItems();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('付款', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.6,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _expired ? Colors.redAccent.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _expired ? Colors.redAccent.withOpacity(0.25) : Colors.orange.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  _expired ? '已逾時' : '剩餘 ${_fmtLeft(_left)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _expired ? Colors.redAccent : Colors.orange[900],
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
        children: [
          _OrderHeaderCard(
            orderId: widget.orderId,
            totalText: _fmtMoney(_total),
            subtitle: widget.coupon == null
                ? '請於倒數結束前完成付款'
                : '已套用：${(widget.coupon?['title'] ?? '優惠券').toString()}',
            expired: _expired,
          ),
          const SizedBox(height: 12),

          if (items.isNotEmpty || widget.orderSummary != null) ...[
            _OrderSummaryCard(
              items: items,
              subtotal: _subtotal,
              shipping: _shippingFee,
              discount: _discount,
              total: _total,
              fmtMoney: _fmtMoney,
            ),
            const SizedBox(height: 12),
          ],

          _MethodSelector(
            value: _method,
            onChanged: (m) => setState(() => _method = m),
          ),
          const SizedBox(height: 12),

          if (_method == PayMethod.card) _buildCardForm(),
          if (_method != PayMethod.card) _buildMethodHint(),

          const SizedBox(height: 14),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_expired || _paying) ? null : _pay,
              icon: _paying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.payment_outlined),
              label: Text(
                _expired ? '付款已逾時' : (_paying ? '處理中...' : '立即付款 ${_fmtMoney(_total)}'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            '提示：目前為模板付款流程（尚未串接金流 API）。之後接入綠界/藍新/Stripe/LINE Pay 時，保留此 UI 與導頁即可。',
            style: TextStyle(color: Colors.grey.shade600, height: 1.35, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCardForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const _BlockTitle(icon: Icons.credit_card, title: '信用卡資訊'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _cardNumber,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '卡號',
                hintText: '4242 4242 4242 4242',
                prefixIcon: Icon(Icons.credit_card_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').replaceAll(' ', '');
                if (s.length < 12) return '請輸入正確卡號';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _cardName,
              decoration: const InputDecoration(
                labelText: '持卡人姓名',
                hintText: 'CARDHOLDER NAME',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '請輸入姓名' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cardExp,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: '有效期限',
                      hintText: 'MM/YY',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (!RegExp(r'^\d{2}\/\d{2}$').hasMatch(s)) return '格式 MM/YY';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _cardCvv,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.length < 3) return 'CVV 3-4 碼';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodHint() {
    String title;
    String desc;
    IconData icon;

    switch (_method) {
      case PayMethod.bank:
        title = '轉帳付款（模板）';
        desc = '請於付款成功後更新訂單狀態。模板期可直接按「立即付款」模擬成功。';
        icon = Icons.account_balance_outlined;
        break;
      case PayMethod.linePay:
        title = 'LINE Pay（模板）';
        desc = '之後接入 LINE Pay API 時，保留此入口與回傳導頁即可。';
        icon = Icons.qr_code_scanner_outlined;
        break;
      case PayMethod.applePay:
        title = 'Apple Pay（模板）';
        desc = 'iOS 端可接 Apple Pay / Stripe Apple Pay。模板期先模擬流程。';
        icon = Icons.phone_iphone_outlined;
        break;
      case PayMethod.card:
        title = '信用卡';
        desc = '';
        icon = Icons.credit_card;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BlockTitle(icon: icon, title: title),
          const SizedBox(height: 8),
          Text(desc, style: TextStyle(color: Colors.grey.shade700, height: 1.35)),
          if (_method == PayMethod.bank) ...[
            const SizedBox(height: 10),
            _KeyValueRow(k: '銀行代碼', v: '013'),
            _KeyValueRow(k: '帳號', v: '123-456-789-000'),
            _KeyValueRow(k: '戶名', v: 'Osmile Co., Ltd.'),
          ],
        ],
      ),
    );
  }
}

// =====================================================
// ✅ PaymentStatusPage（付款結果頁｜含 confetti）
// =====================================================
class PaymentStatusPage extends StatefulWidget {
  final PayResult result;
  final String orderId;
  final double totalAmount;
  final String message;
  final Map<String, dynamic>? summary;

  const PaymentStatusPage({
    super.key,
    required this.result,
    required this.orderId,
    required this.totalAmount,
    required this.message,
    this.summary,
  });

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage> {
  ConfettiController? _confetti;

  @override
  void initState() {
    super.initState();
    if (widget.result == PayResult.success) {
      _confetti = ConfettiController(duration: const Duration(seconds: 2))..play();
    }
  }

  @override
  void dispose() {
    _confetti?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = widget.result == PayResult.success;
    final expired = widget.result == PayResult.expired;

    final color = ok
        ? Colors.green
        : (expired ? Colors.orangeAccent : Colors.redAccent);

    final icon = ok
        ? Icons.check_circle_outline
        : (expired ? Icons.timer_off_outlined : Icons.error_outline);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          if (_confetti != null)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti!,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.08,
                numberOfParticles: 18,
                gravity: 0.35,
              ),
            ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 72, color: color),
                      const SizedBox(height: 10),
                      Text(
                        ok ? '付款成功' : (expired ? '付款逾時' : '付款失敗'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                      ),
                      const SizedBox(height: 14),
                      _KeyValueRow(k: '訂單編號', v: widget.orderId),
                      _KeyValueRow(
                        k: '付款金額',
                        v: NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$').format(widget.totalAmount),
                      ),
                      const SizedBox(height: 16),

                      // buttons
                      if (ok) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // 你 main.dart 已有 /lottery route
                              Navigator.pushNamedAndRemoveUntil(context, '/lottery', (r) => r.isFirst);
                            },
                            icon: const Icon(Icons.casino_outlined),
                            label: const Text('前往抽獎', style: TextStyle(fontWeight: FontWeight.w900)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.popUntil(context, (r) => r.isFirst);
                          },
                          icon: const Icon(Icons.home_outlined),
                          label: const Text('回首頁', style: TextStyle(fontWeight: FontWeight.w900)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueGrey,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),

                      if (!ok) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // 回到付款頁重新嘗試（保留上一頁就好）
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('返回重試', style: TextStyle(fontWeight: FontWeight.w900)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
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

// =====================================================
// UI Parts
// =====================================================

class _OrderHeaderCard extends StatelessWidget {
  final String orderId;
  final String totalText;
  final String subtitle;
  final bool expired;

  const _OrderHeaderCard({
    required this.orderId,
    required this.totalText,
    required this.subtitle,
    required this.expired,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = expired ? Colors.redAccent : Colors.green;
    final badgeText = expired ? '已逾時' : '待付款';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.receipt_long_outlined, color: Colors.blueAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '訂單 $orderId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: badgeColor.withOpacity(0.25)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Text(
                totalText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Colors.orangeAccent,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double shipping;
  final double discount;
  final double total;
  final String Function(num) fmtMoney;

  const _OrderSummaryCard({
    required this.items,
    required this.subtotal,
    required this.shipping,
    required this.discount,
    required this.total,
    required this.fmtMoney,
  });

  double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BlockTitle(icon: Icons.list_alt_outlined, title: '訂單摘要'),
          const SizedBox(height: 10),

          if (items.isEmpty)
            Text('（無商品明細）', style: TextStyle(color: Colors.grey.shade600))
          else
            ...items.take(6).map((it) {
              final name = (it['name'] ?? '商品').toString();
              final qty = _toInt(it['qty']);
              final price = _toDouble(it['price']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text('x$qty', style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(width: 10),
                    Text(fmtMoney(price * qty), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              );
            }),

          const Divider(height: 18),
          _KeyValueRow(k: '商品小計', v: fmtMoney(subtotal)),
          _KeyValueRow(k: '運費', v: fmtMoney(shipping)),
          _KeyValueRow(k: '折扣', v: '- ${fmtMoney(discount)}'),
          const Divider(height: 18),
          _KeyValueRow(
            k: '應付金額',
            v: fmtMoney(total),
            bold: true,
            vColor: Colors.orangeAccent,
          ),
        ],
      ),
    );
  }
}

class _MethodSelector extends StatelessWidget {
  final PayMethod value;
  final ValueChanged<PayMethod> onChanged;

  const _MethodSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BlockTitle(icon: Icons.payments_outlined, title: '選擇付款方式'),
          const SizedBox(height: 10),
          _MethodTile(
            selected: value == PayMethod.card,
            title: '信用卡',
            subtitle: 'Visa / MasterCard / JCB（模板）',
            icon: Icons.credit_card,
            onTap: () => onChanged(PayMethod.card),
          ),
          _MethodTile(
            selected: value == PayMethod.linePay,
            title: 'LINE Pay',
            subtitle: '之後可接 LINE Pay API（模板）',
            icon: Icons.qr_code_scanner_outlined,
            onTap: () => onChanged(PayMethod.linePay),
          ),
          _MethodTile(
            selected: value == PayMethod.applePay,
            title: 'Apple Pay',
            subtitle: 'iOS 可接 Apple Pay（模板）',
            icon: Icons.phone_iphone_outlined,
            onTap: () => onChanged(PayMethod.applePay),
          ),
          _MethodTile(
            selected: value == PayMethod.bank,
            title: '銀行轉帳',
            subtitle: '提供轉帳資訊（模板）',
            icon: Icons.account_balance_outlined,
            onTap: () => onChanged(PayMethod.bank),
          ),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Web 模式提示：Apple Pay 需搭配實際金流與裝置能力。',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MethodTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? Colors.blueAccent : Colors.grey.shade200;
    final bg = selected ? Colors.blueAccent.withOpacity(0.06) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.blueAccent : Colors.grey.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ]),
            ),
            if (selected) const Icon(Icons.check_circle, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }
}

class _BlockTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _BlockTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueGrey, size: 18),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String k;
  final String v;
  final bool bold;
  final Color? vColor;

  const _KeyValueRow({
    required this.k,
    required this.v,
    this.bold = false,
    this.vColor,
  });

  @override
  Widget build(BuildContext context) {
    final fw = bold ? FontWeight.w900 : FontWeight.w700;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: TextStyle(color: Colors.grey.shade700, fontWeight: fw))),
          Text(v, style: TextStyle(fontWeight: fw, color: vColor ?? Colors.black87)),
        ],
      ),
    );
  }
}

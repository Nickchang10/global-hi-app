// lib/pages/payment_status_page.dart
//
// ✅ PaymentStatusPage（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// 修正：移除 LotterySpinResult 型別依賴（避免 Undefined class 'LotterySpinResult'）
// 改用 dynamic 儲存抽獎結果，並用安全方式讀取 prize 資訊
// ----------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/cloud_push_service.dart';
import '../services/lottery_service.dart';

class PaymentStatusPage extends StatefulWidget {
  final String? orderId;
  final bool success;
  final num? amount;
  final String currency;

  const PaymentStatusPage({
    super.key,
    this.orderId,
    this.success = true,
    this.amount,
    this.currency = 'TWD',
  });

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage> {
  bool _busy = false;
  bool _initedArgs = false;

  String? _orderId;
  bool _success = true;
  num? _amount;
  String _currency = 'TWD';

  // ✅ 不再用 LotterySpinResult（避免 undefined_class）
  dynamic _lotteryResult;

  @override
  void initState() {
    super.initState();
    // 付款狀態頁通常會在畫面出來後自動做後處理（通知 + 抽獎）
    WidgetsBinding.instance.addPostFrameCallback((_) => _postProcessIfNeeded());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initedArgs) return;
    _initedArgs = true;

    // 先吃 widget 傳入
    _orderId = widget.orderId;
    _success = widget.success;
    _amount = widget.amount;
    _currency = widget.currency;

    // 若是 NamedRoute arguments 傳入，也支援 Map
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _orderId ??= args['orderId']?.toString();
      if (args['success'] is bool) _success = args['success'] as bool;
      if (args['amount'] is num) _amount = args['amount'] as num;
      if (args['currency'] != null) _currency = args['currency'].toString();
    }
  }

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _postProcessIfNeeded() async {
    if (!_success) return;

    final orderId = _orderId;
    final user = _user;
    if (orderId == null || orderId.isEmpty || user == null) return;

    // 避免重複跑（例如 hot-reload / rebuild）
    if (_lotteryResult != null || _busy) return;

    setState(() => _busy = true);
    try {
      // ✅ 1) 寫入訂單通知（通知中心）
      await CloudPushService.instance.notifyOrder(
        uid: user.uid,
        orderId: orderId,
        title: '付款成功',
        body: '訂單 $orderId 已付款完成',
        type: 'order',
        extra: {
          if (_amount != null) 'amount': _amount,
          'currency': _currency,
          'from': 'payment_status',
        },
      );

      // ✅ 2) 抽獎（同 orderId 防重複）
      final r = await LotteryService.instance.spinForOrder(
        orderId: orderId,
        lotteryId: 'default',
        meta: {
          'from': 'payment_status_page',
          if (_amount != null) 'amount': _amount,
          'currency': _currency,
        },
      );

      if (!mounted) return;
      setState(() => _lotteryResult = r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('後處理失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -------------------------
  // ✅ 安全取得 prize 資訊（不管 r 是 class 或 Map）
  // -------------------------
  Map<String, dynamic> _extractPrize(dynamic r) {
    if (r == null) return const {};

    // 1) 嘗試 class: r.prize.name / r.prize.type / r.prize.value
    try {
      final p = r.prize;
      final name = (p.name ?? '獎品').toString();
      final type = (p.type ?? 'none').toString();
      final value = p.value ?? 0;
      return {'name': name, 'type': type, 'value': value};
    } catch (_) {}

    // 2) Map 結構（常見：prizeName/prizeType/prizeValue）
    if (r is Map) {
      final name = (r['prizeName'] ?? r['name'] ?? '獎品').toString();
      final type = (r['prizeType'] ?? r['type'] ?? 'none').toString();
      final value = r['prizeValue'] ?? r['value'] ?? 0;
      return {'name': name, 'type': type, 'value': value};
    }

    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      appBar: AppBar(title: Text(_success ? '付款成功' : '付款失敗')),
      body: u == null
          ? _needLogin(context)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statusCard(),
                const SizedBox(height: 12),
                _lotteryCard(),
                const SizedBox(height: 12),
                _actions(),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  Widget _needLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            const Text('請先登入', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/login'),
              child: const Text('前往登入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    final orderId = _orderId;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _success ? Icons.check_circle_outline : Icons.error_outline,
              size: 44,
              color: _success ? Colors.green : Colors.redAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _success ? '付款已完成' : '付款未完成',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '訂單編號：${orderId ?? '—'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (_amount != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '金額：$_amount $_currency',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lotteryCard() {
    if (!_success) {
      return const Card(
        elevation: 0,
        child: Padding(padding: EdgeInsets.all(16), child: Text('付款失敗不進行抽獎。')),
      );
    }

    if (_lotteryResult == null) {
      return const Card(
        elevation: 0,
        child: Padding(padding: EdgeInsets.all(16), child: Text('正在準備抽獎結果...')),
      );
    }

    final p = _extractPrize(_lotteryResult);
    final name = (p['name'] ?? '獎品').toString();
    final type = (p['type'] ?? 'none').toString();
    final value = p['value'] ?? 0;

    String subtitle;
    switch (type) {
      case 'points':
        subtitle = '獲得 ${_asInt(value)} 點';
        break;
      case 'coupon':
        subtitle = '已發放優惠券（$value）';
        break;
      case 'voucher':
        subtitle = '已發放代金券（$value）';
        break;
      default:
        subtitle = '再接再厲！';
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.card_giftcard_outlined, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '抽獎結果',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回'),
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (r) => false),
              icon: const Icon(Icons.home_outlined),
              label: const Text('回首頁'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _postProcessIfNeeded,
              icon: const Icon(Icons.refresh),
              label: const Text('重試抽獎'),
            ),
          ],
        ),
      ),
    );
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}

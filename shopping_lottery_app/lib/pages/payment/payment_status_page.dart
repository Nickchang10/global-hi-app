// shopping_lottery_app/lib/pages/payment/payment_status_page.dart
//
// ✅ PaymentStatusPage（前端金流流程｜正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// - 監聽 orders/{orderId}.status
// - status == paid：才做後處理（通知 + 抽獎）
// - 後處理完成：自動導到 /order_success（帶 orderId + amount）
// - 兼容：arguments Map / widget 參數
//

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/cloud_push_service.dart';
import '../../services/lottery_service.dart';

class PaymentStatusPage extends StatefulWidget {
  const PaymentStatusPage({
    super.key,
    this.args,
    this.orderId,
    this.amount,
    this.currency = 'TWD',
    this.autoGoSuccess = true,
  });

  /// ✅ main.dart 用 PaymentStatusPage(args: args) 進來
  final Object? args;

  /// 也支援直接傳入（可選）
  final String? orderId;
  final num? amount;
  final String currency;

  /// paid 且後處理完成後是否自動跳成功頁
  final bool autoGoSuccess;

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage> {
  bool _busy = false;
  bool _initedArgs = false;
  bool _navigated = false;

  String _orderId = '';
  num? _amount;
  String _currency = 'TWD';
  bool _autoGoSuccess = true;

  // ✅ 不再用 LotterySpinResult（避免 undefined class）
  dynamic _lotteryResult;

  User? get _user => FirebaseAuth.instance.currentUser;

  String _s(dynamic v) => (v ?? '').toString().trim();

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    final s = v.toString().replaceAll(',', '').trim();
    return int.tryParse(s) ?? (double.tryParse(s)?.round() ?? 0);
  }

  Map<String, dynamic> _map(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initedArgs) return;
    _initedArgs = true;

    // 1) widget 參數
    _orderId = _s(widget.orderId);
    _amount = widget.amount;
    _currency = widget.currency;
    _autoGoSuccess = widget.autoGoSuccess;

    // 2) args / route arguments
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final merged = widget.args ?? routeArgs;

    if (merged is Map) {
      final oid = merged['orderId'];
      if (oid != null && _orderId.isEmpty) _orderId = _s(oid);

      final amt = merged['amount'];
      if (amt is num) _amount ??= amt;

      final cur = merged['currency'];
      if (cur != null) _currency = _s(cur).isEmpty ? _currency : _s(cur);

      final ags = merged['autoGoSuccess'];
      if (ags is bool) _autoGoSuccess = ags;
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

    // 2) Map 結構
    if (r is Map) {
      final name = (r['prizeName'] ?? r['name'] ?? '獎品').toString();
      final type = (r['prizeType'] ?? r['type'] ?? 'none').toString();
      final value = r['prizeValue'] ?? r['value'] ?? 0;
      return {'name': name, 'type': type, 'value': value};
    }

    return const {};
  }

  String _statusText(String s) {
    final v = s.trim().toLowerCase();
    switch (v) {
      case 'created':
      case 'pending':
      case 'pending_payment':
      case 'unpaid':
        return '等待付款';
      case 'paid':
        return '已付款';
      case 'failed':
        return '付款失敗';
      case 'cancelled':
      case 'canceled':
        return '已取消';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  bool _isPaid(String raw) => raw.trim().toLowerCase() == 'paid';

  Future<void> _postProcessPaid({
    required String orderId,
    required String uid,
    required int total,
  }) async {
    // ✅ paid 才做；避免重複跑（hot reload / rebuild）
    if (_busy) return;
    if (_lotteryResult != null) return;

    setState(() => _busy = true);
    try {
      // ✅ 1) 通知中心
      await CloudPushService.instance.notifyOrder(
        uid: uid,
        orderId: orderId,
        title: '付款成功',
        body: '訂單 $orderId 已付款完成',
        type: 'order',
        extra: {
          'amount': total,
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
          'amount': total,
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

  void _goSuccess({required String orderId, required int total}) {
    if (!mounted) return;
    if (_navigated) return;
    _navigated = true;

    Navigator.of(context).pushReplacementNamed(
      '/order_success',
      arguments: {'orderId': orderId, 'amount': total, 'autoBackSeconds': 0},
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
              ).pushNamedAndRemoveUntil('/home', (r) => false),
              child: const Text('回首頁/登入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard({required String statusRaw, required int total}) {
    final paid = _isPaid(statusRaw);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              paid ? Icons.check_circle_outline : Icons.hourglass_bottom,
              size: 44,
              color: paid ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paid ? '付款已完成' : '付款處理中',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '訂單編號：${_orderId.isEmpty ? '—' : _orderId}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '狀態：${_statusText(statusRaw)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '金額：$total $_currency',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lotteryCard() {
    if (_lotteryResult == null) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _busy ? '正在處理抽獎...' : '抽獎結果尚未產生',
            style: const TextStyle(color: Colors.black87),
          ),
        ),
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

  Widget _actions({required String statusRaw, required int total}) {
    final paid = _isPaid(statusRaw);

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
                    ).pushNamedAndRemoveUntil('/home', (r) => false),
              icon: const Icon(Icons.home_outlined),
              label: const Text('回首頁'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || _orderId.isEmpty
                  ? null
                  : () => Navigator.of(context).pushNamed(
                      '/order_detail',
                      arguments: {'orderId': _orderId},
                    ),
              icon: const Icon(Icons.receipt_long),
              label: const Text('訂單詳情'),
            ),
            if (paid)
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _goSuccess(orderId: _orderId, total: total),
                icon: const Icon(Icons.check),
                label: const Text('完成'),
              ),
            if (paid)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        final u = _user;
                        if (u == null) return;
                        _postProcessPaid(
                          orderId: _orderId,
                          uid: u.uid,
                          total: total,
                        );
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('重試後處理'),
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

  @override
  Widget build(BuildContext context) {
    final u = _user;
    if (u == null)
      return Scaffold(
        appBar: AppBar(title: const Text('付款狀態')),
        body: _needLogin(context),
      );
    if (_orderId.isEmpty) {
      return const Scaffold(body: Center(child: Text('缺少 orderId')));
    }

    final ref = FirebaseFirestore.instance.collection('orders').doc(_orderId);

    return Scaffold(
      appBar: AppBar(title: const Text('付款狀態')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取訂單失敗：\n${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('找不到訂單'));
          }

          final data = snap.data!.data() ?? <String, dynamic>{};
          final statusRaw = _s(data['status'] ?? 'created');

          final pricing = _map(data['pricing']);
          final total = _toInt(
            pricing['total'] ?? data['total'] ?? (_amount ?? 0),
          );
          _amount ??= total; // 讓畫面與導頁都有值

          final paid = _isPaid(statusRaw);

          // ✅ paid 才做後處理；完成後（或已完成）自動導到成功頁
          if (paid) {
            // 先確保後處理（通知/抽獎）有跑
            if (_lotteryResult == null && !_busy) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _postProcessPaid(orderId: _orderId, uid: u.uid, total: total);
              });
            }

            // 如果你希望 paid 就直接跳成功頁（不等抽獎），改成：_lotteryResult == null 也跳
            if (_autoGoSuccess &&
                !_navigated &&
                (_lotteryResult != null || !_busy)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _goSuccess(orderId: _orderId, total: total);
              });
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statusCard(statusRaw: statusRaw, total: total),
              const SizedBox(height: 12),
              if (paid) _lotteryCard(),
              if (paid) const SizedBox(height: 12),
              _actions(statusRaw: statusRaw, total: total),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}

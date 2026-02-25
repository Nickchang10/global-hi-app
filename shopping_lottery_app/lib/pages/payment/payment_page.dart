// lib/pages/payment/payment_page.dart
//
// ✅ PaymentPage（付款頁｜最終完整版｜可編譯）
// ------------------------------------------------------------
// - ✅ 不使用 firebase_functions（避免你目前套件未安裝導致編譯失敗）
// - 以 Firestore 模擬「付款成功」流程：更新 orders/{orderId}.status = 'paid'
// - 並寫入 orders/{orderId}/payments/{txId} 付款紀錄
//
// 路由建議：
// - '/payment' -> PaymentPage
// - (可選) '/payment_status' -> 你的付款結果頁（若沒有也不會 crash）
//
// Checkout 進來的 arguments 建議：
// {
//   'orderId': 'xxx',
//   'amount': 1234,
//   'payMethod': 'creditCard' / 'atm' / 'cod'
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = false;

  String _orderId = '';
  int _amount = 0;
  String _payMethod = 'creditCard';

  String? get _uid => _auth.currentUser?.uid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 只解析一次
    if (_orderId.isNotEmpty) {
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _orderId = (args['orderId'] ?? '').toString().trim();
      _payMethod = (args['payMethod'] ?? 'creditCard').toString().trim();

      final a = args['amount'];
      if (a is int) {
        _amount = a;
      } else if (a is num) {
        _amount = a.toInt();
      } else if (a is String) {
        _amount = int.tryParse(a) ?? 0;
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _money(int v) => 'NT\$ $v';

  String _newTxId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = (ms % 10007).toString().padLeft(4, '0');
    return 'tx_${ms}_$rand';
  }

  Future<void> _confirmPay() async {
    if (_loading) {
      return;
    }
    if (_orderId.isEmpty) {
      _snack('缺少 orderId，無法付款');
      return;
    }
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      _snack('請先登入');
      try {
        Navigator.of(context).pushNamed('/login');
      } catch (_) {}
      return;
    }

    setState(() => _loading = true);

    String? err;
    final txId = _newTxId();

    try {
      final now = FieldValue.serverTimestamp();

      final orderRef = _db.collection('orders').doc(_orderId);
      final userOrderRef = _db
          .collection('users')
          .doc(uid)
          .collection('orders')
          .doc(_orderId);

      // 1) 更新訂單狀態
      await orderRef.set(<String, dynamic>{
        'status': 'paid',
        'paidAt': now,
        'updatedAt': now,
        'payMethod': _payMethod,
        'paidAmount': _amount,
        'lastTxId': txId,
      }, SetOptions(merge: true));

      // 2) 同步更新 users/{uid}/orders/{orderId}（若存在）
      try {
        await userOrderRef.set(<String, dynamic>{
          'status': 'paid',
          'paidAt': now,
          'updatedAt': now,
          'payMethod': _payMethod,
          'paidAmount': _amount,
          'lastTxId': txId,
        }, SetOptions(merge: true));
      } catch (_) {
        // ignore
      }

      // 3) 寫入付款紀錄
      await orderRef.collection('payments').doc(txId).set(<String, dynamic>{
        'txId': txId,
        'uid': uid,
        'orderId': _orderId,
        'method': _payMethod,
        'amount': _amount,
        'status': 'success',
        'createdAt': now,
      });

      // 4) 成功 → 盡量跳 payment_status，沒有就顯示成功再返回
      if (!mounted) {
        return;
      }

      bool pushed = false;
      try {
        Navigator.of(context).pushNamed(
          '/payment_status',
          arguments: <String, dynamic>{
            'orderId': _orderId,
            'txId': txId,
            'status': 'success',
            'amount': _amount,
            'payMethod': _payMethod,
          },
        );
        pushed = true;
      } catch (_) {
        pushed = false;
      }

      if (!pushed) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('付款成功'),
            content: Text('訂單：$_orderId\n交易：$txId\n金額：${_money(_amount)}'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('確定'),
              ),
            ],
          ),
        );
        if (!mounted) {
          return;
        }
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      err = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }

    if (!mounted) {
      return;
    }
    if (err != null) {
      _snack('付款失敗：$err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final methodLabel = _payMethod == 'atm'
        ? 'ATM 轉帳'
        : _payMethod == 'cod'
        ? '貨到付款'
        : '信用卡 / 行動支付';

    return Scaffold(
      appBar: AppBar(title: const Text('付款')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cs.primary.withValues(alpha: 0.12),
                        child: Icon(Icons.payments_outlined, color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _orderId.isEmpty ? '付款資訊' : '訂單：$_orderId',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '付款方式：$methodLabel',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '應付金額：${_money(_amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '目前使用「模擬付款」模式（不依賴 Cloud Functions）。\n'
                  '按下「確認付款」後會：\n'
                  '- 更新 orders/$_orderId 狀態為 paid\n'
                  '- 寫入付款紀錄到 orders/$_orderId/payments',
                  style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _confirmPay,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: Text(_loading ? '處理中…' : '確認付款'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

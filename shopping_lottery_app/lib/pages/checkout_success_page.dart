// lib/pages/checkout_success_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import 'payment_status_page.dart';
import 'product_detail_page.dart';

/// ✅ 訂單完成/狀態頁（專業版）
/// - 支援查詢訂單狀態、取消訂單、重新付款
/// - 展示訂單商品明細
/// - 含動態步驟條與狀態更新
/// - 「繼續加購」支援跳轉商品詳情頁
class CheckoutSuccessPage extends StatefulWidget {
  final dynamic order; // 可為 Order 物件或 Map
  final String? orderId;
  final Map<String, dynamic>? orderSummary;
  final String apiBase;

  const CheckoutSuccessPage({
    super.key,
    this.order,
    this.orderId,
    this.orderSummary,
    this.apiBase = '',
  });

  @override
  State<CheckoutSuccessPage> createState() => _CheckoutSuccessPageState();
}

class _CheckoutSuccessPageState extends State<CheckoutSuccessPage> {
  String? _orderId;
  dynamic _order;
  Map<String, dynamic>? _summary;

  bool _isPaid = false;
  bool _loading = false;
  bool _cancelling = false;
  String _status = 'CHECKING';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _summary = widget.orderSummary;
    _orderId = _extractOrderId(_order) ?? widget.orderId ?? _summary?['id']?.toString();

    final s = (_extractOrderStatus(_order) ?? _summary?['status'])?.toString().toUpperCase();
    if (s == 'COMPLETED' || s == 'PAID') {
      _isPaid = true;
      _status = s;
    } else if (s == 'CANCELLED') {
      _isPaid = false;
      _status = 'CANCELLED';
    } else {
      _status = s?.isNotEmpty == true ? s! : 'CHECKING';
      if (_orderId != null) {
        _checkStatus();
        _startPolling();
      } else {
        _status = 'NO_ORDER_ID';
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ---------- Helpers ----------
  String? _extractOrderId(dynamic order) {
    if (order == null) return null;
    try {
      if (order is Map && order['id'] != null) return order['id'].toString();
      final id = (order as dynamic).id;
      return id?.toString();
    } catch (_) {
      return null;
    }
  }

  dynamic _extractOrderStatus(dynamic order) {
    if (order == null) return null;
    try {
      if (order is Map && order['status'] != null) return order['status'];
      final s = (order as dynamic).status;
      return s;
    } catch (_) {
      return null;
    }
  }

  String _fmtMoney(num v) => 'NT\$${v.toStringAsFixed(0)}';

  String _statusLabel(String s) {
    switch (s.toUpperCase()) {
      case 'PAID':
      case 'COMPLETED':
        return '已完成';
      case 'PENDING_PAYMENT':
      case 'PENDING':
        return '待付款';
      case 'PROCESSING':
        return '處理中';
      case 'CANCELLED':
        return '已取消';
      case 'CHECKING':
        return '檢查中…';
      default:
        return s;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      if (_isPaid || _status == 'CANCELLED') {
        _pollTimer?.cancel();
        return;
      }
      _checkStatus();
    });
  }

  Future<void> _checkStatus({bool toast = false}) async {
    if (_orderId == null) {
      if (toast) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('找不到訂單編號')));
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ApiClient.getOrderStatus(_orderId!, widget.apiBase);
      final s = (res['status'] ?? '').toString().toUpperCase();

      setState(() {
        _status = s.isEmpty ? 'UNKNOWN' : s;
        _isPaid = (s == 'COMPLETED' || s == 'PAID');
      });
      if (_isPaid || _status == 'CANCELLED') _pollTimer?.cancel();

      if (toast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('目前狀態：${_statusLabel(_status)}')),
        );
      }
    } catch (_) {
      setState(() => _status = 'CHECK_FAILED');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法取得訂單狀態')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToPaymentPage() {
    if (_orderId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PaymentStatusPage(orderId: _orderId!, apiBase: widget.apiBase)),
    );
  }

  Future<void> _cancelOrder() async {
    if (_orderId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('取消訂單'),
        content: const Text('確定要取消此訂單嗎？此動作無法還原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('否')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('是')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _cancelling = true);
    try {
      final res = await ApiClient.cancelOrder(_orderId!, widget.apiBase);
      final status = (res['status'] ?? '').toString().toUpperCase();
      if (status == 'CANCELLED') {
        setState(() {
          _status = 'CANCELLED';
          _isPaid = false;
        });
        _pollTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('訂單已取消')));
      } else if (res['error'] == 'ALREADY_PAID') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已付款的訂單無法取消')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消失敗：${res['status']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('取消發生錯誤：$e')));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _copyOrderId() async {
    if (_orderId == null || _orderId!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _orderId!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製訂單編號')));
  }

  Widget _summaryCard() {
    final items = (_summary?['items'] as List?) ?? [];
    final total = (_summary?['total'] as num?)?.toDouble() ?? 0.0;

    if (items.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('暫無訂單商品資訊'),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ...items.map((it) {
              final name = (it['name'] ?? '商品').toString();
              final price = (it['price'] as num?) ?? 0;
              final qty = (it['qty'] as int?) ?? 1;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('NT\$${price.toStringAsFixed(0)} × $qty'),
                trailing: Text(
                  _fmtMoney(price * qty),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
              );
            }),
            const Divider(),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('總計', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(
                _fmtMoney(total),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String label, int step, int current) {
    final done = step <= current;
    final color = done ? Colors.orangeAccent : Colors.grey.shade300;
    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color,
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : Text('${step + 1}', style: const TextStyle(color: Colors.black87)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: done ? Colors.black : Colors.grey,
              fontSize: 12,
              fontWeight: done ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  int _currentStepIndex() {
    final s = _status.toUpperCase();
    if (_isPaid || s == 'PAID' || s == 'COMPLETED') return 2;
    if (s == 'PENDING_PAYMENT' || s == 'PENDING') return 1;
    if (s == 'CANCELLED') return 0;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final stepIndex = _currentStepIndex();
    final displayStatus = _statusLabel(_status);
    final isCancelled = _status == 'CANCELLED';
    final canPay = !_isPaid && !isCancelled && _orderId != null;

    IconData icon;
    Color iconColor;
    String headline;
    if (_isPaid) {
      icon = Icons.check_circle_outline;
      iconColor = Colors.green;
      headline = '付款成功';
    } else if (isCancelled) {
      icon = Icons.cancel_outlined;
      iconColor = Colors.grey;
      headline = '訂單已取消';
    } else {
      icon = Icons.hourglass_empty;
      iconColor = Colors.orange;
      headline = '尚未完成付款';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('訂單狀態', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _checkStatus(toast: true),
            tooltip: '更新狀態',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            children: [
              // Stepper
              Row(
                children: [
                  Expanded(child: _step('下單', 0, stepIndex)),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Expanded(child: _step('付款中', 1, stepIndex)),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Expanded(child: _step('完成', 2, stepIndex)),
                ],
              ),
              const SizedBox(height: 14),
              // Status card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Text('目前狀態：$displayStatus', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 10),
                      Icon(icon, size: 88, color: iconColor),
                      const SizedBox(height: 10),
                      Text(headline, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('訂單編號：${_orderId ?? ''}', style: const TextStyle(color: Colors.grey)),
                          if (_orderId != null && _orderId!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _copyOrderId,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Text('複製', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _summaryCard(),
                      const SizedBox(height: 12),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _goToPaymentPage(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('重新付款'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: canPay ? _goToPaymentPage : null,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: Colors.orangeAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('前往付款'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (!_isPaid && !isCancelled)
                        TextButton(
                          onPressed: _cancelling ? null : _cancelOrder,
                          child: _cancelling
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('取消訂單', style: TextStyle(color: Colors.red)),
                        ),
                    ],
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

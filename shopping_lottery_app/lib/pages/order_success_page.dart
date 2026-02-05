// lib/pages/order_success_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'payment_status_page.dart';

String _generateIdShort() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  final rnd = Random().nextInt(1000);
  return 'id_${ms}_$rnd';
}

/// 一頁兩用：
/// - 有 product -> 當作 Checkout 流程
/// - 沒 product 但有 orderId -> 當作 Order Success 驗證頁面，會輪詢後端確認 status 為 COMPLETED 才顯示成功
class OrderSuccessPage extends StatefulWidget {
  final Map<String, dynamic>? product; // checkout 用
  final int qty;
  final String? orderId; // success verify 用
  final String apiBase;

  const OrderSuccessPage({Key? key, this.product, this.qty = 1, this.orderId, this.apiBase = ''})
      : super(key: key);

  @override
  State<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends State<OrderSuccessPage> {
  bool _loading = false;
  String? _createdOrderId;
  String _status = '檢查中...';
  bool _verified = false;
  bool _verifying = false;
  Timer? _timer;
  int _attempt = 0;

  /// --- NEW: flag for invalid params (both product and orderId null)
  bool _invalidParams = false;

  @override
  void initState() {
    super.initState();

    // --- NEW: debug prints to trace why page is opened and parameters
    debugPrint("=== OrderSuccessPage INIT ===");
    debugPrint("product: ${widget.product}");
    debugPrint("qty: ${widget.qty}");
    debugPrint("orderId: ${widget.orderId}");
    debugPrint("apiBase: ${widget.apiBase}");

    // --- NEW: guard: if neither product nor orderId is provided, mark invalid and do NOT auto-show success
    if (widget.product == null && widget.orderId == null) {
      debugPrint("OrderSuccessPage called without product or orderId! Marking invalid to avoid accidental success.");
      setState(() {
        _invalidParams = true;
        _status = '無效的頁面參數';
      });
      return;
    }

    // original behavior: if product is null but orderId present => verify loop
    if (widget.product == null && widget.orderId != null) {
      _startVerifyLoop();
    }
  }

  void _startVerifyLoop() {
    _checkStatus();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _attempt++;
      if (_attempt > 30) {
        _timer?.cancel();
      } else {
        _checkStatus();
      }
    });
  }

  Future<void> _checkStatus() async {
    final oid = widget.orderId ?? _createdOrderId;
    if (oid == null) return;
    if (_verifying) return;
    setState(() => _verifying = true);

    try {
      final res = await ApiClient.getOrderStatus(oid, widget.apiBase ?? '');
      if (res == null) {
        // 沒找到訂單
        setState(() => _status = 'NOT_FOUND');
        return;
      }

      // 容錯：有些後端會回 status 或 state
      final s = (res['status'] ?? res['state'] ?? '').toString().toUpperCase();
      setState(() => _status = s.isEmpty ? 'UNKNOWN' : s);

      if (s == 'COMPLETED' || s == 'PAID') {
        _timer?.cancel();
        setState(() => _verified = true);
      }
    } catch (e) {
      debugPrint('checkStatus error: $e');
      setState(() => _status = '檢查錯誤');
    } finally {
      _verifying = false;
    }
  }

  Future<void> _createOrderAndProceed() async {
    if (widget.product == null) return;
    setState(() => _loading = true);
    final idempotencyKey = _generateIdShort();
    final body = {
      "items": [
        {
          "product_id": widget.product!['id'] ?? widget.product!['name'],
          "qty": widget.qty,
          "price": widget.product!['price'] ?? 0,
        }
      ],
      "payment_method": "redirect",
    };

    try {
      final res = await ApiClient.createOrder(body, idempotencyKey, widget.apiBase ?? '');
      final orderId = res['order_id']?.toString();
      final status = (res['status'] ?? '').toString().toUpperCase();
      final paymentUrl = res['payment_url'] as String?;
      if (orderId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('建立訂單失敗')));
        return;
      }

      if (status == 'COMPLETED' || status == 'PAID') {
        await showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: const Text('異常'),
                  content: Text('後端回傳已完成（$status），請檢查後端'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('確定'))],
                ));
        return;
      }

      _createdOrderId = orderId;

      // 若有 payment_url：可開啟 webview/外部頁（此範例為輪詢）
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PaymentStatusPage(orderId: orderId, apiBase: widget.apiBase ?? '')));
    } catch (e) {
      debugPrint('createOrder error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('建立訂單失敗：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildCheckoutView() {
    final p = widget.product!;
    final price = p['price'] ?? 0;
    final total = price * widget.qty;
    return Scaffold(
      appBar: AppBar(title: const Text('結帳確認')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
                leading: p['image'] != null
                    ? Image.network(p['image'], width: 56, height: 56, fit: BoxFit.cover)
                    : const SizedBox(width: 56, height: 56),
                title: Text(p['name']),
                subtitle: Text('數量：${widget.qty}'),
                trailing: Text('NT\$ $total', style: const TextStyle(color: Colors.redAccent))),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _loading ? null : _createOrderAndProceed,
                child: _loading ? const CircularProgressIndicator() : const Text('確認並前往付款'),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48))),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationView() {
    final oid = widget.orderId ?? _createdOrderId ?? '—';

    // --- NEW: if invalid params, show clear message and buttons to go back
    if (_invalidParams) {
      return Scaffold(
        appBar: AppBar(title: const Text('頁面參數錯誤')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, size: 86, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text('此頁面必須帶入 product 或 orderId 參數', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: () {
                    // 回首頁，避免使用者誤以為已成功
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('回首頁')),
              const SizedBox(height: 8),
              ElevatedButton(
                  onPressed: () {
                    // 回上一頁
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('返回上一頁')),
            ]),
          ),
        ),
      );
    }

    if (_verified) {
      return Scaffold(
        appBar: AppBar(title: const Text('結帳成功')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle, size: 120, color: Colors.green),
            const SizedBox(height: 24),
            const Text('訂單建立成功', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('訂單編號：$oid'),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), child: const Text('回到首頁')),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('訂單狀態確認'), automaticallyImplyLeading: false),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 86, color: Colors.orangeAccent),
          const SizedBox(height: 16),
          Text('訂單編號：$oid'),
          const SizedBox(height: 8),
          Text('目前狀態：$_status'),
          const SizedBox(height: 12),
          if (_verifying) const CircularProgressIndicator(),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _verifying ? null : _checkStatus, child: const Text('重新檢查一次')),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), child: const Text('返回')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If this was launched as checkout flow (product != null) => show checkout view
    if (widget.product != null) return _buildCheckoutView();
    // Otherwise show verification view (and if invalid params will show the error)
    return _buildVerificationView();
  }
}

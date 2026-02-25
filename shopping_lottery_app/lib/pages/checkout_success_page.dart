// lib/pages/checkout_success_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ✅ CheckoutSuccessPage（結帳成功頁｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正：
/// - ✅ control_flow_in_finally：finally 只做收尾（不寫 return）
/// - ✅ 避免 use_build_context_synchronously：await 後先檢查 mounted
/// - ✅ withOpacity -> withValues(alpha: ...)
///
/// 使用方式：
/// - pushNamed('/checkout_success', arguments: {'orderId': '<id>'});
/// - 或直接傳入：CheckoutSuccessPage(orderId: '<id>');
///
/// Firestore path：
/// - orders/{orderId}
class CheckoutSuccessPage extends StatefulWidget {
  final String? orderId;

  const CheckoutSuccessPage({super.key, this.orderId});

  @override
  State<CheckoutSuccessPage> createState() => _CheckoutSuccessPageState();
}

class _CheckoutSuccessPageState extends State<CheckoutSuccessPage> {
  final _fs = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _order;

  String? _resolvedOrderId;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    final fromWidget = widget.orderId?.trim();
    String? fromArgs;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final v = args['orderId'];
      if (v != null) fromArgs = v.toString().trim();
    }

    _resolvedOrderId = (fromWidget != null && fromWidget.isNotEmpty)
        ? fromWidget
        : (fromArgs != null && fromArgs.isNotEmpty)
        ? fromArgs
        : null;

    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _order = null;
    });

    String? err;
    Map<String, dynamic>? data;

    try {
      final id = _resolvedOrderId;
      if (id == null || id.isEmpty) {
        err = '缺少 orderId（請用 arguments 傳入 {"orderId": "..."}）';
      } else {
        final doc = await _fs.collection('orders').doc(id).get();
        if (!doc.exists) {
          err = '找不到訂單：$id';
        } else {
          final d = doc.data();
          data = <String, dynamic>{'id': doc.id, ...?d};
        }
      }
    } catch (e) {
      err = '讀取訂單失敗：$e';
    } finally {
      // ✅ finally 不要 return，只做收尾
      if (mounted) {
        setState(() => _loading = false);
      }
    }

    if (!mounted) return;

    setState(() {
      _error = err;
      _order = data;
    });
  }

  String _money(dynamic v) {
    num n = 0;
    if (v is num) n = v;
    if (v is String) n = num.tryParse(v) ?? 0;

    final r = n.round();
    final s = r.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final remaining = s.length - i;
      buf.write(s[i]);
      if (remaining > 1 && remaining % 3 == 1) buf.write(',');
    }
    return 'NT\$ $buf';
  }

  String _statusText(dynamic status) {
    final s = (status ?? '').toString().toLowerCase().trim();
    switch (s) {
      case 'paid':
        return '已付款';
      case 'created':
        return '已建立';
      case 'shipping':
        return '出貨中';
      case 'delivered':
        return '已送達';
      case 'cancelled':
      case 'canceled':
        return '已取消';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  String _safeStr(dynamic v, [String fallback = '']) {
    final s = (v ?? '').toString();
    return s.isEmpty ? fallback : s;
  }

  Map<String, dynamic> _safeMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return <String, dynamic>{};
  }

  Future<void> _goHome() async {
    try {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到 "/" 路由，請在 routes 設定首頁')),
      );
    }
  }

  Future<void> _goOrders() async {
    // 你可改成你實際的訂單頁 route
    try {
      Navigator.of(context).pushNamed('/orders');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到 "/orders" 路由，請在 routes 設定')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('結帳成功'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? _errorView(cs, _error!)
          : _successView(cs, _order ?? const <String, dynamic>{}),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    top: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _goHome,
                        child: const Text('回首頁'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: _goOrders,
                        child: const Text('查看訂單'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _errorView(ColorScheme cs, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 10),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _load,
                          child: const Text('重試'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _goHome,
                          child: const Text('回首頁'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successView(ColorScheme cs, Map<String, dynamic> o) {
    final orderId = _safeStr(o['id'], _resolvedOrderId ?? '');
    final total = _money(o['total']);
    final status = _statusText(o['status']);
    final payMethod = _safeStr(o['paymentMethod'], '—');
    final shipMethod = _safeStr(o['shippingMethod'], '—');
    final couponCode = _safeStr(o['couponCode'], '');

    final address = _safeMap(o['address']);
    final receiverName = _safeStr(address['receiverName'], '—');
    final receiverPhone = _safeStr(address['receiverPhone'], '—');
    final fullAddress = _safeStr(address['fullAddress'], '—');

    final items = (o['items'] is List) ? (o['items'] as List) : const [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '訂單建立完成',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '總計：$total',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '狀態：$status',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        _sectionTitle('訂單資訊'),
        const SizedBox(height: 8),
        _kvCard(
          cs,
          rows: [
            ('訂單編號', orderId.isEmpty ? '—' : orderId),
            ('付款方式', payMethod),
            ('配送方式', shipMethod),
            ('優惠碼', couponCode.isEmpty ? '—' : couponCode),
          ],
        ),

        const SizedBox(height: 12),

        _sectionTitle('收件資訊'),
        const SizedBox(height: 8),
        _kvCard(
          cs,
          rows: [
            ('收件人', receiverName),
            ('電話', receiverPhone),
            ('地址', fullAddress),
          ],
        ),

        const SizedBox(height: 12),

        _sectionTitle('商品明細'),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '（無商品明細）',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          ...items.map((it) {
            final m = _safeMap(it);
            final name = _safeStr(m['name'], '(未命名商品)');
            final qty = (m['qty'] is num)
                ? (m['qty'] as num).toInt()
                : int.tryParse('${m['qty']}') ?? 1;
            final price = _money(m['price']);
            return Card(
              elevation: 1,
              child: ListTile(
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('數量 $qty'),
                trailing: Text(
                  price,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            );
          }),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }

  Widget _kvCard(ColorScheme cs, {required List<(String, String)> rows}) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              _kvRow(cs, rows[i].$1, rows[i].$2),
              if (i != rows.length - 1)
                Divider(
                  height: 14,
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kvRow(ColorScheme cs, String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(k, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

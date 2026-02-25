// lib/pages/admin/orders/admin_order_detail_page.dart
//
// ✅ AdminOrderDetailPage（訂單詳情｜完整版｜可編譯）
// ------------------------------------------------------------
// - 依 orderId 顯示 orders/{orderId} 詳情
// - 相容 Web/桌面/手機
// - 支援：查看摘要、商品清單、金流/物流資訊、時間軸
// - 管理操作：變更狀態、編輯管理員備註、跳轉會員詳情
//
// ✅ 路由註冊建議：
// routes: {
//   '/admin_order_detail': (_) => const AdminOrderDetailPage(),
// }
//
// ✅ 呼叫方式：
// Navigator.pushNamed(context, '/admin_order_detail', arguments: {'orderId': orderId});
// 或 arguments: orderId (String)
//
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ FIX: withOpacity deprecated → withValues(alpha: 0~1)
Color _withOpacity(Color c, double opacity01) {
  final o = opacity01.clamp(0.0, 1.0).toDouble();
  return c.withValues(alpha: o);
}

class AdminOrderDetailPage extends StatefulWidget {
  const AdminOrderDetailPage({super.key});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  final _db = FirebaseFirestore.instance;

  String? _orderId;
  String? _argError;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_orderId != null || _argError != null) {
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments;

    String? oid;
    if (args is String) {
      oid = args.trim();
    }
    if (args is Map) {
      final v = args['orderId'] ?? args['id'];
      if (v != null) {
        oid = v.toString().trim();
      }
    }

    if (oid == null || oid.isEmpty) {
      setState(() {
        _argError =
            '缺少 orderId 參數，請用 Navigator.pushNamed(..., arguments: {\'orderId\': orderId})';
      });
      return;
    }

    setState(() => _orderId = oid);
  }

  DocumentReference<Map<String, dynamic>> get _orderRef =>
      _db.collection('orders').doc(_orderId!);

  // ===========================================================
  // UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_argError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('訂單詳情')),
        body: _ErrorView(
          title: '開啟失敗',
          message: _argError!,
          hint: '請確認你有傳入 orderId。',
          onRetry: () => Navigator.pop(context),
          retryText: '返回',
        ),
      );
    }

    if (_orderId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '訂單詳情：$_orderId',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _orderRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorView(
              title: '讀取訂單失敗',
              message: snap.error.toString(),
              hint: '常見原因：orders 權限不足、文件不存在、欄位型別錯誤。',
              onRetry: () => setState(() {}),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snap.data!;
          if (!doc.exists) {
            return _ErrorView(
              title: '訂單不存在',
              message: '找不到此訂單文件：$_orderId',
              hint: '請確認 orders/{orderId} 是否存在。',
              onRetry: () => Navigator.pop(context),
              retryText: '返回',
            );
          }

          final d = doc.data() ?? <String, dynamic>{};
          final vm = _OrderVM.fromMap(orderId: doc.id, data: d);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _summaryCard(cs, vm),
              const SizedBox(height: 10),
              _statusAndActionsCard(cs, vm),
              const SizedBox(height: 10),
              _itemsCard(cs, vm),
              const SizedBox(height: 10),
              _paymentCard(cs, vm),
              const SizedBox(height: 10),
              _shippingCard(cs, vm),
              const SizedBox(height: 10),
              _timelineCard(cs, vm),
              const SizedBox(height: 18),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================
  // Sections
  // ===========================================================
  Widget _summaryCard(ColorScheme cs, _OrderVM vm) {
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    final fmtDT = DateFormat('yyyy/MM/dd HH:mm');

    final createdText = vm.createdAt == null
        ? '—'
        : fmtDT.format(vm.createdAt!);
    final updatedText = vm.updatedAt == null
        ? '—'
        : fmtDT.format(vm.updatedAt!);

    final badgeBg = _statusColorBg(cs, vm.status);
    final badgeFg = _statusColorFg(cs, vm.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '訂單 ${vm.orderId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _withOpacity(badgeFg, 0.25)),
                  ),
                  child: Text(
                    vm.statusLabel,
                    style: TextStyle(
                      color: badgeFg,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _pill('會員', vm.userId.isEmpty ? '—' : vm.userId),
                _pill('建立', createdText),
                _pill('更新', updatedText),
                _pill('商品數', '${vm.items.length}'),
                _pill('總額', fmtMoney.format(vm.finalAmount)),
              ],
            ),
            if (vm.userId.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    try {
                      Navigator.pushNamed(
                        context,
                        '/admin_member_detail',
                        arguments: {'uid': vm.userId},
                      );
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('尚未註冊路由：/admin_member_detail'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('查看會員'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusAndActionsCard(ColorScheme cs, _OrderVM vm) {
    final statusOptions = _statusOptions();

    final dropdown = DropdownButtonFormField<String>(
      // ✅ initialValue + key：避免 deprecated value；也避免資料更新後不刷新
      key: ValueKey('status_${vm.orderId}_${vm.status}'),
      initialValue: statusOptions.contains(vm.status)
          ? vm.status
          : statusOptions.first,
      items: statusOptions
          .map((s) => DropdownMenuItem(value: s, child: Text(_statusLabel(s))))
          .toList(),
      onChanged: (v) async {
        if (v == null) {
          return;
        }
        if (v == vm.status) {
          return;
        }
        await _updateStatus(vm, v);
      },
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '變更狀態',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '管理操作',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            dropdown,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editAdminNote(vm),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('編輯備註'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openRawData(vm),
                    icon: const Icon(Icons.data_object),
                    label: const Text('查看欄位'),
                  ),
                ),
              ],
            ),
            if (vm.adminNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _withOpacity(cs.primaryContainer, 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _withOpacity(cs.primary, 0.20)),
                ),
                child: Text(
                  '備註：${vm.adminNote}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemsCard(ColorScheme cs, _OrderVM vm) {
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    if (vm.items.isEmpty) {
      return const _EmptyCard(title: '商品清單', message: '此訂單沒有 items（或欄位結構不同）。');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '商品清單',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            for (final it in vm.items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      '${it.qty}',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.title.isEmpty ? '(未命名商品)' : it.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (it.sku.isNotEmpty) 'SKU: ${it.sku}',
                            '單價: ${fmtMoney.format(it.unitPrice)}',
                            '小計: ${fmtMoney.format(it.unitPrice * it.qty)}',
                          ].join('  •  '),
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '合計：${fmtMoney.format(vm.finalAmount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard(ColorScheme cs, _OrderVM vm) {
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '金流資訊',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _kv('付款方式', vm.paymentMethod),
            _kv('付款狀態', vm.paymentStatus),
            _kv('交易編號', vm.paymentTxId),
            _kv('商品金額', fmtMoney.format(vm.subtotal)),
            _kv('運費', fmtMoney.format(vm.shippingFee)),
            _kv('折抵/優惠', fmtMoney.format(vm.discountAmount)),
            _kv('實付金額', fmtMoney.format(vm.finalAmount), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _shippingCard(ColorScheme cs, _OrderVM vm) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '物流資訊',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _kv('收件人', vm.receiverName),
            _kv('電話', vm.receiverPhone),
            _kv('地址', vm.shippingAddress),
            _kv('物流商', vm.shippingCarrier),
            _kv('追蹤碼', vm.trackingNumber),
          ],
        ),
      ),
    );
  }

  Widget _timelineCard(ColorScheme cs, _OrderVM vm) {
    final fmtDT = DateFormat('yyyy/MM/dd HH:mm');

    String t(DateTime? d) {
      if (d == null) {
        return '—';
      }
      return fmtDT.format(d);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '時間軸',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _kv('建立時間', t(vm.createdAt)),
            _kv('更新時間', t(vm.updatedAt)),
            _kv('付款時間', t(vm.paidAt)),
            _kv('出貨時間', t(vm.shippedAt)),
            _kv('完成時間', t(vm.completedAt)),
            _kv('取消時間', t(vm.cancelledAt)),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // Actions (no return in finally!)
  // ===========================================================
  Future<void> _updateStatus(_OrderVM vm, String newStatus) async {
    final ok = await _confirm(
      title: '變更狀態',
      message:
          '確定要將訂單狀態由「${vm.statusLabel}」改為「${_statusLabel(newStatus)}」？\n\n訂單：${vm.orderId}',
      confirmText: '套用',
    );

    if (ok != true) {
      return;
    }

    setState(() => _busy = true);
    try {
      await _orderRef.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新狀態 → ${_statusLabel(newStatus)}')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    } finally {
      // ✅ 不要在 finally return（修掉 control_flow_in_finally）
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _editAdminNote(_OrderVM vm) async {
    final text = await _askText(
      title: '編輯管理員備註',
      hint: '輸入備註內容（可留空）',
      initial: vm.adminNote,
      confirmText: '儲存',
    );
    if (text == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await _orderRef.update({
        'adminNote': text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('備註已更新')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _openRawData(_OrderVM vm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '欄位提示',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          '此頁會從 orders/{orderId} 讀取以下欄位（可不存在）：\n\n'
          '- userId\n'
          '- status\n'
          '- createdAt / updatedAt / paidAt / shippedAt / completedAt / cancelledAt\n'
          '- items: List<Map>（title/name, sku, qty, price/amount）\n'
          '- finalAmount / total / amount\n'
          '- subtotal\n'
          '- shippingFee\n'
          '- discountAmount\n'
          '- payment: { method, status, txId }\n'
          '- shipping: { receiverName, receiverPhone, address, carrier, trackingNumber }\n'
          '- adminNote\n\n'
          '若你的欄位命名不同，貼你的 orders 文件樣本，我會直接改成你的結構。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // Helpers
  // ===========================================================
  List<String> _statusOptions() {
    // 你可以依你的專案調整
    return <String>[
      'pending',
      'paid',
      'processing',
      'shipped',
      'completed',
      'cancelled',
      'refunded',
    ];
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return '待付款';
      case 'paid':
        return '已付款';
      case 'processing':
        return '處理中';
      case 'shipped':
        return '已出貨';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      case 'refunded':
        return '已退款';
      default:
        return s;
    }
  }

  Color _statusColorFg(ColorScheme cs, String s) {
    switch (s) {
      case 'paid':
      case 'completed':
        return cs.primary;
      case 'shipped':
        return Colors.teal.shade700;
      case 'cancelled':
      case 'refunded':
        return cs.error;
      case 'processing':
        return Colors.deepPurple;
      default:
        return cs.onSurface;
    }
  }

  Color _statusColorBg(ColorScheme cs, String s) {
    final fg = _statusColorFg(cs, s);
    return _withOpacity(fg, 0.10);
  }

  Widget _pill(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
      ),
      child: Text(
        '$k：$v',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              v.isEmpty ? '—' : v,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool isDanger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDanger ? cs.error : null,
              foregroundColor: isDanger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<String?> _askText({
    required String title,
    required String hint,
    required String initial,
    required String confirmText,
    bool isDanger = false,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final c = TextEditingController(text: initial);

    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: c,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDanger ? cs.error : null,
              foregroundColor: isDanger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, c.text),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    c.dispose();
    return res;
  }
}

// ============================================================================
// ViewModel
// ============================================================================
class _OrderVM {
  final String orderId;

  final String userId;
  final String status;
  final String statusLabel;

  final num subtotal;
  final num shippingFee;
  final num discountAmount;
  final num finalAmount;

  final String paymentMethod;
  final String paymentStatus;
  final String paymentTxId;

  final String receiverName;
  final String receiverPhone;
  final String shippingAddress;
  final String shippingCarrier;
  final String trackingNumber;

  final String adminNote;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  final List<_OrderItemVM> items;

  _OrderVM({
    required this.orderId,
    required this.userId,
    required this.status,
    required this.statusLabel,
    required this.subtotal,
    required this.shippingFee,
    required this.discountAmount,
    required this.finalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.paymentTxId,
    required this.receiverName,
    required this.receiverPhone,
    required this.shippingAddress,
    required this.shippingCarrier,
    required this.trackingNumber,
    required this.adminNote,
    required this.createdAt,
    required this.updatedAt,
    required this.paidAt,
    required this.shippedAt,
    required this.completedAt,
    required this.cancelledAt,
    required this.items,
  });

  static _OrderVM fromMap({
    required String orderId,
    required Map<String, dynamic> data,
  }) {
    String s(dynamic v) => (v ?? '').toString().trim();
    num n(dynamic v) {
      if (v is num) {
        return v;
      }
      final p = num.tryParse((v ?? '').toString());
      return p ?? 0;
    }

    DateTime? dt(dynamic v) {
      if (v == null) {
        return null;
      }
      if (v is Timestamp) {
        return v.toDate();
      }
      if (v is DateTime) {
        return v;
      }
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v);
      }
      return null;
    }

    final userId = s(data['userId'] ?? data['uid']);
    final status = s(data['status']).isEmpty ? 'pending' : s(data['status']);

    String statusLabel(String st) {
      switch (st) {
        case 'pending':
          return '待付款';
        case 'paid':
          return '已付款';
        case 'processing':
          return '處理中';
        case 'shipped':
          return '已出貨';
        case 'completed':
          return '已完成';
        case 'cancelled':
          return '已取消';
        case 'refunded':
          return '已退款';
        default:
          return st;
      }
    }

    // amounts
    final subtotal = n(data['subtotal']);
    final shippingFee = n(data['shippingFee']);
    final discountAmount = n(data['discountAmount'] ?? data['discount'] ?? 0);
    final finalAmount = n(
      data['finalAmount'] ?? data['total'] ?? data['amount'],
    );

    // payment
    final payment = (data['payment'] is Map) ? (data['payment'] as Map) : null;
    final paymentMethod = s(
      payment?['method'] ?? data['paymentMethod'] ?? data['method'],
    );
    final paymentStatus = s(
      payment?['status'] ?? data['paymentStatus'] ?? data['payStatus'],
    );
    final paymentTxId = s(
      payment?['txId'] ?? data['txId'] ?? data['paymentTxId'],
    );

    // shipping
    final shipping = (data['shipping'] is Map)
        ? (data['shipping'] as Map)
        : null;
    final receiverName = s(
      shipping?['receiverName'] ?? data['receiverName'] ?? data['name'],
    );
    final receiverPhone = s(
      shipping?['receiverPhone'] ?? data['receiverPhone'] ?? data['phone'],
    );
    final shippingAddress = s(
      shipping?['address'] ?? data['shippingAddress'] ?? data['address'],
    );
    final shippingCarrier = s(
      shipping?['carrier'] ?? data['shippingCarrier'] ?? data['carrier'],
    );
    final trackingNumber = s(
      shipping?['trackingNumber'] ?? data['trackingNumber'] ?? data['tracking'],
    );

    // items
    final rawItems = data['items'];
    final items = <_OrderItemVM>[];
    if (rawItems is List) {
      for (final x in rawItems) {
        if (x is Map) {
          items.add(_OrderItemVM.fromMap(Map<String, dynamic>.from(x)));
        }
      }
    }

    return _OrderVM(
      orderId: orderId,
      userId: userId,
      status: status,
      statusLabel: statusLabel(status),
      subtotal: subtotal,
      shippingFee: shippingFee,
      discountAmount: discountAmount,
      finalAmount: finalAmount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      paymentTxId: paymentTxId,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      shippingAddress: shippingAddress,
      shippingCarrier: shippingCarrier,
      trackingNumber: trackingNumber,
      adminNote: s(data['adminNote']),
      createdAt: dt(data['createdAt']),
      updatedAt: dt(data['updatedAt']),
      paidAt: dt(data['paidAt']),
      shippedAt: dt(data['shippedAt']),
      completedAt: dt(data['completedAt']),
      cancelledAt: dt(data['cancelledAt']),
      items: items,
    );
  }
}

class _OrderItemVM {
  final String title;
  final String sku;
  final int qty;
  final num unitPrice;

  _OrderItemVM({
    required this.title,
    required this.sku,
    required this.qty,
    required this.unitPrice,
  });

  static _OrderItemVM fromMap(Map<String, dynamic> m) {
    String s(dynamic v) => (v ?? '').toString().trim();
    num n(dynamic v) {
      if (v is num) {
        return v;
      }
      final p = num.tryParse((v ?? '').toString());
      return p ?? 0;
    }

    int i(dynamic v) {
      if (v is int) {
        return v;
      }
      final p = int.tryParse((v ?? '').toString());
      return p ?? 0;
    }

    final title = s(m['title'] ?? m['name'] ?? m['productName']);
    final sku = s(m['sku'] ?? m['productId'] ?? m['id']);
    final qty = i(m['qty'] ?? m['quantity'] ?? 1);
    final price = n(m['price'] ?? m['unitPrice'] ?? m['amount'] ?? 0);

    return _OrderItemVM(
      title: title,
      sku: sku,
      qty: qty <= 0 ? 1 : qty,
      unitPrice: price,
    );
  }
}

// ============================================================================
// Shared small views
// ============================================================================
class _EmptyCard extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;
  final VoidCallback onRetry;
  final String retryText;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
    this.retryText = '重試',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(retryText),
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

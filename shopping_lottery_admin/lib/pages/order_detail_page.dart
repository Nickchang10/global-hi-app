// lib/pages/order_detail_page.dart
//
// ✅ OrderDetailPage（最終完整版｜Firestore 即時讀取 + 可更新訂單狀態｜完全移除 RadioGroup.of / maybeOf）
// ------------------------------------------------------------
// 你目前 Flutter SDK 沒有 RadioGroup.of / maybeOf（不同 channel/版本 API 差異）
// 所以這版：
// - ✅ 不用 RadioGroup / RadioGroup.of / maybeOf
// - ✅ 也不使用 Radio.groupValue（deprecated）
// - ✅ 改用「單選按鈕列表」：每個選項自己判斷 selected + onTap 更新
//   （在 UI/UX 上等同 radio group，而且可跨版本穩定編譯）
//
// 路由：/order_detail
// arguments：String(orderId) 或 {orderId: ...}
// Firestore：orders/{orderId}
//
// 依賴：cloud_firestore, flutter/material

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final _db = FirebaseFirestore.instance;

  bool _saving = false;
  String? _error;

  String _orderIdFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) return args.trim();
    if (args is Map) {
      final v = args['orderId'] ?? args['id'];
      if (v != null) return v.toString().trim();
    }
    return '';
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  Map<String, dynamic> _asMap(dynamic v) => (v is Map<String, dynamic>)
      ? v
      : (v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{});

  List<Map<String, dynamic>> _asListMap(dynamic v) {
    if (v is List) return v.map((e) => _asMap(e)).toList();
    return const [];
  }

  String _fmtTs(dynamic v) {
    if (v is Timestamp) {
      final dt = v.toDate().toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _db.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _saving = false);
      _snack('已更新狀態：$status');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '更新失敗：$e';
      });
    }
  }

  // 你可以依你的系統擴充更多狀態
  static const _statusOptions = <String, String>{
    'pending': '待處理',
    'paid': '已付款',
    'shipped': '已出貨',
    'completed': '已完成',
    'cancelled': '已取消',
  };

  @override
  Widget build(BuildContext context) {
    final orderId = _orderIdFromArgs(context);
    if (orderId.isEmpty) {
      return const Scaffold(body: Center(child: Text('缺少 orderId')));
    }

    final ref = _db.collection('orders').doc(orderId);

    return Scaffold(
      appBar: AppBar(
        title: Text('訂單詳情：$orderId'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 14),
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
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data() ?? <String, dynamic>{};
          final cs = Theme.of(context).colorScheme;

          final status = _s(data['status']).isEmpty
              ? 'pending'
              : _s(data['status']).toLowerCase();

          final buyerUid = _s(data['buyerUid']);
          final buyerName = _s(data['buyerName']);
          final buyerPhone = _s(data['buyerPhone']);

          final total = (data['total'] is num)
              ? (data['total'] as num).toDouble()
              : double.tryParse(_s(data['total'])) ?? 0.0;

          final createdAt = _fmtTs(data['createdAt']);
          final updatedAt = _fmtTs(data['updatedAt']);

          final payment = _asMap(data['payment']);
          final shipping = _asMap(data['shipping']);
          final items = _asListMap(data['items']);

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: cs.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

              _SectionCard(
                title: '基本資訊',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KV(
                      '訂單狀態',
                      '${_statusOptions[status] ?? status}  ($status)',
                    ),
                    _KV('建立時間', createdAt),
                    _KV('更新時間', updatedAt),
                    _KV('總金額', 'NT\$ ${total.toStringAsFixed(0)}'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ✅ 穩定版單選列表：不依賴 RadioGroup / groupValue API
              _SectionCard(
                title: '更新訂單狀態',
                trailing: _saving ? const Text('儲存中...') : null,
                child: AbsorbPointer(
                  absorbing: _saving,
                  child: Column(
                    children: _statusOptions.entries.map((e) {
                      final value = e.key;
                      final label = e.value;
                      final selected = value == status;

                      return InkWell(
                        onTap: () {
                          if (selected) return;
                          _updateOrderStatus(orderId: orderId, status: value);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selected ? cs.primary : cs.outline,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_circle,
                                  color: cs.primary,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _SectionCard(
                title: '買家資訊',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KV('UID', buyerUid.isEmpty ? '-' : buyerUid),
                    _KV('姓名', buyerName.isEmpty ? '-' : buyerName),
                    _KV('電話', buyerPhone.isEmpty ? '-' : buyerPhone),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _SectionCard(
                title: '付款資訊',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KV(
                      'provider',
                      _s(payment['provider']).isEmpty
                          ? '-'
                          : _s(payment['provider']),
                    ),
                    _KV(
                      'method',
                      _s(payment['method']).isEmpty
                          ? '-'
                          : _s(payment['method']),
                    ),
                    _KV(
                      'status',
                      _s(payment['status']).isEmpty
                          ? '-'
                          : _s(payment['status']),
                    ),
                    _KV(
                      'transactionId',
                      _s(payment['transactionId']).isEmpty
                          ? '-'
                          : _s(payment['transactionId']),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _SectionCard(
                title: '收件 / 配送資訊',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KV(
                      '收件人',
                      _s(shipping['name']).isEmpty ? '-' : _s(shipping['name']),
                    ),
                    _KV(
                      '電話',
                      _s(shipping['phone']).isEmpty
                          ? '-'
                          : _s(shipping['phone']),
                    ),
                    _KV(
                      '地址',
                      _s(shipping['address']).isEmpty
                          ? '-'
                          : _s(shipping['address']),
                    ),
                    _KV(
                      '備註',
                      _s(shipping['note']).isEmpty ? '-' : _s(shipping['note']),
                    ),
                    _KV(
                      '配送狀態',
                      _s(shipping['status']).isEmpty
                          ? '-'
                          : _s(shipping['status']),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _SectionCard(
                title: '商品明細',
                child: items.isEmpty
                    ? const Text('（無 items）')
                    : Column(
                        children: items.map((it) {
                          final title = _s(it['title']).isEmpty
                              ? '-'
                              : _s(it['title']);
                          final qty = (it['qty'] is num)
                              ? (it['qty'] as num).toInt()
                              : int.tryParse(_s(it['qty'])) ?? 0;
                          final price = (it['price'] is num)
                              ? (it['price'] as num).toDouble()
                              : double.tryParse(_s(it['price'])) ?? 0.0;
                          final sub = qty * price;

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.black12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '數量：$qty  單價：${price.toStringAsFixed(0)}',
                                      ),
                                    ],
                                  ),
                                ),
                                Text('小計：${sub.toStringAsFixed(0)}'),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              k,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

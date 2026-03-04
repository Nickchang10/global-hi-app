import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key, this.args});
  final Object? args;

  String _s(dynamic v) => (v ?? '').toString().trim();

  num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return null;
  }

  Map<String, dynamic> _argsMap(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final merged = (args ?? routeArgs);
    if (merged is Map) return Map<String, dynamic>.from(merged);
    return <String, dynamic>{};
  }

  String _fmtMoney(num v) {
    final s = v.round().toString();
    final withComma = s.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return 'NT\$ $withComma';
  }

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
  Widget build(BuildContext context) {
    final m = _argsMap(context);
    final orderId = _s(m['orderId']);
    final amountFromArgs = _num(m['amount']);

    final orderRef = orderId.isEmpty
        ? null
        : FirebaseFirestore.instance.collection('orders').doc(orderId);

    return Scaffold(
      appBar: AppBar(title: const Text('付款')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ 付款資訊：優先從 Firestore 讀 total（最準）
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '付款資訊',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  _kv('訂單編號', orderId.isEmpty ? '（未提供）' : orderId),
                  const SizedBox(height: 6),

                  if (orderRef == null)
                    _kv(
                      '應付金額',
                      amountFromArgs == null ? '—' : _fmtMoney(amountFromArgs as int),
                    )
                  else
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: orderRef.snapshots(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return _kv(
                            '應付金額',
                            amountFromArgs == null
                                ? '—'
                                : '${_fmtMoney(amountFromArgs as int)}（讀取訂單失敗）',
                          );
                        }
                        if (!snap.hasData || !snap.data!.exists) {
                          return _kv(
                            '應付金額',
                            amountFromArgs == null
                                ? '讀取中…'
                                : _fmtMoney(amountFromArgs as int),
                          );
                        }
                        final data = snap.data!.data() ?? <String, dynamic>{};
                        final pricing = _map(data['pricing']);
                        final total = _toInt(
                          pricing['total'] ?? data['total'] ?? 0,
                        );

                        return _kv('應付金額', total > 0 ? _fmtMoney(total) : '—');
                      },
                    ),

                  const SizedBox(height: 12),
                  Text(
                    '目前為「前端流程先接好」版本：\n'
                    '1) 你下單後會進到付款頁\n'
                    '2) 付款是否成功，最終以後端 webhook 更新 orders/{orderId}.status 為準\n'
                    '3) 你可以先進入「付款狀態」頁等待狀態變更',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  if (orderId.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: orderId));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已複製訂單編號')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('複製訂單號'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ✅ Debug：模擬 paid（正式上線要移除）
          if (kDebugMode && orderId.isNotEmpty) ...[
            Card(
              color: Colors.amber.withOpacity(0.12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug 工具（測試用）',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '按下可嘗試把訂單狀態改成 paid。\n'
                      '若 Firestore rules 不允許，會顯示失敗（這是正常的，正式應由後端 webhook 更新）。',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(orderId)
                              .set({
                                'status': 'paid',
                                'paidAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已嘗試標記 paid')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('標記失敗（多半是 rules 擋住，屬正常）：$e'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.bug_report_outlined),
                      label: const Text('模擬付款成功（paid）'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: orderId.isEmpty
                      ? null
                      : () {
                          Navigator.pushNamed(
                            context,
                            '/order_detail',
                            arguments: {'orderId': orderId},
                          );
                        },
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('查看訂單'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: orderId.isEmpty
                      ? null
                      : () {
                          Navigator.pushReplacementNamed(
                            context,
                            '/payment_status',
                            arguments: {'orderId': orderId},
                          );
                        },
                  icon: const Icon(Icons.hourglass_bottom),
                  label: const Text('進入付款狀態'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            k,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

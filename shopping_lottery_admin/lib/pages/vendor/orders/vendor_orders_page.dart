// lib/pages/vendor/orders/vendor_orders_page.dart
//
// ✅ VendorOrdersPage（可編譯完整版｜已修正 DropdownButtonFormField value deprecated）
// ------------------------------------------------------------
// - 可選擇直接傳入 vendorId；若未傳，會透過 AdminGate 由目前登入者取得 role/vendorId
// - 只允許 vendor 進入
// - 顯示「該 vendor 的訂單列表」：orders.vendorIds arrayContains vendorId
//
// 依賴：firebase_auth, cloud_firestore, provider, services/admin_gate.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/admin_gate.dart';

class VendorOrdersPage extends StatefulWidget {
  /// ✅ 若外部已經有 vendorId，可直接傳入（避免重查角色）
  final String? vendorId;

  /// ✅ 如果你有舊路由用到 routeName，保留它避免其他地方壞掉
  static const String routeName = '/vendor/orders';

  const VendorOrdersPage({super.key, this.vendorId});

  @override
  State<VendorOrdersPage> createState() => _VendorOrdersPageState();
}

/// ✅ 有些專案可能用 VendorOrdersPageView / VendorOrdersPagePage 這類名字
/// 這裡做 alias，避免你其他地方 import 後找不到 class。
class VendorOrdersPagePage extends VendorOrdersPage {
  const VendorOrdersPagePage({super.key, super.vendorId});
}

class _VendorOrdersPageState extends State<VendorOrdersPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();

  String _q = '';
  String _status =
      'all'; // all / pending_payment / paid / shipped / completed / canceled ...

  String _s(dynamic v) => (v ?? '').toString().trim();

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString()) ?? 0;
  }

  DateTime? _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return null;
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Color _statusColor(BuildContext context, String status) {
    final s = status.toLowerCase();
    if (s.contains('pending')) return Colors.orange;
    if (s.contains('paid')) return Colors.blue;
    if (s.contains('ship')) return Colors.purple;
    if (s.contains('complete')) return Colors.green;
    if (s.contains('cancel')) return Colors.grey;
    return Theme.of(context).colorScheme.primary;
  }

  Query<Map<String, dynamic>> _buildQuery(String vendorId) {
    Query<Map<String, dynamic>> q = _db
        .collection('orders')
        .where('vendorIds', arrayContains: vendorId)
        .orderBy('createdAt', descending: true)
        .limit(200);

    if (_status != 'all') {
      q = q.where('status', isEqualTo: _status);
    }
    return q;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gate = context.read<AdminGate>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        // ✅ 若已傳入 vendorId，直接使用；否則透過 AdminGate 取 role/vendorId
        final passedVendorId = _s(widget.vendorId);

        if (passedVendorId.isNotEmpty) {
          return _buildBodyWithVendor(context, vendorId: passedVendorId);
        }

        return FutureBuilder<RoleInfo>(
          future: gate.ensureAndGetRole(user, forceRefresh: false),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (roleSnap.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('訂單')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '讀取角色失敗：${roleSnap.error}',
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                ),
              );
            }

            final info = roleSnap.data;
            final role = _s(info?.role).toLowerCase();
            final vendorId = _s(info?.vendorId);

            if (role != 'vendor') {
              return const Scaffold(body: Center(child: Text('需要 Vendor 權限')));
            }
            if (vendorId.isEmpty) {
              return const Scaffold(
                body: Center(child: Text('此帳號尚未綁定 vendorId，請到主後台綁定後再試。')),
              );
            }

            return _buildBodyWithVendor(context, vendorId: vendorId);
          },
        );
      },
    );
  }

  Widget _buildBodyWithVendor(
    BuildContext context, {
    required String vendorId,
  }) {
    final cs = Theme.of(context).colorScheme;
    final query = _buildQuery(vendorId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的訂單（Vendor）'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _q = v.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜尋訂單編號 / 客戶名稱 / 電話（若有）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    // ✅ Flutter 新版：value 已 deprecated，改 initialValue
                    // ✅ initialValue 只在第一次 build 生效，因此加 key 讓狀態變更時重建套用
                    key: ValueKey(_status),
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: '狀態',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('全部')),
                      DropdownMenuItem(
                        value: 'pending_payment',
                        child: Text('待付款'),
                      ),
                      DropdownMenuItem(value: 'paid', child: Text('已付款')),
                      DropdownMenuItem(value: 'shipped', child: Text('已出貨')),
                      DropdownMenuItem(value: 'completed', child: Text('已完成')),
                      DropdownMenuItem(value: 'canceled', child: Text('已取消')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'all'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '載入訂單失敗：${snap.error}',
                        style: TextStyle(color: cs.error),
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;

                final filtered = docs.where((d) {
                  if (_q.isEmpty) return true;
                  final m = d.data();
                  final id = d.id.toLowerCase();
                  final name = _s(m['customerName']).toLowerCase();
                  final phone = _s(m['customerPhone']).toLowerCase();
                  return id.contains(_q) ||
                      name.contains(_q) ||
                      phone.contains(_q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('沒有訂單'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = filtered[i];
                    final m = d.data();

                    final statusRaw = _s(m['status']);
                    final status = statusRaw.isEmpty ? '-' : statusRaw;

                    final total = _toNum(
                      m['total'] ?? m['amount'] ?? m['grandTotal'] ?? 0,
                    );
                    final createdAt = _toDate(m['createdAt']);
                    final customerRaw = _s(m['customerName']);
                    final customer = customerRaw.isEmpty ? '-' : customerRaw;

                    final chipColor = _statusColor(context, status);

                    // ✅ withOpacity deprecated：改用 withAlpha（避免 warning）
                    // 0.12 * 255 ≈ 31，0.25 * 255 ≈ 64
                    final bg = chipColor.withAlpha(31);
                    final bd = chipColor.withAlpha(64);

                    return ListTile(
                      title: Text(
                        '訂單 ${d.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '$customer ・ $status ・ NT\$${total.toStringAsFixed(0)} ・ ${_fmtDate(createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: bd),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: chipColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      onTap: () => _showOrderDialog(context, d.id, m),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOrderDialog(
    BuildContext context,
    String id,
    Map<String, dynamic> m,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final status = _s(m['status']).isEmpty ? '-' : _s(m['status']);
    final total = _toNum(m['total'] ?? m['amount'] ?? m['grandTotal'] ?? 0);
    final createdAt = _toDate(m['createdAt']);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('訂單 $id'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('狀態', status),
              _kv('金額', 'NT\$${total.toStringAsFixed(0)}'),
              _kv('建立時間', _fmtDate(createdAt)),
              const SizedBox(height: 8),
              Text(
                '原始資料（部分）',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                _prettyPick(m),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
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

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              k,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // 只挑常用欄位，避免把整包大 JSON 噴出來
  String _prettyPick(Map<String, dynamic> m) {
    final pick = <String, dynamic>{
      'customerName': m['customerName'],
      'customerPhone': m['customerPhone'],
      'status': m['status'],
      'total': m['total'] ?? m['amount'] ?? m['grandTotal'],
      'paymentMethod': m['paymentMethod'],
      'shippingMethod': m['shippingMethod'],
    };
    return pick.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }
}

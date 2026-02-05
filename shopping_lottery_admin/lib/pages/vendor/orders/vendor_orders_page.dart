// lib/pages/vendor/orders/vendor_orders_page.dart
//
// ✅ VendorOrdersPage（最終完整版｜Vendor 訂單清單｜只看自己的訂單）
// ------------------------------------------------------------
// - 只允許 vendor 角色使用
// - 只顯示 orders.vendorIds contains vendorId 的訂單
// - 搜尋：訂單編號 / Email（前端過濾）
// - 狀態篩選：all / pending_payment / paid / shipping / completed / cancelled / refunded
// - 金額顯示：僅顯示「我的小計」（該 vendor 的 items 小計）
// - 點擊進入 /vendor/orders/detail（你已做 VendorOrderDetailGate + DetailPage）
//
// 注意：where(arrayContains) + orderBy(createdAt) + where(status) 可能需要 Firestore Index
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VendorOrdersPage extends StatefulWidget {
  const VendorOrdersPage({super.key});

  @override
  State<VendorOrdersPage> createState() => _VendorOrdersPageState();
}

class _VendorOrdersPageState extends State<VendorOrdersPage> {
  final _moneyFmt = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
  final _searchCtrl = TextEditingController();

  String _statusFilter = 'all';

  final List<Map<String, String>> _statusOptions = const [
    {'key': 'all', 'label': '全部'},
    {'key': 'pending_payment', 'label': '待付款'},
    {'key': 'paid', 'label': '已付款'},
    {'key': 'shipping', 'label': '出貨中'},
    {'key': 'completed', 'label': '已完成'},
    {'key': 'cancelled', 'label': '已取消'},
    {'key': 'refunded', 'label': '已退款'},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_payment':
        return Colors.orange;
      case 'paid':
        return Colors.blue;
      case 'shipping':
        return Colors.indigo;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      case 'refunded':
        return Colors.redAccent;
      default:
        return Colors.black54;
    }
  }

  String _statusLabel(String status) {
    return _statusOptions
            .firstWhere(
              (e) => e['key'] == status,
              orElse: () => {'label': status},
            )['label'] ??
        status;
  }

  num _num(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  int _int(dynamic v, {int fallback = 1}) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  // 計算「我的小計」：只加總 items 中 vendorId == myVendorId 的項目
  num _calcMySubtotal(List items, String myVendorId) {
    num sum = 0;
    for (final it in items) {
      if (it is! Map) continue;
      final m = Map<String, dynamic>.from(it as Map);
      final vid = (m['vendorId'] ?? '').toString();
      if (vid != myVendorId) continue;
      final price = _num(m['price']);
      final qty = _int(m['qty'] ?? m['quantity'] ?? 1, fallback: 1);
      sum += price * qty;
    }
    return sum;
  }

  bool _matchKeyword(Map<String, dynamic> data, String kw) {
    if (kw.isEmpty) return true;
    final orderNo = (data['orderNo'] ?? '').toString();
    final email = (data['userEmail'] ?? '').toString();
    return orderNo.contains(kw) || email.contains(kw);
  }

  Query _buildQuery(String vendorId) {
    Query q = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorIds', arrayContains: vendorId)
        .orderBy('createdAt', descending: true);

    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }

    return q;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('未登入')));
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, uSnap) {
        if (uSnap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final u = uSnap.data?.data() ?? {};
        final role = (u['role'] ?? '').toString();
        final vendorId = (u['vendorId'] ?? '').toString();

        if (role != 'vendor' || vendorId.isEmpty) {
          return const Scaffold(body: Center(child: Text('僅 Vendor 可使用此頁')));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('訂單管理（Vendor）', style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              IconButton(
                tooltip: '重新整理',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() {}),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildFilters(),
              const Divider(height: 1),
              Expanded(child: _buildList(vendorId)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋訂單編號 / Email',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          DropdownButton<String>(
            value: _statusFilter,
            items: _statusOptions
                .map((e) => DropdownMenuItem(value: e['key'], child: Text(e['label']!)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _statusFilter = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildList(String vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery(vendorId).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('讀取訂單失敗（可能缺少 Index）'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final kw = _searchCtrl.text.trim();
        final docs = snap.data!.docs.where((d) {
          final data = (d.data() as Map?)?.cast<String, dynamic>() ?? {};
          return _matchKeyword(data, kw);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('沒有符合條件的訂單'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => _buildRow(docs[i] as QueryDocumentSnapshot, vendorId),
        );
      },
    );
  }

  Widget _buildRow(QueryDocumentSnapshot doc, String vendorId) {
    final data = (doc.data() as Map?)?.cast<String, dynamic>() ?? {};

    final orderNo = (data['orderNo'] ?? doc.id).toString();
    final email = (data['userEmail'] ?? '-').toString();
    final status = (data['status'] ?? '').toString();
    final createdAt = data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null;

    final items = (data['items'] is List) ? (data['items'] as List) : const [];
    final mySubtotal = _calcMySubtotal(items, vendorId);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _statusColor(status).withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _statusLabel(status),
          style: TextStyle(
            color: _statusColor(status),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(orderNo, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(email),
          if (createdAt != null)
            Text(
              DateFormat('yyyy/MM/dd HH:mm').format(createdAt),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _moneyFmt.format(mySubtotal),
            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent),
          ),
          Text('我的小計', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
      onTap: () {
        Navigator.of(context).pushNamed(
          '/vendor/orders/detail',
          arguments: doc.id,
        );
      },
    );
  }
}

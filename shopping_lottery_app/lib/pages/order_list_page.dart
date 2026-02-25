import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ OrderListPage（最終完整版｜可直接使用｜可編譯）
/// ------------------------------------------------------------
/// - 讀取：users/{uid}/orders（建議由下單時同步寫入）
/// - 支援：狀態篩選（DropdownButtonFormField）
///
/// ✅ 已修正：DropdownButtonFormField.value deprecated → 改用 initialValue
class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  static const routeName = '/orders';

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  String _statusFilter = 'all'; // all/pending/paid/shipped/delivered/cancelled

  User? get _user => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> _userOrders(String uid) =>
      _fs.collection('users').doc(uid).collection('orders');

  Query<Map<String, dynamic>> _query(String uid) {
    Query<Map<String, dynamic>> q = _userOrders(
      uid,
    ).orderBy('createdAt', descending: true).limit(100);

    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }
    return q;
  }

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '我的訂單',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: u == null ? _needLogin(context) : _body(u.uid),
    );
  }

  Widget _needLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能查看訂單',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/login'),
                    icon: const Icon(Icons.login),
                    label: const Text('前往登入'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(String uid) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _filterCard(),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _query(uid).snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }
            if (snap.hasError) {
              return _empty('讀取失敗：${snap.error}');
            }

            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return _empty('目前沒有訂單');

            return Column(
              children: docs.map((d) => _orderCard(d.id, d.data())).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _filterCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('篩選', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),

            /// ✅ 重點：不要再用 value:，改用 initialValue:
            DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              decoration: const InputDecoration(
                labelText: '訂單狀態',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('全部')),
                DropdownMenuItem(value: 'pending', child: Text('待付款')),
                DropdownMenuItem(value: 'paid', child: Text('已付款')),
                DropdownMenuItem(value: 'shipped', child: Text('已出貨')),
                DropdownMenuItem(value: 'delivered', child: Text('已送達')),
                DropdownMenuItem(value: 'cancelled', child: Text('已取消')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _statusFilter = v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(String docId, Map<String, dynamic> data) {
    final id = _s(data['id'], docId);
    final status = _s(data['status'], 'pending');
    final amount = _asInt(data['amount'], fallback: 0);
    final currency = _s(data['currency'], 'TWD');
    final note = _s(data['note'], '');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          id,
          style: const TextStyle(fontWeight: FontWeight.w900),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '狀態：${_statusLabel(status)}  •  金額：$amount $currency'
          '${note.isEmpty ? '' : '\n備註：$note'}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // 你如果有訂單詳情頁，就接這裡
          Navigator.pushNamed(
            context,
            '/order_detail',
            arguments: {'orderId': id},
          );
        },
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return '待付款';
      case 'paid':
        return '已付款';
      case 'shipped':
        return '已出貨';
      case 'delivered':
        return '已送達';
      case 'cancelled':
        return '已取消';
      default:
        return s;
    }
  }

  Widget _empty(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.receipt_long, size: 56, color: Colors.grey),
            const SizedBox(height: 10),
            Text(msg, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

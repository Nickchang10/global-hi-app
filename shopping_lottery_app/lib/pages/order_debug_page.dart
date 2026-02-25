import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ OrderDebugPage（最終完整版｜可直接使用｜可編譯）
/// ------------------------------------------------------------
/// - 用途：開發/測試用「訂單 Debug」頁
/// - 功能：
///   - 建立示範訂單（寫入 users/{uid}/orders 與 orders）
///   - 清空示範訂單
///   - 修改訂單狀態（pending/paid/shipped/delivered/cancelled）
///
/// ✅ 已修正：DropdownButtonFormField.value deprecated → 改用 initialValue
/// ------------------------------------------------------------
/// Firestore（建議）
/// - orders/{orderId}
/// - users/{uid}/orders/{orderId}（可選：給前台快速查）
class OrderDebugPage extends StatefulWidget {
  const OrderDebugPage({super.key});

  static const routeName = '/order_debug';

  @override
  State<OrderDebugPage> createState() => _OrderDebugPageState();
}

class _OrderDebugPageState extends State<OrderDebugPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;
  final _rand = Random();

  bool _busy = false;
  String _log = '尚未操作';

  final _amountCtrl = TextEditingController(text: '1990');
  final _noteCtrl = TextEditingController(text: 'Debug 訂單');

  String _status = 'pending';

  User? get _user => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _fs.collection('orders');

  CollectionReference<Map<String, dynamic>> _userOrders(String uid) =>
      _fs.collection('users').doc(uid).collection('orders');

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _appendLog(String msg) {
    final now = DateTime.now().toIso8601String();
    setState(() => _log = '[$now] $msg\n$_log');
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) _appendLog('❌ 失敗：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _asInt(String s, {int fallback = 0}) {
    final v = int.tryParse(s.trim());
    return v ?? fallback;
  }

  Future<void> _seedDemoOrder() async {
    final u = _user;
    if (u == null) {
      _appendLog('⚠️ 尚未登入，無法建立訂單');
      return;
    }

    final uid = u.uid;
    final amount = _asInt(_amountCtrl.text, fallback: 1990);
    final note = _noteCtrl.text.trim();

    final orderId =
        'dbg_${uid}_${DateTime.now().millisecondsSinceEpoch}_${_rand.nextInt(9999)}';

    final data = <String, dynamic>{
      'id': orderId,
      'userId': uid,
      'amount': amount,
      'currency': 'TWD',
      'status': _status, // pending/paid/shipped/delivered/cancelled
      'note': note,
      'items': [
        {'sku': 'ED1000', 'name': 'ED1000 手錶（示範）', 'qty': 1, 'price': amount},
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDebug': true,
    };

    final batch = _fs.batch();
    batch.set(_orders.doc(orderId), data, SetOptions(merge: true));
    batch.set(_userOrders(uid).doc(orderId), data, SetOptions(merge: true));
    await batch.commit();

    _appendLog('✅ 已建立示範訂單：$orderId（status=$_status, amount=$amount）');
  }

  Future<void> _clearDemoOrders() async {
    final u = _user;
    if (u == null) {
      _appendLog('⚠️ 尚未登入，無法清空');
      return;
    }

    final uid = u.uid;

    // 刪 orders 中 isDebug==true & userId==uid 的資料
    final snap = await _orders
        .where('isDebug', isEqualTo: true)
        .where('userId', isEqualTo: uid)
        .limit(300)
        .get();

    // 刪 users/{uid}/orders 中 isDebug==true
    final snapUser = await _userOrders(
      uid,
    ).where('isDebug', isEqualTo: true).limit(300).get();

    final batch = _fs.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    for (final d in snapUser.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();

    _appendLog(
      '🧹 已清空示範訂單：orders=${snap.docs.length}、userOrders=${snapUser.docs.length}',
    );
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    final u = _user;
    if (u == null) return;

    final uid = u.uid;

    final patch = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = _fs.batch();
    batch.update(_orders.doc(orderId), patch);
    batch.update(_userOrders(uid).doc(orderId), patch);
    await batch.commit();

    _appendLog('✅ 已更新訂單狀態：$orderId -> $status');
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('訂單 Debug'),
        actions: [
          IconButton(
            tooltip: '清空示範訂單',
            onPressed: _busy || u == null ? null : () => _run(_clearDemoOrders),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: u == null
          ? _needLogin(context)
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '建立示範訂單',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '金額（TWD）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                          labelText: '備註',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),

                      /// ✅ 這裡是你遇到的 lint：不要再用 value:
                      /// DropdownButtonFormField.value deprecated → 改 initialValue:
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: '初始狀態',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('pending（待付款）'),
                          ),
                          DropdownMenuItem(
                            value: 'paid',
                            child: Text('paid（已付款）'),
                          ),
                          DropdownMenuItem(
                            value: 'shipped',
                            child: Text('shipped（已出貨）'),
                          ),
                          DropdownMenuItem(
                            value: 'delivered',
                            child: Text('delivered（已送達）'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('cancelled（已取消）'),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() => _status = v);
                              },
                      ),

                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : () => _run(_seedDemoOrder),
                          icon: const Icon(Icons.add),
                          label: Text(_busy ? '處理中…' : '建立示範訂單'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'UID：${u.uid}',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '我的示範訂單列表（users/{uid}/orders）',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _userOrders(u.uid)
                            .where('isDebug', isEqualTo: true)
                            .orderBy('createdAt', descending: true)
                            .limit(50)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Center(
                                child: CircularProgressIndicator.adaptive(),
                              ),
                            );
                          }
                          if (snap.hasError) {
                            return Text('讀取失敗：${snap.error}');
                          }
                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Text(
                              '目前沒有示範訂單（按上方建立）',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            );
                          }

                          return Column(
                            children: docs
                                .map((d) => _orderTile(u.uid, d))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Log',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        _log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _orderTile(String uid, QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final id = (data['id'] ?? d.id).toString();
    final status = (data['status'] ?? 'pending').toString();
    final amount = data['amount'];

    final amountStr = amount is num
        ? amount.toInt().toString()
        : amount.toString();

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
        subtitle: Text('status: $status • amount: $amountStr'),
        trailing: PopupMenuButton<String>(
          tooltip: '變更狀態',
          onSelected: (v) => _run(() => _updateOrderStatus(id, v)),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'pending', child: Text('pending（待付款）')),
            PopupMenuItem(value: 'paid', child: Text('paid（已付款）')),
            PopupMenuItem(value: 'shipped', child: Text('shipped（已出貨）')),
            PopupMenuItem(value: 'delivered', child: Text('delivered（已送達）')),
            PopupMenuItem(value: 'cancelled', child: Text('cancelled（已取消）')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: child,
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
                    '請先登入才能使用 Order Debug',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/login'),
                    child: const Text('前往登入'),
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

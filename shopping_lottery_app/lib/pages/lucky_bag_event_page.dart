import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ LuckyBagEventPage（福袋活動｜可編譯完整版｜修正 Object -> String / 可排序 / 無多餘未使用變數）
/// ------------------------------------------------------------
/// 修正重點：
/// - ✅ 所有 Firestore 欄位一律透過 _s() / _asNum() 轉型保底
/// - ✅ 避免 Object 直接塞入 Text()/String 參數
/// - ✅ docs.sort 先複製可修改 List（避免 UnsupportedError）
/// - ✅ Transaction 內 userRef 實際使用（避免 unused_local_variable）
///
/// Firestore 建議結構：
/// - lucky_bag_events/{eventId}
///   - title: String
///   - subtitle: String (optional)
///   - description: String (optional)
///   - imageUrl: String (optional)
///   - price: num (optional)          // 可當作「點數價」或「金額」
///   - stock: num (optional)
///   - isActive: bool (optional)
///   - startAt: Timestamp (optional)
///   - endAt: Timestamp (optional)
///   - createdAt: Timestamp (optional)
///
/// - lucky_bag_events/{eventId}/orders/{orderId}
///   - uid: String
///   - qty: num
///   - price: num
///   - total: num
///   - status: String  // created/paid/fulfilled/cancelled
///   - createdAt: Timestamp
///
/// - users/{uid}
///   - points: num (optional)  // 若你想用點數購買，可啟用扣點
///   - lastLuckyBagPurchaseAt: Timestamp (optional)
///   - lastLuckyBagEventId: String (optional)
/// ------------------------------------------------------------
class LuckyBagEventPage extends StatefulWidget {
  const LuckyBagEventPage({super.key});

  @override
  State<LuckyBagEventPage> createState() => _LuckyBagEventPageState();
}

class _LuckyBagEventPageState extends State<LuckyBagEventPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _busy = false;

  User? get _user => _auth.currentUser;

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  DateTime? _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _fs.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _eventsRef() =>
      _fs.collection('lucky_bag_events');

  DocumentReference<Map<String, dynamic>> _eventRef(String eventId) =>
      _eventsRef().doc(eventId);

  CollectionReference<Map<String, dynamic>> _ordersRef(String eventId) =>
      _eventRef(eventId).collection('orders');

  @override
  Widget build(BuildContext context) {
    final uid = _user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('福袋活動'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: uid == null ? _needLogin(context) : _body(uid),
    );
  }

  Widget _needLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能查看福袋活動',
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

  Widget _body(String uid) {
    // ✅ 避免索引問題：只用 where(isActive==true) + limit
    final stream = _eventsRef()
        .where('isActive', isEqualTo: true)
        .limit(100)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('進行中活動'),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) return _error('讀取活動失敗：${snap.error}');
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // ✅ 先複製一份可修改 list，避免 docs.sort 直接炸掉
            final docs = [...snap.data!.docs];

            if (docs.isEmpty) return _empty('目前沒有進行中的福袋活動');

            // client-side 排序：若有 startAt 用 startAt desc，否則 docId
            docs.sort((a, b) {
              final sa = _asDate(a.data()['startAt']);
              final sb = _asDate(b.data()['startAt']);
              if (sa == null && sb == null) return b.id.compareTo(a.id);
              if (sa == null) return 1;
              if (sb == null) return -1;
              return sb.compareTo(sa);
            });

            return Column(children: [for (final d in docs) _eventCard(uid, d)]);
          },
        ),
        const SizedBox(height: 24),
        const Text(
          '註：此頁已全面避免 Object 直接餵給 String 參數（全部欄位用 _s() 保底轉型）。',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _eventCard(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final eventId = doc.id;

    final title = _s(data['title'], '未命名活動');
    final subtitle = _s(data['subtitle'], '').trim();
    final price = _asNum(data['price'], fallback: 0).toInt();
    final stock = _asNum(data['stock'], fallback: 0).toInt();

    final startAt = _asDate(data['startAt']);
    final endAt = _asDate(data['endAt']);

    final dateText = [
      if (startAt != null) '開始：${_fmtDate(startAt)}',
      if (endAt != null) '結束：${_fmtDate(endAt)}',
    ].join('  •  ');

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.card_giftcard_outlined)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          [
            if (subtitle.isNotEmpty) subtitle,
            '價格：$price',
            '庫存：$stock',
            if (dateText.isNotEmpty) dateText,
            'ID：$eventId',
          ].join('\n'),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: stock <= 0
            ? const Text(
                '售完',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w900,
                ),
              )
            : FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _openBuyDialog(uid, eventId, title, price, stock),
                child: const Text('購買'),
              ),
        onTap: () => _openDetail(uid, eventId),
      ),
    );
  }

  Future<void> _openDetail(String uid, String eventId) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('活動詳情'),
        content: SizedBox(
          width: 520,
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _eventRef(eventId).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return Text('讀取失敗：${snap.error}');
              if (!snap.hasData) return const LinearProgressIndicator();

              final data = snap.data!.data();
              if (data == null) return const Text('活動不存在或已刪除');

              final title = _s(data['title'], '未命名活動');
              final desc = _s(data['description'], '').trim();
              final price = _asNum(data['price'], fallback: 0).toInt();
              final stock = _asNum(data['stock'], fallback: 0).toInt();
              final startAt = _asDate(data['startAt']);
              final endAt = _asDate(data['endAt']);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text('價格：$price'),
                  Text('庫存：$stock'),
                  if (startAt != null) Text('開始：${_fmtDate(startAt)}'),
                  if (endAt != null) Text('結束：${_fmtDate(endAt)}'),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(desc),
                  ],
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 6),
                  const Text(
                    '我的訂單（Top 10）',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  _myOrders(uid, eventId),
                ],
              );
            },
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

  Widget _myOrders(String uid, String eventId) {
    final stream = _ordersRef(
      eventId,
    ).where('uid', isEqualTo: uid).limit(10).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return Text('讀取訂單失敗：${snap.error}');
        if (!snap.hasData) return const LinearProgressIndicator();

        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Text('尚無訂單');

        return Column(
          children: docs.map((d) {
            final data = d.data();
            final qty = _asNum(data['qty'], fallback: 0).toInt();
            final total = _asNum(data['total'], fallback: 0).toInt();
            final status = _s(data['status'], 'created');
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'qty=$qty  total=$total',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'status=$status  •  id=${d.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _openBuyDialog(
    String uid,
    String eventId,
    String title,
    int price,
    int stock,
  ) async {
    final ctrl = TextEditingController(text: '1');

    final qty = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('購買：$title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('單價：$price'),
            Text('庫存：$stock'),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '數量',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text.trim()) ?? 0;
              Navigator.pop(context, n);
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (qty == null) return;
    final safeQty = qty.clamp(1, 999);
    await _buy(uid: uid, eventId: eventId, qty: safeQty);
  }

  Future<void> _buy({
    required String uid,
    required String eventId,
    required int qty,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _fs.runTransaction((tx) async {
        final evRef = _eventRef(eventId);
        final userRef = _userRef(uid);

        final evSnap = await tx.get(evRef);
        if (!evSnap.exists) throw '活動不存在';

        final ev = evSnap.data() ?? <String, dynamic>{};
        final isActive = (ev['isActive'] ?? false) == true;
        if (!isActive) throw '活動未啟用';

        final stock = _asNum(ev['stock'], fallback: 0).toInt();
        final price = _asNum(ev['price'], fallback: 0).toInt();
        if (stock < qty) throw '庫存不足（目前 $stock，需要 $qty）';

        // ✅ 若你要啟用扣點數，解除下面註解即可
        // final userSnap = await tx.get(userRef);
        // final userData = userSnap.data() ?? <String, dynamic>{};
        // final points = _asNum(userData['points'], fallback: 0).toInt();
        // final cost = price * qty;
        // if (points < cost) throw '點數不足（目前 $points，需要 $cost）';
        // tx.set(userRef, {'points': points - cost}, SetOptions(merge: true));

        // ✅ 這裡用 userRef 實際寫回購買資訊（避免 unused_local_variable，也方便後台追蹤）
        tx.set(userRef, {
          'lastLuckyBagPurchaseAt': FieldValue.serverTimestamp(),
          'lastLuckyBagEventId': eventId,
        }, SetOptions(merge: true));

        // 扣庫存
        tx.set(evRef, {
          'stock': stock - qty,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final orderId = _fs.collection('_tmp').doc().id; // 產生隨機 id
        final orderRef = _ordersRef(eventId).doc(orderId);
        final total = price * qty;

        tx.set(orderRef, {
          'uid': uid,
          'qty': qty,
          'price': price,
          'total': total,
          'status': 'created',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已建立訂單並扣庫存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 購買失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }

  Widget _empty(String text) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _error(String text) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

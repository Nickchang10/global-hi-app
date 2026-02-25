import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ SendPointsPage（轉點數 / 送點數｜修改後完整版）
/// ------------------------------------------------------------
/// 修正重點：
/// - 不再使用 Map.name（Map 沒有 getter）
/// - 全部使用 map['xxx'] 方式安全取值
/// - 以 Firestore users/{uid}.points 為準，transaction 確保扣點/加點一致
/// - 另外寫入 points_transfers（全域轉點紀錄）
///
/// 需求欄位建議：
/// users/{uid}
///   - displayName / name: String
///   - email: String
///   - phone: String
///   - points: num (default 0)
/// ------------------------------------------------------------
class SendPointsPage extends StatefulWidget {
  const SendPointsPage({super.key});

  @override
  State<SendPointsPage> createState() => _SendPointsPageState();
}

class _SendPointsPageState extends State<SendPointsPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _loading = false;

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _goLogin() async {
    Navigator.of(context, rootNavigator: true).pushNamed('/login');
  }

  Future<void> _openSendDialog({
    required String toUid,
    required Map<String, dynamic> toData,
  }) async {
    _amountCtrl.text = '';
    _noteCtrl.text = '';

    final toName = _s(toData['displayName'], _s(toData['name'], '未命名會員'));
    final toEmail = _s(toData['email'], '');
    final toPhone = _s(toData['phone'], '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('送出點數'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(toName.isNotEmpty ? toName.substring(0, 1) : '?'),
                ),
                title: Text(
                  toName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  [
                    if (toEmail.isNotEmpty) toEmail,
                    if (toPhone.isNotEmpty) toPhone,
                    'UID: $toUid',
                  ].join('  •  '),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '點數數量',
                  hintText: '例如 50',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: '備註（可選）',
                  hintText: '例如：謝謝你幫忙',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('請輸入正確的點數數量')));
                return;
              }
              Navigator.pop(context);
              await _sendPoints(
                toUid: toUid,
                toData: toData,
                amount: amount,
                note: _noteCtrl.text.trim(),
              );
            },
            child: const Text('確認送出'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPoints({
    required String toUid,
    required Map<String, dynamic> toData,
    required int amount,
    required String note,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先登入')));
      return;
    }
    final fromUid = user.uid;
    if (fromUid == toUid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('不能轉點數給自己')));
      return;
    }

    setState(() => _loading = true);

    final fromRef = _fs.collection('users').doc(fromUid);
    final toRef = _fs.collection('users').doc(toUid);
    final transferRef = _fs.collection('points_transfers').doc();

    try {
      await _fs.runTransaction((tx) async {
        final fromSnap = await tx.get(fromRef);
        final toSnap = await tx.get(toRef);

        if (!fromSnap.exists) {
          throw '找不到你的會員資料（users/$fromUid）';
        }
        if (!toSnap.exists) {
          throw '找不到對方會員資料（users/$toUid）';
        }

        final fromData = fromSnap.data() as Map<String, dynamic>;
        final toDataLive = toSnap.data() as Map<String, dynamic>;

        final fromPoints = _asNum(fromData['points'], fallback: 0).toInt();
        final toPoints = _asNum(toDataLive['points'], fallback: 0).toInt();

        if (fromPoints < amount) {
          throw '點數不足（你目前 $fromPoints 點）';
        }

        tx.update(fromRef, {'points': fromPoints - amount});
        tx.update(toRef, {'points': toPoints + amount});

        tx.set(transferRef, {
          'fromUid': fromUid,
          'toUid': toUid,
          'amount': amount,
          'note': note,
          'toName': _s(toData['displayName'], _s(toData['name'], '')),
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'success',
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已成功送出 $amount 點')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('送出失敗：$e')));

      // 失敗也記錄（可選）
      try {
        await transferRef.set({
          'fromUid': _auth.currentUser?.uid,
          'toUid': toUid,
          'amount': amount,
          'note': note,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'failed',
          'error': e.toString(),
        }, SetOptions(merge: true));
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('送點數'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: user == null
          ? _needLogin()
          : Stack(
              children: [
                Column(
                  children: [
                    _searchBar(),
                    const Divider(height: 1),
                    Expanded(child: _usersList(currentUid: user.uid)),
                  ],
                ),
                if (_loading)
                  // ✅ 修正：withOpacity -> withValues(alpha: ...)
                  Container(
                    color: Colors.black.withValues(alpha: 0.12),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  Widget _needLogin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
                const SizedBox(height: 10),
                const Text(
                  '請先登入才能送點數',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _goLogin, child: const Text('前往登入')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: '搜尋對象（姓名 / Email / UID / Phone）',
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: _searchCtrl.text.trim().isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _searchCtrl.clear()),
                ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _usersList({required String currentUid}) {
    // 先抓 users 一批做 client-side 搜尋，避免索引/where 限制
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs.collection('users').limit(200).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('讀取失敗：${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final q = _searchCtrl.text.trim().toLowerCase();
        final docs = snap.data!.docs.where((d) {
          if (d.id == currentUid) return false; // 不顯示自己（避免誤轉）

          final data = d.data();
          final name = _s(
            data['displayName'],
            _s(data['name'], ''),
          ).toLowerCase();
          final email = _s(data['email'], '').toLowerCase();
          final phone = _s(data['phone'], '').toLowerCase();
          final uid = d.id.toLowerCase();

          if (q.isEmpty) return true;

          return name.contains(q) ||
              email.contains(q) ||
              phone.contains(q) ||
              uid.contains(q);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('找不到符合條件的會員'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data();

            final name = _s(data['displayName'], _s(data['name'], '未命名會員'));
            final email = _s(data['email'], '');
            final phone = _s(data['phone'], '');
            final points = _asNum(data['points'], fallback: 0).toInt();

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(name.isNotEmpty ? name.substring(0, 1) : '?'),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  [
                    if (email.isNotEmpty) email,
                    if (phone.isNotEmpty) phone,
                    '點數：$points',
                    'UID：${doc.id}',
                  ].join('  •  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => _openSendDialog(toUid: doc.id, toData: data),
              ),
            );
          },
        );
      },
    );
  }
}

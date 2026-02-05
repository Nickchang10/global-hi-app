// lib/pages/lottery_history_page.dart
//
// ✅ LotteryHistoryPage（完整版・最終可編譯強化版）
// ------------------------------------------------------------
// 功能：
// - 顯示使用者全部已抽獎的訂單（從 orders 集合）
// - 中獎顯示優惠券資訊、未中顯示銘謝惠顧
// - 支援 Firestore 即時更新
// - 可複製優惠碼
// - 路由：/lottery_history
//
// 依賴：firebase_auth, cloud_firestore, flutter/services
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LotteryHistoryPage extends StatefulWidget {
  const LotteryHistoryPage({super.key});

  @override
  State<LotteryHistoryPage> createState() => _LotteryHistoryPageState();
}

class _LotteryHistoryPageState extends State<LotteryHistoryPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _copy(String text, {String? done}) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text.trim()));
    _snack(done ?? '已複製');
  }

  bool _matches(dynamic value) {
    if (_query.trim().isEmpty) return true;
    final q = _query.toLowerCase();
    return value.toString().toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('請先登入帳號')));
    }

    final ordersRef = _db
        .collection('orders')
        .where('buyerUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(100);

    return Scaffold(
      appBar: AppBar(
        title: const Text('抽獎紀錄'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋訂單編號或優惠碼',
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ordersRef.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('讀取失敗：${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs.where((d) {
                    final data = d.data();
                    final lottery = data['lottery'] ?? {};
                    if (lottery is! Map) return false;
                    final drawn = lottery['drawn'] == true;
                    final prizeName = (lottery['prizeName'] ?? '').toString();
                    return drawn || prizeName.isNotEmpty;
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(child: Text('尚無抽獎紀錄'));
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final data = doc.data();
                      final id = doc.id;
                      final lottery = (data['lottery'] ?? {}) as Map<String, dynamic>;
                      final prizeName = (lottery['prizeName'] ?? '').toString().trim();
                      final status = (lottery['status'] ?? '').toString().trim().toLowerCase();
                      final code = (lottery['couponCode'] ?? '').toString().trim();
                      final type = (lottery['couponType'] ?? '').toString().trim().toLowerCase();
                      final amountOff = lottery['amountOff'];
                      final percentOff = lottery['percentOff'];
                      final minSpend = lottery['minSpend'];
                      final expiresAt = lottery['expiresAt'];

                      if (!_matches(id) && !_matches(code)) return const SizedBox.shrink();

                      final isWon = status == 'won';
                      final cs = Theme.of(context).colorScheme;

                      String desc = '銘謝惠顧';
                      if (isWon) {
                        if (type == 'amount') {
                          desc = '折抵 NT\$${amountOff ?? 0}（滿 NT\$${minSpend ?? 0} 可用）';
                        } else if (type == 'percent') {
                          desc = '${percentOff ?? 0}% 折扣（滿 NT\$${minSpend ?? 0} 可用）';
                        } else if (type == 'shipping') {
                          desc = '免運一次';
                        }
                      }

                      String? exp;
                      if (expiresAt is Timestamp) {
                        final dt = expiresAt.toDate();
                        exp = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                      }

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            isWon ? Icons.emoji_events : Icons.sentiment_neutral,
                            color: isWon ? cs.primary : cs.outline,
                          ),
                          title: Text(
                            '訂單：$id',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isWon ? '中獎：$prizeName' : '未中獎（銘謝惠顧）'),
                              Text(desc, style: const TextStyle(color: Colors.black54)),
                              if (exp != null)
                                Text('有效期限：$exp',
                                    style: const TextStyle(color: Colors.black45)),
                              if (code.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: GestureDetector(
                                    onTap: () => _copy(code, done: '已複製優惠碼'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.black12),
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.black.withOpacity(0.03),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            code,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                          const Icon(Icons.copy, size: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/pages/lottery_user_page.dart
//
// ✅ LotteryUserPage（最終完整版｜Firestore + NotificationService + AuthService）
// ------------------------------------------------------------
// 功能：
// - 使用者登入後可按下「抽一次」進行抽獎
// - 立即將結果寫入 Firestore lotteries/{docId}
// - 若中獎，自動呼叫 NotificationService 發送通知
// - 顯示歷史抽獎紀錄（最新在上）
//
// Firestore 結構：
// lotteries/{lotteryId}
//   uid: string
//   prize: string
//   status: "won" | "lost"
//   createdAt: Timestamp
//   notified: bool
//
// ------------------------------------------------------------
// 依賴：
// - cloud_firestore
// - firebase_auth
// - provider
// - services/auth_service.dart
// - services/notification_service.dart
// ------------------------------------------------------------

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';

class LotteryUserPage extends StatefulWidget {
  const LotteryUserPage({super.key});

  @override
  State<LotteryUserPage> createState() => _LotteryUserPageState();
}

class _LotteryUserPageState extends State<LotteryUserPage> {
  bool _loading = false;
  String? _result;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _drawLottery() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('請先登入');
      return;
    }

    // ✅ 先取出 service，避免 await 後才用 context.read（消除 use_build_context_synchronously）
    final notifSvc = context.read<NotificationService>();

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      // 模擬抽獎機率
      final rnd = Random();
      final win = rnd.nextDouble() < 0.3; // 30% 中獎率
      final prizeList = ['100元折價券', '免運券', '贈品兌換券'];
      final prize = win ? prizeList[rnd.nextInt(prizeList.length)] : '未中獎';
      final status = win ? 'won' : 'lost';

      final ref = await FirebaseFirestore.instance.collection('lotteries').add({
        'uid': user.uid,
        'prize': prize,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'notified': false,
      });

      if (!mounted) return;

      if (win) {
        await notifSvc.sendToUser(
          uid: user.uid,
          title: '恭喜中獎！',
          body: '您獲得了 $prize！',
          type: 'lottery',
          route: '/lottery',
          extra: {'lotteryId': ref.id},
        );

        await ref.update({'notified': true});

        if (!mounted) return;
      }

      final msg = win ? '恭喜中獎：$prize' : '未中獎，再接再厲！';
      if (mounted) {
        setState(() => _result = msg);
      }
      _snack(msg);
    } catch (e) {
      _snack('抽獎失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authSvc = context.read<AuthService>();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('抽獎活動'),
        actions: [
          IconButton(
            tooltip: '登出',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authSvc.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('請先登入以參加抽獎'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            '每位會員每天可抽一次！',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_loading)
                            const CircularProgressIndicator()
                          else
                            FilledButton.icon(
                              onPressed: _drawLottery,
                              icon: const Icon(Icons.emoji_events_outlined),
                              label: const Text('抽一次'),
                            ),
                          const SizedBox(height: 12),
                          if (_result != null)
                            Text(
                              _result!,
                              style: TextStyle(
                                color: _result!.contains('恭喜')
                                    ? Colors.orange
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildHistoryList(user.uid)),
                ],
              ),
            ),
    );
  }

  Widget _buildHistoryList(String uid) {
    final query = FirebaseFirestore.instance
        .collection('lotteries')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('讀取錯誤：${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('目前沒有抽獎紀錄'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final prize = (data['prize'] ?? '').toString();
            final status = (data['status'] ?? '').toString();
            final createdAt = (data['createdAt'] as Timestamp?)
                ?.toDate()
                .toLocal()
                .toString()
                .split('.')[0];
            final notified = data['notified'] == true;

            return ListTile(
              leading: Icon(
                status == 'won'
                    ? Icons.emoji_events_outlined
                    : Icons.cancel_outlined,
                color: status == 'won' ? Colors.amber : Colors.grey,
              ),
              title: Text(status == 'won' ? '恭喜中獎！' : '未中獎'),
              subtitle: Text('獎項：$prize\n時間：${createdAt ?? '-'}'),
              trailing: notified
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.hourglass_empty, color: Colors.grey),
            );
          },
        );
      },
    );
  }
}

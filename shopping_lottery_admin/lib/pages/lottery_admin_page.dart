// lib/pages/lottery_admin_page.dart
//
// ✅ LotteryAdminPage（最終完整版｜整合 Firestore + AdminGate + NotificationService）
// ------------------------------------------------------------
// 功能：
// - 管理員可檢視所有抽獎紀錄
// - 可依 UID 搜尋抽獎紀錄
// - 可手動新增抽獎紀錄（測試用）
// - 可手動發送中獎通知（透過 NotificationService）
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/auth/auth_service.dart';
import '../services/notification_service.dart';

class LotteryAdminPage extends StatefulWidget {
  const LotteryAdminPage({super.key});

  @override
  State<LotteryAdminPage> createState() => _LotteryAdminPageState();
}

class _LotteryAdminPageState extends State<LotteryAdminPage> {
  String _search = '';
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

  /// ✅ 建立模擬抽獎紀錄（不再傳 BuildContext 進來，避免 async gap 警告）
  Future<void> _createFakeLottery() async {
    final uid = _searchCtrl.text.trim();
    if (uid.isEmpty) {
      _snack('請輸入使用者 UID');
      return;
    }

    final prizeList = ['100元折價券', '免運券', '未中獎'];
    final prize = prizeList[DateTime.now().millisecond % prizeList.length];
    final status = prize == '未中獎' ? 'lost' : 'won';

    try {
      await FirebaseFirestore.instance.collection('lotteries').add({
        'uid': uid,
        'prize': prize,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'notified': false,
      });

      if (!mounted) return;
      _snack('已建立模擬抽獎紀錄');
    } catch (e) {
      if (!mounted) return;
      _snack('建立失敗：$e');
    }
  }

  /// ✅ 發送中獎通知（await 後使用 SnackBar 前都 guard mounted）
  Future<void> _sendNotify(Map<String, dynamic> data, String docId) async {
    final uid = (data['uid'] ?? '').toString().trim();
    if (uid.isEmpty) return;

    try {
      final prize = (data['prize'] ?? '').toString();
      final notifSvc = context.read<NotificationService>();

      await notifSvc.sendToUser(
        uid: uid,
        title: '抽獎結果通知',
        body: '恭喜您獲得 $prize！',
        type: 'lottery',
        route: '/lottery',
        extra: {'lotteryId': docId},
      );

      await FirebaseFirestore.instance
          .collection('lotteries')
          .doc(docId)
          .update({'notified': true});

      if (!mounted) return;
      _snack('已發送通知');
    } catch (e) {
      if (!mounted) return;
      _snack('發送通知失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final authSvc = context.read<AuthService>();

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

        return FutureBuilder<RoleInfo>(
          future: gate.ensureAndGetRole(user),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (roleSnap.hasError) {
              return Scaffold(
                body: Center(child: Text('角色讀取失敗：${roleSnap.error}')),
              );
            }

            final info = roleSnap.data;
            final isAdmin = info?.isAdmin ?? false;

            if (!isAdmin) {
              return Scaffold(
                appBar: AppBar(title: const Text('抽獎管理')),
                body: const Center(child: Text('僅限 Admin 使用')),
              );
            }

            final Query<Map<String, dynamic>> query = FirebaseFirestore.instance
                .collection('lotteries')
                .orderBy('createdAt', descending: true)
                .limit(300);

            return Scaffold(
              appBar: AppBar(
                title: const Text('抽獎管理'),
                actions: [
                  IconButton(
                    tooltip: '登出',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      gate.clearCache();
                      await authSvc.signOut();
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('新增測試紀錄'),
                onPressed: _createFakeLottery,
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: '輸入 UID 搜尋',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _search = v.trim()),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: query.snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('錯誤：${snapshot.error}'));
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        final filtered = _search.isEmpty
                            ? docs
                            : docs.where((d) {
                                final data = d.data();
                                return (data['uid'] ?? '').toString().contains(
                                  _search,
                                );
                              }).toList();

                        if (filtered.isEmpty) {
                          return const Center(child: Text('目前無抽獎紀錄'));
                        }

                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final doc = filtered[i];
                            final data = doc.data();

                            final uid = (data['uid'] ?? '').toString();
                            final prize = (data['prize'] ?? '').toString();
                            final status = (data['status'] ?? '').toString();
                            final notified = data['notified'] == true;

                            final createdAt = (data['createdAt'] is Timestamp)
                                ? (data['createdAt'] as Timestamp)
                                      .toDate()
                                      .toLocal()
                                      .toString()
                                      .split('.')[0]
                                : '-';

                            return ListTile(
                              leading: Icon(
                                status == 'won'
                                    ? Icons.emoji_events_outlined
                                    : Icons.cancel_outlined,
                                color: status == 'won'
                                    ? Colors.amber
                                    : Colors.grey,
                              ),
                              title: Text('UID：$uid'),
                              subtitle: Text('獎項：$prize\n建立時間：$createdAt'),
                              trailing: notified
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : status == 'won'
                                  ? IconButton(
                                      icon: const Icon(Icons.send),
                                      tooltip: '發送通知',
                                      onPressed: () =>
                                          _sendNotify(data, doc.id),
                                    )
                                  : const Icon(
                                      Icons.hourglass_empty,
                                      color: Colors.grey,
                                    ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

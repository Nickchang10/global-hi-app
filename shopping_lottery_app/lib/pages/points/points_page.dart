// lib/pages/points/points_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PointsPage extends StatelessWidget {
  const PointsPage({super.key});

  int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final uid = auth.currentUser?.uid;

    if (uid == null) return const Scaffold(body: Center(child: Text('請先登入')));

    final pointsDoc = db
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('points');
    final txRef = db
        .collection('users')
        .doc(uid)
        .collection('points_transactions');

    return Scaffold(
      appBar: AppBar(title: const Text('積分明細')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: pointsDoc.snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data() ?? <String, dynamic>{};
              final points = _toInt(data['points']);
              final streak = _toInt(data['checkinStreak']);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.stars_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '目前積分',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'NT Points：$points',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '連續簽到：$streak 天',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            '積分紀錄',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: txRef
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return Text('讀取明細失敗：${snap.error}');
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());

              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '目前沒有積分明細（你若想要自動寫入明細，我可以再幫你把 Tasks/下單流程補上 points_transactions 寫入）',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                );
              }

              return Column(
                children: docs.map((d) {
                  final m = d.data();
                  final title = (m['title'] ?? m['type'] ?? '積分變動').toString();
                  final delta = _toInt(m['delta']);
                  final createdAt = (m['createdAt'] is Timestamp)
                      ? (m['createdAt'] as Timestamp).toDate()
                      : null;

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.bolt_outlined),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        createdAt == null ? '' : createdAt.toString(),
                      ),
                      trailing: Text(
                        (delta >= 0 ? '+$delta' : '$delta'),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: delta >= 0 ? Colors.green : Colors.redAccent,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

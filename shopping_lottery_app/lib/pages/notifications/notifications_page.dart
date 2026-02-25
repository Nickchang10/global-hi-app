import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');

    // ✅ 不用 orderBy：避免 index / 權限踩雷，改用 client 端排序
    final q = col.limit(100);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          TextButton(
            onPressed: () async {
              final snap = await col.where('read', isEqualTo: false).get();
              final batch = FirebaseFirestore.instance.batch();
              for (final d in snap.docs) {
                batch.set(d.reference, {
                  'read': true,
                  'readAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              }
              await batch.commit();
            },
            child: const Text('全部已讀'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取通知失敗：\n${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs.toList();

          // client 端排序 createdAt desc
          docs.sort((a, b) {
            DateTime da = DateTime.fromMillisecondsSinceEpoch(0);
            DateTime db = DateTime.fromMillisecondsSinceEpoch(0);
            final ta = a.data()['createdAt'];
            final tb = b.data()['createdAt'];
            if (ta is Timestamp) da = ta.toDate();
            if (tb is Timestamp) db = tb.toDate();
            return db.compareTo(da);
          });

          if (docs.isEmpty) return const Center(child: Text('目前沒有通知'));

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final m = d.data();

              final title = (m['title'] ?? '通知').toString();
              final body = (m['body'] ?? '').toString();
              final type = (m['type'] ?? '')
                  .toString(); // order/lottery/marketing...
              final read = (m['read'] ?? false) == true;

              return ListTile(
                leading: Icon(_iconFor(type)),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: read ? Colors.grey : null,
                  ),
                ),
                subtitle: body.isEmpty ? null : Text(body),
                trailing: read
                    ? const Icon(Icons.done, size: 18)
                    : TextButton(
                        onPressed: () async {
                          await d.reference.set({
                            'read': true,
                            'readAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                        },
                        child: const Text('已讀'),
                      ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'order':
        return Icons.local_shipping_outlined;
      case 'lottery':
        return Icons.emoji_events_outlined;
      case 'marketing':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }
}

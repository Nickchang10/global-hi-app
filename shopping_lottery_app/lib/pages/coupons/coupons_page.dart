import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CouponsPage extends StatelessWidget {
  const CouponsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    final q = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('coupons')
        .orderBy('createdAt', descending: true)
        .limit(50);

    return Scaffold(
      appBar: AppBar(title: const Text('優惠券')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('目前沒有優惠券'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = docs[i].data();
              final title = (m['title'] ?? '優惠券').toString();
              final code = (m['code'] ?? '').toString();
              final desc = (m['desc'] ?? '').toString();
              final active = (m['active'] ?? true) == true;

              return ListTile(
                leading: Icon(
                  active
                      ? Icons.confirmation_number_outlined
                      : Icons.block_outlined,
                ),
                title: Text(title),
                subtitle: Text(
                  [
                    if (code.isNotEmpty) '代碼：$code',
                    if (desc.isNotEmpty) desc,
                  ].join('\n'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

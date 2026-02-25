import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'address_edit_page.dart';

class AddressesPage extends StatelessWidget {
  const AddressesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('請先登入才能管理地址')));
    }

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .orderBy('updatedAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('收件地址'),
        actions: [
          IconButton(
            tooltip: '新增地址',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AddressEditPage(args: AddressEditArgs()),
                ),
              );
              if (ok == true && context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已儲存地址')));
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('尚無地址，右上角新增'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final m = d.data();
              final label = (m['label'] ?? '地址').toString();
              final name = (m['name'] ?? '').toString();
              final phone = (m['phone'] ?? '').toString();
              final address = (m['address'] ?? '').toString();
              final isDefault = (m['isDefault'] ?? false) == true;

              return ListTile(
                title: Row(
                  children: [
                    Text(label),
                    const SizedBox(width: 8),
                    if (isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                        child: Text(
                          '預設',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty || phone.isNotEmpty)
                      Text('$name  $phone'.trim()),
                    if (address.isNotEmpty) Text(address),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddressEditPage(
                        args: AddressEditArgs(addressId: d.id, initialData: m),
                      ),
                    ),
                  );
                  if (ok == true && context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已更新地址')));
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

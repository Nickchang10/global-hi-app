import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '內部公告',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .where('published', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('目前沒有公告'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text(
                    data['title'] ?? '(未命名公告)',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    data['content'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    if (uid != null) {
                      await _markAsRead(d.id, uid);
                    }

                    if (!context.mounted) return;

                    await showDialog(
                      context: context,
                      builder: (_) => _AnnouncementDialog(
                        title: data['title'] ?? '',
                        content: data['content'] ?? '',
                        createdAt: data['createdAt'],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// =========================================================
  /// 寫入已讀回條（防重複）
  /// =========================================================
  Future<void> _markAsRead(String announcementId, String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance
        .collection('announcements')
        .doc(announcementId)
        .collection('reads')
        .doc(uid);

    final snap = await ref.get();
    if (snap.exists) return; // 已讀過就不重寫

    await ref.set({
      'uid': uid,
      'role': 'user', // 若你有 role service 可改成實際角色
      'readAt': FieldValue.serverTimestamp(),
    });
  }
}

/// =========================================================
/// 公告內容 Dialog
/// =========================================================
class _AnnouncementDialog extends StatelessWidget {
  final String title;
  final String content;
  final Timestamp? createdAt;

  const _AnnouncementDialog({
    required this.title,
    required this.content,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy/MM/dd HH:mm');

    return AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content),
            const SizedBox(height: 16),
            const Divider(),
            if (createdAt != null)
              Text(
                '發布時間：${fmt.format(createdAt!.toDate())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
      ],
    );
  }
}

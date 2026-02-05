import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ------------------------------------------------------------
/// AnnouncementReadRate
/// ------------------------------------------------------------
/// 顯示：
/// - 已讀人數 / 應讀人數
/// - 閱讀率 %
///
/// 依據：
/// - announcements/{id}.targetRoles  決定應讀角色
/// - announcements/{id}/reads        已讀紀錄
/// - users.role                      應讀人數統計
///
/// 需求：
/// - 後台 admin 有權限讀 users / reads
/// ------------------------------------------------------------
class AnnouncementReadRate extends StatelessWidget {
  final String announcementId;
  final List<String> targetRoles;

  const AnnouncementReadRate({
    super.key,
    required this.announcementId,
    required this.targetRoles,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    final readsCol = db
        .collection('announcements')
        .doc(announcementId)
        .collection('reads');

    final usersQuery = db
        .collection('users')
        .where('role', whereIn: targetRoles);

    return FutureBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
      future: Future.wait([
        readsCol.get(),
        usersQuery.get(),
      ]),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 16,
            width: 120,
            child: LinearProgressIndicator(minHeight: 3),
          );
        }

        if (snap.hasError || !snap.hasData) {
          return const Text(
            '讀取中…',
            style: TextStyle(fontSize: 12),
          );
        }

        final readCount = snap.data![0].size;
        final totalCount = snap.data![1].size;

        final rate = totalCount == 0
            ? 0
            : ((readCount / totalCount) * 100).round();

        final done = rate >= 100;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pill(
              text: '已讀 $readCount / $totalCount',
              done: done,
            ),
            const SizedBox(width: 6),
            Text(
              '$rate%',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: done ? Colors.green : Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pill({
    required String text,
    required bool done,
  }) {
    final bg = done ? Colors.green.shade100 : Colors.orange.shade100;
    final fg = done ? Colors.green.shade900 : Colors.orange.shade900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

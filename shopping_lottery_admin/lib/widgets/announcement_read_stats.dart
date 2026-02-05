// lib/widgets/announcement_read_stats.dart
//
// ✅ AnnouncementReadStats（公告閱讀統計｜最終完整版｜可編譯｜Web/Chrome OK）
// ------------------------------------------------------------
// 需求功能：
// - 統計：總人數（users）、已讀（announcements/{id}/reads）、未讀、閱讀率
// - UI：ProgressBar + Summary + 可選角色分布（admin/vendor/buyer...）
// - 容錯：
//   - users 集合為空
//   - reads 子集合缺欄位 / role 缺失
//   - Web/Chrome OK（不使用需要平台限制的 API）
//
// 資料假設：
// - users/{uid} (至少存在即可，不強制欄位)
// - announcements/{announcementId}/reads/{uid}
//   { uid: "...", role: "admin|vendor|...", readAt: Timestamp }
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AnnouncementReadStats extends StatelessWidget {
  final String announcementId;

  /// 是否顯示依角色統計（reads 裡的 role 欄位）
  final bool showRoleBreakdown;

  /// users 集合來源（預設 users）
  final String usersCollection;

  /// announcements 集合來源（預設 announcements）
  final String announcementsCollection;

  const AnnouncementReadStats({
    super.key,
    required this.announcementId,
    this.showRoleBreakdown = true,
    this.usersCollection = 'users',
    this.announcementsCollection = 'announcements',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final usersStream =
        FirebaseFirestore.instance.collection(usersCollection).snapshots();

    final readsStream = FirebaseFirestore.instance
        .collection(announcementsCollection)
        .doc(announcementId)
        .collection('reads')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: usersStream,
      builder: (context, usersSnap) {
        if (usersSnap.hasError) {
          return _ErrorCard(
            title: '讀取 users 失敗',
            message: usersSnap.error.toString(),
          );
        }
        if (!usersSnap.hasData) {
          return const _LoadingCard(label: '載入使用者統計...');
        }

        final totalUsers = usersSnap.data!.size;
        if (totalUsers <= 0) {
          return _EmptyCard(
            title: '公告閱讀統計',
            message: '目前 users 集合為空，無法計算閱讀率。',
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: readsStream,
          builder: (context, readsSnap) {
            if (readsSnap.hasError) {
              return _ErrorCard(
                title: '讀取 reads 失敗',
                message: readsSnap.error.toString(),
              );
            }
            if (!readsSnap.hasData) {
              return const _LoadingCard(label: '載入已讀資料...');
            }

            final readDocs = readsSnap.data!.docs;
            final readCount = readDocs.length;

            // 未讀人數不小於 0（避免 users < reads 的異常情境）
            final unreadCount = (totalUsers - readCount) < 0
                ? 0
                : (totalUsers - readCount);

            final rate = totalUsers == 0 ? 0.0 : (readCount / totalUsers);
            final ratePct = (rate * 100);

            // 依 role 統計（可選）
            final roleCount = <String, int>{};
            if (showRoleBreakdown) {
              for (final d in readDocs) {
                final data = d.data();
                final role = _s(data['role']);
                final key = role.isEmpty ? 'unknown' : role.toLowerCase();
                roleCount[key] = (roleCount[key] ?? 0) + 1;
              }
            }

            final sortedRoleEntries = roleCount.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '公告閱讀統計',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),

                    // Progress
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: rate.clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: cs.surfaceVariant.withOpacity(0.45),
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Summary row
                    Wrap(
                      spacing: 14,
                      runSpacing: 10,
                      children: [
                        _metric(
                          label: '已讀',
                          value: readCount.toString(),
                          color: cs.primary,
                        ),
                        _metric(
                          label: '未讀',
                          value: unreadCount.toString(),
                          color: cs.error,
                        ),
                        _metric(
                          label: '總人數',
                          value: totalUsers.toString(),
                          color: cs.onSurfaceVariant,
                        ),
                        _metric(
                          label: '閱讀率',
                          value: '${ratePct.toStringAsFixed(1)}%',
                          color: cs.primary,
                        ),
                      ],
                    ),

                    // Role breakdown
                    if (showRoleBreakdown) ...[
                      const SizedBox(height: 14),
                      Divider(height: 1, color: cs.outlineVariant),
                      const SizedBox(height: 12),
                      const Text(
                        '已讀角色分布',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),

                      if (sortedRoleEntries.isEmpty)
                        Text(
                          'reads 尚未寫入 role 欄位（或目前無已讀資料）',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        )
                      else
                        Column(
                          children: sortedRoleEntries.map((e) {
                            final role = e.key;
                            final count = e.value;
                            final p = readCount == 0 ? 0.0 : count / readCount;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      role,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: p.clamp(0.0, 1.0),
                                        minHeight: 8,
                                        backgroundColor: cs.surfaceVariant
                                            .withOpacity(0.45),
                                        color: cs.secondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      '$count (${(p * 100).toStringAsFixed(1)}%)',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();

  Widget _metric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
        color: color.withOpacity(0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Small UI helpers
// ------------------------------------------------------------

class _LoadingCard extends StatelessWidget {
  final String label;
  const _LoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String title;
  final String message;

  const _ErrorCard({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: cs.error,
              )),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyCard({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

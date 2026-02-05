// lib/widgets/announcement_unread_list.dart
//
// ✅ AnnouncementUnreadList（公告未讀名單｜最終完整版｜可編譯｜Web OK）
// ------------------------------------------------------------
// 功能：
// - 比對 users 與 announcements/{id}/reads
// - 列出尚未閱讀此公告的使用者
// - 顯示 uid / role / email（若存在）
// - 搜尋（uid / email / role）
// - 容錯：
//   - reads 為空
//   - users 欄位缺失
//
// 建議權限：僅 admin 使用
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AnnouncementUnreadList extends StatefulWidget {
  final String announcementId;

  /// users 集合名稱（預設 users）
  final String usersCollection;

  /// announcements 集合名稱（預設 announcements）
  final String announcementsCollection;

  const AnnouncementUnreadList({
    super.key,
    required this.announcementId,
    this.usersCollection = 'users',
    this.announcementsCollection = 'announcements',
  });

  @override
  State<AnnouncementUnreadList> createState() =>
      _AnnouncementUnreadListState();
}

class _AnnouncementUnreadListState extends State<AnnouncementUnreadList> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final usersStream = FirebaseFirestore.instance
        .collection(widget.usersCollection)
        .snapshots();

    final readsStream = FirebaseFirestore.instance
        .collection(widget.announcementsCollection)
        .doc(widget.announcementId)
        .collection('reads')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: usersStream,
      builder: (context, usersSnap) {
        if (usersSnap.hasError) {
          return _ErrorView(
            title: '讀取 users 失敗',
            message: usersSnap.error.toString(),
          );
        }
        if (!usersSnap.hasData) {
          return const _LoadingView(label: '載入使用者...');
        }

        final userDocs = usersSnap.data!.docs;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: readsStream,
          builder: (context, readsSnap) {
            if (readsSnap.hasError) {
              return _ErrorView(
                title: '讀取 reads 失敗',
                message: readsSnap.error.toString(),
              );
            }
            if (!readsSnap.hasData) {
              return const _LoadingView(label: '載入已讀名單...');
            }

            final readIds =
                readsSnap.data!.docs.map((d) => d.id).toSet();

            // 未讀 users
            final unreadUsers = userDocs.where((u) {
              return !readIds.contains(u.id);
            }).toList();

            final q = _s(_searchCtrl.text);
            final filtered = unreadUsers.where((u) {
              if (q.isEmpty) return true;
              final d = u.data();
              return _s(u.id).contains(q) ||
                  _s(d['email']).contains(q) ||
                  _s(d['role']).contains(q);
            }).toList();

            return Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Text(
                          '未讀名單',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${filtered.length} 人',
                            style: TextStyle(
                              color: cs.error,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: '搜尋 uid / email / role',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (filtered.isEmpty)
                      Text(
                        '🎉 所有人都已閱讀此公告（或篩選後無結果）',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final u = filtered[i];
                          final d = u.data();

                          final uid = u.id;
                          final role = (d['role'] ?? '').toString();
                          final email = (d['email'] ?? '').toString();

                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.person_outline,
                              size: 20,
                            ),
                            title: Text(
                              uid,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              [
                                if (role.isNotEmpty) role,
                                if (email.isNotEmpty) email,
                              ].join(' ｜ '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color:
                                      cs.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------
// Small UI helpers
// ------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  final String label;
  const _LoadingView({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(child: Text('載入中...')),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;

  const _ErrorView({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: cs.error)),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(
                  color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

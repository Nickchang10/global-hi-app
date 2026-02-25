// lib/pages/messages_page.dart
//
// ✅ MessagesPage（最終完整版｜可直接使用｜清掉 curly_braces_in_flow_control_structures）
// ------------------------------------------------------------
// - Firestore：users/{uid}/messages（通知/訊息中心）
// - 功能：搜尋、已讀/未讀篩選、全部已讀、刪除單筆、刪除已讀
// - Analyzer：
//   ✅ if 單行語句一律加大括號（修正 curly_braces_in_flow_control_structures）
//   ✅ async 後 UI 操作使用 mounted / dialog ctx.mounted（避免 use_build_context_synchronously）
//   ✅ 不使用 withOpacity（改 withValues）
// - Web/App 可用（不使用 dart:io）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _searchCtrl = TextEditingController();
  String _filter = '全部'; // 全部 / 未讀 / 已讀
  bool _sortNewestFirst = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------
  // helpers
  // ---------------------------
  String _s(dynamic v) => v?.toString() ?? '';

  DateTime? _dt(dynamic v) {
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return null;
  }

  bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    final s = _s(v).toLowerCase().trim();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return fallback;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  String _fmtTime(DateTime? d) {
    if (d == null) return '-';
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }

  // ---------------------------
  // firestore
  // ---------------------------
  CollectionReference<Map<String, dynamic>> _msgCol(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('messages');
  }

  // ---------------------------
  // actions
  // ---------------------------
  Future<void> _markAllRead(String uid) async {
    try {
      final qs = await _msgCol(
        uid,
      ).where('read', isEqualTo: false).limit(200).get();

      if (qs.docs.isEmpty) {
        _toast('沒有未讀訊息');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final d in qs.docs) {
        batch.update(d.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      _toast('已全部標記已讀');
    } catch (e) {
      _toast('操作失敗：$e');
    }
  }

  Future<void> _deleteMessage(String uid, String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('刪除訊息'),
          content: const Text('確定要刪除這則訊息嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await _msgCol(uid).doc(docId).delete();
      _toast('已刪除');
    } catch (e) {
      _toast('刪除失敗：$e');
    }
  }

  Future<void> _deleteRead(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('刪除已讀'),
          content: const Text('確定要刪除所有已讀訊息嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      final qs = await _msgCol(
        uid,
      ).where('read', isEqualTo: true).limit(200).get();

      if (qs.docs.isEmpty) {
        _toast('沒有已讀訊息');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final d in qs.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      _toast('已刪除已讀訊息');
    } catch (e) {
      _toast('刪除失敗：$e');
    }
  }

  Future<void> _markRead(String uid, String docId, bool read) async {
    try {
      await _msgCol(uid).doc(docId).update({
        'read': read,
        if (read) 'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _toast('更新失敗：$e');
    }
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('訊息中心'),
        actions: [
          if (user != null) ...[
            IconButton(
              tooltip: '全部已讀',
              icon: const Icon(Icons.done_all_rounded),
              onPressed: () => _markAllRead(user.uid),
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (v) {
                if (v == 'delete_read') {
                  _deleteRead(user.uid);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete_read', child: Text('刪除已讀訊息')),
              ],
            ),
          ],
        ],
      ),
      body: user == null ? _needLogin() : _body(uid: user.uid),
    );
  }

  Widget _needLogin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('請先登入才能查看訊息', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/login'),
              child: const Text('前往登入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body({required String uid}) {
    return Column(
      children: [
        _topBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _msgCol(uid).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _empty(
                  icon: Icons.error_outline,
                  title: '讀取失敗',
                  subtitle: _s(snap.error),
                );
              }
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }

              var rows = snap.data!.docs.map((d) {
                return _MsgRow(id: d.id, data: d.data());
              }).toList();

              // filter read/unread
              rows = rows.where((r) {
                final read = _b(r.data['read'], fallback: false);
                if (_filter == '未讀') return !read;
                if (_filter == '已讀') return read;
                return true;
              }).toList();

              // search
              final q = _searchCtrl.text.trim().toLowerCase();
              if (q.isNotEmpty) {
                rows = rows.where((r) {
                  final title = _s(r.data['title']).toLowerCase();
                  final body = _s(r.data['body']).toLowerCase();
                  final type = _s(r.data['type']).toLowerCase();
                  return title.contains(q) ||
                      body.contains(q) ||
                      type.contains(q);
                }).toList();
              }

              // sort
              rows.sort((a, b) {
                final ta =
                    _dt(a.data['createdAt']) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final tb =
                    _dt(b.data['createdAt']) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final cmp = ta.compareTo(tb);
                return _sortNewestFirst ? -cmp : cmp;
              });

              if (rows.isEmpty) {
                return _empty(
                  icon: Icons.mark_email_read_outlined,
                  title: '沒有訊息',
                  subtitle: '目前沒有符合條件的訊息。',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _msgCard(uid: uid, row: rows[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.03),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7F9),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: '搜尋標題 / 內容 / 類型',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchCtrl.text.trim().isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _searchCtrl.clear()),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: _sortNewestFirst ? '最新優先' : '最舊優先',
                onPressed: () =>
                    setState(() => _sortNewestFirst = !_sortNewestFirst),
                icon: Icon(_sortNewestFirst ? Icons.south : Icons.north),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _chip('全部'),
              const SizedBox(width: 8),
              _chip('未讀'),
              const SizedBox(width: 8),
              _chip('已讀'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    final active = _filter == label;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _filter = label),
      selectedColor: Colors.blue,
      backgroundColor: const Color(0xFFF3F4F6),
      labelStyle: TextStyle(
        color: active ? Colors.white : Colors.black87,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _msgCard({required String uid, required _MsgRow row}) {
    final data = row.data;

    final title = _s(data['title']).trim();
    final body = _s(data['body']).trim();
    final type = _s(data['type']).trim();

    final createdAt = _dt(data['createdAt']);
    final read = _b(data['read'], fallback: false);

    final badgeColor = read ? Colors.grey : Colors.blue;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          // 點進去就標記已讀（示範）
          if (!read) {
            await _markRead(uid, row.id, true);
          }

          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: Text(title.isEmpty ? '訊息' : title),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (type.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '類型：$type',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    Text(body.isEmpty ? '(無內容)' : body),
                    const SizedBox(height: 10),
                    Text(
                      '時間：${_fmtTime(createdAt)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('關閉'),
                  ),
                ],
              );
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  read
                      ? Icons.mark_email_read_outlined
                      : Icons.mark_email_unread_outlined,
                  color: badgeColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? '(無標題)' : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            read ? '已讀' : '未讀',
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body.isEmpty ? '(無內容)' : body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (type.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F7F9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              type,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          _fmtTime(createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: read ? '標記未讀' : '標記已讀',
                          onPressed: () {
                            // ✅ 修正點：if 單行都用大括號（避免 curly_braces_in_flow_control_structures）
                            if (read) {
                              _markRead(uid, row.id, false);
                            } else {
                              _markRead(uid, row.id, true);
                            }
                          },
                          icon: Icon(
                            read
                                ? Icons.mark_email_unread_outlined
                                : Icons.mark_email_read_outlined,
                            size: 20,
                          ),
                        ),
                        IconButton(
                          tooltip: '刪除',
                          onPressed: () => _deleteMessage(uid, row.id),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MsgRow {
  final String id;
  final Map<String, dynamic> data;
  _MsgRow({required this.id, required this.data});
}

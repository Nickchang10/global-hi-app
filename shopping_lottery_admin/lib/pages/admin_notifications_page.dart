// lib/pages/admin_notifications_page.dart
//
// ✅ AdminNotificationsPage（最終完整版 + 發送通知 + 發送紀錄）
//
// - Admin: 可新增 / 編輯 / 停用 / 刪除 / 推送通知
// - Vendor: 僅可查看啟用通知
//
// Firestore:
//   notifications/{docId}               ← 系統公告（Admin維護用）
//   notifications/{uid}/items/{notifId} ← 實際發送的通知（Vendor接收）
//   notifications_global/{notifId}      ← 發送紀錄（供Admin監控）
//
// fields: title, content, isActive(bool), createdAt, updatedAt

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/auth/auth_service.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final _db = FirebaseFirestore.instance;
  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime _toDate(dynamic ts) =>
      ts is Timestamp ? ts.toDate() : (ts is DateTime ? ts : DateTime.now());

  String _fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour}:${d.minute.toString().padLeft(2, '0')}";

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Query<Map<String, dynamic>> _baseQuery() =>
      _db.collection('notifications').orderBy('createdAt', descending: true);

  bool _matchSearch(Map<String, dynamic> m, String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;
    final title = _s(m['title']).toLowerCase();
    final content = _s(m['content']).toLowerCase();
    return title.contains(s) || content.contains(s);
  }

  // ---------------- Dialog ----------------
  Future<void> _openDialog({String? docId, Map<String, dynamic>? data}) async {
    final titleCtrl = TextEditingController(text: data?['title'] ?? '');
    final contentCtrl = TextEditingController(text: data?['content'] ?? '');
    bool isActive = (data?['isActive'] ?? true) == true;
    bool saving = false;

    // ✅ 先抓 root navigator，避免 await 後用到 dialog builder 的 ctx
    final rootNav = Navigator.of(context, rootNavigator: true);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(docId == null ? '新增通知' : '編輯通知'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: '標題',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contentCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: '內容',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('啟用'),
                    value: isActive,
                    onChanged: (v) => setStateDialog(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => rootNav.pop(), child: const Text('取消')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      final content = contentCtrl.text.trim();
                      if (title.isEmpty || content.isEmpty) {
                        _snack('請輸入完整內容');
                        return;
                      }

                      setStateDialog(() => saving = true);
                      try {
                        final col = _db.collection('notifications');
                        if (docId == null) {
                          await col.add({
                            'title': title,
                            'content': content,
                            'isActive': isActive,
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          _snack('已新增通知');
                        } else {
                          await col.doc(docId).update({
                            'title': title,
                            'content': content,
                            'isActive': isActive,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          _snack('已更新通知');
                        }

                        // ✅ await 後只用 State.mounted + rootNav（不再用 ctx）
                        if (!mounted) return;
                        rootNav.pop();
                      } catch (e) {
                        _snack('儲存失敗：$e');
                      } finally {
                        // dialog 可能已被關掉，所以不用 mounted；這裡維持原樣即可
                        setStateDialog(() => saving = false);
                      }
                    },
              child: Text(saving ? '儲存中...' : '儲存'),
            ),
          ],
        ),
      ),
    );

    titleCtrl.dispose();
    contentCtrl.dispose();
  }

  Future<void> _delete(String docId) async {
    final rootNav = Navigator.of(context, rootNavigator: true);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除通知'),
        content: const Text('確定要刪除此通知嗎？此動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => rootNav.pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => rootNav.pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _db.collection('notifications').doc(docId).delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  // ---------------- 發送通知功能 ----------------
  Future<void> _sendNotificationDialog(Map<String, dynamic> notif) async {
    final toUidCtrl = TextEditingController();
    final sendAllVN = ValueNotifier<bool>(true);
    final rootNav = Navigator.of(context, rootNavigator: true);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('發送通知'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('標題：${notif['title']}'),
              Text('內容：${notif['content']}'),
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: sendAllVN,
                builder: (_, sendAll, __) => Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('發送給所有 Vendor'),
                      value: sendAll,
                      onChanged: (v) => sendAllVN.value = v ?? true,
                    ),
                    if (!sendAll)
                      TextField(
                        controller: toUidCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '接收者 UID',
                          isDense: true,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => rootNav.pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => rootNav.pop(true),
            child: const Text('發送'),
          ),
        ],
      ),
    );

    if (ok != true) {
      toUidCtrl.dispose();
      sendAllVN.dispose();
      return;
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'system';
      final role = 'admin';
      final now = Timestamp.now();

      final data = {
        'title': notif['title'] ?? '',
        'body': notif['content'] ?? '',
        'type': 'system',
        'orderId': null,
        'actorUid': uid,
        'actorRole': role,
        'read': false,
        'createdAt': now,
        'extra': <String, dynamic>{},
      };

      if (sendAllVN.value) {
        final vendors = await _db
            .collection('users')
            .where('role', isEqualTo: 'vendor')
            .get();

        for (final v in vendors.docs) {
          await _db
              .collection('notifications')
              .doc(v.id)
              .collection('items')
              .add(data);
        }

        await _db.collection('notifications_global').add({
          'title': notif['title'],
          'body': notif['content'],
          'actorUid': uid,
          'actorRole': role,
          'target': 'all_vendor',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final toUid = toUidCtrl.text.trim();
        if (toUid.isEmpty) {
          _snack('請輸入接收者 UID');
          return;
        }

        await _db
            .collection('notifications')
            .doc(toUid)
            .collection('items')
            .add(data);

        await _db.collection('notifications_global').add({
          'title': notif['title'],
          'body': notif['content'],
          'actorUid': uid,
          'actorRole': role,
          'target': toUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _snack('通知已發送並同步更新');
    } catch (e) {
      _snack('發送失敗：$e');
    } finally {
      toUidCtrl.dispose();
      sendAllVN.dispose();
    }
  }

  // ---------------- Build ----------------
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

        if (_roleFuture == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _roleFuture = gate.ensureAndGetRole(user);
        }

        return FutureBuilder<RoleInfo>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (roleSnap.hasError) {
              return const Scaffold(body: Center(child: Text('讀取權限錯誤')));
            }

            final role = (roleSnap.data?.role ?? '').toLowerCase();
            final isAdmin = role == 'admin';
            final isVendor = role == 'vendor';

            return Scaffold(
              appBar: AppBar(
                title: const Text('通知中心'),
                centerTitle: true,
                actions: [
                  if (isAdmin)
                    IconButton(
                      tooltip: '新增通知',
                      icon: const Icon(Icons.add),
                      onPressed: () => _openDialog(),
                    ),
                  IconButton(
                    tooltip: '登出',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      // ✅ 先抓 navigator，await 後不再直接用 context
                      final nav = Navigator.of(context);

                      gate.clearCache();
                      await authSvc.signOut();

                      if (!mounted) return;
                      nav.pushReplacementNamed('/login');
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _buildNotificationList(isAdmin, isVendor),
                          ),
                          if (isAdmin) ...[
                            const Divider(height: 20),
                            const Text(
                              '最近發送紀錄',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Expanded(child: _buildSendHistoryList()),
                          ],
                        ],
                      ),
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

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: '搜尋通知（標題/內容）',
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: _q.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _q = '');
                },
              ),
      ),
      onChanged: (v) => setState(() => _q = v),
    );
  }

  Widget _buildNotificationList(bool isAdmin, bool isVendor) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _baseQuery().snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs.where((d) {
          final m = d.data();
          if (isVendor && !(m['isActive'] ?? false)) return false;
          return _matchSearch(m, _q);
        }).toList();

        if (docs.isEmpty) return const Center(child: Text('目前沒有通知'));

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = docs[i];
            final m = d.data();

            final title = _s(m['title']);
            final content = _s(m['content']);
            final active = (m['isActive'] ?? true) == true;
            final createdAt = _toDate(m['createdAt']);

            return ListTile(
              title: Text(
                title.isEmpty ? '(未命名通知)' : title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${_fmt(createdAt)}\n${content.isEmpty ? '(無內容)' : content}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isAdmin
                  ? PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _openDialog(docId: d.id, data: m);
                        if (v == 'toggle') {
                          _db.collection('notifications').doc(d.id).update({
                            'isActive': !active,
                          });
                        }
                        if (v == 'delete') _delete(d.id);
                        if (v == 'send') _sendNotificationDialog(m);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('編輯')),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(active ? '停用' : '啟用'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'send', child: Text('發送通知')),
                        const PopupMenuItem(value: 'delete', child: Text('刪除')),
                      ],
                    )
                  : Switch(value: active, onChanged: null),
              onTap: () {
                final rootNav = Navigator.of(context, rootNavigator: true);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(title),
                    content: Text(content),
                    actions: [
                      TextButton(
                        onPressed: () => rootNav.pop(),
                        child: const Text('關閉'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSendHistoryList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('notifications_global')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Text('尚無發送紀錄');

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final m = docs[i].data();
            final t = _toDate(m['createdAt']);
            return ListTile(
              title: Text(m['title'] ?? '(未命名通知)'),
              subtitle: Text(
                '${_fmt(t)} 由 ${m['actorRole']} 發送 → ${m['target']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        );
      },
    );
  }
}

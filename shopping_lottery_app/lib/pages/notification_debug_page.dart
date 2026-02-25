import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ NotificationDebugPage（通知 Debug｜修改後完整版｜不使用 target:）
/// ------------------------------------------------------------
/// ✅ 修正重點：
/// - 完全不依賴任何 `target:` named parameter
/// - 改用 Firestore 寫入通知資料（可選寫到 user 子集合或全域 notifications）
/// - ✅ 修正 Flutter deprecation：DropdownButtonFormField 的 value -> initialValue
///
/// Firestore 建議結構（擇一或兩者並用）：
/// A) users/{uid}/notifications/{nid}
///   - title: String
///   - body: String
///   - type: String            // e.g. "system" "order" "coupon"
///   - route: String?          // 點擊後要導到哪個 route（例如 "/orders"）
///   - data: Map<String,dynamic>? // 參數（可選）
///   - isRead: bool
///   - createdAt: Timestamp
///
/// B) notifications/{nid}
///   - uid: String             // 收件人 uid
///   - title/body/type/route/data/isRead/createdAt 同上
/// ------------------------------------------------------------
class NotificationDebugPage extends StatefulWidget {
  const NotificationDebugPage({super.key});

  @override
  State<NotificationDebugPage> createState() => _NotificationDebugPageState();
}

class _NotificationDebugPageState extends State<NotificationDebugPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _busy = false;

  final _titleCtrl = TextEditingController(text: '測試通知標題');
  final _bodyCtrl = TextEditingController(text: '這是一則測試通知內容');
  final _routeCtrl = TextEditingController(text: '/messages');

  String _type = 'system';
  bool _writeToUserSubcollection = true; // users/{uid}/notifications
  bool _alsoWriteToGlobal = false; // notifications

  User? get _user => _auth.currentUser;

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _fs.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _userNotiRef(String uid) =>
      _userRef(uid).collection('notifications');

  CollectionReference<Map<String, dynamic>> get _globalNotiRef =>
      _fs.collection('notifications');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _routeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: uid == null ? _needLogin(context) : _body(uid),
    );
  }

  Widget _needLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能使用通知 Debug',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/login'),
                    child: const Text('前往登入'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(String uid) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('建立測試通知'),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'title',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bodyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'body',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // ✅ FIX: value 已 deprecated -> 改 initialValue
                        initialValue: _type,
                        items: const [
                          DropdownMenuItem(
                            value: 'system',
                            child: Text('system'),
                          ),
                          DropdownMenuItem(
                            value: 'order',
                            child: Text('order'),
                          ),
                          DropdownMenuItem(
                            value: 'coupon',
                            child: Text('coupon'),
                          ),
                          DropdownMenuItem(
                            value: 'lottery',
                            child: Text('lottery'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? 'system'),
                        decoration: const InputDecoration(
                          labelText: 'type',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _routeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'route（可選）',
                          hintText: '/messages',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: _writeToUserSubcollection,
                  onChanged: (v) =>
                      setState(() => _writeToUserSubcollection = v),
                  title: const Text('寫入 users/{uid}/notifications'),
                  subtitle: const Text('推薦：通知中心通常讀這裡'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: _alsoWriteToGlobal,
                  onChanged: (v) => setState(() => _alsoWriteToGlobal = v),
                  title: const Text('同時寫入 notifications（全域）'),
                  subtitle: const Text('可做後台統一派發/查詢用'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _send(uid),
                        icon: const Icon(Icons.send),
                        label: const Text('送出測試通知'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _createDemoBatch(uid),
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('批次建立 5 則'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('我的通知（users/{uid}/notifications）'),
        const SizedBox(height: 8),
        _userNotificationList(uid),
        const SizedBox(height: 16),
        _sectionTitle('快速動作'),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.mark_email_read_outlined),
                title: const Text(
                  '全部標記已讀',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                onTap: _busy ? null : () => _markAllRead(uid),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text(
                  '清空通知（最多 200）',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('只會刪 user 子集合通知，不動全域 notifications'),
                onTap: _busy ? null : () => _clearUserNotifications(uid),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '註：此檔案已完全移除任何 target: 參數使用，確保可編譯。',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _userNotificationList(String uid) {
    final stream = _userNotiRef(
      uid,
    ).orderBy('createdAt', descending: true).limit(50).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return _error('讀取通知失敗：${snap.error}');
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) return _empty('目前沒有通知');

        return Column(children: [for (final d in docs) _notiTile(uid, d)]);
      },
    );
  }

  Widget _notiTile(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    final title = _s(d['title'], '');
    final body = _s(d['body'], '');
    final type = _s(d['type'], 'system');
    final route = _s(d['route'], '');
    final isRead = (d['isRead'] ?? false) == true;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          isRead ? Icons.notifications_none : Icons.notifications_active,
        ),
        title: Text(
          title.isEmpty ? '(無標題)' : title,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: isRead ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          [
            if (body.isNotEmpty) body,
            'type=$type',
            if (route.isNotEmpty) 'route=$route',
            'id=${doc.id}',
          ].join('\n'),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'read') _markRead(uid, doc.id, true);
            if (v == 'unread') _markRead(uid, doc.id, false);
            if (v == 'delete') _delete(uid, doc.id);
            if (v == 'nav' && route.isNotEmpty) _navigate(route);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: isRead ? 'unread' : 'read',
              child: Text(isRead ? '標記未讀' : '標記已讀'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('刪除')),
            if (route.isNotEmpty)
              const PopupMenuItem(value: 'nav', child: Text('測試導航（route）')),
          ],
        ),
        onTap: () async {
          if (!isRead) await _markRead(uid, doc.id, true);
        },
      ),
    );
  }

  void _navigate(String route) {
    Navigator.of(context).pushNamed(route);
  }

  Future<void> _send(String uid) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final title = _titleCtrl.text.trim();
      final body = _bodyCtrl.text.trim();
      final route = _routeCtrl.text.trim();

      final payload = <String, dynamic>{
        'uid': uid,
        'title': title.isEmpty ? '測試通知' : title,
        'body': body.isEmpty ? '（無內容）' : body,
        'type': _type,
        'route': route.isEmpty ? null : route,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final batch = _fs.batch();

      if (_writeToUserSubcollection) {
        final id = _userNotiRef(uid).doc().id;
        batch.set(_userNotiRef(uid).doc(id), payload);
      }

      if (_alsoWriteToGlobal) {
        final id = _globalNotiRef.doc().id;
        batch.set(_globalNotiRef.doc(id), payload);
      }

      if (!_writeToUserSubcollection && !_alsoWriteToGlobal) {
        throw '至少勾選一種寫入方式（user 子集合 或 全域 notifications）';
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已送出測試通知')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 送出失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createDemoBatch(String uid) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final batch = _fs.batch();
      for (int i = 1; i <= 5; i++) {
        final payload = <String, dynamic>{
          'uid': uid,
          'title': 'Demo 通知 #$i',
          'body': '這是第 $i 則示範通知',
          'type': 'system',
          'route': '/messages',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (_writeToUserSubcollection) {
          final id = _userNotiRef(uid).doc().id;
          batch.set(_userNotiRef(uid).doc(id), payload);
        }
        if (_alsoWriteToGlobal) {
          final id = _globalNotiRef.doc().id;
          batch.set(_globalNotiRef.doc(id), payload);
        }
      }

      if (!_writeToUserSubcollection && !_alsoWriteToGlobal) {
        throw '至少勾選一種寫入方式（user 子集合 或 全域 notifications）';
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已批次建立 5 則通知')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 建立失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markRead(String uid, String notiId, bool isRead) async {
    try {
      await _userNotiRef(
        uid,
      ).doc(notiId).set({'isRead': isRead}, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 更新失敗：$e')));
    }
  }

  Future<void> _delete(String uid, String notiId) async {
    try {
      await _userNotiRef(uid).doc(notiId).delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 刪除失敗：$e')));
    }
  }

  Future<void> _markAllRead(String uid) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final snap = await _userNotiRef(
        uid,
      ).orderBy('createdAt', descending: true).limit(200).get();

      final batch = _fs.batch();
      for (final d in snap.docs) {
        batch.set(d.reference, {'isRead': true}, SetOptions(merge: true));
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已全部標記已讀')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 操作失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearUserNotifications(String uid) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final snap = await _userNotiRef(uid).limit(200).get();
      final batch = _fs.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ 已清空通知（最多 200）')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 清空失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }

  Widget _empty(String text) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _error(String text) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

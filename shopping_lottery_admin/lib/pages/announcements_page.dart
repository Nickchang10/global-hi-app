// lib/pages/announcements_page.dart
//
// ✅ AnnouncementsPage（最終完整版｜可編譯｜Admin Only｜CRUD＋推播通知）
//
// 功能：
// - Admin Only：公告 CRUD、啟用/停用、搜尋、篩選
// - 公告資料：announcements/{id}
// - 推播：寫入 notifications/{uid}/items/{notificationId}
//   - type: 'announcement'
//   - extra: { announcementId, audience }
//
// Firestore 結構建議：
// announcements/{announcementId}
//   - title: String
//   - body: String
//   - audience: String  (all / admins / vendors)
//   - isActive: bool
//   - publishAt: Timestamp? (可選)
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//   - authorUid: String
//
// users/{uid}（用於查 audience）
//   - role: 'admin' / 'vendor' / ...
//
// 依賴：
// - cloud_firestore
// - firebase_auth
// - flutter/services
// - provider
// - services/admin_gate.dart
// - services/notification_service.dart
//
// ------------------------------------------------------------

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/notification_service.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final _db = FirebaseFirestore.instance;

  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  String _q = '';
  bool? _isActive; // null=全部
  String? _selectedId;

  bool _pushing = false;

  // ---------- utils ----------
  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _b(dynamic v) => v == true;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      try {
        if (v < 10000000000) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {}
    }
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  // ---------- query ----------
  Stream<QuerySnapshot<Map<String, dynamic>>> _queryStream() {
    Query<Map<String, dynamic>> q = _db
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(800);

    if (_isActive != null) {
      q = q.where('isActive', isEqualTo: _isActive);
    }

    return q.snapshots();
  }

  bool _match(String id, Map<String, dynamic> d) {
    final t = _q.trim().toLowerCase();
    if (t.isEmpty) return true;
    final title = _s(d['title']).toLowerCase();
    final body = _s(d['body']).toLowerCase();
    final aid = id.toLowerCase();
    final aud = _s(d['audience']).toLowerCase();
    return aid.contains(t) || title.contains(t) || body.contains(t) || aud.contains(t);
  }

  // ---------- CRUD ----------
  Future<void> _toggleActive(String id, bool v) async {
    final aid = id.trim();
    if (aid.isEmpty) return;

    try {
      await _db.collection('announcements').doc(aid).set(
        <String, dynamic>{
          'isActive': v,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _snack('公告 $aid 已${v ? '啟用' : '停用'}');
    } catch (e) {
      _snack('操作失敗：$e');
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    final aid = id.trim();
    if (aid.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除公告'),
        content: Text('確定要刪除 $aid 嗎？（不可復原）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _db.collection('announcements').doc(aid).delete();
      _snack('已刪除公告：$aid');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final base = initial ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return DateTime(date.year, date.month, date.day);

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _openEditDialog({
    String? id,
    Map<String, dynamic>? data,
    required String authorUid,
  }) async {
    final isCreate = (id == null || id.trim().isEmpty);

    final idCtrl = TextEditingController(text: isCreate ? '' : id);
    final titleCtrl = TextEditingController(text: _s(data?['title']));
    final bodyCtrl = TextEditingController(text: _s(data?['body']));
    final noteCtrl = TextEditingController(text: _s(data?['note']));

    String audience = _s(data?['audience']).isEmpty ? 'all' : _s(data?['audience']);
    bool isActive = data == null ? true : _b(data['isActive']);
    DateTime? publishAt = _toDate(data?['publishAt']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isCreate ? '新增公告' : '編輯公告'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCreate) ...[
                  TextField(
                    controller: idCtrl,
                    decoration: const InputDecoration(
                      labelText: 'announcementId（可留空自動產生）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '標題',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: '內容',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: audience,
                  decoration: const InputDecoration(
                    labelText: '受眾 audience',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('all（全部）')),
                    DropdownMenuItem(value: 'admins', child: Text('admins（僅管理員）')),
                    DropdownMenuItem(value: 'vendors', child: Text('vendors（僅廠商）')),
                  ],
                  onChanged: (v) => audience = (v ?? 'all'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('啟用（可被前台看到/推播）'),
                  value: isActive,
                  onChanged: (v) => isActive = v,
                ),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('發布時間 publishAt（可選）'),
                  subtitle: Text(publishAt == null ? '未設定' : _fmt(publishAt)),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final picked = await _pickDateTime(publishAt);
                          if (picked != null) {
                            publishAt = picked;
                            // ignore: use_build_context_synchronously
                            Navigator.pop(context, false);
                            // 重新開一次，避免 StatefulBuilder 複雜化
                            _openEditDialog(id: id, data: {
                              ...(data ?? <String, dynamic>{}),
                              'title': titleCtrl.text,
                              'body': bodyCtrl.text,
                              'audience': audience,
                              'isActive': isActive,
                              'publishAt': Timestamp.fromDate(publishAt!),
                              'note': noteCtrl.text,
                            }, authorUid: authorUid);
                          }
                        },
                        child: const Text('選擇'),
                      ),
                      TextButton(
                        onPressed: () {
                          publishAt = null;
                          Navigator.pop(context, false);
                          _openEditDialog(id: id, data: {
                            ...(data ?? <String, dynamic>{}),
                            'title': titleCtrl.text,
                            'body': bodyCtrl.text,
                            'audience': audience,
                            'isActive': isActive,
                            'publishAt': null,
                            'note': noteCtrl.text,
                          }, authorUid: authorUid);
                        },
                        child: const Text('清除'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '備註（可選）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('儲存')),
        ],
      ),
    );

    if (ok != true) {
      idCtrl.dispose();
      titleCtrl.dispose();
      bodyCtrl.dispose();
      noteCtrl.dispose();
      return;
    }

    final title = titleCtrl.text.trim();
    final body = bodyCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _snack('標題與內容不可為空');
      idCtrl.dispose();
      titleCtrl.dispose();
      bodyCtrl.dispose();
      noteCtrl.dispose();
      return;
    }

    try {
      if (isCreate) {
        final customId = idCtrl.text.trim();
        final ref = customId.isEmpty
            ? _db.collection('announcements').doc()
            : _db.collection('announcements').doc(customId);

        await ref.set(<String, dynamic>{
          'title': title,
          'body': body,
          'audience': audience,
          'isActive': isActive,
          'note': noteCtrl.text.trim(),
          if (publishAt != null) 'publishAt': Timestamp.fromDate(publishAt!),
          'authorUid': authorUid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        _snack('已新增公告：${ref.id}');
      } else {
        final aid = id!.trim();
        await _db.collection('announcements').doc(aid).set(<String, dynamic>{
          'title': title,
          'body': body,
          'audience': audience,
          'isActive': isActive,
          'note': noteCtrl.text.trim(),
          'publishAt': publishAt == null ? FieldValue.delete() : Timestamp.fromDate(publishAt!),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        _snack('已更新公告：$aid');
      }
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      idCtrl.dispose();
      titleCtrl.dispose();
      bodyCtrl.dispose();
      noteCtrl.dispose();
    }
  }

  // ---------- push notifications ----------
  Future<List<String>> _resolveAudienceUids(String audience, {int limit = 200}) async {
    // audience: all / admins / vendors
    final aud = audience.trim().isEmpty ? 'all' : audience.trim().toLowerCase();

    Query<Map<String, dynamic>> q = _db.collection('users');

    if (aud == 'admins') {
      q = q.where('role', isEqualTo: 'admin');
    } else if (aud == 'vendors') {
      q = q.where('role', isEqualTo: 'vendor');
    } else {
      // all：不加 where
    }

    final snap = await q.limit(limit.clamp(1, 500)).get();
    return snap.docs.map((d) => d.id).where((e) => e.trim().isNotEmpty).toList();
  }

  Future<void> _pushToUids({
    required List<String> uids,
    required String title,
    required String body,
    required String announcementId,
    required String audience,
  }) async {
    if (_pushing) return;
    setState(() => _pushing = true);

    try {
      final clean = uids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
      if (clean.isEmpty) {
        _snack('沒有可推播的對象');
        return;
      }

      // 分批 batch（每批 450 保守）
      const page = 450;
      int idx = 0;

      while (idx < clean.length) {
        final chunk = clean.skip(idx).take(page).toList();
        final batch = _db.batch();

        for (final uid in chunk) {
          final ref = _db.collection('notifications').doc(uid).collection('items').doc();
          batch.set(ref, <String, dynamic>{
            'title': title,
            'body': body,
            'type': 'announcement',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'extra': <String, dynamic>{
              'announcementId': announcementId,
              'audience': audience,
            },
          }, SetOptions(merge: true));
        }

        await batch.commit();
        idx += chunk.length;
      }

      _snack('已推播 ${clean.length} 則通知');
    } catch (e) {
      _snack('推播失敗：$e');
    } finally {
      if (mounted) setState(() => _pushing = false);
    }
  }

  Future<void> _openPushSheet({
    required String announcementId,
    required Map<String, dynamic> data,
    required String myUid,
  }) async {
    final title = _s(data['title']);
    final body = _s(data['body']);
    final audience = _s(data['audience']).isEmpty ? 'all' : _s(data['audience']);

    if (title.isEmpty || body.isEmpty) {
      _snack('公告標題/內容為空，無法推播');
      return;
    }

    final uidCtrl = TextEditingController();
    int limit = 200;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 14,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              Widget secTitle(String t) => Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
                  );

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('推播公告', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        ),
                        if (_pushing) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('公告：$announcementId', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(body, maxLines: 4, overflow: TextOverflow.ellipsis),
                    const Divider(height: 20),

                    secTitle('快速推播'),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pushing
                                ? null
                                : () async {
                                    Navigator.pop(context);
                                    await _pushToUids(
                                      uids: [myUid],
                                      title: title,
                                      body: body,
                                      announcementId: announcementId,
                                      audience: 'me',
                                    );
                                  },
                            icon: const Icon(Icons.person_outline),
                            label: const Text('推播給我自己'),
                          ),
                        ),
                      ],
                    ),

                    secTitle('推播給指定 UID'),
                    TextField(
                      controller: uidCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: '輸入 uid（例如 FirebaseAuth uid）',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _pushing
                                ? null
                                : () async {
                                    final uid = uidCtrl.text.trim();
                                    if (uid.isEmpty) return;
                                    Navigator.pop(context);
                                    await _pushToUids(
                                      uids: [uid],
                                      title: title,
                                      body: body,
                                      announcementId: announcementId,
                                      audience: 'uid',
                                    );
                                  },
                            icon: const Icon(Icons.send_outlined),
                            label: const Text('推播'),
                          ),
                        ),
                      ],
                    ),

                    secTitle('依 audience 批次推播'),
                    Text('audience：$audience（從 users/{uid}.role 取得）',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('limit：'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: limit.toDouble(),
                            min: 50,
                            max: 500,
                            divisions: 9,
                            label: '$limit',
                            onChanged: (v) => setLocal(() => limit = v.round()),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text('$limit', textAlign: TextAlign.end),
                        ),
                      ],
                    ),
                    Text(
                      '提示：大量全量推播建議用 Cloud Function/後端批次；此頁面預設安全上限 500。',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _pushing
                                ? null
                                : () async {
                                    Navigator.pop(context);
                                    final uids = await _resolveAudienceUids(audience, limit: limit);
                                    await _pushToUids(
                                      uids: uids,
                                      title: title,
                                      body: body,
                                      announcementId: announcementId,
                                      audience: audience,
                                    );
                                  },
                            icon: const Icon(Icons.campaign_outlined),
                            label: const Text('開始推播'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    uidCtrl.dispose();
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final notifSvc = context.read<NotificationService>(); // 確保 Provider 有提供（此頁用 batch 寫入，但仍依賴結構一致）
    // ignore: unused_local_variable
    final _ = notifSvc;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        if (_roleFuture == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);
          _selectedId = null;
        }

        return FutureBuilder<RoleInfo>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (roleSnap.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('公告管理')),
                body: Center(child: Text('讀取角色失敗：${roleSnap.error}')),
              );
            }

            final info = roleSnap.data;
            final role = _s(info?.role).toLowerCase();
            final isAdmin = role == 'admin';

            if (!isAdmin) {
              return Scaffold(
                appBar: AppBar(title: const Text('公告管理')),
                body: const Center(child: Text('此頁僅限 Admin 使用')),
              );
            }

            final cs = Theme.of(context).colorScheme;

            return Scaffold(
              appBar: AppBar(
                title: const Text('公告管理', style: TextStyle(fontWeight: FontWeight.w900)),
                actions: [
                  IconButton(
                    tooltip: '新增公告',
                    onPressed: () => _openEditDialog(authorUid: user.uid),
                    icon: const Icon(Icons.add_box_outlined),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _queryStream(),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snap.data!.docs;
                  final list = docs
                      .map((d) => _AnnRow(id: d.id, data: d.data()))
                      .where((r) => _match(r.id, r.data))
                      .toList();

                  Widget filters() {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 320,
                            child: TextField(
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.search),
                                hintText: '搜尋：id / 標題 / 內容 / audience',
                              ),
                              onChanged: (v) => setState(() => _q = v),
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<bool?>(
                              value: _isActive,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                labelText: '狀態',
                              ),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('全部')),
                                DropdownMenuItem(value: true, child: Text('啟用')),
                                DropdownMenuItem(value: false, child: Text('停用')),
                              ],
                              onChanged: (v) => setState(() => _isActive = v),
                            ),
                          ),
                          Text('共 ${list.length} 項', style: TextStyle(color: cs.onSurfaceVariant)),
                          if (_pushing) ...[
                            const SizedBox(width: 10),
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            Text('推播中...', style: TextStyle(color: cs.onSurfaceVariant)),
                          ],
                        ],
                      ),
                    );
                  }

                  Widget tile(_AnnRow r, bool isWide) {
                    final d = r.data;
                    final title = _s(d['title']).isEmpty ? '（無標題）' : _s(d['title']);
                    final body = _s(d['body']);
                    final aud = _s(d['audience']).isEmpty ? 'all' : _s(d['audience']);
                    final active = _b(d['isActive']);
                    final createdAt = _toDate(d['createdAt']);
                    final publishAt = _toDate(d['publishAt']);
                    final selected = r.id == _selectedId;

                    return ListTile(
                      selected: selected,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Pill(label: active ? '啟用' : '停用', color: active ? cs.primary : cs.error),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              children: [
                                Text('ID：${r.id}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                Text('audience：$aud', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                Text('建立：${_fmt(createdAt)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                if (publishAt != null)
                                  Text('發布：${_fmt(publishAt)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                              ],
                            ),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                      leading: const Icon(Icons.campaign_outlined),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: '複製公告ID',
                            onPressed: () => _copy(r.id, done: '已複製公告ID'),
                            icon: const Icon(Icons.copy, size: 20),
                          ),
                          Switch(
                            value: active,
                            onChanged: (v) => _toggleActive(r.id, v),
                          ),
                          PopupMenuButton<String>(
                            tooltip: '更多',
                            onSelected: (v) async {
                              if (v == 'push') {
                                await _openPushSheet(
                                  announcementId: r.id,
                                  data: d,
                                  myUid: user.uid,
                                );
                              } else if (v == 'edit') {
                                await _openEditDialog(id: r.id, data: d, authorUid: user.uid);
                              } else if (v == 'delete') {
                                await _deleteAnnouncement(r.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'push', child: Text('推播通知')),
                              PopupMenuDivider(),
                              PopupMenuItem(value: 'edit', child: Text('編輯')),
                              PopupMenuDivider(),
                              PopupMenuItem(value: 'delete', child: Text('刪除')),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() => _selectedId = r.id);
                        if (!isWide) {
                          showDialog(
                            context: context,
                            builder: (_) => _AnnDetailDialog(
                              id: r.id,
                              data: d,
                              onCopy: () => _copy(r.id, done: '已複製公告ID'),
                              onEdit: () => _openEditDialog(id: r.id, data: d, authorUid: user.uid),
                              onPush: () => _openPushSheet(announcementId: r.id, data: d, myUid: user.uid),
                            ),
                          );
                        }
                      },
                    );
                  }

                  return Column(
                    children: [
                      filters(),
                      const Divider(height: 1),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final isWide = c.maxWidth > 980;

                            return Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: list.isEmpty
                                      ? Center(child: Text('沒有資料', style: TextStyle(color: cs.onSurfaceVariant)))
                                      : ListView.separated(
                                          itemCount: list.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1),
                                          itemBuilder: (_, i) => tile(list[i], isWide),
                                        ),
                                ),
                                if (isWide) const VerticalDivider(width: 1),
                                if (isWide)
                                  Expanded(
                                    flex: 2,
                                    child: _selectedId == null
                                        ? Center(child: Text('請選擇一則公告', style: TextStyle(color: cs.onSurfaceVariant)))
                                        : _AnnDetailPanel(
                                            id: _selectedId!,
                                            data: list.firstWhere((e) => e.id == _selectedId, orElse: () => _AnnRow(id: '', data: const {})).data,
                                            onCopy: () => _copy(_selectedId!, done: '已複製公告ID'),
                                            onEdit: () {
                                              final row = list.firstWhere((e) => e.id == _selectedId, orElse: () => _AnnRow(id: '', data: const {}));
                                              if (row.id.isEmpty) return;
                                              _openEditDialog(id: row.id, data: row.data, authorUid: user.uid);
                                            },
                                            onPush: () {
                                              final row = list.firstWhere((e) => e.id == _selectedId, orElse: () => _AnnRow(id: '', data: const {}));
                                              if (row.id.isEmpty) return;
                                              _openPushSheet(announcementId: row.id, data: row.data, myUid: user.uid);
                                            },
                                          ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------
// Models
// ------------------------------------------------------------
class _AnnRow {
  final String id;
  final Map<String, dynamic> data;
  _AnnRow({required this.id, required this.data});
}

// ------------------------------------------------------------
// Detail UI
// ------------------------------------------------------------
class _AnnDetailPanel extends StatelessWidget {
  const _AnnDetailPanel({
    required this.id,
    required this.data,
    required this.onCopy,
    required this.onEdit,
    required this.onPush,
  });

  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onPush;

  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _b(dynamic v) => v == true;

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (id.trim().isEmpty || data.isEmpty) return const Center(child: Text('無資料'));

    final cs = Theme.of(context).colorScheme;
    final title = _s(data['title']).isEmpty ? '（無標題）' : _s(data['title']);
    final body = _s(data['body']);
    final aud = _s(data['audience']).isEmpty ? 'all' : _s(data['audience']);
    final active = _b(data['isActive']);
    final createdAt = _toDate(data['createdAt']);
    final updatedAt = _toDate(data['updatedAt']);
    final publishAt = _toDate(data['publishAt']);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              const SizedBox(width: 8),
              _Pill(label: active ? '啟用' : '停用', color: active ? cs.primary : cs.error),
            ],
          ),
          const SizedBox(height: 10),
          Text('公告ID：$id', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('audience：$aud', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('建立：${_fmt(createdAt)}', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('更新：${_fmt(updatedAt)}', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('發布：${publishAt == null ? '未設定' : _fmt(publishAt)}', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          const Text('內容', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Text(body.isEmpty ? '（無內容）' : body),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy),
                  label: const Text('複製 ID'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('編輯'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onPush,
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('推播通知'),
          ),
        ],
      ),
    );
  }
}

class _AnnDetailDialog extends StatelessWidget {
  const _AnnDetailDialog({
    required this.id,
    required this.data,
    required this.onCopy,
    required this.onEdit,
    required this.onPush,
  });

  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onPush;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(
        width: 520,
        height: 520,
        child: _AnnDetailPanel(
          id: id,
          data: data,
          onCopy: onCopy,
          onEdit: () {
            Navigator.pop(context);
            onEdit();
          },
          onPush: () {
            Navigator.pop(context);
            onPush();
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Small pill chip
// ------------------------------------------------------------
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

// lib/pages/admin_contacts_page.dart
//
// ✅ AdminContactsPage（聯絡人/會員名單｜可編譯完整版）
// ------------------------------------------------------------
// - 讀取 users 集合（最多 500）
// - 搜尋：name / email / phone / uid
// - 勾選多位用戶，批次發送通知
// - 呼叫 NotificationService.sendToUsers(uids:, title:, body:, type:, route:)
//   ✅ 修正：參數改用 route（你的 NotificationService 沒有 deepLink）
// - ✅ 修正：use_build_context_synchronously（徹底避免跨 async gap 再用 context）
//    1) await 前先取 messenger / notifier
//    2) showDialog actions 內 pop 一律使用 dialogCtx
//    3) await 後若需操作 UI，使用 if (!mounted) return;（符合 State.context 規則）
// - ✅ 修正：withOpacity deprecated（若你的 SDK 有提示）-> withValues(alpha: ...)
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';

class AdminContactsPage extends StatefulWidget {
  const AdminContactsPage({super.key});

  @override
  State<AdminContactsPage> createState() => _AdminContactsPageState();
}

class _AdminContactsPageState extends State<AdminContactsPage> {
  final _db = FirebaseFirestore.instance;

  final _search = TextEditingController();

  // send form
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _route = TextEditingController(); // UI 可叫 deepLink，但 service 用 route

  String _type = 'general';

  bool _loading = true;
  String? _error;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _title.dispose();
    _body.dispose();
    _route.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Query<Map<String, dynamic>> q = _db.collection('users');

      try {
        final snap = await q
            .orderBy('createdAt', descending: true)
            .limit(500)
            .get();
        _docs = snap.docs;
      } catch (_) {
        final snap = await q
            .orderBy(FieldPath.documentId, descending: true)
            .limit(500)
            .get();
        _docs = snap.docs;
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _docs;

    return _docs.where((doc) {
      final d = doc.data();
      final uid = doc.id.toLowerCase();
      final name = _s(d['displayName'] ?? d['name']).toLowerCase();
      final email = _s(d['email']).toLowerCase();
      final phone = _s(d['phone']).toLowerCase();
      return uid.contains(q) ||
          name.contains(q) ||
          email.contains(q) ||
          phone.contains(q);
    }).toList();
  }

  bool get _allVisibleSelected {
    final visible = _filtered;
    if (visible.isEmpty) return false;
    return visible.every((d) => _selected.contains(d.id));
  }

  void _toggleSelectAllVisible() {
    final visible = _filtered;
    if (visible.isEmpty) return;

    final all = _allVisibleSelected;
    setState(() {
      if (all) {
        for (final d in visible) {
          _selected.remove(d.id);
        }
      } else {
        for (final d in visible) {
          _selected.add(d.id);
        }
      }
    });
  }

  Future<void> _sendToSelected() async {
    // ✅ await 前先取出（避免跨 async gap 再用 context）
    final notifier = context.read<NotificationService>();
    final messenger = ScaffoldMessenger.of(context);

    final title = _title.text.trim();
    final body = _body.text.trim();
    final route = _route.text.trim();

    if (_selected.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('請先勾選至少 1 位會員')));
      return;
    }
    if (title.isEmpty || body.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('title / body 不可為空')),
      );
      return;
    }

    // ✅ Dialog 內 pop 一律用 dialogCtx
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text(
            '確認發送',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            '將發送通知給 ${_selected.length} 位會員。\n\n標題：$title\n類型：$_type',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('確認送出'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await notifier.sendToUsers(
        uids: _selected.toList(),
        title: title,
        body: body,
        type: _type,
        route: route.isEmpty ? null : route,
      );

      // ✅ await 後若要更新 UI：用 State 的 mounted（符合 lint）
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已送出通知')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('送出失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '聯絡人 / 會員',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null && _docs.isEmpty)
          ? Center(child: Text('載入失敗：$_error'))
          : Column(
              children: [
                _topBar(cs),
                const Divider(height: 1),
                Expanded(child: _list()),
                const Divider(height: 1),
                _sendPanel(cs),
              ],
            ),
    );
  }

  Widget _topBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋 name / email / phone / uid',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _toggleSelectAllVisible,
            icon: Icon(
              _allVisibleSelected
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            label: Text(_allVisibleSelected ? '取消全選(可見)' : '全選(可見)'),
          ),
          const SizedBox(width: 10),
          Chip(
            label: Text('已選 ${_selected.length}'),
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    final list = _filtered;
    if (list.isEmpty) return const Center(child: Text('無符合條件的會員'));

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final doc = list[i];
        final d = doc.data();

        final uid = doc.id;
        final name = _s(d['displayName'] ?? d['name']);
        final email = _s(d['email']);
        final phone = _s(d['phone']);
        final role = _s(d['role']).isEmpty ? 'user' : _s(d['role']);

        final checked = _selected.contains(uid);

        return ListTile(
          leading: Checkbox(
            value: checked,
            onChanged: (v) => setState(() {
              if (v == true) {
                _selected.add(uid);
              } else {
                _selected.remove(uid);
              }
            }),
          ),
          title: Text(
            name.isNotEmpty ? name : uid,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            [
              'uid: $uid',
              if (email.isNotEmpty) 'email: $email',
              if (phone.isNotEmpty) 'phone: $phone',
              'role: $role',
            ].join('  •  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => setState(() {
            if (checked) {
              _selected.remove(uid);
            } else {
              _selected.add(uid);
            }
          }),
        );
      },
    );
  }

  Widget _sendPanel(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: '通知標題 title',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('general')),
                  DropdownMenuItem(value: 'promo', child: Text('promo')),
                  DropdownMenuItem(value: 'system', child: Text('system')),
                  DropdownMenuItem(value: 'order', child: Text('order')),
                  DropdownMenuItem(value: 'sos', child: Text('sos')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'general'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _body,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '通知內容 body',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _route,
            decoration: const InputDecoration(
              labelText: 'route（可留空）',
              hintText: '/orders/xxx 或 /notifications',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty ? null : _sendToSelected,
                  icon: const Icon(Icons.send),
                  label: Text(
                    _selected.isEmpty
                        ? '請先勾選會員'
                        : '發送給已選會員（${_selected.length}）',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '✅ 已修正：通知服務使用 route 參數（不是 deepLink）。',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

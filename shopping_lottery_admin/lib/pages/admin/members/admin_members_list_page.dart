// lib/pages/admin/members/admin_members_list_page.dart
//
// ✅ AdminMembersListPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：Dart 3 "_" wildcard 不可讀 -> builder 改用 dialogCtx/sheetCtx
// ✅ 修正：use_build_context_synchronously（async gap 後皆 guarded）
// ✅ Firestore：users
// ✅ 功能：搜尋（uid / displayName / email）、列表顯示 points / updatedAt
// ✅ 快捷：複製 uid、開啟點數/任務、刪除會員（可選）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// 若路徑不同請自行調整
import 'admin_member_points_tasks_page.dart';

class AdminMembersListPage extends StatefulWidget {
  const AdminMembersListPage({super.key});

  @override
  State<AdminMembersListPage> createState() => _AdminMembersListPageState();
}

class _AdminMembersListPageState extends State<AdminMembersListPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();

  String _keyword = '';
  bool _busy = false;

  String _orderByField = 'updatedAt';
  bool _desc = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final v = _searchCtrl.text.trim();
      if (v == _keyword) return;
      setState(() => _keyword = v);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    return _db
        .collection('users')
        .orderBy(_orderByField, descending: _desc)
        .limit(300);
  }

  // -------------------------
  // Helpers
  // -------------------------
  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  DateTime? _asDt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  String _fmtDt(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('yyyy/MM/dd HH:mm').format(dt);
  }

  bool _match(Map<String, dynamic> m) {
    final k = _keyword.trim().toLowerCase();
    if (k.isEmpty) return true;

    final uid = (m['uid'] ?? '').toString().toLowerCase();
    final name = (m['displayName'] ?? m['name'] ?? '').toString().toLowerCase();
    final email = (m['email'] ?? '').toString().toLowerCase();

    return uid.contains(k) || name.contains(k) || email.contains(k);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('已複製：$text');
  }

  // -------------------------
  // Actions (async with mounted guard)
  // -------------------------
  Future<void> _deleteUser(String uid) async {
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('刪除會員'),
        content: Text('確定要刪除會員：$uid ？此操作不可復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    // ✅ async gap 後 guard
    if (!mounted) return;
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _db.collection('users').doc(uid).delete();

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已刪除會員')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPointsTasks(String uid) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminMemberPointsTasksPage(uid: uid)),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _openSortMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('排序：updatedAt'),
              subtitle: const Text('最近更新優先（預設）'),
              onTap: () {
                Navigator.pop(sheetCtx);
                if (!mounted) return;
                setState(() {
                  _orderByField = 'updatedAt';
                  _desc = true;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('排序：createdAt'),
              subtitle: const Text('最新建立優先'),
              onTap: () {
                Navigator.pop(sheetCtx);
                if (!mounted) return;
                setState(() {
                  _orderByField = 'createdAt';
                  _desc = true;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text('排序：displayName'),
              subtitle: const Text('名稱 A → Z'),
              onTap: () {
                Navigator.pop(sheetCtx);
                if (!mounted) return;
                setState(() {
                  _orderByField = 'displayName';
                  _desc = false;
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '會員管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '排序/篩選',
            icon: const Icon(Icons.sort),
            onPressed: _openSortMenu,
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _buildQuery().snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return _ErrorView(
                        message:
                            '讀取失敗：${snap.error}\n\n'
                            '若出現索引需求（FAILED_PRECONDITION: requires an index），'
                            '請到 Firebase Console 建立對應索引（$_orderByField）。',
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs;
                    final filtered = docs.where((d) {
                      final m = d.data();
                      m['uid'] ??= d.id;
                      return _match(m);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('沒有符合條件的會員'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final doc = filtered[i];
                        final m = doc.data();

                        final uid = (m['uid'] ?? doc.id).toString();
                        final name = (m['displayName'] ?? m['name'] ?? '')
                            .toString();
                        final email = (m['email'] ?? '').toString();
                        final points = _asInt(m['points']);
                        final updatedAt = _asDt(m['updatedAt']);
                        final createdAt = _asDt(m['createdAt']);

                        return Card(
                          elevation: 0.8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name.isEmpty ? '(未命名)' : name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _Pill(
                                      text: 'Points $points',
                                      bg: cs.primaryContainer,
                                      fg: cs.onPrimaryContainer,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    _kv('uid', uid),
                                    if (email.isNotEmpty) _kv('email', email),
                                    _kv('updatedAt', _fmtDt(updatedAt)),
                                    if (createdAt != null)
                                      _kv('createdAt', _fmtDt(createdAt)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _copy(uid),
                                      icon: const Icon(Icons.copy),
                                      label: const Text('複製 uid'),
                                    ),
                                    FilledButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _openPointsTasks(uid),
                                      icon: const Icon(Icons.payments_outlined),
                                      label: const Text('點數/任務'),
                                    ),
                                    TextButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _deleteUser(uid),
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
                                        '刪除',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                if (_busy)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: Container(
                        color: const Color.fromARGB(13, 0, 0, 0),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: '搜尋 uid / 名稱 / Email',
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: _keyword.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除',
                  onPressed: () => _searchCtrl.clear(),
                  icon: const Icon(Icons.clear),
                ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    final text = v.trim().isEmpty ? '-' : v.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '$k：',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

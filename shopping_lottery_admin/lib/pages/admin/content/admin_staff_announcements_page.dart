// lib/pages/admin/content/admin_staff_announcements_page.dart
//
// ✅ AdminStaffAnnouncementsPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// Firestore collection: staff_announcements
//
// 功能：
// ✅ 列表（前端搜尋 / 前端置頂排序）
// ✅ 新增 / 編輯（Dialog 表單）
// ✅ 刪除（確認）
// ✅ 發佈/下架（published）
// ✅ 置頂（pinned）
// ✅ 等級（level: info / warning / urgent）
//
// 欄位建議：
// title        String
// body         String
// level        String (info|warning|urgent)
// published    bool
// pinned       bool
// createdAt    Timestamp
// updatedAt    Timestamp
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminStaffAnnouncementsPage extends StatefulWidget {
  const AdminStaffAnnouncementsPage({super.key});

  @override
  State<AdminStaffAnnouncementsPage> createState() =>
      _AdminStaffAnnouncementsPageState();
}

class _AdminStaffAnnouncementsPageState
    extends State<AdminStaffAnnouncementsPage> {
  static const String _colName = 'staff_announcements';

  final _searchCtrl = TextEditingController();
  String _keyword = '';

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(_colName);

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
    // ✅ 避免複合索引：只用 createdAt 排序，pinned 在前端排序
    return _col.orderBy('createdAt', descending: true).limit(300);
  }

  bool _matchKeyword(Map<String, dynamic> data) {
    final k = _keyword.trim().toLowerCase();
    if (k.isEmpty) return true;

    final title = (data['title'] ?? '').toString().toLowerCase();
    final body = (data['body'] ?? '').toString().toLowerCase();
    final level = (data['level'] ?? '').toString().toLowerCase();

    return title.contains(k) || body.contains(k) || level.contains(k);
  }

  String _fmtTs(dynamic ts) {
    try {
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();
      if (ts is DateTime) dt = ts;
      if (dt == null) return '';
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $hh:$mm';
    } catch (_) {
      return '';
    }
  }

  Future<void> _openEditor({
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final result = await showDialog<_StaffAnnEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StaffAnnEditDialog(doc: doc),
    );

    if (!mounted || result == null) return;

    try {
      if (doc == null) {
        await _col.add({
          ...result.data,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await doc.reference.update({
          ...result.data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(doc == null ? '已新增公告' : '已更新公告')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  Future<void> _toggleBool(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String field,
    required bool nextValue,
  }) async {
    try {
      await doc.reference.update({
        field: nextValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final title = (doc.data()?['title'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除公告'),
        content: Text('確定要刪除「$title」？此操作不可復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await doc.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'urgent':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String _levelLabel(String level) {
    switch (level) {
      case 'urgent':
        return '緊急';
      case 'warning':
        return '注意';
      default:
        return '一般';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('員工公告管理'),
        actions: [
          IconButton(
            tooltip: '新增公告',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜尋 標題 / 內容 / 等級',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除',
                        onPressed: () => _searchCtrl.clear(),
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buildQuery().snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs
              .where((d) => _matchKeyword(d.data()))
              .toList();

          // ✅ pinned 前端排序置頂
          docs.sort((a, b) {
            final ap = a.data()['pinned'] == true ? 1 : 0;
            final bp = b.data()['pinned'] == true ? 1 : 0;
            if (ap != bp) return bp.compareTo(ap);
            return b.id.compareTo(a.id);
          });

          if (docs.isEmpty) {
            return const Center(child: Text('目前沒有公告'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();

              final title = (d['title'] ?? '').toString();
              final body = (d['body'] ?? '').toString();
              final published = d['published'] == true;
              final pinned = d['pinned'] == true;
              final level = (d['level'] ?? 'info').toString();

              final createdAt = _fmtTs(d['createdAt']);
              final updatedAt = _fmtTs(d['updatedAt']);

              final levelColor = _levelColor(level);
              final levelText = _levelLabel(level);

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
                              title.isEmpty ? '(未命名公告)' : title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Tag(
                            text: pinned ? '置頂' : '一般',
                            color: pinned ? Colors.purple : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          _Tag(
                            text: published ? '已發佈' : '未發佈',
                            color: published ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          _Tag(text: levelText, color: levelColor),
                        ],
                      ),
                      if (body.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black87,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        [
                          if (createdAt.isNotEmpty) '建立：$createdAt',
                          if (updatedAt.isNotEmpty) '更新：$updatedAt',
                          'ID：${doc.id}',
                        ].join('   '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _openEditor(doc: doc),
                            icon: const Icon(Icons.edit),
                            label: const Text('編輯'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _toggleBool(
                              doc,
                              field: 'published',
                              nextValue: !published,
                            ),
                            icon: Icon(
                              published
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            label: Text(published ? '下架' : '發佈'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _toggleBool(
                              doc,
                              field: 'pinned',
                              nextValue: !pinned,
                            ),
                            icon: Icon(
                              pinned ? Icons.push_pin : Icons.push_pin_outlined,
                            ),
                            label: Text(pinned ? '取消置頂' : '置頂'),
                          ),
                          TextButton.icon(
                            onPressed: () => _delete(doc),
                            icon: const Icon(Icons.delete, color: Colors.red),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('新增公告'),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // ✅ 避免 withOpacity（Dart/Flutter 新版會提示精度問題），改用 withValues(alpha: )
    // 0.12 * 255 ≈ 31；0.35 * 255 ≈ 89
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 31),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 89)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StaffAnnEditResult {
  final Map<String, dynamic> data;
  const _StaffAnnEditResult(this.data);
}

class _StaffAnnEditDialog extends StatefulWidget {
  const _StaffAnnEditDialog({required this.doc});
  final DocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  State<_StaffAnnEditDialog> createState() => _StaffAnnEditDialogState();
}

class _StaffAnnEditDialogState extends State<_StaffAnnEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;

  bool _published = false;
  bool _pinned = false;
  String _level = 'info'; // info / warning / urgent

  @override
  void initState() {
    super.initState();
    final data = widget.doc?.data() ?? <String, dynamic>{};

    _titleCtrl = TextEditingController(text: (data['title'] ?? '').toString());
    _bodyCtrl = TextEditingController(text: (data['body'] ?? '').toString());

    _published = data['published'] == true;
    _pinned = data['pinned'] == true;
    _level = (data['level'] ?? 'info').toString();
    if (_level != 'info' && _level != 'warning' && _level != 'urgent') {
      _level = 'info';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'body': _bodyCtrl.text.trim(),
      'level': _level,
      'published': _published,
      'pinned': _pinned,
    };

    Navigator.pop(context, _StaffAnnEditResult(payload));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.doc != null;

    return AlertDialog(
      title: Text(isEdit ? '編輯公告' : '新增公告'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '標題',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return '請輸入標題';
                    if (s.length < 2) return '標題太短';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ✅ 這裡是你遇到的 deprecated 修正重點：
                //    Flutter 新版把 DropdownButtonFormField 的 value 參數 deprecated，
                //    改用 initialValue。
                DropdownButtonFormField<String>(
                  initialValue: _level, // ✅ 不要再用 value:
                  decoration: const InputDecoration(
                    labelText: '等級',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('一般')),
                    DropdownMenuItem(value: 'warning', child: Text('注意')),
                    DropdownMenuItem(value: 'urgent', child: Text('緊急')),
                  ],
                  onChanged: (v) => setState(() => _level = v ?? 'info'),
                ),

                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyCtrl,
                  decoration: const InputDecoration(
                    labelText: '內容',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 8,
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return '請輸入內容';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _published,
                  onChanged: (v) => setState(() => _published = v),
                  title: const Text('發佈'),
                  subtitle: Text(_published ? '前台可見' : '前台不可見'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v),
                  title: const Text('置頂'),
                  subtitle: const Text('置頂公告會顯示在列表前方（此頁用前端排序）'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('儲存')),
      ],
    );
  }
}

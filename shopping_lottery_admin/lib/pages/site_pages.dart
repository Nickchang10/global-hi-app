// lib/pages/site_pages.dart
//
// ✅ SitePages（最終完整版｜可編譯｜修正 non_constant_identifier_names + camel_case_types）
// ------------------------------------------------------------
// - 顯示 site_contents 的頁面清單（About/Terms/Privacy...）
// - 可新增、編輯
// - 依賴：cloud_firestore、site_content_edit_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'site_content_edit_page.dart';

class SitePages extends StatefulWidget {
  const SitePages({super.key});

  @override
  State<SitePages> createState() => _SitePagesState();
}

class _SitePagesState extends State<SitePages> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _openEditor({String? key}) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const SiteContentEditPage(),
        settings: RouteSettings(arguments: key ?? ''),
      ),
    );

    if (!mounted) return;
    if (ok == true) _snack('已更新');
  }

  Future<void> _createQuick() async {
    final keyCtrl = TextEditingController();
    final titleCtrl = TextEditingController();

    final ok =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('新增頁面'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Key（doc id）',
                    hintText: '例如 about / terms / privacy',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '標題'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('下一步'),
              ),
            ],
          ),
        ) ??
        false;

    final key = keyCtrl.text.trim();
    final title = titleCtrl.text.trim();
    keyCtrl.dispose();
    titleCtrl.dispose();

    if (!ok) return;
    if (key.isEmpty) {
      _snack('Key 不可空白');
      return;
    }

    try {
      final ref = _db.collection('site_contents').doc(key);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'key': key,
          'title': title.isEmpty ? key : title,
          'content': '',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (!mounted) return;
      await _openEditor(key: key);
    } catch (e) {
      if (!mounted) return;
      _snack('新增失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _scaffoldWrap(
      title: '網站頁面內容',
      actions: [
        IconButton(
          tooltip: '新增',
          onPressed: _createQuick,
          icon: const Icon(Icons.add),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋 key / title',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                suffixIcon: IconButton(
                  tooltip: '清除',
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('site_contents')
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? const [];
                final q = _searchCtrl.text.trim().toLowerCase();

                final filtered = docs.where((d) {
                  if (q.isEmpty) return true;
                  final m = d.data();
                  final key = d.id.toLowerCase();
                  final title = _s(m['title']).toLowerCase();
                  final k2 = _s(m['key']).toLowerCase();
                  return key.contains(q) || title.contains(q) || k2.contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      q.isEmpty ? '目前沒有內容頁' : '沒有符合搜尋的頁面',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final d = filtered[i];
                    final m = d.data();
                    final title = _s(m['title']).isEmpty
                        ? d.id
                        : _s(m['title']);
                    final isActive = (m['isActive'] ?? true) == true;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _Pill(
                              text: isActive ? '啟用' : '停用',
                              fg: isActive ? cs.primary : cs.onSurfaceVariant,
                              bg: isActive
                                  ? cs.primary.withValues(alpha: 0.12)
                                  : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.35,
                                    ),
                              border: cs.outlineVariant,
                            ),
                          ],
                        ),
                        subtitle: Text('key: ${d.id}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openEditor(key: d.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ lowerCamelCase OK（function）
/// 你如果想更「標準」，也可以改成 _buildScaffoldWrap（不是必要）
Widget _scaffoldWrap({
  required String title,
  List<Widget> actions = const [],
  required Widget body,
}) {
  return Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: body,
  );
}

/// ✅ FIX：type name 必須 UpperCamelCase
class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.fg,
    required this.bg,
    required this.border,
  });

  final String text;
  final Color fg;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

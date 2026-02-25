// lib/pages/site_content_page.dart
//
// ✅ SiteContentPage（最終完整版｜可編譯｜內建 Doc Preview Page）
// ------------------------------------------------------------
// 功能：
// - Firestore: site_contents
// - 列表：搜尋（title/slug/category/id）、category 篩選、published 篩選
// - 操作：新增 / 編輯 / 刪除 / 切換 published
// - 預覽：SiteContentDocPreviewPage（同檔提供，解決 undefined_method）
//
// 建議 Firestore schema（彈性容錯）
// site_contents/{id} {
//   title: String
//   slug: String
//   category: String
//   content: String
//   published: bool
//   pinned: bool?
//   createdAt: Timestamp
//   updatedAt: Timestamp
// }
//
// 依賴：cloud_firestore, flutter/material

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SiteContentPage extends StatefulWidget {
  const SiteContentPage({super.key});

  @override
  State<SiteContentPage> createState() => _SiteContentPageState();
}

class _SiteContentPageState extends State<SiteContentPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _category = 'all';
  String _pubFilter = 'all'; // all / published / draft

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ----------------------------
  // helpers
  // ----------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.trim().toLowerCase();
      if (t == 'true' || t == '1' || t == 'yes') return true;
      if (t == 'false' || t == '0' || t == 'no') return false;
    }
    return fallback;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Query<Map<String, dynamic>> _baseQuery() {
    // 只用一個 orderBy，避免複合索引問題
    return _db
        .collection('site_contents')
        .orderBy('updatedAt', descending: true);
  }

  bool _match(String id, Map<String, dynamic> d) {
    final cat = _category.trim().toLowerCase();
    if (cat.isNotEmpty && cat != 'all') {
      final docCat = _s(d['category']).toLowerCase();
      if (docCat != cat) return false;
    }

    final pub = _pubFilter.trim().toLowerCase();
    final published = _b(d['published'], fallback: true);
    if (pub == 'published' && !published) return false;
    if (pub == 'draft' && published) return false;

    final k = _searchCtrl.text.trim().toLowerCase();
    if (k.isEmpty) return true;

    final title = _s(d['title']).toLowerCase();
    final slug = _s(d['slug']).toLowerCase();
    final category = _s(d['category']).toLowerCase();

    return id.toLowerCase().contains(k) ||
        title.contains(k) ||
        slug.contains(k) ||
        category.contains(k);
  }

  // ----------------------------
  // actions
  // ----------------------------
  Future<void> _togglePublished(String id, bool to) async {
    await _db.collection('site_contents').doc(id).set({
      'published': to,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteDoc(String id, String title) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('刪除內容？'),
            content: Text('將刪除：$title\n（不可復原）'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('刪除'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    await _db.collection('site_contents').doc(id).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已刪除')));
  }

  Future<void> _openEditor({
    required String docId,
    required Map<String, dynamic> data,
    required bool isNew,
  }) async {
    final titleCtrl = TextEditingController(text: _s(data['title']));
    final slugCtrl = TextEditingController(text: _s(data['slug']));
    final categoryCtrl = TextEditingController(text: _s(data['category']));
    final contentCtrl = TextEditingController(text: _s(data['content']));
    bool published = _b(data['published'], fallback: true);

    bool ok = false;
    try {
      ok =
          await showDialog<bool>(
            context: context,
            builder: (dialogCtx) => AlertDialog(
              title: Text(isNew ? '新增內容' : '編輯內容'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _field(titleCtrl, '標題*'),
                      _field(
                        slugCtrl,
                        'slug（可空，建議唯一）',
                        hint: 'about / terms / privacy / news-xxx',
                      ),
                      _field(
                        categoryCtrl,
                        'category*',
                        hint: 'about / terms / privacy / news / faq ...',
                      ),
                      _field(
                        contentCtrl,
                        'content',
                        maxLines: 10,
                        hint: '支援純文字或 Markdown（依你前台解析）',
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        value: published,
                        onChanged: (v) => published = v,
                        title: const Text('發布（published）'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('儲存'),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      // 先不 dispose，因為後面還要讀 text（避免你再遇到 use_build_context/async gap 警告）
    }

    if (!ok) {
      titleCtrl.dispose();
      slugCtrl.dispose();
      categoryCtrl.dispose();
      contentCtrl.dispose();
      return;
    }

    final title = titleCtrl.text.trim();
    final slug = slugCtrl.text.trim();
    final category = categoryCtrl.text.trim();

    if (title.isEmpty || category.isEmpty) {
      titleCtrl.dispose();
      slugCtrl.dispose();
      categoryCtrl.dispose();
      contentCtrl.dispose();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('標題與 category 不可空白')));
      return;
    }

    final payload = <String, dynamic>{
      'title': title,
      'slug': slug,
      'category': category.toLowerCase(),
      'content': contentCtrl.text,
      'published': published,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isNew) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await _db
        .collection('site_contents')
        .doc(docId)
        .set(payload, SetOptions(merge: true));

    titleCtrl.dispose();
    slugCtrl.dispose();
    categoryCtrl.dispose();
    contentCtrl.dispose();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已儲存')));
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _openPreview({required String id, required Map<String, dynamic> data}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SiteContentDocPreviewPage(docId: id, initialData: data),
      ),
    );
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('官網內容管理'),
        actions: [
          IconButton(
            tooltip: '新增內容',
            onPressed: () async {
              final id = _db.collection('site_contents').doc().id;
              await _openEditor(
                docId: id,
                data: const <String, dynamic>{},
                isNew: true,
              );
            },
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜尋 title / slug / category / id',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(
                        alpha: 56,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _pubFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部')),
                    DropdownMenuItem(value: 'published', child: Text('已發布')),
                    DropdownMenuItem(value: 'draft', child: Text('草稿/未發布')),
                  ],
                  onChanged: (v) => setState(() => _pubFilter = v ?? 'all'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _category,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部分類')),
                    DropdownMenuItem(value: 'about', child: Text('about')),
                    DropdownMenuItem(value: 'terms', child: Text('terms')),
                    DropdownMenuItem(value: 'privacy', child: Text('privacy')),
                    DropdownMenuItem(value: 'news', child: Text('news')),
                    DropdownMenuItem(value: 'faq', child: Text('faq')),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? 'all'),
                ),
                const SizedBox(width: 10),
                Text(
                  '提示：分類可自行擴充（此下拉僅示範）',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? const [];
                final filtered = docs
                    .where((d) => _match(d.id, d.data()))
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _searchCtrl.text.trim().isEmpty ? '目前沒有內容' : '沒有符合的內容',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    final data = d.data();

                    final title = _s(data['title']).isEmpty
                        ? d.id
                        : _s(data['title']);
                    final slug = _s(data['slug']);
                    final category = _s(data['category']);
                    final published = _b(data['published'], fallback: true);
                    final updatedAt = _fmt(_toDate(data['updatedAt']));

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: ListTile(
                        onTap: () => _openPreview(id: d.id, data: data),
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
                            _PubPill(published: published),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  if (category.isNotEmpty)
                                    _MiniChip(
                                      icon: Icons.folder,
                                      text: category,
                                    ),
                                  if (slug.isNotEmpty)
                                    _MiniChip(
                                      icon: Icons.link,
                                      text: 'slug:$slug',
                                    ),
                                  if (updatedAt.isNotEmpty)
                                    _MiniChip(
                                      icon: Icons.update,
                                      text: updatedAt,
                                    ),
                                  _MiniChip(icon: Icons.tag, text: d.id),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'preview') {
                              _openPreview(id: d.id, data: data);
                            } else if (v == 'edit') {
                              await _openEditor(
                                docId: d.id,
                                data: data,
                                isNew: false,
                              );
                            } else if (v == 'pub_on') {
                              await _togglePublished(d.id, true);
                            } else if (v == 'pub_off') {
                              await _togglePublished(d.id, false);
                            } else if (v == 'delete') {
                              await _deleteDoc(d.id, title);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'preview',
                              child: Row(
                                children: [
                                  Icon(Icons.open_in_new, size: 18),
                                  SizedBox(width: 8),
                                  Text('預覽'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('編輯'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: published ? 'pub_off' : 'pub_on',
                              child: Row(
                                children: [
                                  Icon(
                                    published
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(published ? '改為未發布' : '發布'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '刪除',
                                    style: TextStyle(color: Colors.red),
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// ✅ 你缺的預覽頁：SiteContentDocPreviewPage（同檔提供）
// ------------------------------------------------------------
class SiteContentDocPreviewPage extends StatelessWidget {
  const SiteContentDocPreviewPage({
    super.key,
    required this.docId,
    this.initialData,
  });

  final String docId;
  final Map<String, dynamic>? initialData;

  String _s(dynamic v) => (v ?? '').toString().trim();

  bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.trim().toLowerCase();
      if (t == 'true' || t == '1' || t == 'yes') return true;
      if (t == 'false' || t == '0' || t == 'no') return false;
    }
    return fallback;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final db = FirebaseFirestore.instance;

    final ref = db.collection('site_contents').doc(docId);

    Widget buildBody(Map<String, dynamic> data) {
      final title = _s(data['title']).isEmpty ? docId : _s(data['title']);
      final slug = _s(data['slug']);
      final category = _s(data['category']);
      final content = _s(data['content']);
      final published = _b(data['published'], fallback: true);
      final updatedAt = _fmt(_toDate(data['updatedAt']));
      final createdAt = _fmt(_toDate(data['createdAt']));

      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _MiniChip(icon: Icons.tag, text: docId),
                      if (category.isNotEmpty)
                        _MiniChip(icon: Icons.folder, text: category),
                      if (slug.isNotEmpty)
                        _MiniChip(icon: Icons.link, text: 'slug:$slug'),
                      _MiniChip(
                        icon: published ? Icons.public : Icons.visibility_off,
                        text: published ? '已發布' : '未發布',
                      ),
                      if (updatedAt.isNotEmpty)
                        _MiniChip(icon: Icons.update, text: updatedAt),
                      if (createdAt.isNotEmpty)
                        _MiniChip(icon: Icons.schedule, text: createdAt),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: content.isEmpty
                  ? Text('（無內容）', style: TextStyle(color: cs.onSurfaceVariant))
                  : SelectableText(
                      content,
                      style: const TextStyle(fontSize: 15, height: 1.55),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('內容預覽')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          // 若 initialData 有值：先顯示（讓畫面更快），但仍以 Firestore stream 為準
          if (!snap.hasData) {
            if (initialData != null) return buildBody(initialData!);
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));

          final doc = snap.data!;
          if (!doc.exists) return Center(child: Text('找不到內容：$docId'));

          final data = doc.data() ?? <String, dynamic>{};
          return buildBody(data);
        },
      ),
    );
  }
}

// ----------------------------
// UI chips
// ----------------------------
class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PubPill extends StatelessWidget {
  const _PubPill({required this.published});
  final bool published;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = published
        ? cs.primary.withValues(alpha: 18)
        : cs.surfaceContainerHighest.withValues(alpha: 56);
    final fg = published ? cs.primary : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        published ? '已發布' : '未發布',
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

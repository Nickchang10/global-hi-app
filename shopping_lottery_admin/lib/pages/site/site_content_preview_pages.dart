// lib/pages/site/site_content_preview_pages.dart
//
// ✅ Site Content Preview Pages（最終完整版｜可編譯｜移除 unused _toDate｜移除 surfaceVariant deprecated）
// ------------------------------------------------------------
// 目的：提供前台官網內容的預覽頁（About/Terms/Privacy/News...）
// - 讀取 Firestore: site_contents
// - 以 category + slug 或 docId 預覽
// - 支援純文字 / Markdown（此處以純文字顯示，若你要 Markdown 可自行換套件）
//
// 建議 schema：
// site_contents/{id} {
//   title: String
//   slug: String
//   category: String
//   content: String
//   published: bool
//   updatedAt: Timestamp
//   createdAt: Timestamp
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SiteContentByDocIdPreviewPage extends StatelessWidget {
  const SiteContentByDocIdPreviewPage({super.key, required this.docId});
  final String docId;

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

  String _fmtTs(dynamic v) {
    if (v is Timestamp) {
      final d = v.toDate();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ref = FirebaseFirestore.instance
        .collection('site_contents')
        .doc(docId);

    return Scaffold(
      appBar: AppBar(title: const Text('官網內容預覽')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }
          if (!snap.hasData || !(snap.data?.exists ?? false)) {
            return Center(child: Text('找不到內容：$docId'));
          }

          final data = snap.data!.data() ?? <String, dynamic>{};

          final title = _s(data['title']).isEmpty ? docId : _s(data['title']);
          final category = _s(data['category']);
          final slug = _s(data['slug']);
          final content = _s(data['content']);
          final published = _b(data['published'], fallback: true);
          final updatedAt = _fmtTs(data['updatedAt']);
          final createdAt = _fmtTs(data['createdAt']);

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: cs.outlineVariant),
                ),
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
                          _MetaChip(icon: Icons.tag, text: docId),
                          if (category.isNotEmpty)
                            _MetaChip(icon: Icons.folder, text: category),
                          if (slug.isNotEmpty)
                            _MetaChip(icon: Icons.link, text: 'slug:$slug'),
                          _MetaChip(
                            icon: published
                                ? Icons.public
                                : Icons.visibility_off,
                            text: published ? '已發布' : '未發布',
                          ),
                          if (updatedAt.isNotEmpty)
                            _MetaChip(icon: Icons.update, text: updatedAt),
                          if (createdAt.isNotEmpty)
                            _MetaChip(icon: Icons.schedule, text: createdAt),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: content.isEmpty
                      ? Text(
                          '（無內容）',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        )
                      : SelectableText(
                          content,
                          style: const TextStyle(fontSize: 15, height: 1.55),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

class SiteContentByCategorySlugPreviewPage extends StatelessWidget {
  const SiteContentByCategorySlugPreviewPage({
    super.key,
    required this.category,
    required this.slug,
  });

  final String category;
  final String slug;

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

  String _fmtTs(dynamic v) {
    if (v is Timestamp) {
      final d = v.toDate();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ 避免複合索引：只用 where + limit(1)，不 orderBy
    final q = FirebaseFirestore.instance
        .collection('site_contents')
        .where('category', isEqualTo: category.trim().toLowerCase())
        .where('slug', isEqualTo: slug.trim())
        .limit(1);

    return Scaffold(
      appBar: AppBar(title: const Text('官網內容預覽')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Center(child: Text('找不到內容：$category / $slug'));
          }

          final doc = docs.first;
          final data = doc.data();

          final title = _s(data['title']).isEmpty ? doc.id : _s(data['title']);
          final content = _s(data['content']);
          final published = _b(data['published'], fallback: true);
          final updatedAt = _fmtTs(data['updatedAt']);
          final createdAt = _fmtTs(data['createdAt']);

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: cs.outlineVariant),
                ),
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
                          _MetaChip(icon: Icons.tag, text: doc.id),
                          _MetaChip(icon: Icons.folder, text: category),
                          _MetaChip(icon: Icons.link, text: 'slug:$slug'),
                          _MetaChip(
                            icon: published
                                ? Icons.public
                                : Icons.visibility_off,
                            text: published ? '已發布' : '未發布',
                          ),
                          if (updatedAt.isNotEmpty)
                            _MetaChip(icon: Icons.update, text: updatedAt),
                          if (createdAt.isNotEmpty)
                            _MetaChip(icon: Icons.schedule, text: createdAt),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: content.isEmpty
                      ? Text(
                          '（無內容）',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        )
                      : SelectableText(
                          content,
                          style: const TextStyle(fontSize: 15, height: 1.55),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // ✅ surfaceVariant deprecated -> surfaceContainerHighest
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

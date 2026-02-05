// lib/pages/site/site_content_preview_pages.dart
//
// ✅ Site Content Preview Pages（前台預覽完整版｜Carousel｜Quill Delta/純文字 fallback）
// ------------------------------------------------------------
// Firestore: site_contents/{id}
// fields (建議/相容)：
// - category: String
// - title: String
// - body: String (純文字或你目前儲存的內容)
// - bodyPlain: String? (可選)
// - bodyDelta: List<dynamic>? (可選，Quill delta json)
// - images: List<String>? (可選)
// - createdAt/updatedAt: Timestamp
//
// ✅ 不依賴 flutter_html，不新增套件
// ✅ 若有 bodyDelta -> 用 flutter_quill readOnly 顯示
// ✅ 否則 -> 顯示純文字
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class SiteContentPreviewPage extends StatefulWidget {
  final String category;
  final String pageTitle;

  /// 單頁預覽：取該 category 最新一筆（updatedAt desc limit 1）
  const SiteContentPreviewPage({
    super.key,
    required this.category,
    required this.pageTitle,
  });

  @override
  State<SiteContentPreviewPage> createState() => _SiteContentPreviewPageState();
}

class _SiteContentPreviewPageState extends State<SiteContentPreviewPage> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final q = _db
        .collection('site_contents')
        .where('category', isEqualTo: widget.category)
        .orderBy('updatedAt', descending: true)
        .limit(1);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageTitle),
      ),
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
            return const Center(child: Text('尚無內容'));
          }

          final doc = docs.first;
          final data = doc.data();
          return _ContentRenderer(
            titleFallback: widget.pageTitle,
            docId: doc.id,
            data: data,
          );
        },
      ),
    );
  }
}

/// ✅ 最新消息列表（多筆）
class SiteNewsListPreviewPage extends StatefulWidget {
  final String category;
  final String pageTitle;

  const SiteNewsListPreviewPage({
    super.key,
    this.category = 'news',
    this.pageTitle = '最新消息（預覽）',
  });

  @override
  State<SiteNewsListPreviewPage> createState() => _SiteNewsListPreviewPageState();
}

class _SiteNewsListPreviewPageState extends State<SiteNewsListPreviewPage> {
  final _db = FirebaseFirestore.instance;

  String _fmtTs(dynamic v) {
    final dt = (v is Timestamp) ? v.toDate() : null;
    if (dt == null) return '';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final q = _db
        .collection('site_contents')
        .where('category', isEqualTo: widget.category)
        .orderBy('updatedAt', descending: true)
        .limit(100);

    return Scaffold(
      appBar: AppBar(title: Text(widget.pageTitle)),
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
          if (docs.isEmpty) return const Center(child: Text('尚無消息'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();
              final title = _s(data['title']);
              final updatedAt = _fmtTs(data['updatedAt']);
              final bodyPlain = _s(data['bodyPlain']).isNotEmpty
                  ? _s(data['bodyPlain'])
                  : _s(data['body']);

              return ListTile(
                title: Text(
                  title.isEmpty ? '(未命名消息)' : title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  [
                    if (updatedAt.isNotEmpty) updatedAt,
                    if (bodyPlain.isNotEmpty) bodyPlain,
                  ].join('\n'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SiteContentDetailPreviewPage(
                        docId: d.id,
                        pageTitle: title.isEmpty ? '消息內容（預覽）' : title,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// ✅ 單筆詳情預覽（給 news 點進去用）
class SiteContentDetailPreviewPage extends StatelessWidget {
  final String docId;
  final String pageTitle;

  const SiteContentDetailPreviewPage({
    super.key,
    required this.docId,
    required this.pageTitle,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('site_contents').doc(docId);

    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: ref.get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('讀取失敗：${snap.error}'));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('內容不存在或已刪除'));
          }
          final data = snap.data!.data() ?? <String, dynamic>{};
          return _ContentRenderer(
            titleFallback: pageTitle,
            docId: docId,
            data: data,
          );
        },
      ),
    );
  }
}

class _ContentRenderer extends StatefulWidget {
  final String titleFallback;
  final String docId;
  final Map<String, dynamic> data;

  const _ContentRenderer({
    required this.titleFallback,
    required this.docId,
    required this.data,
  });

  @override
  State<_ContentRenderer> createState() => _ContentRendererState();
}

class _ContentRendererState extends State<_ContentRenderer> {
  int _imgIndex = 0;

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _fmtTs(dynamic v) {
    final dt = (v is Timestamp) ? v.toDate() : null;
    if (dt == null) return '';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  quill.QuillController? _buildReadOnlyQuillController(dynamic bodyDelta) {
    try {
      if (bodyDelta is List) {
        final doc = quill.Document.fromJson(
          bodyDelta.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        );
        return quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final title = _s(data['title']).isNotEmpty ? _s(data['title']) : widget.titleFallback;
    final updatedAt = _fmtTs(data['updatedAt']);

    final imagesRaw = data['images'];
    final images = (imagesRaw is List)
        ? imagesRaw.map((e) => _s(e)).where((e) => e.isNotEmpty).toList()
        : <String>[];

    final bodyDelta = data['bodyDelta'];
    final quillCtrl = _buildReadOnlyQuillController(bodyDelta);

    final bodyPlain = _s(data['bodyPlain']).isNotEmpty ? _s(data['bodyPlain']) : _s(data['body']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        if (updatedAt.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('更新：$updatedAt', style: TextStyle(color: Theme.of(context).hintColor)),
        ],
        const SizedBox(height: 14),

        // ✅ 圖片輪播
        if (images.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: PageView.builder(
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _imgIndex = i),
                itemBuilder: (_, i) => Image.network(
                  images[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Text('圖片載入失敗')),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Dots(count: images.length, index: _imgIndex),
          const SizedBox(height: 18),
        ],

        // ✅ 富文字 / 純文字
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: quillCtrl != null
              ? quill.QuillEditor.basic(
                  controller: quillCtrl,
                  readOnly: true,
                )
              : SelectableText(
                  bodyPlain.isEmpty ? '(無內容)' : bodyPlain,
                  style: const TextStyle(height: 1.5, fontSize: 15),
                ),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;

  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 14 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

// lib/pages/front/front_site_shell.dart
//
// ✅ FrontSiteShell（前台網站主頁框架｜Firebase + Firestore Auto Content）
// ------------------------------------------------------------
// 共用 Firestore 結構：site_contents
// - custom-home: 首頁輪播 + 卡片內容
// - news: 最新消息列表
// - about / faq / contact: 靜態頁內容（用 category 最新一筆 or 指定 docId）
//
// ✅ 本檔已內建：
// - SiteContentDocPreviewPage（用 docId 預覽單篇）
// - SiteCategoryListPage（用 category 列表）
// - SiteSingleCategoryPage（用 category 顯示最新一筆）
// - FAQ：用 category=faq 顯示 ExpansionTile
//
// 支援內容欄位：
// - rich text: contentJson(String) / delta(List) / content(List) / quill(List) / {ops:[...]}
// - fallback: plainText / body / bodyHtml
// - images: images(List<String>) / imageUrls(List<String>)
//
// ✅ 修正：避免 flutter_quill 版本差異造成 QuillEditorConfig(readOnly: ) 編譯失敗
// - 不使用 readOnly 參數
// - 用 AbsorbPointer 讓預覽不可編輯（相容性最高）
//
// ✅ 修正：移除 doc.data() 的 unnecessary_cast（原本第 498 行）
//
// ✅ 修正：surfaceVariant deprecated → 改 surfaceContainerHighest
// ✅ 修正：withOpacity deprecated → 改 withValues(alpha: ...)

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

// 你原本的 import 可保留（若你已建立該檔案），但本檔不依賴它也能編譯。
// ignore: unused_import
import '../site/site_content_preview_pages.dart';

class FrontSiteShell extends StatefulWidget {
  const FrontSiteShell({super.key});

  @override
  State<FrontSiteShell> createState() => _FrontSiteShellState();
}

class _FrontSiteShellState extends State<FrontSiteShell> {
  int _currentIndex = 0;

  final _pages = const [
    _HomeSection(),
    _NewsSection(),
    _AboutSection(),
    _FAQSection(),
    _ContactSection(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Osmile 官網預覽'),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/admin'),
            child: const Text('後台登入', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首頁'),
          BottomNavigationBarItem(
            icon: Icon(Icons.newspaper_outlined),
            label: '最新消息',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment_outlined),
            label: '公司簡介',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: 'FAQ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.call_outlined),
            label: '聯絡我們',
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 首頁（custom-home）
// ------------------------------------------------------------
class _HomeSection extends StatelessWidget {
  const _HomeSection();

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    final q = db
        .collection('site_contents')
        .where('category', isEqualTo: 'custom-home')
        .orderBy('updatedAt', descending: true)
        .limit(5);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('尚未建立首頁內容（category=custom-home）'));
        }

        final images = <String>[];
        for (final d in docs) {
          final data = d.data();
          images.addAll(_safeStringList(data['images']));
          images.addAll(_safeStringList(data['imageUrls']));
        }
        images.removeWhere((e) => e.trim().isEmpty);

        return ListView(
          children: [
            if (images.isNotEmpty)
              SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (_, i) => Image.network(
                    images[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 40),
                    ),
                    loadingBuilder: (_, child, ev) => ev == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Text(
                '最新內容',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ...docs.map((d) {
              final data = d.data();
              final title = _s(data['title']).isNotEmpty
                  ? _s(data['title'])
                  : d.id;
              final subtitle = _pickBodyPreview(data);

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(title),
                  subtitle: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SiteContentDocPreviewPage(
                          docId: d.id,
                          pageTitle: title,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 最新消息（news）
// ------------------------------------------------------------
class _NewsSection extends StatelessWidget {
  const _NewsSection();

  @override
  Widget build(BuildContext context) {
    return const SiteCategoryListPage(category: 'news', pageTitle: '最新消息');
  }
}

// ------------------------------------------------------------
// 公司簡介（about）
// ------------------------------------------------------------
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return const SiteSingleCategoryPage(
      category: 'about',
      pageTitle: '公司簡介',
      emptyText: '尚未建立公司簡介（category=about）',
    );
  }
}

// ------------------------------------------------------------
// FAQ（faq）
// ------------------------------------------------------------
class _FAQSection extends StatelessWidget {
  const _FAQSection();

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final q = db
        .collection('site_contents')
        .where('category', isEqualTo: 'faq')
        .orderBy('updatedAt', descending: true)
        .limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('讀取失敗：${snap.error}'));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('尚無 FAQ（category=faq）'));
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: docs.map((d) {
            final data = d.data();
            final title = _s(data['title']).isNotEmpty
                ? _s(data['title'])
                : d.id;
            final body = _pickBodyFull(data);

            return Card(
              margin: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: ExpansionTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                children: [
                  if (_hasRichContent(data))
                    _RichContentViewer(data: data)
                  else
                    Text(body.isEmpty ? '（無內容）' : body),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 聯絡我們（contact）
// ------------------------------------------------------------
class _ContactSection extends StatelessWidget {
  const _ContactSection();

  @override
  Widget build(BuildContext context) {
    return const SiteSingleCategoryPage(
      category: 'contact',
      pageTitle: '聯絡我們',
      emptyText: '尚未建立聯絡資訊（category=contact）',
    );
  }
}

// ============================================================
// ✅ 共用頁：Category 列表
// ============================================================
class SiteCategoryListPage extends StatelessWidget {
  final String category;
  final String pageTitle;
  final int limit;

  const SiteCategoryListPage({
    super.key,
    required this.category,
    required this.pageTitle,
    this.limit = 50,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final q = db
        .collection('site_contents')
        .where('category', isEqualTo: category)
        .orderBy('updatedAt', descending: true)
        .limit(limit);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('讀取失敗：${snap.error}'));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Text('尚無內容（category=$category）'));
        }

        return ListView(
          padding: const EdgeInsets.all(10),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Text(
                pageTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ...docs.map((d) {
              final data = d.data();
              final title = _s(data['title']).isNotEmpty
                  ? _s(data['title'])
                  : d.id;
              final subtitle = _pickBodyPreview(data);

              return Card(
                child: ListTile(
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SiteContentDocPreviewPage(
                          docId: d.id,
                          pageTitle: title,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ============================================================
// ✅ 共用頁：單篇（用 category 最新一篇）
// ============================================================
class SiteSingleCategoryPage extends StatelessWidget {
  final String category;
  final String pageTitle;
  final String emptyText;

  const SiteSingleCategoryPage({
    super.key,
    required this.category,
    required this.pageTitle,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final q = db
        .collection('site_contents')
        .where('category', isEqualTo: category)
        .orderBy('updatedAt', descending: true)
        .limit(1);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return Center(child: Text(emptyText));

        final d = docs.first;
        final data = d.data();
        final title = _s(data['title']).isNotEmpty
            ? _s(data['title'])
            : pageTitle;

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (_hasRichContent(data))
              _RichContentViewer(data: data)
            else
              SelectableText(
                _pickBodyFull(data).isEmpty ? '（無內容）' : _pickBodyFull(data),
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
          ],
        );
      },
    );
  }
}

// ============================================================
// ✅ 共用頁：單篇（用 docId）
// ============================================================
class SiteContentDocPreviewPage extends StatefulWidget {
  final String docId;
  final String pageTitle;

  const SiteContentDocPreviewPage({
    super.key,
    required this.docId,
    required this.pageTitle,
  });

  @override
  State<SiteContentDocPreviewPage> createState() =>
      _SiteContentDocPreviewPageState();
}

class _SiteContentDocPreviewPageState extends State<SiteContentDocPreviewPage> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  Map<String, dynamic> _data = const {};
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
      _data = const {};
    });

    try {
      final doc = await _db.collection('site_contents').doc(widget.docId).get();

      // ✅ FIX：doc.data() 本身就是 Map<String, dynamic>?，不需要 as cast
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageTitle),
        actions: [
          IconButton(
            tooltip: '重新載入',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(child: Text('載入失敗：$_error'))
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _DocImagesBlock(data: _data),
                if ((_s(_data['title']).isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _s(_data['title']),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                if (_hasRichContent(_data))
                  _RichContentViewer(data: _data)
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      // ✅ FIX: surfaceVariant deprecated + withOpacity deprecated
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: SelectableText(
                      _pickBodyFull(_data).isEmpty
                          ? '（無內容）'
                          : _pickBodyFull(_data),
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DocImagesBlock extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DocImagesBlock({required this.data});

  @override
  Widget build(BuildContext context) {
    final images = <String>[];
    images.addAll(_safeStringList(data['images']));
    images.addAll(_safeStringList(data['imageUrls']));
    images.removeWhere((e) => e.trim().isEmpty);

    if (images.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 220,
          child: PageView.builder(
            itemCount: images.length,
            itemBuilder: (_, i) => Image.network(
              images[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 40),
              ),
              loadingBuilder: (_, child, ev) => ev == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ✅ Rich content viewer（Quill delta readOnly preview）
// - 不用 QuillEditorConfig(readOnly:)
// - 用 AbsorbPointer 讓它不可編輯（相容性最高）
// ============================================================
class _RichContentViewer extends StatefulWidget {
  final Map<String, dynamic> data;
  const _RichContentViewer({required this.data});

  @override
  State<_RichContentViewer> createState() => _RichContentViewerState();
}

class _RichContentViewerState extends State<_RichContentViewer> {
  quill.QuillController? _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = _buildController(widget.data);
  }

  @override
  void didUpdateWidget(covariant _RichContentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      _ctrl = _buildController(widget.data);
    }
  }

  quill.QuillController _buildController(Map<String, dynamic> data) {
    final raw =
        data['contentJson'] ??
        data['delta'] ??
        data['content'] ??
        data['quill'];

    quill.Document doc;
    try {
      if (raw is String && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          doc = quill.Document.fromJson(decoded);
        } else if (decoded is Map && decoded['ops'] is List) {
          doc = quill.Document.fromJson(List.from(decoded['ops']));
        } else {
          doc = quill.Document();
        }
      } else if (raw is List) {
        doc = quill.Document.fromJson(raw);
      } else if (raw is Map && raw['ops'] is List) {
        doc = quill.Document.fromJson(List.from(raw['ops']));
      } else {
        doc = quill.Document();
      }
    } catch (_) {
      doc = quill.Document();
    }

    return quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_ctrl == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: AbsorbPointer(
        absorbing: true, // ✅ 讓預覽不可編輯（最相容）
        child: quill.QuillEditor.basic(
          controller: _ctrl!,
          config: const quill.QuillEditorConfig(),
        ),
      ),
    );
  }
}

// ============================================================
// ✅ Helpers（安全取值）
// ============================================================

String _s(dynamic v) => (v ?? '').toString().trim();

List<String> _safeStringList(dynamic v) {
  if (v is List) {
    return v.map((e) => (e ?? '').toString()).toList();
  }
  return const [];
}

bool _hasRichContent(Map<String, dynamic> data) {
  final raw =
      data['contentJson'] ?? data['delta'] ?? data['content'] ?? data['quill'];
  if (raw == null) return false;
  if (raw is String) return raw.trim().isNotEmpty;
  if (raw is List) return raw.isNotEmpty;
  if (raw is Map && raw['ops'] is List) return (raw['ops'] as List).isNotEmpty;
  return false;
}

String _pickBodyPreview(Map<String, dynamic> data) {
  final t = _s(data['plainText']);
  if (t.isNotEmpty) return t.length > 120 ? '${t.substring(0, 120)}…' : t;

  final b = _s(data['body']);
  if (b.isNotEmpty) return b.length > 120 ? '${b.substring(0, 120)}…' : b;

  final h = _s(data['bodyHtml']);
  if (h.isNotEmpty) return h.length > 120 ? '${h.substring(0, 120)}…' : h;

  if (_hasRichContent(data)) return '（點擊查看內容）';

  return '';
}

String _pickBodyFull(Map<String, dynamic> data) {
  final t = _s(data['plainText']);
  if (t.isNotEmpty) return t;

  final b = _s(data['body']);
  if (b.isNotEmpty) return b;

  final h = _s(data['bodyHtml']);
  if (h.isNotEmpty) return h;

  return '';
}

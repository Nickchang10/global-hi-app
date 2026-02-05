// lib/pages/vendor_support_center_page.dart
//
// ✅ VendorSupportCenterPage（完整版｜可編譯｜Vendor Only｜支援中心/知識庫｜Firestore 即時同步｜分類/搜尋｜文章詳情｜附件連結複製｜匯出CSV(複製剪貼簿)｜Web+App）
//
// 目的：
// - 廠商後台的「支援中心/FAQ/文件下載」入口
// - 與主後台共用同一份 Firestore collection（連動）
// - Admin 可在主後台維護 support_articles，Vendor 端即時看到更新
//
// Firestore 結構建議：support_articles/{id}
//   - title: String
//   - category: String            // e.g. 帳號問題/出貨教學/保固維修
//   - content: String             // 純文字/Markdown/HTML（此頁以純文字顯示，不做 HTML render，避免套件依賴）
//   - fileUrl: String             // 附件URL（PDF/表單/教學連結）
//   - tags: List<String>          // e.g. ['登入','出貨']
//   - isActive: bool              // 預設 true
//   - sort: num (選用)            // 用於排序（越小越前）
//   - updatedAt: Timestamp
//   - createdAt: Timestamp
//
// 索引建議：
// - where(isActive==true) + orderBy(sort asc) + orderBy(updatedAt desc)（若有 sort）
// - where(isActive==true) + orderBy(updatedAt desc)
//
// 依賴：cloud_firestore, flutter/material, flutter/services
//
// 注意：
// - 若你要「開啟連結」到瀏覽器，需要 url_launcher 套件。此頁為保持可編譯不加外部依賴，改採「複製連結」。
//   你若已安裝 url_launcher，可在 _openUrl() 內改成 launchUrl。

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorSupportCenterPage extends StatefulWidget {
  const VendorSupportCenterPage({
    super.key,
    this.collection = 'support_articles',
    this.onlyActive = true,
    this.maxItems = 500,
    this.title = '支援中心',
  });

  final String collection;
  final bool onlyActive;
  final int maxItems;
  final String title;

  @override
  State<VendorSupportCenterPage> createState() => _VendorSupportCenterPageState();
}

class _VendorSupportCenterPageState extends State<VendorSupportCenterPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _q = '';

  String? _category; // null=全部
  String? _selectedId;

  bool _busy = false;
  String _busyLabel = '';

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(widget.collection);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Utils
  // -------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  Future<void> _setBusy(bool v, {String label = ''}) async {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  bool _isTrue(dynamic v) => v == true;

  bool _matchLocal(_ArticleRow r) {
    final d = r.data;

    if (widget.onlyActive && !_isTrue(d['isActive'])) return false;

    // category filter
    if (_category != null && _category!.trim().isNotEmpty) {
      if (_s(d['category']) != _category) return false;
    }

    // keyword filter
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final id = r.id.toLowerCase();
    final title = _s(d['title']).toLowerCase();
    final category = _s(d['category']).toLowerCase();
    final content = _s(d['content']).toLowerCase();
    final fileUrl = _s(d['fileUrl']).toLowerCase();
    final tags = (d['tags'] is List)
        ? (d['tags'] as List).map((e) => e.toString().toLowerCase()).join(' ')
        : '';

    return id.contains(q) ||
        title.contains(q) ||
        category.contains(q) ||
        content.contains(q) ||
        tags.contains(q) ||
        fileUrl.contains(q);
  }

  // -------------------------
  // Stream
  // -------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    Query<Map<String, dynamic>> q = _col;

    if (widget.onlyActive) {
      q = q.where('isActive', isEqualTo: true);
    }

    // 若有 sort 欄位可用 sort 排序，沒有也不會壞（Firestore 會要求欄位存在才可 orderBy）
    // 為避免缺欄位導致 runtime error，這裡不強制 sort orderBy。
    // 改用 updatedAt desc 做通用排序。
    q = q.orderBy('updatedAt', descending: true).limit(widget.maxItems);

    return q.snapshots();
  }

  // -------------------------
  // Detail dialog
  // -------------------------
  Future<void> _openDetail({required String id, required Map<String, dynamic> data}) async {
    final title = _s(data['title']).isEmpty ? '（無標題）' : _s(data['title']);
    final category = _s(data['category']);
    final content = _s(data['content']);
    final fileUrl = _s(data['fileUrl']);
    final tags = (data['tags'] is List) ? (data['tags'] as List).map((e) => e.toString()).toList() : <String>[];

    final updatedAt = _toDate(data['updatedAt']);
    final createdAt = _toDate(data['createdAt']);

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 760,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ),
                    IconButton(
                      tooltip: '複製文章ID',
                      onPressed: () => _copy(id, done: '已複製文章ID'),
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (category.isNotEmpty) _Pill(label: category, color: Theme.of(context).colorScheme.primary),
                    if (tags.isNotEmpty)
                      ...tags.take(8).map((t) => _MiniTag(label: t)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '更新：${_fmt(updatedAt)}    建立：${_fmt(createdAt)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                const Divider(height: 22),
                Text('內容', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                _Box(text: content.isEmpty ? '（無內容）' : content),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: fileUrl.isEmpty ? null : () => _copy(fileUrl, done: '已複製附件連結'),
                        icon: const Icon(Icons.link),
                        label: Text(fileUrl.isEmpty ? '無附件' : '複製附件連結'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copy(jsonEncode(data), done: '已複製文章 JSON'),
                        icon: const Icon(Icons.code),
                        label: const Text('複製 JSON'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('關閉'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------
  // Export CSV (copy)
  // -------------------------
  Future<void> _exportCsv(List<_ArticleRow> rows) async {
    if (rows.isEmpty) return;

    await _setBusy(true, label: '匯出中...');
    try {
      final headers = <String>[
        'articleId',
        'title',
        'category',
        'tags',
        'isActive',
        'updatedAt',
        'createdAt',
        'fileUrl',
      ];

      final buffer = StringBuffer()..writeln(headers.join(','));

      for (final r in rows) {
        final d = r.data;
        final tags = (d['tags'] is List) ? (d['tags'] as List).map((e) => e.toString()).join('|') : '';

        final line = <String>[
          r.id,
          _s(d['title']),
          _s(d['category']),
          tags,
          (_isTrue(d['isActive'])).toString(),
          (_toDate(d['updatedAt'])?.toIso8601String() ?? ''),
          (_toDate(d['createdAt'])?.toIso8601String() ?? ''),
          _s(d['fileUrl']),
        ].map((e) => e.replaceAll(',', '，')).toList();

        buffer.writeln(line.join(','));
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      _snack('已複製 CSV 到剪貼簿（可貼到 Excel）');
    } catch (e) {
      _snack('匯出失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final allRows = snap.data!.docs.map((d) => _ArticleRow(id: d.id, data: d.data())).toList();
              final rows = allRows.where(_matchLocal).toList();

              // categories
              final categories = <String>{};
              for (final r in allRows) {
                final c = _s(r.data['category']);
                if (c.isNotEmpty) categories.add(c);
              }
              final categoryList = categories.toList()..sort();

              final ids = rows.map((e) => e.id).toSet();
              if (_selectedId != null && !ids.contains(_selectedId)) _selectedId = null;

              return Column(
                children: [
                  _Filters(
                    searchCtrl: _searchCtrl,
                    category: _category,
                    categories: categoryList,
                    onlyActive: widget.onlyActive,
                    countLabel: '${rows.length} 筆',
                    onQueryChanged: (v) => setState(() => _q = v),
                    onClearQuery: () {
                      _searchCtrl.clear();
                      setState(() => _q = '');
                    },
                    onCategoryChanged: (v) => setState(() => _category = v),
                    onExport: (_busy || rows.isEmpty) ? null : () => _exportCsv(rows),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth >= 980;

                        final list = ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = rows[i];
                            final d = r.data;

                            final title = _s(d['title']).isEmpty ? '（無標題）' : _s(d['title']);
                            final category = _s(d['category']);
                            final content = _s(d['content']);
                            final fileUrl = _s(d['fileUrl']);
                            final updatedAt = _toDate(d['updatedAt']);

                            final tags = (d['tags'] is List)
                                ? (d['tags'] as List).map((e) => e.toString()).toList()
                                : <String>[];

                            return ListTile(
                              selected: r.id == _selectedId,
                              leading: Icon(fileUrl.isEmpty ? Icons.article_outlined : Icons.description_outlined),
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
                                  if (category.isNotEmpty)
                                    _Pill(label: category, color: Theme.of(context).colorScheme.primary),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (tags.isNotEmpty)
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: tags.take(6).map((t) => _MiniTag(label: t)).toList(),
                                      ),
                                    if (tags.isNotEmpty) const SizedBox(height: 6),
                                    Text(
                                      content.isEmpty ? '（無內容）' : content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '更新：${_fmt(updatedAt)}',
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'open') {
                                    setState(() => _selectedId = r.id);
                                    await _openDetail(id: r.id, data: d);
                                  } else if (v == 'copy_id') {
                                    await _copy(r.id, done: '已複製文章ID');
                                  } else if (v == 'copy_link') {
                                    final url = _s(d['fileUrl']);
                                    if (url.isEmpty) {
                                      _snack('此文章沒有附件連結');
                                    } else {
                                      await _copy(url, done: '已複製附件連結');
                                    }
                                  } else if (v == 'copy_json') {
                                    await _copy(jsonEncode(d), done: '已複製文章 JSON');
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'open', child: Text('開啟詳情')),
                                  PopupMenuDivider(),
                                  PopupMenuItem(value: 'copy_id', child: Text('複製文章ID')),
                                  PopupMenuItem(value: 'copy_link', child: Text('複製附件連結')),
                                  PopupMenuItem(value: 'copy_json', child: Text('複製 JSON')),
                                ],
                              ),
                              onTap: () async {
                                setState(() => _selectedId = r.id);
                                if (!wide) {
                                  await _openDetail(id: r.id, data: d);
                                }
                              },
                            );
                          },
                        );

                        if (!wide) return list;

                        final selected = _selectedId == null
                            ? null
                            : rows.where((e) => e.id == _selectedId).cast<_ArticleRow?>().firstOrNull;

                        return Row(
                          children: [
                            Expanded(flex: 3, child: list),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 2,
                              child: selected == null
                                  ? Center(
                                      child: Text(
                                        '請選擇一篇文章',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                    )
                                  : _DetailSide(
                                      id: selected.id,
                                      data: selected.data,
                                      fmt: _fmt,
                                      toDate: _toDate,
                                      onOpen: () => _openDetail(id: selected.id, data: selected.data),
                                      onCopyId: () => _copy(selected.id, done: '已複製文章ID'),
                                      onCopyLink: () {
                                        final url = _s(selected.data['fileUrl']);
                                        if (url.isEmpty) {
                                          _snack('此文章沒有附件連結');
                                          return Future.value();
                                        }
                                        return _copy(url, done: '已複製附件連結');
                                      },
                                      onCopyJson: () => _copy(jsonEncode(selected.data), done: '已複製文章 JSON'),
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
          if (_busy)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BusyBar(label: _busyLabel.isEmpty ? '處理中...' : _busyLabel),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Models / Extensions
// ------------------------------------------------------------
class _ArticleRow {
  final String id;
  final Map<String, dynamic> data;
  _ArticleRow({required this.id, required this.data});
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ------------------------------------------------------------
// Filters UI
// ------------------------------------------------------------
class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchCtrl,
    required this.category,
    required this.categories,
    required this.onlyActive,
    required this.countLabel,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onCategoryChanged,
    required this.onExport,
  });

  final TextEditingController searchCtrl;

  final String? category;
  final List<String> categories;
  final bool onlyActive;

  final String countLabel;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String?> onCategoryChanged;

  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final search = TextField(
      controller: searchCtrl,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        hintText: '搜尋：標題 / 內容 / tags / 類別 / 連結',
        suffixIcon: searchCtrl.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: '清除',
                onPressed: onClearQuery,
                icon: const Icon(Icons.clear),
              ),
      ),
      onChanged: onQueryChanged,
    );

    final dd = DropdownButtonFormField<String?>(
      value: category,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        labelText: '分類',
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('全部')),
        ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
      ],
      onChanged: onCategoryChanged,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 980;

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: dd),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('匯出CSV'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '共 $countLabel${onlyActive ? '（僅顯示啟用）' : ''}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              SizedBox(width: 240, child: dd),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined),
                label: const Text('匯出CSV'),
              ),
              const SizedBox(width: 10),
              Text(
                '共 $countLabel${onlyActive ? '（僅顯示啟用）' : ''}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Detail Side Panel
// ------------------------------------------------------------
class _DetailSide extends StatelessWidget {
  const _DetailSide({
    required this.id,
    required this.data,
    required this.fmt,
    required this.toDate,
    required this.onOpen,
    required this.onCopyId,
    required this.onCopyLink,
    required this.onCopyJson,
  });

  final String id;
  final Map<String, dynamic> data;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  final Future<void> Function() onOpen;
  final Future<void> Function() onCopyId;
  final Future<void> Function() onCopyLink;
  final Future<void> Function() onCopyJson;

  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _isTrue(dynamic v) => v == true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final title = _s(data['title']).isEmpty ? '（無標題）' : _s(data['title']);
    final category = _s(data['category']);
    final fileUrl = _s(data['fileUrl']);
    final content = _s(data['content']);
    final tags = (data['tags'] is List) ? (data['tags'] as List).map((e) => e.toString()).toList() : <String>[];

    final updatedAt = toDate(data['updatedAt']);
    final active = _isTrue(data['isActive']);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (category.isNotEmpty) _Pill(label: category, color: cs.primary),
              _MiniTag(label: active ? '啟用' : '停用'),
              if (tags.isNotEmpty) ...tags.take(10).map((t) => _MiniTag(label: t)),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'articleId', value: id, onCopy: onCopyId),
          const SizedBox(height: 6),
          _InfoRow(label: 'updatedAt', value: fmt(updatedAt)),
          const SizedBox(height: 6),
          _InfoRow(label: 'fileUrl', value: fileUrl.isEmpty ? '-' : fileUrl, onCopy: fileUrl.isEmpty ? null : onCopyLink),
          const Divider(height: 22),
          Text('內容', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Expanded(child: _Box(text: content.isEmpty ? '（無內容）' : content)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('開啟詳情'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopyJson,
                  icon: const Icon(Icons.code),
                  label: const Text('複製JSON'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Shared Widgets
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
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.onCopy});
  final String label;
  final String value;
  final Future<void> Function()? onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 92, child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
        Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w800))),
        if (onCopy != null)
          IconButton(
            tooltip: '複製',
            onPressed: () => onCopy!(),
            icon: const Icon(Icons.copy, size: 18),
          ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.18)),
      ),
      child: SingleChildScrollView(child: Text(text)),
    );
  }
}

class _BusyBar extends StatelessWidget {
  const _BusyBar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }
}

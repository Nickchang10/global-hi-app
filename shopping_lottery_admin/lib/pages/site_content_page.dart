// lib/pages/site_content_page.dart
//
// ✅ SiteContentPage（共用資訊頁底座｜最終穩定可編譯版）
// ------------------------------------------------------------
// 目的：統一 /services /news /faq /downloads 四頁樣式與行為
//
// Firestore：site_contents/{docId}
// 建議欄位：
// - title: String
// - content: String（可選）
// - items: List<Map>（可選）
//    items 每筆建議：
//    - title 或 name: String
//    - body 或 desc 或 content: String
//    - url 或 link: String
//    - order: number（可選）
//    - createdAt/updatedAt: Timestamp（可選）
//
// 功能：
// - 即時監聽（snapshots）
// - AppBar：重新整理 / 複製 doc path / 匯出 CSV
// - 搜尋：title/body/url/id
// - 可複製：JSON、URL、docId、內容
// - 不依賴 url_launcher / markdown 套件（避免編譯失敗）
//
// 依賴：cloud_firestore, flutter/material, flutter/services

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SiteContentPage extends StatefulWidget {
  const SiteContentPage({
    super.key,
    required this.docId,
    required this.fallbackTitle,
    required this.fallbackContent,
    this.collection = 'site_contents',
  });

  final String collection;
  final String docId;
  final String fallbackTitle;
  final String fallbackContent;

  @override
  State<SiteContentPage> createState() => _SiteContentPageState();
}

class _SiteContentPageState extends State<SiteContentPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _q = '';

  bool _busy = false;
  String _busyLabel = '';

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection(widget.collection).doc(widget.docId);

  String get _path => '${widget.collection}/${widget.docId}';

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

  Future<void> _setBusy(bool v, {String label = ''}) async {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  Future<void> _refreshServer() async {
    await _setBusy(true, label: '重新整理中...');
    try {
      await _ref.get(const GetOptions(source: Source.server));
      _snack('已重新整理');
    } catch (e) {
      _snack('重新整理失敗：$e');
    } finally {
      await _setBusy(false);
      if (mounted) setState(() {});
    }
  }

  // -------------------------
  // Parse
  // -------------------------
  _Parsed _parse(DocumentSnapshot<Map<String, dynamic>>? snap) {
    final exists = snap?.exists == true;
    final data = snap?.data() ?? <String, dynamic>{};

    final title = _s(data['title']).isEmpty ? widget.fallbackTitle : _s(data['title']);
    final content = _s(data['content']).isEmpty ? widget.fallbackContent : _s(data['content']);

    final rawItems = data['items'];
    final items = <_Item>[];

    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map) {
          final m = Map<String, dynamic>.from(it as Map);
          items.add(_Item.fromMap(m));
        }
      }
    }

    // order（可選）
    items.sort((a, b) {
      final ao = a.order ?? 1 << 30;
      final bo = b.order ?? 1 << 30;
      final c = ao.compareTo(bo);
      if (c != 0) return c;
      // 次排序：updatedAt/createdAt（新到舊）
      final ad = a.updatedAt ?? a.createdAt;
      final bd = b.updatedAt ?? b.createdAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    return _Parsed(
      exists: exists,
      data: data,
      title: title,
      content: content,
      items: items,
    );
  }

  bool _matchItem(_Item it) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    return it.id.toLowerCase().contains(q) ||
        it.title.toLowerCase().contains(q) ||
        it.body.toLowerCase().contains(q) ||
        it.url.toLowerCase().contains(q);
  }

  Future<void> _exportCsv(_Parsed p) async {
    // 若 items 有資料：匯出 items；否則匯出 title/content
    final buffer = StringBuffer();

    if (p.items.isNotEmpty) {
      buffer.writeln('id,title,body,url,order,createdAt,updatedAt');
      for (final it in p.items) {
        final row = <String>[
          it.id,
          it.title,
          it.body,
          it.url,
          (it.order ?? '').toString(),
          (it.createdAt?.toIso8601String() ?? ''),
          (it.updatedAt?.toIso8601String() ?? ''),
        ].map((e) => e.replaceAll(',', '，')).toList();
        buffer.writeln(row.join(','));
      }
    } else {
      buffer.writeln('title,content');
      buffer.writeln('${p.title.replaceAll(',', '，')},${p.content.replaceAll(',', '，')}');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    _snack('已複製 CSV 到剪貼簿（可貼到 Excel）');
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fallbackTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _busy ? null : _refreshServer,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '複製 doc path',
            onPressed: () => _copy(_path, done: '已複製 doc path'),
            icon: const Icon(Icons.copy),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorBody(
              title: widget.fallbackTitle,
              error: '讀取失敗：${snap.error}',
              hint: kDebugMode ? 'doc=$_path' : null,
            );
          }

          final p = _parse(snap.data);

          final filteredItems = p.items.where(_matchItem).toList();
          final hasList = p.items.isNotEmpty;

          return Stack(
            children: [
              Column(
                children: [
                  _FilterBar(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _q = v),
                    onClear: () {
                      _searchCtrl.clear();
                      setState(() => _q = '');
                    },
                    subtitle: hasList
                        ? '共 ${p.items.length} 筆（篩選後 ${filteredItems.length} 筆）'
                        : (p.exists ? '已讀取 $_path' : '使用預設內容（$_path 不存在）'),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: hasList
                        ? _ItemsList(
                            title: p.title,
                            items: filteredItems,
                            fmtTime: _fmt,
                            onCopyJson: (m) => _copy(jsonEncode(m), done: '已複製 JSON'),
                            onCopyUrl: (u) => _copy(u, done: '已複製 URL'),
                            onCopyText: (t) => _copy(t, done: '已複製內容'),
                          )
                        : _DocBody(
                            title: p.title,
                            content: p.content,
                            debugHint: kDebugMode ? 'doc=$_path exists=${p.exists}' : null,
                            onCopyTitle: () => _copy(p.title, done: '已複製標題'),
                            onCopyContent: () => _copy(p.content, done: '已複製內容'),
                            onCopyJson: () => _copy(jsonEncode(p.data), done: '已複製 JSON'),
                          ),
                  ),
                ],
              ),
              if (_busy)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BusyBar(label: _busyLabel.isEmpty ? '處理中...' : _busyLabel),
                ),
              // 浮動匯出按鈕（右下）
              Positioned(
                right: 14,
                bottom: 14 + (_busy ? 50 : 0),
                child: FloatingActionButton.extended(
                  onPressed: _busy ? null : () => _exportCsv(p),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('匯出CSV'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Models
// ------------------------------------------------------------
class _Parsed {
  final bool exists;
  final Map<String, dynamic> data;
  final String title;
  final String content;
  final List<_Item> items;

  _Parsed({
    required this.exists,
    required this.data,
    required this.title,
    required this.content,
    required this.items,
  });
}

class _Item {
  final String id;
  final String title;
  final String body;
  final String url;
  final int? order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  _Item({
    required this.id,
    required this.title,
    required this.body,
    required this.url,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();
  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  factory _Item.fromMap(Map<String, dynamic> m) {
    final title = _s(m['title']).isNotEmpty ? _s(m['title']) : _s(m['name']);
    final body = _s(m['body']).isNotEmpty
        ? _s(m['body'])
        : (_s(m['desc']).isNotEmpty ? _s(m['desc']) : _s(m['content']));
    final url = _s(m['url']).isNotEmpty ? _s(m['url']) : _s(m['link']);

    return _Item(
      id: _s(m['id']).isEmpty ? '' : _s(m['id']),
      title: title,
      body: body,
      url: url,
      order: m['order'] is num ? (m['order'] as num).toInt() : null,
      createdAt: _toDate(m['createdAt']),
      updatedAt: _toDate(m['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'url': url,
        'order': order,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}

// ------------------------------------------------------------
// Widgets
// ------------------------------------------------------------
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.subtitle,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              hintText: '搜尋：標題 / 內容 / URL / id',
              suffixIcon: controller.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除',
                      onPressed: onClear,
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocBody extends StatelessWidget {
  const _DocBody({
    required this.title,
    required this.content,
    required this.onCopyTitle,
    required this.onCopyContent,
    required this.onCopyJson,
    this.debugHint,
  });

  final String title;
  final String content;
  final String? debugHint;

  final VoidCallback onCopyTitle;
  final VoidCallback onCopyContent;
  final VoidCallback onCopyJson;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '複製標題',
              onPressed: onCopyTitle,
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          content,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onCopyContent,
              icon: const Icon(Icons.content_copy),
              label: const Text('複製內容'),
            ),
            OutlinedButton.icon(
              onPressed: onCopyJson,
              icon: const Icon(Icons.code),
              label: const Text('複製JSON'),
            ),
          ],
        ),
        if (debugHint != null) ...[
          const SizedBox(height: 18),
          const Divider(),
          Text(debugHint!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      ],
    );
  }
}

class _ItemsList extends StatelessWidget {
  const _ItemsList({
    required this.title,
    required this.items,
    required this.fmtTime,
    required this.onCopyJson,
    required this.onCopyUrl,
    required this.onCopyText,
  });

  final String title;
  final List<_Item> items;
  final String Function(DateTime?) fmtTime;

  final ValueChanged<Map<String, dynamic>> onCopyJson;
  final ValueChanged<String> onCopyUrl;
  final ValueChanged<String> onCopyText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Center(
        child: Text('沒有資料', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        for (final it in items)
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest.withOpacity(0.35),
            child: ExpansionTile(
              title: Text(
                it.title.isEmpty ? '（未命名）' : it.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  if (it.url.isNotEmpty)
                    Text('URL：${it.url}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  if (it.createdAt != null)
                    Text('建立：${fmtTime(it.createdAt)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  if (it.updatedAt != null)
                    Text('更新：${fmtTime(it.updatedAt)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (it.body.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SelectableText(it.body),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (it.url.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () => onCopyUrl(it.url),
                              icon: const Icon(Icons.link),
                              label: const Text('複製URL'),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => onCopyText(it.body.isNotEmpty ? it.body : it.title),
                            icon: const Icon(Icons.content_copy),
                            label: const Text('複製內容'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => onCopyJson(it.toJson()),
                            icon: const Icon(Icons.code),
                            label: const Text('複製JSON'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.title, required this.error, this.hint});

  final String title;
  final String error;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text(error, style: TextStyle(color: cs.error)),
        if (hint != null) ...[
          const SizedBox(height: 16),
          Text(hint!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      ],
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
            Expanded(
              child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

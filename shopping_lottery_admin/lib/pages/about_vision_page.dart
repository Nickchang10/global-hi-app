// lib/pages/about_vision_page.dart
//
// ✅ AboutVisionPage（最終穩定可編譯完整版｜支援 imageUrl + 簡易排版｜Web+App）
// ------------------------------------------------------------
// Route: /about/vision
//
// Firestore：site_contents/about_vision
// 建議欄位：
//   - title: String
//   - content: String
//   - imageUrl: String?          (可選)
//   - updatedAt: Timestamp?      (可選)
//
// 特性：
// - doc 不存在 / 欄位空白：顯示預設內容
// - 重新整理（強制 server）
// - 支援即時更新、錯誤顯示、Debug 提示（僅 Debug）
// - 支援複製：標題 / 內容 / doc 路徑
// - content 簡易排版：
//    # / ## / ### 標題行
//    - 或 * 項目符號
//    **粗體**、`行內碼`
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutVisionPage extends StatefulWidget {
  const AboutVisionPage({super.key});

  static const String routeName = '/about/vision';

  @override
  State<AboutVisionPage> createState() => _AboutVisionPageState();
}

class _AboutVisionPageState extends State<AboutVisionPage> {
  final DocumentReference<Map<String, dynamic>> _docRef =
      FirebaseFirestore.instance.collection('site_contents').doc('about_vision');

  static const String _fallbackTitle = '品牌願景';
  static const String _fallbackContent =
      '這裡是「品牌願景」頁面。\n\n'
      '你可以在 Firestore 的 site_contents/about_vision 設定 title、content（以及可選的 imageUrl）來更新顯示內容。';

  bool _busy = false;

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
    if (d == null) return '';
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

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _docRef.get(const GetOptions(source: Source.server));
      _snack('已重新整理');
    } catch (e) {
      _snack('重新整理失敗：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -------------------------
  // Content rendering (simple formatting)
  // -------------------------
  List<InlineSpan> _inlineSpans(
    String line, {
    required TextStyle base,
    required TextStyle bold,
    required TextStyle code,
    required Color codeBg,
  }) {
    // 支援 **bold** 與 `code`
    final spans = <InlineSpan>[];

    int i = 0;
    while (i < line.length) {
      final boldStart = line.indexOf('**', i);
      final codeStart = line.indexOf('`', i);

      // 找最近的標記（bold 或 code）
      int next = line.length;
      String? type; // 'bold' | 'code'
      if (boldStart >= 0 && boldStart < next) {
        next = boldStart;
        type = 'bold';
      }
      if (codeStart >= 0 && codeStart < next) {
        next = codeStart;
        type = 'code';
      }

      // 先加普通文字
      if (next > i) {
        spans.add(TextSpan(text: line.substring(i, next), style: base));
        i = next;
      }

      if (type == null) break;

      if (type == 'bold') {
        final start = i + 2;
        final end = line.indexOf('**', start);
        if (end < 0) {
          // 沒有閉合，視為普通文字
          spans.add(TextSpan(text: line.substring(i), style: base));
          break;
        }
        final txt = line.substring(start, end);
        spans.add(TextSpan(text: txt, style: bold));
        i = end + 2;
      } else if (type == 'code') {
        final start = i + 1;
        final end = line.indexOf('`', start);
        if (end < 0) {
          spans.add(TextSpan(text: line.substring(i), style: base));
          break;
        }
        final txt = line.substring(start, end);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: codeBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: codeBg.withOpacity(0.6)),
              ),
              child: Text(txt, style: code),
            ),
          ),
        );
        i = end + 1;
      }
    }

    return spans;
  }

  List<Widget> _renderContentBlocks(String content) {
    final cs = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55) ??
        const TextStyle(fontSize: 15, height: 1.55);
    final bold = base.copyWith(fontWeight: FontWeight.w900);
    final code = base.copyWith(
      fontFamily: 'monospace',
      fontSize: (base.fontSize ?? 15) - 1,
      height: 1.2,
    );

    final lines = content.replaceAll('\r\n', '\n').split('\n');

    final blocks = <Widget>[];
    for (final raw in lines) {
      final line = raw.trimRight();

      // 空行：段落間距
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 10));
        continue;
      }

      // Heading: # / ## / ###
      TextStyle? headingStyle;
      String headingText = line;
      if (line.startsWith('### ')) {
        headingText = line.substring(4).trim();
        headingStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            );
      } else if (line.startsWith('## ')) {
        headingText = line.substring(3).trim();
        headingStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            );
      } else if (line.startsWith('# ')) {
        headingText = line.substring(2).trim();
        headingStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            );
      }

      if (headingStyle != null) {
        blocks.add(const SizedBox(height: 4));
        blocks.add(Text(headingText, style: headingStyle));
        blocks.add(const SizedBox(height: 6));
        continue;
      }

      // Bullet: - / *
      final isBullet = line.startsWith('- ') || line.startsWith('* ');
      if (isBullet) {
        final txt = line.substring(2).trimLeft();
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: bold.copyWith(color: cs.onSurfaceVariant)),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: _inlineSpans(
                        txt,
                        base: base,
                        bold: bold,
                        code: code,
                        codeBg: cs.surfaceContainerHighest.withOpacity(0.55),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Normal paragraph line
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: RichText(
            text: TextSpan(
              children: _inlineSpans(
                line,
                base: base,
                bold: bold,
                code: code,
                codeBg: cs.surfaceContainerHighest.withOpacity(0.55),
              ),
            ),
          ),
        ),
      );
    }

    return blocks;
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(_fallbackTitle),
        actions: [
          IconButton(
            tooltip: '重新整理（Server）',
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _busy ? null : _refresh,
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (v) async {
              if (v == 'copy_path') {
                await _copy('site_contents/about_vision', done: '已複製 doc 路徑');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'copy_path',
                child: Text('複製 Firestore 路徑'),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _docRef.snapshots(),
        builder: (context, snap) {
          final isFirstLoading = snap.connectionState == ConnectionState.waiting &&
              !snap.hasData &&
              !snap.hasError;

          if (isFirstLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final exists = snap.data?.exists == true;
          final data = snap.data?.data() ?? <String, dynamic>{};

          // 內容（fallback 保底）
          final title = exists ? _s(data['title']) : '';
          final content = exists ? _s(data['content']) : '';
          final imageUrl = exists ? _s(data['imageUrl']) : '';
          final updatedAt = _toDate(data['updatedAt']);

          final displayTitle = title.isEmpty ? _fallbackTitle : title;
          final displayContent = content.isEmpty ? _fallbackContent : content;

          // 錯誤狀態：仍顯示 fallback + 錯誤
          final errorText = snap.hasError ? '讀取失敗：${snap.error}' : '';

          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // error banner
                if (errorText.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.error.withOpacity(0.25)),
                    ),
                    child: Text(
                      '$errorText\n\n（仍顯示可用內容，避免空白）',
                      style: TextStyle(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // image
                if (imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: cs.surfaceContainerHighest.withOpacity(0.25),
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        displayTitle,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '複製標題',
                      onPressed: () => _copy(displayTitle, done: '已複製標題'),
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),

                // meta
                if (updatedAt != null && _fmt(updatedAt).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '更新時間：${_fmt(updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],

                const SizedBox(height: 12),

                // content blocks
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outline.withOpacity(0.18)),
                    color: cs.surfaceContainerHighest.withOpacity(0.18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderContentBlocks(displayContent),
                  ),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copy(displayContent, done: '已複製內容'),
                      icon: const Icon(Icons.copy_all),
                      label: const Text('複製內容'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copy(
                        'site_contents/about_vision',
                        done: '已複製 doc 路徑',
                      ),
                      icon: const Icon(Icons.link),
                      label: const Text('複製路徑'),
                    ),
                  ],
                ),

                if (kDebugMode) ...[
                  const SizedBox(height: 18),
                  Divider(color: cs.outline.withOpacity(0.25)),
                  Text(
                    'Debug：doc=site_contents/about_vision exists=$exists',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

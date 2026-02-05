// lib/pages/news_detail_page.dart
//
// ✅ NewsDetailPage（最終穩定可編譯完整版｜最新消息詳情｜Web+App）
// ------------------------------------------------------------
// 建議路由：
// - 方式 A：Navigator.pushNamed(context, '/news_detail', arguments: newsId);
// - 方式 B：直接用路徑 /news/{id}（需要 main.dart 做 startsWith('/news/') 解析）
//
// Firestore：collection('news') / {newsId}
// 建議欄位：
//   - title (String)
//   - summary (String)
//   - content (String)
//   - imageUrl (String?)
//   - createdAt (Timestamp)
//   - updatedAt (Timestamp?)
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NewsDetailPage extends StatefulWidget {
  const NewsDetailPage({
    super.key,
    required this.newsId,
    this.collection = 'news',
  });

  static const String routeName = '/news_detail';

  final String newsId;
  final String collection;

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  final _db = FirebaseFirestore.instance;

  bool _busy = false;
  String _busyLabel = '';

  String get _id => widget.newsId.trim();

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection(widget.collection).doc(_id);

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

  Future<void> _refresh() async {
    await _setBusy(true, label: '重新整理中...');
    try {
      await _doc.get(const GetOptions(source: Source.server));
      _snack('已重新整理');
    } catch (e) {
      _snack('重新整理失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    if (_id.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('newsId 不可為空')),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('最新消息'),
            actions: [
              IconButton(
                tooltip: '重新整理',
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: '複製 newsId',
                onPressed: () => _copy(_id, done: '已複製 newsId'),
                icon: const Icon(Icons.copy),
              ),
              if (kDebugMode)
                IconButton(
                  tooltip: 'Debug：複製 Firestore doc 路徑',
                  onPressed: () => _copy(
                    '${widget.collection}/$_id',
                    done: '已複製 doc 路徑',
                  ),
                  icon: const Icon(Icons.bug_report_outlined),
                ),
              const SizedBox(width: 6),
            ],
          ),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _doc.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                return _ErrorBody(
                  message: '讀取失敗：${snap.error}\n\n請稍後再試或聯繫管理員。',
                );
              }

              final exists = snap.data?.exists == true;
              final data = snap.data?.data() ?? <String, dynamic>{};

              if (!exists) {
                return _ErrorBody(
                  message: '此消息不存在或已被刪除。\n\nnewsId：$_id',
                );
              }

              final title =
                  _s(data['title']).isEmpty ? '（未命名）' : _s(data['title']);
              final summary = _s(data['summary']);
              final content = _s(data['content']);
              final imageUrl = _s(data['imageUrl']);
              final createdAt = _toDate(data['createdAt']);
              final updatedAt = _toDate(data['updatedAt']);

              final displayBody = content.isNotEmpty
                  ? content
                  : (summary.isNotEmpty ? summary : '（暫無內容）');

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _MetaChip(
                        icon: Icons.schedule,
                        label: '發布：${_fmt(createdAt)}',
                      ),
                      if (updatedAt != null)
                        _MetaChip(
                          icon: Icons.update,
                          label: '更新：${_fmt(updatedAt)}',
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (imageUrl.isNotEmpty)
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

                  if (imageUrl.isNotEmpty) const SizedBox(height: 12),

                  if (summary.isNotEmpty) ...[
                    Text(
                      '摘要',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outline.withOpacity(0.18)),
                        color: cs.surfaceContainerHighest.withOpacity(0.22),
                      ),
                      child: Text(summary),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    '內容',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withOpacity(0.18)),
                      color: cs.surfaceContainerHighest.withOpacity(0.22),
                    ),
                    child: Text(displayBody),
                  ),

                  const SizedBox(height: 14),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _copy(displayBody, done: '已複製內容'),
                        icon: const Icon(Icons.copy_all),
                        label: const Text('複製內容'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _copy(title, done: '已複製標題'),
                        icon: const Icon(Icons.title),
                        label: const Text('複製標題'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _copy(
                          data.toString(),
                          done: '已複製資料（toString）',
                        ),
                        icon: const Icon(Icons.data_object),
                        label: const Text('複製資料'),
                      ),
                    ],
                  ),

                  if (kDebugMode) ...[
                    const SizedBox(height: 18),
                    const Divider(),
                    Text(
                      'Debug：doc=${widget.collection}/$_id exists=$exists',
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ],
              );
            },
          ),
        ),

        if (_busy)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child:
                _BusyBar(label: _busyLabel.isEmpty ? '處理中...' : _busyLabel),
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
        color: cs.surfaceContainerHighest.withOpacity(0.18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: TextStyle(color: cs.error, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
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
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/pages/downloads_page.dart
//
// ✅ DownloadsPage（最終可編譯完整版｜下載中心｜免複合索引版｜Web+App）
// ------------------------------------------------------------
// Route: /downloads
//
// Firestore（方案 A：頂層集合）
// collection: downloads
// 建議欄位：
//   - title: String
//   - description: String
//   - url: String (下載連結)
//   - fileName: String? (檔名)
//   - size: num? (bytes or KB/MB 由你自訂)
//   - createdAt: Timestamp
//   - updatedAt: Timestamp? (optional)
//   - isPublic: bool? (optional)
//
// ✅ 特性：
// - 只使用 orderBy(createdAt desc)（不使用 where），因此「不需要建立 composite index」
// - 搜尋（標題/描述/連結/id/檔名）改為前端過濾，避免索引問題
// - 支援即時更新、錯誤顯示、空狀態、Debug 訊息
// - 內建複製：連結 / id / 原始資料
//
// ✅ 修正：移除 withOpacity deprecations（改用 withValues(alpha: ...)）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  static const String routeName = '/downloads';

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();

  String _q = '';

  CollectionReference<Map<String, dynamic>> get _coll =>
      _db.collection('downloads');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Utils
  // -------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();
  String _lower(dynamic v) => _s(v).toLowerCase();

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '—';
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

  bool _matchDownload({
    required String id,
    required Map<String, dynamic> data,
    required String q,
  }) {
    final qq = q.trim().toLowerCase();
    if (qq.isEmpty) return true;

    final title = _lower(data['title']);
    final desc = _lower(data['description']);
    final url = _lower(data['url']);
    final fileName = _lower(data['fileName']);
    final idLower = id.toLowerCase();

    return title.contains(qq) ||
        desc.contains(qq) ||
        url.contains(qq) ||
        fileName.contains(qq) ||
        idLower.contains(qq);
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('下載中心'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // 搜尋列
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋：標題 / 描述 / 連結 / id / 檔名',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                suffixIcon: _q.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _q = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),

          // 清單
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // ✅ 只 orderBy，不加 where => 不需要 composite index
              stream: _coll.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return _ErrorBody(
                    message:
                        '讀取失敗：${snap.error}\n\n若你之前是用 where+orderBy 才會需要索引；\n此版本已改為前端搜尋，不需建立索引。',
                  );
                }

                final docs =
                    snap.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                // 前端搜尋過濾
                final filtered = docs.where((d) {
                  return _matchDownload(id: d.id, data: d.data(), q: _q);
                }).toList();

                if (filtered.isEmpty) {
                  return _EmptyBody(
                    label: _q.trim().isEmpty
                        ? '目前尚無可下載的項目。'
                        : '沒有符合「${_q.trim()}」的下載項目。',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final data = doc.data();
                    final id = doc.id;

                    final title = _s(data['title']).isEmpty
                        ? '(未命名)'
                        : _s(data['title']);
                    final desc = _s(data['description']);
                    final url = _s(data['url']);
                    final fileName = _s(data['fileName']);
                    final createdAt = _toDate(data['createdAt']);
                    final updatedAt = _toDate(data['updatedAt']);

                    return Card(
                      elevation: 1.2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + time
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _fmt(createdAt),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: cs.outline,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),

                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                desc,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],

                            const SizedBox(height: 10),

                            // Meta
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _MetaChip(
                                  icon: Icons.fingerprint,
                                  label: 'ID：$id',
                                ),
                                if (fileName.isNotEmpty)
                                  _MetaChip(
                                    icon: Icons.insert_drive_file_outlined,
                                    label: fileName,
                                  ),
                                if (updatedAt != null)
                                  _MetaChip(
                                    icon: Icons.update,
                                    label: '更新：${_fmt(updatedAt)}',
                                  ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // URL box
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: cs.outline.withValues(alpha: 0.18),
                                ),
                                color: cs.surfaceContainerHighest.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.link,
                                    size: 18,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SelectableText(
                                      url.isEmpty ? '（尚未設定下載連結 url）' : url,
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Actions
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: url.isEmpty
                                      ? null
                                      : () => _copy(url, done: '已複製下載連結'),
                                  icon: const Icon(Icons.copy),
                                  label: const Text('複製連結'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _copy(id, done: '已複製 ID'),
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('複製 ID'),
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
                              const SizedBox(height: 12),
                              Divider(
                                color: cs.outline.withValues(alpha: 0.25),
                              ),
                              Text(
                                'Debug：collection=downloads / docId=$id',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (kDebugMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
              child: Text(
                'Debug：collection=downloads orderBy=createdAt desc  search="${_q.trim()}"',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
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
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.16),
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

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          label,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          textAlign: TextAlign.center,
        ),
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

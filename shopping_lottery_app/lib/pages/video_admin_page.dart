import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ✅ VideoAdminPage（影片管理｜完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正重點：
/// - ✅ 移除 youtube_player_flutter 依賴（避免 uri_does_not_exist）
/// - ✅ 修正第 11 行：移除未註解的「—」字元行（避免 missing_const_final_var_or_type）
/// - ✅ 修正：withOpacity deprecated → withValues(alpha: ...)
///
/// 功能（管理層級 UI，先確保可跑）：
/// - 影片清單（可排序 Reorder）
/// - 搜尋 / 只顯示啟用
/// - 新增 / 編輯 / 刪除
/// - 自動解析 YouTube Video ID
/// - 顯示縮圖（img.youtube.com）
/// - 複製連結 / 複製 VideoId
/// ------------------------------------------------------------
class VideoAdminPage extends StatefulWidget {
  const VideoAdminPage({super.key});

  @override
  State<VideoAdminPage> createState() => _VideoAdminPageState();
}

class _VideoAdminPageState extends State<VideoAdminPage> {
  final TextEditingController _search = TextEditingController();
  bool _onlyActive = false;

  final List<_VideoItem> _items = [
    _VideoItem(
      id: 'v1',
      title: 'Osmile 介紹影片',
      youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    _VideoItem(
      id: 'v2',
      title: '抽獎活動說明',
      youtubeUrl: 'https://youtu.be/dQw4w9WgXcQ',
      isActive: false,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  List<_VideoItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _items.where((e) {
      if (_onlyActive && !e.isActive) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          e.youtubeUrl.toLowerCase().contains(q) ||
          (e.videoId ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('影片管理'),
        actions: [
          IconButton(
            tooltip: '新增',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: '重置示範資料',
            onPressed: _resetDemo,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: Column(
        children: [
          _toolbar(),
          const Divider(height: 1),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('沒有影片'))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;

                        final moved = list.removeAt(oldIndex);
                        list.insert(newIndex, moved);

                        // 依 filtered 新順序重排回 _items
                        final ids = list.map((e) => e.id).toList();
                        final remaining = _items
                            .where((e) => !ids.contains(e.id))
                            .toList();
                        _items
                          ..clear()
                          ..addAll(list)
                          ..addAll(remaining);
                      });
                    },
                    itemBuilder: (context, i) {
                      final v = list[i];
                      return _videoCard(v, key: ValueKey(v.id));
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('新增影片'),
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋：標題 / 連結 / Video ID',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          FilterChip(
            label: const Text('只顯示啟用'),
            selected: _onlyActive,
            onSelected: (v) => setState(() => _onlyActive = v),
          ),
        ],
      ),
    );
  }

  Widget _videoCard(_VideoItem v, {required Key key}) {
    final vid = v.videoId;
    final thumb = (vid == null || vid.isEmpty)
        ? null
        : 'https://img.youtube.com/vi/$vid/0.jpg';

    return Card(
      key: key,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumb(thumb),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          v.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Switch(
                        value: v.isActive,
                        onChanged: (on) => setState(() => v.isActive = on),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    v.youtubeUrl,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _miniChip(
                        icon: Icons.videocam_outlined,
                        text: (vid == null || vid.isEmpty)
                            ? '無法解析 VideoId'
                            : 'ID: $vid',
                      ),
                      _miniChip(
                        icon: Icons.calendar_month_outlined,
                        text: '建立：${_fmtDate(v.createdAt)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openPreview(v),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('預覽'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _copy(v.youtubeUrl, label: '已複製連結'),
                        icon: const Icon(Icons.link),
                        label: const Text('複製連結'),
                      ),
                      OutlinedButton.icon(
                        onPressed: (vid == null || vid.isEmpty)
                            ? null
                            : () => _copy(vid, label: '已複製 VideoId'),
                        icon: const Icon(Icons.copy),
                        label: const Text('複製 ID'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _openEditor(edit: v),
                        icon: const Icon(Icons.edit),
                        label: const Text('編輯'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _remove(v),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('刪除'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        height: 72,
        color: Colors.grey.shade200,
        child: url == null
            ? Center(
                child: Text(
                  'No\nThumbnail',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    'Thumb\nError',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _miniChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        // ✅ withOpacity -> withValues(alpha: ...)
        color: Colors.blueAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blueAccent),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  // ---------------- actions ----------------

  Future<void> _openEditor({_VideoItem? edit}) async {
    final titleCtrl = TextEditingController(text: edit?.title ?? '');
    final urlCtrl = TextEditingController(text: edit?.youtubeUrl ?? '');
    bool isActive = edit?.isActive ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(edit == null ? '新增影片' : '編輯影片'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: '標題',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'YouTube 連結',
                  hintText: 'https://www.youtube.com/watch?v=...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isActive,
                onChanged: (v) => isActive = v,
                title: const Text('啟用'),
                subtitle: const Text('不啟用則不顯示於前台'),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '提示：此版本不內嵌播放，只做管理。要內嵌請加入 youtube_player_flutter。',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('儲存'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final t = titleCtrl.text.trim();
    final u = urlCtrl.text.trim();

    if (t.isEmpty || u.isEmpty) {
      _toast('標題與連結不可空白');
      return;
    }

    setState(() {
      if (edit == null) {
        final id = 'v_${DateTime.now().millisecondsSinceEpoch}';
        _items.insert(
          0,
          _VideoItem(
            id: id,
            title: t,
            youtubeUrl: u,
            isActive: isActive,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        edit.title = t;
        edit.youtubeUrl = u;
        edit.isActive = isActive;
      }
    });

    _toast('已儲存');
  }

  void _remove(_VideoItem v) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除影片'),
        content: Text('確定刪除「${v.title}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _items.removeWhere((e) => e.id == v.id));
              _toast('已刪除');
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  void _openPreview(_VideoItem v) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _VideoPreviewPage(item: v)));
  }

  Future<void> _copy(String text, {required String label}) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast(label);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _resetDemo() {
    setState(() {
      _items
        ..clear()
        ..addAll([
          _VideoItem(
            id: 'v1',
            title: 'Osmile 介紹影片',
            youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            isActive: true,
            createdAt: DateTime.now().subtract(const Duration(days: 10)),
          ),
          _VideoItem(
            id: 'v2',
            title: '抽獎活動說明',
            youtubeUrl: 'https://youtu.be/dQw4w9WgXcQ',
            isActive: false,
            createdAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
        ]);
    });
    _toast('已重置示範資料');
  }
}

class _VideoPreviewPage extends StatelessWidget {
  const _VideoPreviewPage({required this.item});

  final _VideoItem item;

  @override
  Widget build(BuildContext context) {
    final vid = item.videoId;
    final thumb = (vid == null || vid.isEmpty)
        ? null
        : 'https://img.youtube.com/vi/$vid/0.jpg';

    return Scaffold(
      appBar: AppBar(title: const Text('影片預覽')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (thumb != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                thumb,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Text('縮圖載入失敗'),
                ),
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text('無法解析縮圖'),
            ),
          const SizedBox(height: 14),
          Text(
            item.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(item.youtubeUrl, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // ✅ withOpacity -> withValues(alpha: ...)
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.18)),
            ),
            child: const Text(
              '此版本未內嵌 YouTube 播放器（避免缺套件造成編譯失敗）。\n'
              '若要內嵌播放，請加入 youtube_player_flutter 或 webview_flutter。',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoItem {
  _VideoItem({
    required this.id,
    required this.title,
    required this.youtubeUrl,
    required this.isActive,
    required this.createdAt,
  });

  String id;
  String title;
  String youtubeUrl;
  bool isActive;
  DateTime createdAt;

  String? get videoId => _extractYoutubeId(youtubeUrl);

  static String? _extractYoutubeId(String url) {
    final u = url.trim();

    final short = RegExp(r'youtu\.be\/([a-zA-Z0-9_-]{6,})');
    final m1 = short.firstMatch(u);
    if (m1 != null) return m1.group(1);

    final watch = RegExp(r'v=([a-zA-Z0-9_-]{6,})');
    final m2 = watch.firstMatch(u);
    if (m2 != null) return m2.group(1);

    final embed = RegExp(r'embed\/([a-zA-Z0-9_-]{6,})');
    final m3 = embed.firstMatch(u);
    if (m3 != null) return m3.group(1);

    final shorts = RegExp(r'shorts\/([a-zA-Z0-9_-]{6,})');
    final m4 = shorts.firstMatch(u);
    if (m4 != null) return m4.group(1);

    return null;
  }
}

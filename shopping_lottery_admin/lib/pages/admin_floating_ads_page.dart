// lib/pages/admin_floating_ads_page.dart
//
// ✅ AdminFloatingAdsPage v8.1 Final（右側浮動廣告管理｜最終完整版）
// ------------------------------------------------------------
// Firestore：floating_ads/{id}
// fields:
// - title: String
// - link: String
// - openInNewTab: bool
// - images: List<String> (downloadURL)
// - isActive: bool
// - startAt: Timestamp? (optional)
// - endAt: Timestamp? (optional)
// - order: int
// - createdAt, updatedAt: Timestamp
//
// Storage：floating_ads/{id}/{timestamp_filename}
// - refFromURL(url) 刪除（best effort）
//
// 功能：新增 / 編輯 / 刪除 / 搜尋 / 上下架 / 拖拉排序 / 多圖上傳與刪除 / 期間設定
// ------------------------------------------------------------
// 依賴：cloud_firestore, firebase_storage, file_picker, intl, flutter/services
// ------------------------------------------------------------

// ✅ 修正：移除不必要的 dart:typed_data（Uint8List 已由 flutter/services.dart 提供）
// import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminFloatingAdsPage extends StatefulWidget {
  const AdminFloatingAdsPage({super.key});

  @override
  State<AdminFloatingAdsPage> createState() => _AdminFloatingAdsPageState();
}

class _AdminFloatingAdsPageState extends State<AdminFloatingAdsPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _keyword = '';
  String _activeFilter = '全部'; // 全部/上架/下架
  String _timeFilter = '全部'; // 全部/有效中/未開始/已結束
  bool _busyReorder = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Query<Map<String, dynamic>> _baseQuery() =>
      _db.collection('floating_ads').orderBy('order').limit(200);

  DateTime? _toDate(dynamic v) =>
      v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('yyyy/MM/dd HH:mm').format(d);
  }

  bool _isWithin(DateTime now, DateTime? start, DateTime? end) {
    final okStart = start == null ? true : !now.isBefore(start);
    final okEnd = end == null ? true : !now.isAfter(end);
    return okStart && okEnd;
  }

  bool _matchFilter(Map<String, dynamic> d) {
    final title = (d['title'] ?? '').toString().toLowerCase();
    final link = (d['link'] ?? '').toString().toLowerCase();
    final isActive = d['isActive'] == true;

    final kw = _keyword.trim().toLowerCase();
    final okKeyword = kw.isEmpty || title.contains(kw) || link.contains(kw);

    final okActive =
        _activeFilter == '全部' ||
        (_activeFilter == '上架' && isActive) ||
        (_activeFilter == '下架' && !isActive);

    final now = DateTime.now();
    final startAt = _toDate(d['startAt']);
    final endAt = _toDate(d['endAt']);

    bool okTime = true;
    if (_timeFilter == '有效中') {
      okTime = _isWithin(now, startAt, endAt);
    } else if (_timeFilter == '未開始') {
      okTime = startAt != null && now.isBefore(startAt);
    } else if (_timeFilter == '已結束') {
      okTime = endAt != null && now.isAfter(endAt);
    }

    return okKeyword && okActive && okTime;
  }

  Future<void> _create() async {
    try {
      final ref = _db.collection('floating_ads').doc();
      final now = FieldValue.serverTimestamp();

      await ref.set({
        'title': '新浮動廣告',
        'link': '',
        'openInNewTab': true,
        'images': <String>[],
        'isActive': true,
        'order': DateTime.now().millisecondsSinceEpoch,
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      if (!mounted) return;
      await _edit(ref.id);
    } catch (e) {
      _snack('新增失敗：$e');
    }
  }

  Future<void> _edit(String id) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FloatingAdEditSheet(id: id),
    );
  }

  Future<void> _toggleActive(DocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      final cur = doc.data()?['isActive'] == true;
      await doc.reference.set({
        'isActive': !cur,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('更新失敗：$e');
    }
  }

  Future<void> _copyText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack('已複製');
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data() ?? {};
    final title = (d['title'] ?? '').toString().trim();
    final images = (d['images'] is List)
        ? List<String>.from(d['images'])
        : <String>[];

    bool deleteStorage = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('刪除浮動廣告'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('確定要刪除「${title.isEmpty ? '(未命名)' : title}」？'),
              const SizedBox(height: 12),
              if (images.isNotEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: deleteStorage,
                  onChanged: (v) => setState(() => deleteStorage = v == true),
                  title: const Text('同步刪除 Storage 圖片'),
                  subtitle: const Text('勾選後會嘗試使用 refFromURL 刪除（best effort）'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      if (deleteStorage && images.isNotEmpty) {
        for (final url in images) {
          final u = url.trim();
          if (u.isEmpty) continue;
          try {
            await FirebaseStorage.instance.refFromURL(u).delete();
          } catch (_) {}
        }
      }
      await doc.reference.delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  Future<void> _applyReorder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_busyReorder) return;
    setState(() => _busyReorder = true);

    try {
      // docs 已 limit(200)，一次 batch 足夠；保守仍可分段
      const chunkSize = 400;
      int i = 0;

      while (i < docs.length) {
        final end = (i + chunkSize > docs.length) ? docs.length : i + chunkSize;
        final chunk = docs.sublist(i, end);

        final batch = _db.batch();
        for (int idx = 0; idx < chunk.length; idx++) {
          final globalIndex = i + idx;
          batch.set(chunk[idx].reference, {
            'order': globalIndex + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await batch.commit();
        i = end;
      }
    } catch (e) {
      _snack('排序更新失敗：$e');
    } finally {
      if (mounted) setState(() => _busyReorder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _baseQuery();

    return Scaffold(
      appBar: AppBar(
        title: const Text('右側浮動廣告'),
        actions: [
          IconButton(
            tooltip: '新增',
            onPressed: _create,
            icon: const Icon(Icons.add_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snap.data!.docs.toList();
                if (allDocs.isEmpty) {
                  return const Center(child: Text('目前沒有浮動廣告'));
                }

                final filtered = allDocs
                    .where((d) => _matchFilter(d.data()))
                    .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('沒有符合條件的資料'));
                }

                return Stack(
                  children: [
                    ReorderableListView.builder(
                      itemCount: filtered.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (_busyReorder) return;
                        if (newIndex > oldIndex) newIndex--;

                        final moved = filtered.removeAt(oldIndex);
                        filtered.insert(newIndex, moved);

                        await _applyReorder(filtered);
                      },
                      itemBuilder: (context, i) {
                        final doc = filtered[i];
                        final d = doc.data();

                        final title = (d['title'] ?? '').toString().trim();
                        final link = (d['link'] ?? '').toString().trim();
                        final isActive = d['isActive'] == true;
                        final openNewTab = d['openInNewTab'] == true;

                        final images = (d['images'] is List)
                            ? List<String>.from(d['images'])
                            : <String>[];
                        final firstImage = images.isNotEmpty
                            ? images.first.trim()
                            : '';

                        final startAt = _toDate(d['startAt']);
                        final endAt = _toDate(d['endAt']);
                        final now = DateTime.now();
                        final inTime = _isWithin(now, startAt, endAt);
                        final timeLabel = (startAt == null && endAt == null)
                            ? '期間：未限制'
                            : '期間：${_fmtDateTime(startAt)} ～ ${_fmtDateTime(endAt)}';

                        final subtitle = [
                          '狀態：${isActive ? '上架' : '下架'}',
                          '有效：${inTime ? '是' : '否'}',
                          '圖片：${images.length} 張',
                          if (link.isNotEmpty) '連結：$link',
                          if (openNewTab) '新分頁',
                        ].join('｜');

                        return Card(
                          key: ValueKey(doc.id),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: firstImage.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      firstImage,
                                      width: 54,
                                      height: 54,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    Icons.ad_units_outlined,
                                    color: isActive ? Colors.blue : Colors.grey,
                                  ),
                            title: Text(
                              title.isEmpty ? '(未命名浮動廣告)' : title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(subtitle),
                                const SizedBox(height: 4),
                                Text(
                                  timeLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') await _edit(doc.id);
                                if (v == 'toggle') await _toggleActive(doc);
                                if (v == 'copy') await _copyText(link);
                                if (v == 'delete') await _delete(doc);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('編輯/上傳圖片'),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(isActive ? '下架' : '上架'),
                                ),
                                const PopupMenuItem(
                                  value: 'copy',
                                  child: Text('複製連結'),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('刪除'),
                                ),
                              ],
                            ),
                            onTap: () => _edit(doc.id),
                          ),
                        );
                      },
                    ),
                    if (_busyReorder)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Material(
                          elevation: 10,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: const [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '更新排序中...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋標題/連結',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
          DropdownButton<String>(
            value: _activeFilter,
            items: const [
              '全部',
              '上架',
              '下架',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _activeFilter = v ?? '全部'),
          ),
          DropdownButton<String>(
            value: _timeFilter,
            items: const [
              '全部',
              '有效中',
              '未開始',
              '已結束',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _timeFilter = v ?? '全部'),
          ),
          IconButton(
            tooltip: '清除篩選',
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _keyword = '';
                _activeFilter = '全部';
                _timeFilter = '全部';
              });
            },
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// ✅ BottomSheet：編輯浮動廣告（多圖 + 期間）
// ------------------------------------------------------------
class _FloatingAdEditSheet extends StatefulWidget {
  final String id;
  const _FloatingAdEditSheet({required this.id});

  @override
  State<_FloatingAdEditSheet> createState() => _FloatingAdEditSheetState();
}

class _FloatingAdEditSheetState extends State<_FloatingAdEditSheet> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _titleCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();

  bool _active = true;
  bool _openInNewTab = true;

  DateTime? _startAt;
  DateTime? _endAt;

  List<String> _images = <String>[];

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  DateTime? _toDate(dynamic v) =>
      v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('yyyy/MM/dd').format(d);
  }

  String _guessContentType(String? ext) {
    final e = (ext ?? '').toLowerCase().trim();
    if (e == 'png') return 'image/png';
    if (e == 'jpg' || e == 'jpeg') return 'image/jpeg';
    if (e == 'gif') return 'image/gif';
    if (e == 'webp') return 'image/webp';
    return 'application/octet-stream';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final doc = await _db.collection('floating_ads').doc(widget.id).get();
      if (doc.exists) {
        final d = doc.data() ?? {};
        _titleCtrl.text = (d['title'] ?? '').toString();
        _linkCtrl.text = (d['link'] ?? '').toString();
        _active = d['isActive'] == true;
        _openInNewTab = d['openInNewTab'] == true;

        _startAt = _toDate(d['startAt']);
        _endAt = _toDate(d['endAt']);

        _images = (d['images'] is List)
            ? List<String>.from(d['images'])
            : <String>[];
      }
    } catch (e) {
      _snack('讀取失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initial = _startAt ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(
      () => _startAt = DateTime(picked.year, picked.month, picked.day, 0, 0, 0),
    );
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = _endAt ?? (_startAt ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(
      () =>
          _endAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
    );
  }

  Future<void> _uploadImage() async {
    if (_saving) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      _snack('讀取圖片失敗');
      return;
    }

    setState(() => _saving = true);
    try {
      final safeName = f.name.replaceAll(' ', '_');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final path = 'floating_ads/${widget.id}/$fileName';

      final ref = _storage.ref().child(path);
      await ref.putData(
        bytes,
        SettableMetadata(contentType: _guessContentType(f.extension)),
      );
      final url = await ref.getDownloadURL();

      if (!mounted) return;
      setState(() => _images.add(url));

      _snack('圖片已上傳');
    } catch (e) {
      _snack('上傳失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeImage(String url) async {
    if (_saving) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除圖片'),
        content: const Text('確定要刪除這張圖片？（會嘗試刪除 Storage 檔案）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      setState(() => _images.remove(url));
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (_) {}
      _snack('已刪除圖片');
    } catch (e) {
      _snack('刪除失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _snack('請輸入標題');
      return;
    }

    if (_startAt != null && _endAt != null && _endAt!.isBefore(_startAt!)) {
      _snack('結束日期不能早於開始日期');
      return;
    }

    setState(() => _saving = true);
    try {
      await _db.collection('floating_ads').doc(widget.id).set({
        'title': title,
        'link': _linkCtrl.text.trim(),
        'openInNewTab': _openInNewTab,
        'images': _images,
        'isActive': _active,
        'updatedAt': FieldValue.serverTimestamp(),
        if (_startAt != null) 'startAt': Timestamp.fromDate(_startAt!),
        if (_startAt == null) 'startAt': FieldValue.delete(),
        if (_endAt != null) 'endAt': Timestamp.fromDate(_endAt!),
        if (_endAt == null) 'endAt': FieldValue.delete(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: SizedBox(
          height: 280,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '編輯浮動廣告',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '標題',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _linkCtrl,
                decoration: const InputDecoration(
                  labelText: '連結（可空白）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    final t = _linkCtrl.text.trim();
                    if (t.isEmpty) return;
                    await Clipboard.setData(ClipboardData(text: t));
                    _snack('已複製連結');
                  },
                  child: const Text('複製連結'),
                ),
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '前台上架',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                value: _active,
                onChanged: _saving ? null : (v) => setState(() => _active = v),
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '新分頁開啟',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                value: _openInNewTab,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _openInNewTab = v),
              ),

              const Divider(height: 22),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '有效期間（選填）',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickStartDate,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      _startAt == null ? '設定開始日' : '開始：${_fmt(_startAt)}',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickEndDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _endAt == null ? '設定結束日' : '結束：${_fmt(_endAt)}',
                    ),
                  ),
                  if (_startAt != null || _endAt != null)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _startAt = null;
                              _endAt = null;
                            }),
                      child: const Text('清除日期'),
                    ),
                ],
              ),

              const Divider(height: 22),

              Row(
                children: [
                  const Text(
                    '圖片（可多張）',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _uploadImage,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('上傳'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_images.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('尚未上傳圖片'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _images.map((url) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            url,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: InkWell(
                            onTap: _saving ? null : () => _removeImage(url),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('儲存'),
              ),

              if (_saving) ...[
                const SizedBox(height: 12),
                Row(
                  children: const [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '處理中...',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

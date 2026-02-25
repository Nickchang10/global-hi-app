// lib/pages/admin_home_blocks_page.dart
//
// ✅ AdminHomeBlocksPage v8.1 Final（首頁中間自訂區塊管理｜最終完整版｜可編譯可用｜修正 Uint8List/unused_import）
// ------------------------------------------------------------
// Firestore：home_blocks/{id}
// fields:
// - title: String
// - subtitle: String
// - imageUrl: String
// - link: String
// - isActive: bool
// - order: int
// - createdAt, updatedAt
//
// Storage：/home_blocks/{id}/{timestamp_filename}
// ------------------------------------------------------------
// 依賴：cloud_firestore, firebase_storage, file_picker, intl
// ------------------------------------------------------------

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminHomeBlocksPage extends StatefulWidget {
  const AdminHomeBlocksPage({super.key});

  @override
  State<AdminHomeBlocksPage> createState() => _AdminHomeBlocksPageState();
}

class _AdminHomeBlocksPageState extends State<AdminHomeBlocksPage> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  bool _busyReorder = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmt(dynamic v) =>
      v is Timestamp ? DateFormat('yyyy/MM/dd HH:mm').format(v.toDate()) : '-';

  Query<Map<String, dynamic>> _query() =>
      _db.collection('home_blocks').orderBy('order').limit(200);

  Future<void> _create() async {
    final ref = _db.collection('home_blocks').doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'title': '新區塊',
      'subtitle': '副標題',
      'imageUrl': '',
      'link': '',
      'isActive': true,
      'order': DateTime.now().millisecondsSinceEpoch,
      'createdAt': now,
      'updatedAt': now,
    });
    if (!mounted) return;
    await _edit(ref.id);
  }

  Future<void> _edit(String id) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HomeBlockEditSheet(id: id),
    );
  }

  Future<void> _toggleActive(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final cur = doc.data()?['isActive'] == true;
    try {
      await doc.reference.update({
        'isActive': !cur,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _snack('更新狀態失敗：$e');
    }
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? <String, dynamic>{};
    final title = (data['title'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();

    bool deleteImage = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('刪除區塊'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('確定要刪除「$title」嗎？\n\n此操作不可復原。'),
              if (imageUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: deleteImage,
                  onChanged: (v) => setLocal(() => deleteImage = v ?? false),
                  title: const Text('同步刪除圖片'),
                  subtitle: const Text('會嘗試刪除 Storage 上的圖片'),
                ),
              ],
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
      if (deleteImage && imageUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(imageUrl).delete();
        } catch (_) {}
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
    if (!mounted) return;

    setState(() => _busyReorder = true);
    try {
      final batch = _db.batch();
      for (int i = 0; i < docs.length; i++) {
        batch.update(docs[i].reference, {
          'order': i + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      _snack('更新排序失敗：$e');
    } finally {
      if (mounted) setState(() => _busyReorder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _query().snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('首頁中間區塊管理'),
        actions: [
          IconButton(
            onPressed: _create,
            icon: const Icon(Icons.add_outlined),
            tooltip: '新增區塊',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('載入失敗：${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: Text('尚無資料'));
          }

          // ✅ QuerySnapshot.docs 可能是不可變 List：改成可變 list，避免 reorder 時 removeAt/insert 崩潰
          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snap.data!.docs,
          );

          if (docs.isEmpty) return const Center(child: Text('尚無區塊內容'));

          return Stack(
            children: [
              ReorderableListView.builder(
                itemCount: docs.length,
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex--;
                  final moved = docs.removeAt(oldIndex);
                  docs.insert(newIndex, moved);
                  await _applyReorder(docs);
                },
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final title = (d['title'] ?? '').toString();
                  final subtitle = (d['subtitle'] ?? '').toString();
                  final link = (d['link'] ?? '').toString();
                  final imageUrl = (d['imageUrl'] ?? '').toString();
                  final active = d['isActive'] == true;
                  final updated = _fmt(d['updatedAt']);

                  return Card(
                    key: ValueKey(docs[i].id),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                imageUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                            )
                          : const Icon(Icons.image_outlined),
                      title: Text(
                        title.isEmpty ? '(未命名區塊)' : title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        [
                          if (subtitle.isNotEmpty) subtitle,
                          if (link.isNotEmpty) '連結：$link',
                          '狀態：${active ? '上架' : '下架'}',
                          '更新：$updated',
                        ].join('｜'),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') await _edit(docs[i].id);
                          if (v == 'toggle') await _toggleActive(docs[i]);
                          if (v == 'delete') await _delete(docs[i]);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('編輯')),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(active ? '下架' : '上架'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('刪除'),
                          ),
                        ],
                      ),
                      onTap: () => _edit(docs[i].id),
                    ),
                  );
                },
              ),
              if (_busyReorder)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Material(
                    elevation: 10,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '更新排序中...',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
    );
  }
}

// ------------------------------------------------------------
// ✅ 編輯區塊 BottomSheet
// ------------------------------------------------------------
class _HomeBlockEditSheet extends StatefulWidget {
  final String id;
  const _HomeBlockEditSheet({required this.id});

  @override
  State<_HomeBlockEditSheet> createState() => _HomeBlockEditSheetState();
}

class _HomeBlockEditSheetState extends State<_HomeBlockEditSheet> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();

  String _imageUrl = '';
  bool _active = true;

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    try {
      final doc = await _db.collection('home_blocks').doc(widget.id).get();
      if (doc.exists) {
        final d = doc.data() ?? <String, dynamic>{};
        _titleCtrl.text = (d['title'] ?? '').toString();
        _subtitleCtrl.text = (d['subtitle'] ?? '').toString();
        _linkCtrl.text = (d['link'] ?? '').toString();
        _imageUrl = (d['imageUrl'] ?? '').toString();
        _active = d['isActive'] == true;
      }
    } catch (e) {
      _snack('載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _safeFilename(String name) =>
      name.replaceAll(RegExp(r'[^\w\.\-]+'), '_');

  String _guessContentType(String? ext) {
    final e = (ext ?? '').toLowerCase();
    if (e == 'jpg' || e == 'jpeg') return 'image/jpeg';
    if (e == 'png') return 'image/png';
    if (e == 'gif') return 'image/gif';
    if (e == 'webp') return 'image/webp';
    return 'application/octet-stream';
  }

  Future<void> _tryDeleteOldImage() async {
    final url = _imageUrl.trim();
    if (url.isEmpty) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  Future<void> _uploadImage() async {
    if (_uploading) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;

    final file = result.files.first;
    final rawBytes = file.bytes;
    if (rawBytes == null) {
      _snack('讀取圖片失敗：bytes 為空');
      return;
    }

    // ✅ 關鍵：確保 putData 一定拿到 Uint8List（同時也讓 dart:typed_data 變成「有使用」）
    final Uint8List bytes = Uint8List.fromList(rawBytes);

    setState(() => _uploading = true);
    try {
      // 上傳前先刪掉舊圖（避免 Storage 堆垃圾）
      await _tryDeleteOldImage();

      final safeName = _safeFilename(file.name);
      final path =
          'home_blocks/${widget.id}/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final ref = _storage.ref().child(path);
      await ref.putData(
        bytes,
        SettableMetadata(contentType: _guessContentType(file.extension)),
      );

      final url = await ref.getDownloadURL();
      if (!mounted) return;
      setState(() => _imageUrl = url);
      _snack('上傳完成');
    } catch (e) {
      _snack('上傳失敗：$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeImage() async {
    if (_imageUrl.trim().isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('移除圖片'),
        content: const Text('要移除此區塊圖片嗎？\n\n（會同時嘗試刪除 Storage 圖片）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _uploading = true);
    try {
      await _tryDeleteOldImage();
      if (!mounted) return;
      setState(() => _imageUrl = '');
      _snack('已移除圖片');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _snack('標題不可為空');
      return;
    }

    setState(() => _saving = true);
    try {
      await _db.collection('home_blocks').doc(widget.id).set({
        'title': title,
        'subtitle': _subtitleCtrl.text.trim(),
        'link': _linkCtrl.text.trim(),
        'imageUrl': _imageUrl.trim(),
        'isActive': _active,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                '編輯首頁區塊',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '標題',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _subtitleCtrl,
                decoration: const InputDecoration(
                  labelText: '副標題（可空白）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _linkCtrl,
                decoration: const InputDecoration(
                  labelText: '連結網址（可空白）',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    '圖片',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_imageUrl.isNotEmpty)
                    TextButton.icon(
                      onPressed: _uploading ? null : _removeImage,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('移除'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _uploading ? null : _uploadImage,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_outlined),
                    label: Text(
                      _uploading
                          ? '上傳中...'
                          : (_imageUrl.isEmpty ? '上傳圖片' : '替換圖片'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              if (_imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      alignment: Alignment.center,
                      color: Colors.black12,
                      child: const Text('圖片載入失敗'),
                    ),
                  ),
                ),

              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('前台顯示（上架）'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_saving || _uploading) ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? '儲存中...' : '儲存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

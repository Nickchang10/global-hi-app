// lib/pages/admin/app_center/admin_banners_page.dart
//
// ✅ AdminBannersPage（A. 基礎專業版｜完整版｜可編譯＋可用｜修正 use_build_context_synchronously）
// ------------------------------------------------------------
// Firestore 結構：banners
// {
//   imageUrl: "https://...",
//   title: "主打活動",
//   link: "https://example.com",
//   enabled: true,
//   order: 1,
//   createdAt: Timestamp,
//   updatedAt: Timestamp
// }
// ------------------------------------------------------------

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AdminBannersPage extends StatefulWidget {
  const AdminBannersPage({super.key});

  @override
  State<AdminBannersPage> createState() => _AdminBannersPageState();
}

class _AdminBannersPageState extends State<AdminBannersPage> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  bool _loading = false;

  Future<void> _addBanner() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _loading = true);
    try {
      final file = File(image.path);
      final fileName = 'banners/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploadTask = await _storage.ref(fileName).putFile(file);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      await _db.collection('banners').add({
        'imageUrl': imageUrl,
        'title': '新 Banner',
        'link': '',
        'enabled': true,
        'order': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已新增 Banner')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('新增失敗：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ✅ 修正點：
  /// - 不要把 BuildContext 當參數傳入 async function
  /// - await 後要用 mounted guard，再使用 context
  Future<void> _updateField(String id, String key, dynamic value) async {
    try {
      await _db.collection('banners').doc(id).set({
        key: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  /// ✅ 修正點：
  /// - showDialog await 後、以及 async 操作後再用 context 前都加 mounted guard
  Future<void> _deleteBanner(String id, String imageUrl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('刪除 Banner'),
        content: const Text('確定要刪除此 Banner？此動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // ✅ await showDialog 後先 guard
    if (!mounted) return;

    try {
      await _db.collection('banners').doc(id).delete();
      await _storage.refFromURL(imageUrl).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除 Banner')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Banner 管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: '新增 Banner',
            onPressed: _loading ? null : _addBanner,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('banners').orderBy('order').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('載入失敗：${snap.error}'));
          }
          final docs = (snap.data?.docs ?? []).toList();
          if (docs.isEmpty) {
            return const Center(child: Text('目前尚無 Banner'));
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;

              final moved = docs.removeAt(oldIndex);
              docs.insert(newIndex, moved);

              for (int i = 0; i < docs.length; i++) {
                await _db.collection('banners').doc(docs[i].id).update({
                  'order': i,
                });
              }
            },
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final id = docs[i].id;
              final imageUrl = (d['imageUrl'] ?? '') as String;
              final enabled = d['enabled'] == true;
              final title = (d['title'] ?? '') as String;
              final link = (d['link'] ?? '') as String;
              final updatedAt = d['updatedAt'] is Timestamp
                  ? DateFormat(
                      'MM/dd HH:mm',
                    ).format((d['updatedAt'] as Timestamp).toDate())
                  : '—';

              return Card(
                key: ValueKey(id),
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          width: 100,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 100,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: TextEditingController(text: title),
                              decoration: const InputDecoration(
                                labelText: '標題',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (v) => _updateField(id, 'title', v),
                            ),
                            TextField(
                              controller: TextEditingController(text: link),
                              decoration: const InputDecoration(
                                labelText: '連結（可空白）',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (v) => _updateField(id, 'link', v),
                            ),
                            Text(
                              '更新於 $updatedAt',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Switch(
                            value: enabled,
                            onChanged: (v) => _updateField(id, 'enabled', v),
                          ),
                          IconButton(
                            tooltip: '刪除',
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade400,
                            ),
                            onPressed: () => _deleteBanner(id, imageUrl),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// lib/pages/admin/shop/admin_banner_settings_page.dart
//
// ✅ AdminBannerSettingsPage（最終完整版｜可編譯｜可直接使用）
// ------------------------------------------------------------
// - Firestore: shop_config/banners
//   {
//     enabled: true,  // 第二層總開關（可選）
//     items: [
//       {
//         id: "b_170....",
//         enabled: true,
//         order: 10,
//         title: "主打商品",
//         subtitle: "一句話賣點",
//         imageUrl: "https://...",
//         route: "/shop",       // 可選：點擊導向
//         productId: "xxx"      // 可選：點擊開商品（前台會用商品列表內 id 尋找）
//       }
//     ],
//     updatedAt: serverTimestamp
//   }
//
// - ✅ 支援：
//   1) Banner 總開關（shop_config/banners.enabled）
//   2) Banner 項目 CRUD（新增/編輯/刪除）
//   3) 拖拉排序（ReorderableListView）
//   4) 單項啟用/停用
//   5) ✅ 上傳圖片至 Firebase Storage，回寫 imageUrl
//
// - 注意：前台還受 app_config/app_center.bannerEnabled 控制（更上層總開關）
// ------------------------------------------------------------

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AdminBannerSettingsPage extends StatelessWidget {
  const AdminBannerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Banner 管理', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: const AdminBannerSettingsBody(),
    );
  }
}

class AdminBannerSettingsBody extends StatefulWidget {
  const AdminBannerSettingsBody({super.key});

  @override
  State<AdminBannerSettingsBody> createState() => _AdminBannerSettingsBodyState();
}

class _AdminBannerSettingsBodyState extends State<AdminBannerSettingsBody> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get _bannerRef =>
      _db.collection('shop_config').doc('banners');

  DocumentReference<Map<String, dynamic>> get _appCenterRef =>
      _db.collection('app_config').doc('app_center');

  static const Map<String, dynamic> _defaults = {
    'enabled': true,
    'items': <dynamic>[],
  };

  bool _hydrated = false;
  bool _saving = false;

  bool _enabled = true;
  List<_BannerItem> _items = [];

  // upload 狀態（顯示在對話框上）
  bool _uploading = false;
  double _uploadProgress = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _addBanner,
        icon: const Icon(Icons.add),
        label: const Text('新增 Banner'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _bannerRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              title: '載入失敗',
              message: snap.error.toString(),
              onRetry: () => setState(() {}),
            );
          }

          final raw = <String, dynamic>{
            ..._defaults,
            ...(snap.data?.data() ?? const <String, dynamic>{}),
          };

          if (!_hydrated) {
            _enabled = raw['enabled'] == true;
            _items = (raw['items'] as List? ?? const [])
                .whereType<Map>()
                .map((e) => _BannerItem.fromMap(Map<String, dynamic>.from(e)))
                .toList();
            _items.sort((a, b) => a.order.compareTo(b.order));
            _hydrated = true;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              // ===== 上層開關提醒：app_center.bannerEnabled =====
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _appCenterRef.snapshots(),
                builder: (context, ac) {
                  final data = ac.data?.data() ?? const <String, dynamic>{};
                  final enabled = data['bannerEnabled'] != false; // 缺省 true
                  if (enabled) return const SizedBox.shrink();
                  return Card(
                    elevation: 0,
                    color: Colors.amber.withOpacity(0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '注意：App 控制中心已關閉 bannerEnabled，前台不會顯示 Banner（即使你這裡開啟也一樣）。',
                              style: TextStyle(color: cs.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ===== 狀態卡 =====
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.photo_library_outlined, color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Banner 設定',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Text('總開關：'),
                                Switch(
                                  value: _enabled,
                                  onChanged: (v) => setState(() => _enabled = v),
                                ),
                                Text(_enabled ? 'enabled=true' : 'enabled=false'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '儲存',
                        icon: const Icon(Icons.save_outlined),
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const _SectionTitle(
                title: 'Banner 列表',
                subtitle: '拖拉可排序；點編輯可設定文字 / 跳轉 / 商品 / 圖片',
              ),
              const SizedBox(height: 8),

              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _items.isEmpty
                      ? const Text('目前沒有 Banner，請新增。')
                      : ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final it = _items.removeAt(oldIndex);
                              _items.insert(newIndex, it);
                              _reassignOrders();
                            });
                          },
                          itemBuilder: (context, i) {
                            final b = _items[i];
                            return _BannerRow(
                              key: ValueKey(b.id),
                              item: b,
                              onToggle: (v) => setState(() {
                                _items[i] = b.copyWith(enabled: v);
                              }),
                              onEdit: () => _editBanner(i),
                              onDelete: () => _deleteBanner(i),
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(height: 12),

              ExpansionTile(
                title: const Text('JSON 預覽'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(_buildDoc()),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _reassignOrders() {
    // 用 10,20,30… 便於日後插入
    for (int i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(order: (i + 1) * 10);
    }
  }

  Map<String, dynamic> _buildDoc() => {
        'enabled': _enabled,
        'items': _items.map((e) => e.toMap()).toList(),
      };

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _bannerRef.set(
        {
          ..._buildDoc(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已儲存')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addBanner() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = _BannerItem(
      id: 'b_$now',
      enabled: true,
      order: (_items.length + 1) * 10,
      title: '',
      subtitle: '',
      imageUrl: '',
      route: '',
      productId: '',
    );

    setState(() {
      _items.add(item);
      _items.sort((a, b) => a.order.compareTo(b.order));
    });

    // 直接開編輯
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx >= 0) await _editBanner(idx);
  }

  Future<void> _deleteBanner(int i) async {
    final b = _items[i];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除 Banner'),
        content: Text('確定刪除「${b.title.isEmpty ? b.id : b.title}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _items.removeAt(i));
  }

  Future<void> _editBanner(int index) async {
    final origin = _items[index];
    var editing = origin;

    final titleCtrl = TextEditingController(text: origin.title);
    final subCtrl = TextEditingController(text: origin.subtitle);
    final imgCtrl = TextEditingController(text: origin.imageUrl);
    final routeCtrl = TextEditingController(text: origin.route);
    final pidCtrl = TextEditingController(text: origin.productId);

    void updateFromCtrls() {
      editing = editing.copyWith(
        title: titleCtrl.text.trim(),
        subtitle: subCtrl.text.trim(),
        imageUrl: imgCtrl.text.trim(),
        route: routeCtrl.text.trim(),
        productId: pidCtrl.text.trim(),
      );
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Future<void> doUpload() async {
              setLocal(() {
                _uploading = true;
                _uploadProgress = 0;
              });

              try {
                final res = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  withData: true, // ✅ 這樣 Web/手機都可以用 putData，不用 dart:io
                );
                if (res == null || res.files.isEmpty) return;

                final file = res.files.first;
                final bytes = file.bytes;
                if (bytes == null) {
                  throw Exception('讀取圖片失敗：bytes=null（請改用 withData:true）');
                }

                final ext = (file.extension ?? 'jpg').toLowerCase();
                final contentType =
                    ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');

                final path = 'banners/${editing.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
                final ref = _storage.ref().child(path);

                final task = ref.putData(
                  bytes,
                  SettableMetadata(contentType: contentType),
                );

                task.snapshotEvents.listen((s) {
                  final total = s.totalBytes == 0 ? 1 : s.totalBytes;
                  final p = s.bytesTransferred / total;
                  setLocal(() => _uploadProgress = p.clamp(0, 1));
                });

                await task;
                final url = await ref.getDownloadURL();

                setLocal(() {
                  imgCtrl.text = url;
                  updateFromCtrls();
                });
              } finally {
                setLocal(() {
                  _uploading = false;
                  _uploadProgress = 0;
                });
              }
            }

            return AlertDialog(
              title: const Text('編輯 Banner', style: TextStyle(fontWeight: FontWeight.w900)),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('啟用', style: TextStyle(fontWeight: FontWeight.w800)),
                        value: editing.enabled,
                        onChanged: (v) => setLocal(() {
                          editing = editing.copyWith(enabled: v);
                        }),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: '標題（title）',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocal(updateFromCtrls),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: subCtrl,
                        decoration: const InputDecoration(
                          labelText: '副標（subtitle）',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocal(updateFromCtrls),
                      ),
                      const SizedBox(height: 10),

                      // 圖片
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: imgCtrl,
                              decoration: const InputDecoration(
                                labelText: '圖片 URL（imageUrl）',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setLocal(updateFromCtrls),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.tonalIcon(
                            onPressed: _uploading ? null : doUpload,
                            icon: const Icon(Icons.upload),
                            label: const Text('上傳'),
                          ),
                        ],
                      ),
                      if (_uploading) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _uploadProgress == 0 ? null : _uploadProgress),
                        const SizedBox(height: 6),
                        Text(
                          '上傳中... ${(kDebugMode ? (_uploadProgress * 100).toStringAsFixed(0) : '')}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 10),

                      if (imgCtrl.text.trim().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 7,
                            child: Image.network(
                              imgCtrl.text.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // 跳轉（route / productId 二擇一即可）
                      TextField(
                        controller: routeCtrl,
                        decoration: const InputDecoration(
                          labelText: '點擊導向路由（route，例如 /shop、/login）',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocal(updateFromCtrls),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: pidCtrl,
                        decoration: const InputDecoration(
                          labelText: '點擊開商品（productId，優先於 route）',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocal(updateFromCtrls),
                      ),

                      const SizedBox(height: 8),
                      Text(
                        '提示：productId 會在前台用商品列表的 id 尋找並開啟詳情；若找不到會提示。',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    updateFromCtrls();
                    Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('套用'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    setState(() {
      _items[index] = editing;
      _items.sort((a, b) => a.order.compareTo(b.order));
    });
  }
}

// ============================================================
// Model
// ============================================================

class _BannerItem {
  final String id;
  final bool enabled;
  final int order;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String route;
  final String productId;

  const _BannerItem({
    required this.id,
    required this.enabled,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.route,
    required this.productId,
  });

  factory _BannerItem.fromMap(Map<String, dynamic> m) {
    String s(dynamic v) => (v ?? '').toString().trim();
    int i(dynamic v, [int fb = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(s(v)) ?? fb;
    }

    final id = s(m['id']);
    return _BannerItem(
      id: id.isEmpty ? 'b_${m.hashCode}' : id,
      enabled: m['enabled'] != false,
      order: i(m['order'], 0),
      title: s(m['title']),
      subtitle: s(m['subtitle']),
      imageUrl: s(m['imageUrl']).isEmpty ? s(m['image']) : s(m['imageUrl']),
      route: s(m['route']),
      productId: s(m['productId']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'enabled': enabled,
        'order': order,
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        'route': route,
        'productId': productId,
      };

  _BannerItem copyWith({
    bool? enabled,
    int? order,
    String? title,
    String? subtitle,
    String? imageUrl,
    String? route,
    String? productId,
  }) {
    return _BannerItem(
      id: id,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      route: route ?? this.route,
      productId: productId ?? this.productId,
    );
  }
}

// ============================================================
// UI Widgets
// ============================================================

class _BannerRow extends StatelessWidget {
  final _BannerItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BannerRow({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = item.title.isEmpty ? '未命名 Banner' : item.title;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 54,
            height: 54,
            child: item.imageUrl.trim().isEmpty
                ? Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_outlined, color: Colors.grey),
                  )
                : Image.network(
                    item.imageUrl.trim(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                    ),
                  ),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          'order=${item.order} • ${item.productId.isNotEmpty ? 'productId=${item.productId}' : (item.route.isNotEmpty ? 'route=${item.route}' : '未設定跳轉')}',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: item.enabled, onChanged: onToggle),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
            const Icon(Icons.drag_handle),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 44, color: cs.error),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重試'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

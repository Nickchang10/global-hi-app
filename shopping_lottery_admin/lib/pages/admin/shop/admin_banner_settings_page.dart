// lib/pages/admin/shop/admin_banner_settings_page.dart
// =====================================================
// ✅ AdminBannerSettingsPage（Banner 設定｜修正版完整版｜可編譯）
//
// FIXES
// - ✅ withOpacity deprecated → withValues(alpha:)
// - ✅ DropdownButtonFormField deprecated: value → initialValue
// - ✅ 修正 unused_local_variable: dragHandle（現在真的用在畫面上）
//
// FEATURES
// - Banner CRUD（新增/編輯/啟用停用/刪除）
// - 拖曳排序（ReorderableListView）→ 寫回 sort（batch update）
// - 篩選（全部/啟用/停用）
// - 相容 Web/桌面/手機（窄寬自動換行）
//
// Firestore（預設）
// - shop_banners/{bannerId}
//   - title: String
//   - imageUrl: String
//   - linkUrl: String
//   - enabled: bool
//   - sort: int
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
// =====================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ FIX: withOpacity deprecated → withValues(alpha: 0~1)
Color _withOpacity(Color c, double opacity01) {
  final o = opacity01.clamp(0.0, 1.0).toDouble();
  return c.withValues(alpha: o);
}

class AdminBannerSettingsPage extends StatefulWidget {
  const AdminBannerSettingsPage({super.key});

  @override
  State<AdminBannerSettingsPage> createState() =>
      _AdminBannerSettingsPageState();
}

class _AdminBannerSettingsPageState extends State<AdminBannerSettingsPage> {
  final _db = FirebaseFirestore.instance;
  final _df = DateFormat('yyyy/MM/dd HH:mm');

  _BannerFilter _filter = _BannerFilter.all;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('shop_banners');

  Query<Map<String, dynamic>> _query() {
    return _col.orderBy('sort', descending: false).limit(300);
  }

  bool _hitFilter(_BannerDoc b) {
    switch (_filter) {
      case _BannerFilter.all:
        return true;
      case _BannerFilter.enabled:
        return b.enabled == true;
      case _BannerFilter.disabled:
        return b.enabled != true;
    }
  }

  String _fmtTs(dynamic v) {
    if (v is Timestamp) {
      return _df.format(v.toDate());
    }
    return '-';
  }

  Future<void> _createBanner(List<_BannerDoc> current) async {
    final res = await showDialog<_BannerEditResult>(
      context: context,
      builder: (_) => const _BannerEditDialog(title: '新增 Banner'),
    );
    if (res == null) {
      return;
    }

    final maxSort = current.isEmpty
        ? -1
        : current.map((e) => e.sort).reduce((a, b) => a > b ? a : b);

    try {
      await _col.add({
        'title': res.title.trim(),
        'imageUrl': res.imageUrl.trim(),
        'linkUrl': res.linkUrl.trim(),
        'enabled': res.enabled,
        'sort': maxSort + 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已新增 Banner')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('新增失敗：$e')));
    }
  }

  Future<void> _editBanner(_BannerDoc b) async {
    final res = await showDialog<_BannerEditResult>(
      context: context,
      builder: (_) => _BannerEditDialog(
        title: '編輯 Banner',
        initialTitle: b.title,
        initialImageUrl: b.imageUrl,
        initialLinkUrl: b.linkUrl,
        initialEnabled: b.enabled,
      ),
    );
    if (res == null) {
      return;
    }

    try {
      await _col.doc(b.id).update({
        'title': res.title.trim(),
        'imageUrl': res.imageUrl.trim(),
        'linkUrl': res.linkUrl.trim(),
        'enabled': res.enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新 Banner')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _toggleEnabled(_BannerDoc b) async {
    try {
      await _col.doc(b.id).update({
        'enabled': !b.enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(b.enabled ? '已停用' : '已啟用')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新狀態失敗：$e')));
    }
  }

  Future<void> _deleteBanner(_BannerDoc b) async {
    final ok = await _confirm(
      title: '刪除 Banner',
      message: '確定要刪除「${b.title.isEmpty ? b.id : b.title}」嗎？',
      confirmText: '刪除',
      isDanger: true,
    );
    if (ok != true) {
      return;
    }

    try {
      await _col.doc(b.id).delete();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  Future<void> _reorder(
    List<_BannerDoc> list,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final items = [...list];
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    try {
      final batch = _db.batch();
      for (int i = 0; i < items.length; i++) {
        final b = items[i];
        // 重新寫入 sort
        batch.update(_col.doc(b.id), {
          'sort': i,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新排序')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新排序失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Banner 設定'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query().snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? const [];
          final list = docs.map((e) => _BannerDoc.fromDoc(e)).toList();
          return FloatingActionButton.extended(
            onPressed: () => _createBanner(list),
            icon: const Icon(Icons.add),
            label: const Text('新增 Banner'),
          );
        },
      ),
      body: Column(
        children: [
          _filterBar(cs),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _ErrorView(
                    title: '讀取失敗',
                    message: snap.error.toString(),
                    hint:
                        '若錯誤包含 orderBy(sort)，請確認 shop_banners 都有 sort 欄位，或把 query 改成 createdAt/documentId。',
                    onRetry: () => setState(() {}),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snap.data!.docs
                    .map((e) => _BannerDoc.fromDoc(e))
                    .toList();
                final filtered = all.where(_hitFilter).toList(growable: false);

                if (filtered.isEmpty) {
                  return const _EmptyView(
                    title: '沒有 Banner',
                    message: '目前篩選條件下沒有資料。',
                  );
                }

                return ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: filtered.length,
                  onReorder: (oldIndex, newIndex) =>
                      _reorder(filtered, oldIndex, newIndex),
                  itemBuilder: (context, i) {
                    final b = filtered[i];
                    return _bannerTile(
                      key: ValueKey(b.id),
                      cs: cs,
                      b: b,
                      index: i, // ✅ 讓 dragHandle 能用 index
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar(ColorScheme cs) {
    final dropdown = DropdownButtonFormField<_BannerFilter>(
      key: ValueKey('bannerFilter_${_filter.name}'),
      initialValue: _filter,
      items: _BannerFilter.values
          .map(
            (e) =>
                DropdownMenuItem<_BannerFilter>(value: e, child: Text(e.label)),
          )
          .toList(),
      onChanged: (v) {
        if (v == null) {
          return;
        }
        setState(() => _filter = v);
      },
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '篩選',
        isDense: true,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 520;
          if (isNarrow) {
            return dropdown;
          }
          return SizedBox(width: 260, child: dropdown);
        },
      ),
    );
  }

  Widget _bannerTile({
    required Key key,
    required ColorScheme cs,
    required _BannerDoc b,
    required int index,
  }) {
    final statusColor = b.enabled ? cs.primary : cs.error;
    final statusBg = b.enabled ? cs.primaryContainer : cs.errorContainer;
    final statusFg = b.enabled ? cs.onPrimaryContainer : cs.onErrorContainer;

    final title = b.title.isEmpty ? '（未命名）' : b.title;

    // ✅ FIX: dragHandle「真的用上」→ 不會再 unused_local_variable
    final dragHandle = ReorderableDragStartListener(
      index: index,
      child: const Tooltip(
        message: '拖曳排序',
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Icon(Icons.drag_handle),
        ),
      ),
    );

    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 240,
        height: 120,
        color: _withOpacity(cs.onSurface, 0.05),
        child: b.imageUrl.isEmpty
            ? Center(
                child: Text(
                  '無圖片',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            : Image.network(
                b.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    '圖片載入失敗',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
      ),
    );

    final statusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _withOpacity(statusColor, 0.20)),
      ),
      child: Text(
        b.enabled ? '啟用' : '停用',
        style: TextStyle(color: statusFg, fontWeight: FontWeight.w900),
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            statusChip,
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'id: ${b.id}  •  sort: ${b.sort}',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 6),
        if (b.linkUrl.isNotEmpty) ...[
          Text(
            'link: ${b.linkUrl}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          'created: ${_fmtTs(b.createdAt)}   updated: ${_fmtTs(b.updatedAt)}',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _editBanner(b),
              icon: const Icon(Icons.edit),
              label: const Text('編輯'),
            ),
            OutlinedButton.icon(
              onPressed: () => _toggleEnabled(b),
              icon: Icon(
                b.enabled
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
              label: Text(b.enabled ? '停用' : '啟用'),
            ),
            OutlinedButton.icon(
              onPressed: () => _deleteBanner(b),
              icon: const Icon(Icons.delete_outline),
              label: const Text('刪除'),
              style: OutlinedButton.styleFrom(foregroundColor: cs.error),
            ),
          ],
        ),
      ],
    );

    return Card(
      key: key,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, c) {
            final isNarrow = c.maxWidth < 760;

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: preview),
                      dragHandle, // ✅ 使用 dragHandle
                    ],
                  ),
                  const SizedBox(height: 10),
                  info,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                preview,
                const SizedBox(width: 12),
                Expanded(child: info),
                dragHandle, // ✅ 使用 dragHandle
              ],
            );
          },
        ),
      ),
    );
  }

  // =====================================================
  // Dialog helpers
  // =====================================================
  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool isDanger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDanger ? cs.error : null,
              foregroundColor: isDanger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// Models / Enums / Dialogs / Views
// =====================================================
enum _BannerFilter {
  all('全部'),
  enabled('啟用'),
  disabled('停用');

  final String label;
  const _BannerFilter(this.label);
}

class _BannerDoc {
  final String id;
  final String title;
  final String imageUrl;
  final String linkUrl;
  final bool enabled;
  final int sort;
  final dynamic createdAt;
  final dynamic updatedAt;

  _BannerDoc({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.linkUrl,
    required this.enabled,
    required this.sort,
    required this.createdAt,
    required this.updatedAt,
  });

  static _BannerDoc fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? <String, dynamic>{};

    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    return _BannerDoc(
      id: doc.id,
      title: (m['title'] ?? '').toString(),
      imageUrl: (m['imageUrl'] ?? '').toString(),
      linkUrl: (m['linkUrl'] ?? '').toString(),
      enabled: m['enabled'] == true,
      sort: asInt(m['sort']),
      createdAt: m['createdAt'],
      updatedAt: m['updatedAt'],
    );
  }
}

class _BannerEditResult {
  final String title;
  final String imageUrl;
  final String linkUrl;
  final bool enabled;

  _BannerEditResult({
    required this.title,
    required this.imageUrl,
    required this.linkUrl,
    required this.enabled,
  });
}

class _BannerEditDialog extends StatefulWidget {
  final String title;

  final String initialTitle;
  final String initialImageUrl;
  final String initialLinkUrl;
  final bool initialEnabled;

  const _BannerEditDialog({
    required this.title,
    this.initialTitle = '',
    this.initialImageUrl = '',
    this.initialLinkUrl = '',
    this.initialEnabled = true,
  });

  @override
  State<_BannerEditDialog> createState() => _BannerEditDialogState();
}

class _BannerEditDialogState extends State<_BannerEditDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initialTitle,
  );
  late final TextEditingController _imageUrl = TextEditingController(
    text: widget.initialImageUrl,
  );
  late final TextEditingController _linkUrl = TextEditingController(
    text: widget.initialLinkUrl,
  );

  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
  }

  @override
  void dispose() {
    _title.dispose();
    _imageUrl.dispose();
    _linkUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('啟用'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: '標題（可留空）',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _imageUrl,
                decoration: InputDecoration(
                  labelText: '圖片 URL（建議填）',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _linkUrl,
                decoration: InputDecoration(
                  labelText: '連結 URL（可留空）',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '提示：右側拖曳把手可調整排序（sort 越小越前）。',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(
              context,
              _BannerEditResult(
                title: _title.text,
                imageUrl: _imageUrl.text,
                linkUrl: _linkUrl.text,
                enabled: _enabled,
              ),
            );
          },
          icon: const Icon(Icons.check),
          label: const Text('套用'),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyView({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.photo_outlined, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

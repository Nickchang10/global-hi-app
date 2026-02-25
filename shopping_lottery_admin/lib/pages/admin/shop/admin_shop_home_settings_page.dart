// lib/pages/admin/shop/admin_shop_home_settings_page.dart
//
// ✅ AdminShopHomeSettingsPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正重點（本次）
// - 修正 deprecated_member_use：DropdownButtonFormField 的 value 已 deprecated
//   → 改用 initialValue
//
// ✅ 功能：商店首頁設定（公告列、主視覺 Banner、首頁區塊 Sections）CRUD + 重新排序 + 啟用/停用 + Firestore 儲存
// 預設 Firestore 路徑：site_settings/shop_home（可自行改 _docRef）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminShopHomeSettingsPage extends StatefulWidget {
  const AdminShopHomeSettingsPage({super.key});

  @override
  State<AdminShopHomeSettingsPage> createState() =>
      _AdminShopHomeSettingsPageState();
}

class _AdminShopHomeSettingsPageState extends State<AdminShopHomeSettingsPage> {
  DocumentReference<Map<String, dynamic>> get _docRef =>
      FirebaseFirestore.instance.collection('site_settings').doc('shop_home');

  bool _busy = false;
  bool _didSyncOnce = false;

  // Notice
  bool _noticeEnabled = true;
  final _noticeTextCtrl = TextEditingController();
  final _noticeLinkCtrl = TextEditingController();

  // Banners / Sections
  final List<HomeBannerItem> _banners = [];
  final List<HomeSectionItem> _sections = [];

  @override
  void dispose() {
    _noticeTextCtrl.dispose();
    _noticeLinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFromSnapshot(Map<String, dynamic>? data) async {
    final m = data ?? <String, dynamic>{};

    final noticeRaw = m['notice'];
    final notice = noticeRaw is Map
        ? Map<String, dynamic>.from(noticeRaw)
        : <String, dynamic>{};

    _noticeEnabled = notice['enabled'] == true;
    _noticeTextCtrl.text = (notice['text'] ?? '').toString();
    _noticeLinkCtrl.text = (notice['linkUrl'] ?? '').toString();

    _banners
      ..clear()
      ..addAll(HomeBannerItem.listFromAny(m['heroBanners']));
    _sections
      ..clear()
      ..addAll(HomeSectionItem.listFromAny(m['sections']));

    _banners.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _sections.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      for (int i = 0; i < _banners.length; i++) {
        _banners[i] = _banners[i].copyWith(sortOrder: i * 10);
      }
      for (int i = 0; i < _sections.length; i++) {
        _sections[i] = _sections[i].copyWith(sortOrder: i * 10);
      }

      final payload = <String, dynamic>{
        'notice': {
          'enabled': _noticeEnabled,
          'text': _noticeTextCtrl.text.trim(),
          'linkUrl': _noticeLinkCtrl.text.trim(),
        },
        'heroBanners': _banners.map((e) => e.toMap()).toList(),
        'sections': _sections.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _docRef.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存首頁設定')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ===========================
  // Banner CRUD
  // ===========================

  Future<void> _addBanner() async {
    final result = await showModalBottomSheet<HomeBannerItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BannerEditorSheet(initial: const HomeBannerItem()),
    );
    if (result == null) return;
    setState(
      () => _banners.add(result.copyWith(sortOrder: _banners.length * 10)),
    );
  }

  Future<void> _editBanner(int index) async {
    final current = _banners[index];
    final result = await showModalBottomSheet<HomeBannerItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BannerEditorSheet(initial: current),
    );
    if (result == null) return;
    setState(
      () => _banners[index] = result.copyWith(sortOrder: current.sortOrder),
    );
  }

  void _deleteBanner(int index) => setState(() => _banners.removeAt(index));
  void _toggleBanner(int index, bool next) =>
      setState(() => _banners[index] = _banners[index].copyWith(enabled: next));

  // ===========================
  // Section CRUD
  // ===========================

  Future<void> _addSection() async {
    final result = await showModalBottomSheet<HomeSectionItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SectionEditorSheet(initial: const HomeSectionItem()),
    );
    if (result == null) return;
    setState(
      () => _sections.add(result.copyWith(sortOrder: _sections.length * 10)),
    );
  }

  Future<void> _editSection(int index) async {
    final current = _sections[index];
    final result = await showModalBottomSheet<HomeSectionItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SectionEditorSheet(initial: current),
    );
    if (result == null) return;
    setState(
      () => _sections[index] = result.copyWith(sortOrder: current.sortOrder),
    );
  }

  void _deleteSection(int index) => setState(() => _sections.removeAt(index));
  void _toggleSection(int index, bool next) => setState(
    () => _sections[index] = _sections[index].copyWith(enabled: next),
  );

  // ===========================
  // UI
  // ===========================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _docRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('商城首頁設定')),
            body: _ErrorView(message: '讀取失敗：${snap.error}'),
          );
        }

        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('商城首頁設定')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data();

        if (!_didSyncOnce) {
          _didSyncOnce = true;
          Future.microtask(() async {
            await _loadFromSnapshot(data);
            if (!mounted) return;
            setState(() {});
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('商城首頁設定'),
            actions: [
              IconButton(
                tooltip: '重新載入（覆蓋本地未保存變更）',
                onPressed: _busy
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await _loadFromSnapshot(data);
                        if (!mounted) return;
                        setState(() {});
                        messenger.showSnackBar(
                          const SnackBar(content: Text('已重新載入')),
                        );
                      },
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('保存'),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _NoticeCard(
                enabled: _noticeEnabled,
                onEnabledChanged: (v) => setState(() => _noticeEnabled = v),
                noticeTextCtrl: _noticeTextCtrl,
                noticeLinkCtrl: _noticeLinkCtrl,
              ),
              const SizedBox(height: 12),
              _BannersCard(
                banners: _banners,
                onAdd: _addBanner,
                onEdit: _editBanner,
                onDelete: _deleteBanner,
                onToggle: _toggleBanner,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _banners.removeAt(oldIndex);
                    _banners.insert(newIndex, item);
                  });
                },
              ),
              const SizedBox(height: 12),
              _SectionsCard(
                sections: _sections,
                onAdd: _addSection,
                onEdit: _editSection,
                onDelete: _deleteSection,
                onToggle: _toggleSection,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _sections.removeAt(oldIndex);
                    _sections.insert(newIndex, item);
                  });
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// Models
// ============================================================

class HomeBannerItem {
  const HomeBannerItem({
    this.enabled = true,
    this.title = '',
    this.subtitle = '',
    this.imageUrl = '',
    this.linkType = 'url',
    this.linkValue = '',
    this.sortOrder = 0,
  });

  final bool enabled;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String linkType;
  final String linkValue;
  final int sortOrder;

  HomeBannerItem copyWith({
    bool? enabled,
    String? title,
    String? subtitle,
    String? imageUrl,
    String? linkType,
    String? linkValue,
    int? sortOrder,
  }) {
    return HomeBannerItem(
      enabled: enabled ?? this.enabled,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      linkType: linkType ?? this.linkType,
      linkValue: linkValue ?? this.linkValue,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'linkType': linkType,
      'linkValue': linkValue,
      'sortOrder': sortOrder,
    };
  }

  static HomeBannerItem fromMap(Map<String, dynamic> m) {
    return HomeBannerItem(
      enabled: m['enabled'] == true,
      title: (m['title'] ?? '').toString(),
      subtitle: (m['subtitle'] ?? '').toString(),
      imageUrl: (m['imageUrl'] ?? '').toString(),
      linkType: (m['linkType'] ?? 'url').toString(),
      linkValue: (m['linkValue'] ?? '').toString(),
      sortOrder: _Num.asInt(m['sortOrder']),
    );
  }

  static List<HomeBannerItem> listFromAny(dynamic v) {
    if (v is List) {
      return v.map((e) {
        if (e is Map) {
          return HomeBannerItem.fromMap(Map<String, dynamic>.from(e));
        }
        return const HomeBannerItem();
      }).toList();
    }
    return <HomeBannerItem>[];
  }
}

class HomeSectionItem {
  const HomeSectionItem({
    this.enabled = true,
    this.type = 'featuredProducts',
    this.title = '',
    this.subtitle = '',
    this.itemIds = const <String>[],
    this.imageUrl = '',
    this.linkUrl = '',
    this.sortOrder = 0,
  });

  final bool enabled;
  final String type;
  final String title;
  final String subtitle;
  final List<String> itemIds;
  final String imageUrl;
  final String linkUrl;
  final int sortOrder;

  HomeSectionItem copyWith({
    bool? enabled,
    String? type,
    String? title,
    String? subtitle,
    List<String>? itemIds,
    String? imageUrl,
    String? linkUrl,
    int? sortOrder,
  }) {
    return HomeSectionItem(
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      itemIds: itemIds ?? this.itemIds,
      imageUrl: imageUrl ?? this.imageUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'itemIds': itemIds,
      'imageUrl': imageUrl,
      'linkUrl': linkUrl,
      'sortOrder': sortOrder,
    };
  }

  static HomeSectionItem fromMap(Map<String, dynamic> m) {
    final ids = <String>[];
    final raw = m['itemIds'];
    if (raw is List) {
      for (final x in raw) {
        final s = x.toString().trim();
        if (s.isNotEmpty) ids.add(s);
      }
    }
    return HomeSectionItem(
      enabled: m['enabled'] == true,
      type: (m['type'] ?? 'featuredProducts').toString(),
      title: (m['title'] ?? '').toString(),
      subtitle: (m['subtitle'] ?? '').toString(),
      itemIds: ids,
      imageUrl: (m['imageUrl'] ?? '').toString(),
      linkUrl: (m['linkUrl'] ?? '').toString(),
      sortOrder: _Num.asInt(m['sortOrder']),
    );
  }

  static List<HomeSectionItem> listFromAny(dynamic v) {
    if (v is List) {
      return v.map((e) {
        if (e is Map) {
          return HomeSectionItem.fromMap(Map<String, dynamic>.from(e));
        }
        return const HomeSectionItem();
      }).toList();
    }
    return <HomeSectionItem>[];
  }
}

// ============================================================
// Cards
// ============================================================

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.enabled,
    required this.onEnabledChanged,
    required this.noticeTextCtrl,
    required this.noticeLinkCtrl,
  });

  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final TextEditingController noticeTextCtrl;
  final TextEditingController noticeLinkCtrl;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '公告列 Notice',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: enabled, onChanged: onEnabledChanged),
          Text(
            enabled ? '啟用' : '停用',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: noticeTextCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '公告文字',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noticeLinkCtrl,
            decoration: const InputDecoration(
              labelText: '點擊連結（可空）',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannersCard extends StatelessWidget {
  const _BannersCard({
    required this.banners,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onReorder,
  });

  final List<HomeBannerItem> banners;
  final VoidCallback onAdd;
  final void Function(int index) onEdit;
  final void Function(int index) onDelete;
  final void Function(int index, bool next) onToggle;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '主視覺 Hero Banners',
      trailing: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('新增 Banner'),
      ),
      child: banners.isEmpty
          ? Text('尚未設定任何 Banner', style: TextStyle(color: Colors.grey[700]))
          : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: banners.length,
              onReorder: onReorder,
              itemBuilder: (context, index) {
                final b = banners[index];
                return Card(
                  key: ValueKey('banner_${index}_${b.sortOrder}'),
                  elevation: 0.4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      b.enabled ? Icons.image : Icons.image_not_supported,
                    ),
                    title: Text(
                      b.title.trim().isEmpty ? '(未命名 Banner)' : b.title,
                    ),
                    subtitle: Text(
                      'type=${b.linkType}  value=${b.linkValue}\n${b.imageUrl}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Switch(
                          value: b.enabled,
                          onChanged: (v) => onToggle(index, v),
                        ),
                        IconButton(
                          onPressed: () => onEdit(index),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => onDelete(index),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                    onTap: () => onEdit(index),
                  ),
                );
              },
            ),
    );
  }
}

class _SectionsCard extends StatelessWidget {
  const _SectionsCard({
    required this.sections,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onReorder,
  });

  final List<HomeSectionItem> sections;
  final VoidCallback onAdd;
  final void Function(int index) onEdit;
  final void Function(int index) onDelete;
  final void Function(int index, bool next) onToggle;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '首頁區塊 Sections',
      trailing: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('新增區塊'),
      ),
      child: sections.isEmpty
          ? Text('尚未設定任何區塊', style: TextStyle(color: Colors.grey[700]))
          : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sections.length,
              onReorder: onReorder,
              itemBuilder: (context, index) {
                final s = sections[index];
                final title = s.title.trim().isEmpty ? '(未命名區塊)' : s.title;
                final ids = s.itemIds.isEmpty ? '-' : s.itemIds.join(', ');
                return Card(
                  key: ValueKey('section_${index}_${s.sortOrder}'),
                  elevation: 0.4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      s.enabled ? Icons.view_quilt : Icons.view_quilt_outlined,
                    ),
                    title: Text('$title  [${s.type}]'),
                    subtitle: Text(
                      'items=$ids\nimageUrl=${s.imageUrl}\nlinkUrl=${s.linkUrl}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Switch(
                          value: s.enabled,
                          onChanged: (v) => onToggle(index, v),
                        ),
                        IconButton(
                          onPressed: () => onEdit(index),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => onDelete(index),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                    onTap: () => onEdit(index),
                  ),
                );
              },
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Editors
// ============================================================

class _BannerEditorSheet extends StatefulWidget {
  const _BannerEditorSheet({required this.initial});
  final HomeBannerItem initial;

  @override
  State<_BannerEditorSheet> createState() => _BannerEditorSheetState();
}

class _BannerEditorSheetState extends State<_BannerEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late bool _enabled;
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _imageUrl;
  late final TextEditingController _linkValue;
  String _linkType = 'url';

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _enabled = i.enabled;
    _title = TextEditingController(text: i.title);
    _subtitle = TextEditingController(text: i.subtitle);
    _imageUrl = TextEditingController(text: i.imageUrl);
    _linkValue = TextEditingController(text: i.linkValue);
    _linkType = i.linkType.trim().isNotEmpty ? i.linkType : 'url';
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _imageUrl.dispose();
    _linkValue.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      widget.initial.copyWith(
        enabled: _enabled,
        title: _title.text.trim(),
        subtitle: _subtitle.text.trim(),
        imageUrl: _imageUrl.text.trim(),
        linkType: _linkType,
        linkValue: _linkValue.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: pad.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '編輯 Banner',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _tf(_title, '標題（可空）'),
                const SizedBox(height: 10),
                _tf(_subtitle, '副標（可空）'),
                const SizedBox(height: 10),
                _tf(_imageUrl, '圖片 URL（必填）', required: true),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  // ✅ value deprecated → initialValue
                  initialValue: _linkType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'LinkType',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'url', child: Text('url（外部連結）')),
                    DropdownMenuItem(
                      value: 'product',
                      child: Text('product（商品 ID）'),
                    ),
                    DropdownMenuItem(
                      value: 'category',
                      child: Text('category（分類 ID）'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _linkType = (v ?? 'url')),
                ),
                const SizedBox(height: 10),
                _tf(_linkValue, 'LinkValue（可空）'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: const Text('完成'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, {bool required = false}) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (v) => (v ?? '').trim().isEmpty ? '必填' : null
          : null,
    );
  }
}

class _SectionEditorSheet extends StatefulWidget {
  const _SectionEditorSheet({required this.initial});
  final HomeSectionItem initial;

  @override
  State<_SectionEditorSheet> createState() => _SectionEditorSheetState();
}

class _SectionEditorSheetState extends State<_SectionEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late bool _enabled;
  String _type = 'featuredProducts';

  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _ids;
  late final TextEditingController _imageUrl;
  late final TextEditingController _linkUrl;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _enabled = i.enabled;
    _type = i.type.trim().isNotEmpty ? i.type : 'featuredProducts';
    _title = TextEditingController(text: i.title);
    _subtitle = TextEditingController(text: i.subtitle);
    _ids = TextEditingController(text: i.itemIds.join(','));
    _imageUrl = TextEditingController(text: i.imageUrl);
    _linkUrl = TextEditingController(text: i.linkUrl);
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _ids.dispose();
    _imageUrl.dispose();
    _linkUrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ids = _ids.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    Navigator.pop(
      context,
      widget.initial.copyWith(
        enabled: _enabled,
        type: _type,
        title: _title.text.trim(),
        subtitle: _subtitle.text.trim(),
        itemIds: ids,
        imageUrl: _imageUrl.text.trim(),
        linkUrl: _linkUrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: pad.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '編輯區塊',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ✅ value deprecated → initialValue
                  initialValue: _type,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Type',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'featuredProducts',
                      child: Text('featuredProducts（精選商品）'),
                    ),
                    DropdownMenuItem(
                      value: 'featuredCategories',
                      child: Text('featuredCategories（精選分類）'),
                    ),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text('custom（自訂）'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _type = (v ?? 'featuredProducts')),
                ),
                const SizedBox(height: 10),
                _tf(_title, 'Title（必填）', required: true),
                const SizedBox(height: 10),
                _tf(_subtitle, 'Subtitle（可空）'),
                const SizedBox(height: 10),
                _tf(_ids, 'Item IDs（逗號分隔，可空）'),
                const SizedBox(height: 10),
                _tf(_imageUrl, 'imageUrl（可空）'),
                const SizedBox(height: 10),
                _tf(_linkUrl, 'linkUrl（可空）'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: const Text('完成'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, {bool required = false}) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (v) => (v ?? '').trim().isEmpty ? '必填' : null
          : null,
    );
  }
}

class _Num {
  static int asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

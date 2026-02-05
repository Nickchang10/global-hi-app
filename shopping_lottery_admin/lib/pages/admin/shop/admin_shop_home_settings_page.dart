// lib/pages/admin/shop/admin_shop_home_settings_page.dart
//
// ✅ AdminShopHomeSettingsPage（最終完整版）
// - 可獨立使用（有返回鍵 AppBar）
// - 可嵌入 AdminShell（內容本體不使用 Scaffold）
// - 可新增/編輯/刪除/拖曳排序區塊
// - Firestore：shop_config/home
//
// Doc Example:
// {
//   enabled: true,
//   sections: [
//     {
//       id: "1700000000000",
//       type: "rich_text",
//       enabled: true,
//       title: "公告",
//       ids: [],
//       limit: 12,
//       layout: "carousel",
//       body: "..."
///    }
//   ],
//   updatedAt: Timestamp
// }

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ============================================================
/// 對外入口（有返回鍵）
/// ============================================================
class AdminShopHomeSettingsPage extends StatelessWidget {
  const AdminShopHomeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          '商城首頁設定',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: const AdminShopHomeSettingsBody(),
    );
  }
}

/// ============================================================
/// 內容本體（可嵌入 AdminShell：不使用 Scaffold）
/// ============================================================
class AdminShopHomeSettingsBody extends StatefulWidget {
  const AdminShopHomeSettingsBody({super.key});

  @override
  State<AdminShopHomeSettingsBody> createState() =>
      _AdminShopHomeSettingsBodyState();
}

class _AdminShopHomeSettingsBodyState extends State<AdminShopHomeSettingsBody> {
  final _db = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('shop_config').doc('home');

  static const _defaults = <String, dynamic>{
    'enabled': true,
    'sections': <dynamic>[],
  };

  bool _hydrated = false;
  bool _dirty = false;
  bool _saving = false;

  bool _enabled = true;
  List<_HomeSection> _sections = [];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        // loading
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // error
        if (snap.hasError) {
          return _ErrorView(
            title: '載入失敗',
            message: snap.error.toString(),
            onRetry: () => setState(() {}),
          );
        }

        final exists = snap.data?.exists == true;

        final raw = <String, dynamic>{
          ..._defaults,
          ...(snap.data?.data() ?? <String, dynamic>{}),
        };

        // 只在第一次 or 未編輯狀態下同步遠端（避免你在編輯時被 stream 覆蓋）
        if (!_hydrated || !_dirty) {
          _enabled = raw['enabled'] == true;

          final list = (raw['sections'] as List? ?? const <dynamic>[])
              .whereType<Map>()
              .map((e) => _HomeSection.fromMap(Map<String, dynamic>.from(e)))
              .toList();

          _sections = list;
          _hydrated = true;
        }

        final updatedAt = _toDateTime(raw['updatedAt']);
        final updatedText = updatedAt == null
            ? '—'
            : '${updatedAt.year}/${updatedAt.month.toString().padLeft(2, '0')}/${updatedAt.day.toString().padLeft(2, '0')} '
                '${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}';

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                // ===== 狀態卡 =====
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          child: Icon(Icons.home, color: cs.onPrimaryContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '商城首頁設定',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '更新時間：$updatedText',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Text('總開關：'),
                                  Switch(
                                    value: _enabled,
                                    onChanged: (v) => setState(() {
                                      _enabled = v;
                                      _dirty = true;
                                    }),
                                  ),
                                  Text(_enabled ? 'enabled=true' : 'enabled=false'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!exists)
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _initIfMissing,
                            icon: const Icon(Icons.add),
                            label: const Text('初始化'),
                          ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(_saving ? '儲存中' : '儲存'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ===== 區塊列表（含拖曳排序）=====
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _sections.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('目前沒有任何區塊，請按右下角新增。'),
                          )
                        : ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _sections.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex -= 1;
                                final item = _sections.removeAt(oldIndex);
                                _sections.insert(newIndex, item);
                                _dirty = true;
                              });
                            },
                            itemBuilder: (context, i) {
                              final s = _sections[i];
                              return _SectionRow(
                                key: ValueKey(s.id.isEmpty ? 'idx_$i' : s.id),
                                index: i,
                                section: s,
                                onToggle: (v) => setState(() {
                                  _sections[i] = s.copyWith(enabled: v);
                                  _dirty = true;
                                }),
                                onEdit: () => _openEditor(editIndex: i),
                                onDelete: () => _deleteSection(i),
                              );
                            },
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // ===== JSON 預覽 =====
                ExpansionTile(
                  title: const Text(
                    'JSON 預覽',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        const JsonEncoder.withIndent('  ').convert(_buildDoc()),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ===== 右下角新增 =====
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _saving ? null : () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('新增區塊'),
              ),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------
  // Firestore Doc Build
  // ----------------------------
  Map<String, dynamic> _buildDoc() => <String, dynamic>{
        'enabled': _enabled,
        'sections': _sections.map((e) => e.toMap()).toList(),
      };

  Future<void> _initIfMissing() async {
    setState(() => _saving = true);
    await _ref.set(
      {..._defaults, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
      _hydrated = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已初始化設定文件')));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _ref.set(
      {..._buildDoc(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已儲存')));
  }

  Future<void> _deleteSection(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除區塊？'),
        content: const Text('刪除後無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _sections.removeAt(i);
      _dirty = true;
    });
  }

  // ----------------------------
  // Editor (新增/編輯共用)
  // ----------------------------
  Future<void> _openEditor({int? editIndex}) async {
    final isEdit = editIndex != null;
    final initial = isEdit ? _sections[editIndex!] : _HomeSection.newOf('rich_text');

    final result = await showDialog<_HomeSection>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SectionEditorDialog(initial: initial),
    );

    if (result == null) return;

    setState(() {
      if (isEdit) {
        _sections[editIndex!] = result;
      } else {
        _sections.add(result);
      }
      _dirty = true;
    });
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}

/// ============================================================
/// Model
/// ============================================================

class _HomeSection {
  final String id;
  final String type;
  final bool enabled;
  final String title;
  final List<String> ids;
  final int limit;
  final String layout;
  final String body;

  const _HomeSection({
    required this.id,
    required this.type,
    required this.enabled,
    required this.title,
    required this.ids,
    required this.limit,
    required this.layout,
    required this.body,
  });

  factory _HomeSection.newOf(String type) => _HomeSection(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: type,
        enabled: true,
        title: '',
        ids: const [],
        limit: 12,
        layout: 'carousel',
        body: '',
      );

  factory _HomeSection.fromMap(Map<String, dynamic> m) => _HomeSection(
        id: (m['id'] ?? '').toString(),
        type: (m['type'] ?? 'rich_text').toString(),
        enabled: m['enabled'] == true,
        title: (m['title'] ?? '').toString(),
        ids: (m['ids'] is List)
            ? List<String>.from((m['ids'] as List).map((e) => e.toString()))
            : const <String>[],
        limit: (m['limit'] is int) ? (m['limit'] as int) : 12,
        layout: (m['layout'] ?? 'carousel').toString(),
        body: (m['body'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'type': type,
        'enabled': enabled,
        'title': title,
        'ids': ids,
        'limit': limit,
        'layout': layout,
        'body': body,
      };

  _HomeSection copyWith({
    String? id,
    String? type,
    bool? enabled,
    String? title,
    List<String>? ids,
    int? limit,
    String? layout,
    String? body,
  }) =>
      _HomeSection(
        id: id ?? this.id,
        type: type ?? this.type,
        enabled: enabled ?? this.enabled,
        title: title ?? this.title,
        ids: ids ?? this.ids,
        limit: limit ?? this.limit,
        layout: layout ?? this.layout,
        body: body ?? this.body,
      );
}

/// ============================================================
/// Row UI
/// ============================================================

class _SectionRow extends StatelessWidget {
  final int index;
  final _HomeSection section;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SectionRow({
    super.key,
    required this.index,
    required this.section,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final title = section.title.trim().isEmpty ? '未命名區塊' : section.title.trim();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              section.enabled ? cs.primaryContainer : Colors.grey.shade200,
          child: Icon(
            Icons.drag_handle,
            color: section.enabled ? cs.onPrimaryContainer : Colors.grey,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          'type=${section.type} • layout=${section.layout} • limit=${section.limit}',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        trailing: SizedBox(
          width: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Switch(value: section.enabled, onChanged: onToggle),
              IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
              IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// Editor Dialog（新增/編輯共用）
/// ============================================================

class _SectionEditorDialog extends StatefulWidget {
  final _HomeSection initial;
  const _SectionEditorDialog({required this.initial});

  @override
  State<_SectionEditorDialog> createState() => _SectionEditorDialogState();
}

class _SectionEditorDialogState extends State<_SectionEditorDialog> {
  late bool enabled;
  late String id;
  late String type;
  late String layout;

  late TextEditingController titleCtl;
  late TextEditingController idsCtl;
  late TextEditingController limitCtl;
  late TextEditingController bodyCtl;

  final _formKey = GlobalKey<FormState>();

  static const _typeOptions = <String>[
    'rich_text',
    'products',
    'categories',
    'collection',
    'custom',
  ];

  static const _layoutOptions = <String>[
    'carousel',
    'grid',
    'list',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.initial;

    enabled = s.enabled;
    id = s.id;
    type = _typeOptions.contains(s.type) ? s.type : 'custom';
    layout = _layoutOptions.contains(s.layout) ? s.layout : 'carousel';

    titleCtl = TextEditingController(text: s.title);
    idsCtl = TextEditingController(text: s.ids.join(','));
    limitCtl = TextEditingController(text: s.limit.toString());
    bodyCtl = TextEditingController(text: s.body);
  }

  @override
  void dispose() {
    titleCtl.dispose();
    idsCtl.dispose();
    limitCtl.dispose();
    bodyCtl.dispose();
    super.dispose();
  }

  List<String> _parseIds(String raw) {
    final parts = raw
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts;
  }

  int _parseLimit(String raw) {
    final v = int.tryParse(raw.trim());
    if (v == null) return 12;
    if (v < 1) return 1;
    if (v > 200) return 200;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('編輯區塊', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('啟用此區塊', style: TextStyle(fontWeight: FontWeight.w800)),
                  value: enabled,
                  onChanged: (v) => setState(() => enabled = v),
                ),
                const SizedBox(height: 8),
                _readonlyRow('ID', id),
                const SizedBox(height: 8),
                TextFormField(
                  controller: titleCtl,
                  decoration: const InputDecoration(
                    labelText: '標題（顯示名稱）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
                  items: _typeOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => type = v ?? 'rich_text'),
                  decoration: const InputDecoration(
                    labelText: '區塊類型 type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: layout,
                  items: _layoutOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => layout = v ?? 'carousel'),
                  decoration: const InputDecoration(
                    labelText: '版型 layout',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: limitCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'limit（1~200）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: idsCtl,
                  decoration: const InputDecoration(
                    labelText: 'ids（用逗號/換行分隔）',
                    helperText: '例如：商品ID、分類ID、集合ID…依你的前台解析規則使用',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: bodyCtl,
                  decoration: InputDecoration(
                    labelText: 'body（rich_text 用）',
                    helperText: '只有 type=rich_text 時前台通常會用到',
                    border: const OutlineInputBorder(),
                    fillColor: cs.surface,
                  ),
                  minLines: 4,
                  maxLines: 8,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final result = widget.initial.copyWith(
              enabled: enabled,
              title: titleCtl.text.trim(),
              type: type,
              layout: layout,
              limit: _parseLimit(limitCtl.text),
              ids: _parseIds(idsCtl.text),
              body: bodyCtl.text,
            );
            Navigator.pop(context, result);
          },
          child: const Text('確定'),
        ),
      ],
    );
  }

  Widget _readonlyRow(String k, String v) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          Expanded(
            child: SelectableText(v, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// Error View
/// ============================================================

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
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
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

// lib/pages/admin/marketing/admin_segment_templates_panel.dart
//
// ✅ AdminSegmentTemplatesPanel（分眾模板面板｜正式版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：use_build_context_synchronously
// - 所有 async gap 之前先取得 messenger / navigator
// - await 之後不再直接用 context 取 ScaffoldMessenger/Navigator
// - await 後若需要 setState / push/pop，一律先 mounted guard
//
// ✅ 修正：library_private_types_in_public_api
// - 不在 public API 使用 private type（底線類別）
// - _SegmentTemplate 改為公開 SegmentTemplate
//
// 功能：
// - 從 Firestore 讀取 segment_templates（可選）
// - 若沒有資料：提供內建模板
// - 一鍵「套用模板」：
//   - 若提供 onApplyTemplate callback：回傳 template.rules 給外層（例如 SegmentEditPage）
//   - 否則：預設導到 /admin/segments/edit 並帶 arguments（你可自行在路由接收）
//
// Firestore collection（預設）：segment_templates
// 建議欄位：
// {
//   name: "高活躍會員",
//   description: "...",
//   enabled: true,
//   rules: { minPoints: 1000, minOrders: 3, lastActiveDays: 30, tags: ["vip"] },
//   updatedAt: Timestamp,
// }
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSegmentTemplatesPanel extends StatefulWidget {
  const AdminSegmentTemplatesPanel({
    super.key,
    this.collectionName = 'segment_templates',
    this.onApplyTemplate,
    this.onCreateFromTemplate,
    this.routeToCreate = '/admin/segments/edit',
    this.limit = 100,
    this.showFirestoreTemplates = true,
  });

  final String collectionName;

  /// 套用模板（通常用在 Segment 編輯頁：把 rules 填入表單）
  final void Function(Map<String, dynamic> rules)? onApplyTemplate;

  /// 建立分眾（外層自己處理建立/導頁）
  /// ✅ 不可用 private type，改用 public SegmentTemplate
  final Future<void> Function(SegmentTemplate template)? onCreateFromTemplate;

  /// 若沒有提供 onCreateFromTemplate，預設 pushNamed 到此路由
  final String routeToCreate;

  /// Firestore 最大抓取筆數
  final int limit;

  /// 是否顯示 Firestore 模板（關掉則只顯示內建模板）
  final bool showFirestoreTemplates;

  @override
  State<AdminSegmentTemplatesPanel> createState() =>
      _AdminSegmentTemplatesPanelState();
}

class _AdminSegmentTemplatesPanelState
    extends State<AdminSegmentTemplatesPanel> {
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final v = _searchCtrl.text.trim();
      if (v == _keyword) return;
      setState(() => _keyword = v);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(widget.collectionName);

  // -------------------------
  // Built-in templates fallback
  // -------------------------
  List<SegmentTemplate> _builtInTemplates() {
    return [
      SegmentTemplate(
        id: 'builtin_active_30d',
        name: '高活躍（近 30 天）',
        description: '最近 30 天內活躍，且至少 1 筆訂單',
        enabled: true,
        rules: {
          'minPoints': 0,
          'minOrders': 1,
          'lastActiveDays': 30,
          'tags': ['active'],
        },
      ),
      SegmentTemplate(
        id: 'builtin_vip_points',
        name: 'VIP（點數 >= 1000）',
        description: '累積點數達 1000 以上，適用 VIP 優惠',
        enabled: true,
        rules: {
          'minPoints': 1000,
          'minOrders': 0,
          'lastActiveDays': 0,
          'tags': ['vip'],
        },
      ),
      SegmentTemplate(
        id: 'builtin_new_users',
        name: '新客（低門檻）',
        description: '新客或低活躍：點數 < 200 或訂單 < 1（你可自行在後端解釋）',
        enabled: true,
        rules: {
          'minPoints': 0,
          'minOrders': 0,
          'lastActiveDays': 0,
          'tags': ['newbie'],
        },
      ),
    ];
  }

  bool _match(SegmentTemplate t) {
    final k = _keyword.trim().toLowerCase();
    if (k.isEmpty) return true;
    return t.id.toLowerCase().contains(k) ||
        t.name.toLowerCase().contains(k) ||
        (t.description ?? '').toLowerCase().contains(k);
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  // -------------------------
  // Actions (NO context across async gaps)
  // -------------------------
  Future<void> _confirmAndApply(SegmentTemplate t) async {
    // ✅ FIX: await 前先抓 messenger / navigator
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('套用模板'),
        content: Text('確定要套用「${t.name}」模板？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('套用'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (!mounted) return;

    // 1) 若外層提供 onApplyTemplate：直接回傳 rules
    if (widget.onApplyTemplate != null) {
      widget.onApplyTemplate!(t.rules);
      messenger.showSnackBar(const SnackBar(content: Text('已套用模板')));
      return;
    }

    // 2) 否則嘗試走「建立分眾」流程
    await _createFromTemplate(t, messenger: messenger, nav: nav);
  }

  Future<void> _createFromTemplate(
    SegmentTemplate t, {
    required ScaffoldMessengerState messenger,
    required NavigatorState nav,
  }) async {
    // 若外層自己處理建立
    if (widget.onCreateFromTemplate != null) {
      try {
        await widget.onCreateFromTemplate!(t);
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('已套用模板並建立/導向')));
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('操作失敗：$e')));
      }
      return;
    }

    // 預設：導到 segment edit 並帶 template payload（你可在 edit page 讀 arguments）
    nav.pushNamed(widget.routeToCreate, arguments: {'template': t.toArgs()});
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('分眾模板', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋模板名稱 / 描述 / id',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除',
                        onPressed: () => _searchCtrl.clear(),
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (!widget.showFirestoreTemplates) ...[
              _builtInList(),
            ] else ...[
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _col
                    .orderBy('updatedAt', descending: true)
                    .limit(widget.limit)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return _hintBox(
                      '讀取 Firestore 模板失敗：${snap.error}\n將顯示內建模板。',
                    );
                  }
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final docs = snap.data!.docs;
                  final firestoreTemplates = docs
                      .map((d) {
                        final m = d.data();
                        return SegmentTemplate(
                          id: d.id,
                          name: (m['name'] ?? m['title'] ?? d.id).toString(),
                          description: (m['description'] ?? m['desc'])
                              ?.toString(),
                          enabled: m['enabled'] == true,
                          rules: _asMap(m['rules']),
                        );
                      })
                      .where(_match)
                      .toList();

                  if (firestoreTemplates.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _hintBox('目前沒有符合條件的 Firestore 模板，改顯示內建模板。'),
                        const SizedBox(height: 10),
                        _builtInList(),
                      ],
                    );
                  }

                  return Column(
                    children: [...firestoreTemplates.map(_templateTile)],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _builtInList() {
    final list = _builtInTemplates().where(_match).toList();
    if (list.isEmpty) return _hintBox('沒有符合條件的模板。');
    return Column(children: [...list.map(_templateTile)]);
  }

  Widget _templateTile(SegmentTemplate t) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          t.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            (t.description ?? '').trim().isEmpty
                ? 'rules: ${t.rules.keys.join(', ')}'
                : t.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: OutlinedButton(
          onPressed: () => _confirmAndApply(t),
          child: Text(widget.onApplyTemplate != null ? '套用' : '套用/建立'),
        ),
      ),
    );
  }

  Widget _hintBox(String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
        color: cs.surfaceContainerHighest,
      ),
      child: Text(text, style: TextStyle(color: cs.onSurfaceVariant)),
    );
  }
}

// -------------------------
// ✅ Public Model (no underscore)
// -------------------------
class SegmentTemplate {
  final String id;
  final String name;
  final String? description;
  final bool enabled;
  final Map<String, dynamic> rules;

  const SegmentTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.enabled,
    required this.rules,
  });

  Map<String, dynamic> toArgs() => {
    'id': id,
    'name': name,
    'description': description,
    'enabled': enabled,
    'rules': rules,
  };
}

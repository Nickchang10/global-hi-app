// lib/pages/admin/app_center/admin_feature_toggles_page.dart
//
// ✅ AdminFeatureTogglesPage（完整版｜可編譯＋可用）
// ------------------------------------------------------------
// ✅ 修正 deprecated：PopScope.onPopInvoked → onPopInvokedWithResult
// ✅ 修正 curly_braces_in_flow_control_structures：所有 if 單行敘述改用 { } 包起來
// ✅ 不使用 withOpacity（改用 withAlpha 計算透明度）
//
// Firestore（前後台串接同一份 doc）：app_config/feature_toggles
// {
//   enabled: true,
//   items: [
//     {
//       id: "sos",
//       key: "sos",
//       title: "SOS 求救",
//       group: "安全",
//       description: "手錶求救通知／家長端推播",
//       enabled: true,
//       rollout: 100,   // 0~100（可做灰度）
//       order: 0
//     }
//   ],
//   updatedAt: Timestamp
// }
// ------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminFeatureTogglesPage extends StatefulWidget {
  const AdminFeatureTogglesPage({super.key});

  static const String routeName = '/admin-feature-toggles';

  @override
  State<AdminFeatureTogglesPage> createState() =>
      _AdminFeatureTogglesPageState();
}

class _AdminFeatureTogglesPageState extends State<AdminFeatureTogglesPage> {
  final _db = FirebaseFirestore.instance;

  /// ✅ 前後台串接固定同一份 doc
  late final DocumentReference<Map<String, dynamic>> _docRef = _db
      .collection('app_config')
      .doc('feature_toggles');

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  bool _systemEnabled = true;
  List<_ToggleItem> _items = <_ToggleItem>[];

  String _baselineSig = '';
  bool _dirty = false;

  bool _remoteHasUpdateWhileDirty = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ----------------------------
  // Helpers (no withOpacity)
  // ----------------------------

  Color _alpha(Color c, double opacity01) {
    final a = (opacity01 * 255).round().clamp(0, 255);
    return c.withAlpha(a);
  }

  // ----------------------------
  // Boot / Subscribe
  // ----------------------------

  Future<void> _boot() async {
    await _ensureDefaults();

    _sub = _docRef.snapshots().listen((snap) {
      if (!mounted) {
        return;
      }

      final data = snap.data() ?? <String, dynamic>{};
      final sysEnabled = (data['enabled'] as bool?) ?? true;
      final parsedItems = _parseItems(data['items']);

      final remoteSig = _computeSig(sysEnabled, parsedItems);

      if (_dirty) {
        if (remoteSig != _baselineSig) {
          setState(() => _remoteHasUpdateWhileDirty = true);
        }
        return;
      }

      setState(() {
        _systemEnabled = sysEnabled;
        _items = parsedItems;
        _baselineSig = remoteSig;
        _dirty = false;
        _remoteHasUpdateWhileDirty = false;
        _loading = false;
      });
    });
  }

  // ----------------------------
  // Defaults
  // ----------------------------

  List<_ToggleItem> _defaultItems() {
    return <_ToggleItem>[
      _ToggleItem(
        id: 'sos',
        key: 'sos',
        title: 'SOS 求救',
        group: '安全',
        description: '手錶求救通知／家長端推播',
        enabled: true,
        rollout: 100,
        order: 0,
      ),
      _ToggleItem(
        id: 'coupon',
        key: 'coupon',
        title: '優惠券',
        group: '行銷',
        description: '結帳折扣／自動派發／領取',
        enabled: true,
        rollout: 100,
        order: 1,
      ),
      _ToggleItem(
        id: 'lottery',
        key: 'lottery',
        title: '抽獎',
        group: '行銷',
        description: '付款後抽獎／活動抽獎',
        enabled: true,
        rollout: 100,
        order: 2,
      ),
      _ToggleItem(
        id: 'notifications',
        key: 'notifications',
        title: '通知中心',
        group: '系統',
        description: '站內通知／推播整合',
        enabled: true,
        rollout: 100,
        order: 3,
      ),
      _ToggleItem(
        id: 'ble',
        key: 'ble',
        title: 'BLE 連線',
        group: '裝置',
        description: '手錶連線／設備同步',
        enabled: true,
        rollout: 100,
        order: 4,
      ),
      _ToggleItem(
        id: 'voice_assistant',
        key: 'voice_assistant',
        title: '語音助理',
        group: '互動',
        description: '語音互動／快速操作',
        enabled: false,
        rollout: 0,
        order: 5,
      ),
    ];
  }

  Future<void> _ensureDefaults() async {
    try {
      final snap = await _docRef.get();
      final data = snap.data();

      final sysEnabled = (data?['enabled'] as bool?) ?? true;
      final raw = data?['items'];

      final itemsEmpty = raw is! List || raw.isEmpty;

      if (!snap.exists || itemsEmpty) {
        final defaults = _defaultItems();
        await _docRef.set(<String, dynamic>{
          'enabled': sysEnabled,
          'items': defaults.map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // init 不干擾畫面
    }
  }

  // ----------------------------
  // Parse / Signature / Dirty
  // ----------------------------

  List<_ToggleItem> _parseItems(dynamic raw) {
    final list = <_ToggleItem>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(_ToggleItem.fromMap(e));
        } else if (e is Map) {
          list.add(_ToggleItem.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  String _computeSig(bool sysEnabled, List<_ToggleItem> items) {
    final sorted = [...items]..sort((a, b) => a.order.compareTo(b.order));
    return jsonEncode(<String, dynamic>{
      'enabled': sysEnabled,
      'items': sorted.map((e) => e.toMap()).toList(),
    });
  }

  void _markDirty() {
    final sig = _computeSig(_systemEnabled, _items);
    if (!mounted) {
      return;
    }
    setState(() => _dirty = sig != _baselineSig);
  }

  // ----------------------------
  // PopScope (NEW API)
  // ----------------------------

  void _onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) {
      return;
    }
    _confirmDiscardAndPop();
  }

  Future<void> _confirmDiscardAndPop() async {
    if (!_dirty || _saving) {
      if (mounted) {
        Navigator.of(context).maybePop();
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('尚未儲存'),
        content: const Text('你有未儲存的變更，確定要放棄並離開嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放棄'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    // 放棄：重新抓遠端
    try {
      final snap = await _docRef.get();
      final data = snap.data() ?? <String, dynamic>{};

      final sysEnabled = (data['enabled'] as bool?) ?? true;
      final items = _parseItems(data['items']);
      final sig = _computeSig(sysEnabled, items);

      if (!mounted) {
        return;
      }
      setState(() {
        _systemEnabled = sysEnabled;
        _items = items;
        _baselineSig = sig;
        _dirty = false;
        _remoteHasUpdateWhileDirty = false;
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // ----------------------------
  // Save / Refresh / Defaults
  // ----------------------------

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (mounted) {
      setState(() => _saving = true);
    }

    try {
      final sorted = [..._items]..sort((a, b) => a.order.compareTo(b.order));

      await _docRef.set(<String, dynamic>{
        'enabled': _systemEnabled,
        'items': sorted.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final sig = _computeSig(_systemEnabled, sorted);

      if (!mounted) {
        return;
      }
      setState(() {
        _items = sorted;
        _baselineSig = sig;
        _dirty = false;
        _remoteHasUpdateWhileDirty = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存 Feature Toggles')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _applyDefaultsDraft() {
    final defaults = _defaultItems();
    if (!mounted) {
      return;
    }
    setState(() {
      _systemEnabled = true;
      _items = defaults;
    });
    _markDirty();
  }

  Future<void> _discardAndRefresh() async {
    try {
      final snap = await _docRef.get();
      final data = snap.data() ?? <String, dynamic>{};

      final sysEnabled = (data['enabled'] as bool?) ?? true;
      final items = _parseItems(data['items']);
      final sig = _computeSig(sysEnabled, items);

      if (!mounted) {
        return;
      }
      setState(() {
        _systemEnabled = sysEnabled;
        _items = items;
        _baselineSig = sig;
        _dirty = false;
        _remoteHasUpdateWhileDirty = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刷新並套用遠端最新設定')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刷新失敗：$e')));
    }
  }

  // ----------------------------
  // CRUD
  // ----------------------------

  Future<void> _addOrEdit({_ToggleItem? initial}) async {
    final result = await _showEditDialog(initial: initial);
    if (result == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (initial case final init?) {
        _items = _items.map((e) {
          if (e.id == init.id) {
            return result.copyWith(order: e.order);
          }
          return e;
        }).toList();
      } else {
        final maxOrder = _items.isEmpty
            ? -1
            : _items.map((e) => e.order).reduce((a, b) => a > b ? a : b);
        _items = [..._items, result.copyWith(order: maxOrder + 1)];
      }

      _items.sort((a, b) => a.order.compareTo(b.order));
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(order: i);
      }
    });

    _markDirty();
  }

  Future<void> _deleteItem(_ToggleItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除 Toggle'),
        content: Text('確定要刪除「${item.title}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _items = _items.where((e) => e.id != item.id).toList();
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(order: i);
      }
    });
    _markDirty();
  }

  // ----------------------------
  // Dialog
  // ----------------------------

  static const List<String> _groups = <String>[
    '安全',
    '行銷',
    '系統',
    '裝置',
    '互動',
    '商城',
    '任務',
    '其他',
  ];

  Future<_ToggleItem?> _showEditDialog({_ToggleItem? initial}) async {
    final isEdit = initial != null;

    final keyCtrl = TextEditingController(text: initial?.key ?? '');
    final titleCtrl = TextEditingController(text: initial?.title ?? '');
    final descCtrl = TextEditingController(text: initial?.description ?? '');

    String group = initial?.group ?? _groups.first;
    bool enabled = initial?.enabled ?? true;
    int rollout = (initial?.rollout ?? 100).clamp(0, 100);

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<_ToggleItem?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Text(isEdit ? '編輯 Toggle' : '新增 Toggle'),
            content: SizedBox(
              width: 600,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownMenu<String>(
                      initialSelection: _groups.contains(group)
                          ? group
                          : _groups.first,
                      dropdownMenuEntries: _groups
                          .map(
                            (g) =>
                                DropdownMenuEntry<String>(value: g, label: g),
                          )
                          .toList(),
                      label: const Text('群組（Group）'),
                      onSelected: (v) {
                        if (v == null) {
                          return;
                        }
                        setStateDialog(() => group = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: keyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Key（唯一識別）',
                        hintText: '例如：sos / coupon / lottery',
                      ),
                      enabled: !isEdit,
                      validator: (v) {
                        final val = (v ?? '').trim();
                        if (val.isEmpty) {
                          return 'Key 不能為空';
                        }
                        final dup = _items.any(
                          (e) => e.key == val && e.id != initial?.id,
                        );
                        if (dup) {
                          return 'Key 已存在，請換一個';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: '名稱（Title）'),
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) {
                          return '名稱不能為空';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: '描述（可空）'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      onChanged: (v) => setStateDialog(() => enabled = v),
                      title: const Text('啟用此 Toggle'),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('灰度比例（Rollout）：$rollout%'),
                              Slider(
                                value: rollout.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 20,
                                onChanged: (v) =>
                                    setStateDialog(() => rollout = v.round()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (enabled && rollout == 0)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '⚠️ 已啟用但 rollout=0%，前台仍可能完全看不到（灰度為 0）',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) {
                    return;
                  }

                  final key = keyCtrl.text.trim();
                  final title = titleCtrl.text.trim();
                  final desc = descCtrl.text.trim();

                  Navigator.of(ctx).pop(
                    _ToggleItem(
                      id: initial?.id ?? key,
                      key: key,
                      title: title,
                      group: group,
                      description: desc,
                      enabled: enabled,
                      rollout: rollout,
                      order: initial?.order ?? 999,
                    ),
                  );
                },
                child: const Text('儲存'),
              ),
            ],
          );
        },
      ),
    );

    keyCtrl.dispose();
    titleCtrl.dispose();
    descCtrl.dispose();

    return result;
  }

  // ----------------------------
  // UI
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final keyword = _searchCtrl.text.trim().toLowerCase();
    final visible = _items.where((e) {
      if (keyword.isEmpty) {
        return true;
      }
      return e.key.toLowerCase().contains(keyword) ||
          e.title.toLowerCase().contains(keyword) ||
          e.group.toLowerCase().contains(keyword) ||
          e.description.toLowerCase().contains(keyword);
    }).toList()..sort((a, b) => a.order.compareTo(b.order));

    final enabledCount = _items.where((e) => e.enabled).length;
    final rolloutCount = _items
        .where((e) => e.enabled && e.rollout < 100)
        .length;

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Feature Toggles 管理',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            TextButton.icon(
              onPressed: _saving ? null : _applyDefaultsDraft,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('套用預設'),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: _saving ? null : () => _addOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text('新增'),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: (_dirty && !_saving) ? _save : null,
              icon: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.save),
              label: const Text('儲存'),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_remoteHasUpdateWhileDirty)
                    Material(
                      color: cs.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: cs.onTertiaryContainer,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text('遠端設定已更新，你目前有未儲存變更。建議先儲存或放棄後再刷新。'),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: _saving ? null : _discardAndRefresh,
                              child: const Text('放棄並刷新'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search),
                                  hintText:
                                      '搜尋 key / title / group / description',
                                  filled: true,
                                  fillColor: _alpha(
                                    cs.surfaceContainerHighest,
                                    0.6,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _alpha(cs.outlineVariant, 0.4),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _alpha(cs.outlineVariant, 0.4),
                                    ),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 320,
                              child: Card(
                                elevation: 0,
                                color: _alpha(cs.surfaceContainerHighest, 0.35),
                                child: SwitchListTile(
                                  value: _systemEnabled,
                                  onChanged: _saving
                                      ? null
                                      : (v) {
                                          setState(() => _systemEnabled = v);
                                          _markDirty();
                                        },
                                  title: const Text('啟用 Toggle 系統'),
                                  subtitle: const Text('關閉時前台可忽略本設定'),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: '總數',
                                value: '${_items.length}',
                                icon: Icons.list_alt,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                title: '啟用中',
                                value: '$enabledCount',
                                icon: Icons.toggle_on,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                title: '灰度中',
                                value: '$rolloutCount',
                                icon: Icons.percent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                title: '狀態',
                                value: _dirty ? '未儲存' : '已同步',
                                icon: _dirty
                                    ? Icons.warning_amber_rounded
                                    : Icons.verified,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Card(
                      margin: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      child: visible.isEmpty
                          ? const Center(child: Text('沒有符合條件的 Toggle'))
                          : ReorderableListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: visible.length,
                              onReorder: (oldIndex, newIndex) {
                                if (keyword.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('搜尋中不建議拖曳排序，請清空搜尋再排序'),
                                    ),
                                  );
                                  return;
                                }

                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }

                                final list = [..._items]
                                  ..sort((a, b) => a.order.compareTo(b.order));
                                final moved = list.removeAt(oldIndex);
                                list.insert(newIndex, moved);

                                for (int i = 0; i < list.length; i++) {
                                  list[i] = list[i].copyWith(order: i);
                                }

                                setState(() => _items = list);
                                _markDirty();
                              },
                              itemBuilder: (context, i) {
                                final item = visible[i];

                                return Card(
                                  key: ValueKey(item.id),
                                  elevation: 0,
                                  child: ListTile(
                                    leading: ReorderableDragStartListener(
                                      index: i,
                                      child: const Icon(Icons.drag_handle),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _Pill(
                                          text: item.group,
                                          bg: _alpha(
                                            cs.secondaryContainer,
                                            0.55,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _Pill(
                                          text: item.key,
                                          bg: _alpha(cs.primary, 0.10),
                                          fg: cs.primary,
                                        ),
                                        if (item.enabled &&
                                            item.rollout < 100) ...[
                                          const SizedBox(width: 6),
                                          _Pill(
                                            text: '灰度 ${item.rollout}%',
                                            bg: _alpha(Colors.orange, 0.12),
                                            fg: Colors.orange.shade800,
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        item.description.isEmpty
                                            ? '—'
                                            : item.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    trailing: Wrap(
                                      spacing: 6,
                                      children: [
                                        Switch(
                                          value: item.enabled,
                                          onChanged: _saving
                                              ? null
                                              : (v) {
                                                  setState(() {
                                                    _items = _items.map((e) {
                                                      if (e.id == item.id) {
                                                        return e.copyWith(
                                                          enabled: v,
                                                        );
                                                      }
                                                      return e;
                                                    }).toList();
                                                  });
                                                  _markDirty();
                                                },
                                        ),
                                        IconButton(
                                          tooltip: '編輯',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: _saving
                                              ? null
                                              : () => _addOrEdit(initial: item),
                                        ),
                                        IconButton(
                                          tooltip: '刪除',
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Colors.red.shade400,
                                          ),
                                          onPressed: _saving
                                              ? null
                                              : () => _deleteItem(item),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color? fg;

  const _Pill({required this.text, required this.bg, this.fg});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveFg = fg ?? cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: effectiveFg.withAlpha(40)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: effectiveFg,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ToggleItem {
  final String id;
  final String key;
  final String title;
  final String group;
  final String description;
  final bool enabled;
  final int rollout; // 0~100
  final int order;

  const _ToggleItem({
    required this.id,
    required this.key,
    required this.title,
    required this.group,
    required this.description,
    required this.enabled,
    required this.rollout,
    required this.order,
  });

  _ToggleItem copyWith({
    String? id,
    String? key,
    String? title,
    String? group,
    String? description,
    bool? enabled,
    int? rollout,
    int? order,
  }) {
    return _ToggleItem(
      id: id ?? this.id,
      key: key ?? this.key,
      title: title ?? this.title,
      group: group ?? this.group,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      rollout: rollout ?? this.rollout,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'key': key,
    'title': title,
    'group': group,
    'description': description,
    'enabled': enabled,
    'rollout': rollout,
    'order': order,
  };

  static _ToggleItem fromMap(Map<String, dynamic> m) {
    final rolloutRaw = m['rollout'];
    int rollout = 100;

    if (rolloutRaw is int) {
      rollout = rolloutRaw;
    } else if (rolloutRaw is num) {
      rollout = rolloutRaw.round();
    }

    rollout = rollout.clamp(0, 100);

    return _ToggleItem(
      id: (m['id'] ?? m['key'] ?? '').toString(),
      key: (m['key'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      group: (m['group'] ?? '其他').toString(),
      description: (m['description'] ?? '').toString(),
      enabled: (m['enabled'] as bool?) ?? true,
      rollout: rollout,
      order: (m['order'] as int?) ?? 0,
    );
  }
}

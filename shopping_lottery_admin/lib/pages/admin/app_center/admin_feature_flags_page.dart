// lib/pages/admin/app_center/admin_feature_flags_page.dart
//
// ✅ AdminFeatureFlagsPage（完整版｜可編譯＋可用）
// ------------------------------------------------------------
// ✅ 修正 deprecated：WillPopScope → PopScope
// ✅ 修正 deprecated：PopScope.onPopInvoked → onPopInvokedWithResult
// ✅ 修正 unused_field：移除 _pendingRemoteSig
// ✅ 修正 unnecessary_non_null_assertion：移除多餘 '!'
// ✅ 修正 control_flow_in_finally：finally 區塊不使用 return
// ✅ 修正 lint：curly_braces_in_flow_control_structures（全檔單行 if 改成區塊）
//
// Firestore（前後台串接同一份 doc）：app_config/feature_flags
// {
//   enabled: true,
//   items: [
//     { id: "sos", key: "sos", title: "SOS 求救", description: "...", enabled: true, order: 0 },
//     ...
//   ],
//   updatedAt: Timestamp
// }
// ------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminFeatureFlagsPage extends StatefulWidget {
  const AdminFeatureFlagsPage({super.key});

  static const String routeName = '/admin-feature-flags';

  @override
  State<AdminFeatureFlagsPage> createState() => _AdminFeatureFlagsPageState();
}

class _AdminFeatureFlagsPageState extends State<AdminFeatureFlagsPage> {
  final _db = FirebaseFirestore.instance;

  /// ✅ 前後台串接固定同一份 doc
  late final DocumentReference<Map<String, dynamic>> _docRef = _db
      .collection('app_config')
      .doc('feature_flags');

  final _searchCtrl = TextEditingController();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  bool _loading = true;
  bool _saving = false;

  bool _enabled = true;
  List<_FlagItem> _items = <_FlagItem>[];

  /// 遠端基準（用來判斷 dirty / discard）
  String _baselineSig = '';
  bool _dirty = false;

  /// 若你正在編輯（dirty=true），遠端又更新，先提示（不覆蓋你的草稿）
  bool _remoteHasUpdateWhileDirty = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _ensureDefaults();

    _sub = _docRef.snapshots().listen((snap) {
      final data = snap.data() ?? <String, dynamic>{};
      final parsedEnabled = (data['enabled'] as bool?) ?? true;

      final raw = data['items'];
      final parsedItems = _parseItems(raw);

      final remoteSig = _computeSig(parsedEnabled, parsedItems);

      if (_dirty) {
        // 你正在編輯，就不要覆蓋草稿，只提示遠端有更新
        if (remoteSig != _baselineSig) {
          if (mounted) {
            setState(() {
              _remoteHasUpdateWhileDirty = true;
            });
          }
        }
        return;
      }

      // 非 dirty：直接同步到畫面
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = parsedEnabled;
        _items = parsedItems;
        _baselineSig = remoteSig;
        _dirty = false;
        _remoteHasUpdateWhileDirty = false;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------- Defaults ----------

  List<_FlagItem> _defaultItems() {
    return <_FlagItem>[
      _FlagItem(
        id: 'sos',
        key: 'sos',
        title: 'SOS 求救',
        description: '手錶求救通知／家長端推播',
        enabled: true,
        order: 0,
      ),
      _FlagItem(
        id: 'coupon',
        key: 'coupon',
        title: '優惠券',
        description: '結帳折扣／自動派發／領取',
        enabled: true,
        order: 1,
      ),
      _FlagItem(
        id: 'lottery',
        key: 'lottery',
        title: '抽獎',
        description: '付款後抽獎／活動抽獎',
        enabled: true,
        order: 2,
      ),
      _FlagItem(
        id: 'notifications',
        key: 'notifications',
        title: '通知中心',
        description: '站內通知／推播整合',
        enabled: true,
        order: 3,
      ),
      _FlagItem(
        id: 'ble',
        key: 'ble',
        title: 'BLE 連線',
        description: '手錶連線／設備同步',
        enabled: true,
        order: 4,
      ),
      _FlagItem(
        id: 'voice_assistant',
        key: 'voice_assistant',
        title: '語音助理',
        description: '語音互動／快速操作',
        enabled: false,
        order: 5,
      ),
      _FlagItem(
        id: 'warranty',
        key: 'warranty',
        title: '保固服務',
        description: '保固查詢／延長保固',
        enabled: true,
        order: 6,
      ),
      _FlagItem(
        id: 'support',
        key: 'support',
        title: '客服支援',
        description: '客服工單／即時客服',
        enabled: true,
        order: 7,
      ),
    ];
  }

  Future<void> _ensureDefaults() async {
    try {
      final snap = await _docRef.get();
      final data = snap.data();
      final enabled = (data?['enabled'] as bool?) ?? true;
      final rawItems = data?['items'];

      final itemsEmpty = rawItems is! List || rawItems.isEmpty;

      if (!snap.exists || itemsEmpty) {
        final defaults = _defaultItems();
        await _docRef.set(<String, dynamic>{
          'enabled': enabled,
          'items': defaults.map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // 不干擾畫面
    }
  }

  // ---------- Parsing / Signature ----------

  List<_FlagItem> _parseItems(dynamic raw) {
    final list = <_FlagItem>[];

    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(_FlagItem.fromMap(e));
        } else if (e is Map) {
          list.add(_FlagItem.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }

    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  String _computeSig(bool enabled, List<_FlagItem> items) {
    final sorted = [...items]..sort((a, b) => a.order.compareTo(b.order));
    final payload = <String, dynamic>{
      'enabled': enabled,
      'items': sorted.map((e) => e.toMap()).toList(),
    };
    return jsonEncode(payload);
  }

  void _markDirty() {
    final sig = _computeSig(_enabled, _items);
    if (!mounted) {
      return;
    }
    setState(() {
      _dirty = sig != _baselineSig;
    });
  }

  // ---------- PopScope (onPopInvokedWithResult) ----------

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

    // 放棄：回到 baseline（安全做法：重新抓遠端一次）
    try {
      final snap = await _docRef.get();
      final data = snap.data() ?? <String, dynamic>{};
      final parsedEnabled = (data['enabled'] as bool?) ?? true;
      final parsedItems = _parseItems(data['items']);
      final remoteSig = _computeSig(parsedEnabled, parsedItems);

      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = parsedEnabled;
        _items = parsedItems;
        _baselineSig = remoteSig;
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

  // ---------- Save ----------

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (mounted) {
      setState(() {
        _saving = true;
      });
    }

    try {
      final sorted = [..._items]..sort((a, b) => a.order.compareTo(b.order));

      await _docRef.set(<String, dynamic>{
        'enabled': _enabled,
        'items': sorted.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final newSig = _computeSig(_enabled, sorted);

      if (!mounted) {
        return;
      }

      setState(() {
        _items = sorted;
        _baselineSig = newSig;
        _dirty = false;
        _remoteHasUpdateWhileDirty = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存功能開關設定')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      // ✅ finally 內不做 return
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _applyDefaultsDraft() {
    final defaults = _defaultItems();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = defaults;
      _enabled = true;
    });
    _markDirty();
  }

  // ---------- Add/Edit/Delete ----------

  Future<void> _addOrEdit({_FlagItem? initial}) async {
    final isEdit = initial != null;

    final keyCtrl = TextEditingController(text: initial?.key ?? '');
    final titleCtrl = TextEditingController(text: initial?.title ?? '');
    final descCtrl = TextEditingController(text: initial?.description ?? '');

    bool enabled = initial?.enabled ?? true;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<_FlagItem?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(isEdit ? '編輯功能' : '新增功能'),
              content: SizedBox(
                width: 560,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: keyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Key（唯一識別）',
                          hintText: '例如：sos / coupon / lottery',
                        ),
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
                        enabled: !isEdit,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: '名稱（顯示用）',
                          hintText: '例如：SOS 求救',
                        ),
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
                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: enabled,
                        onChanged: (v) => setStateDialog(() => enabled = v),
                        title: const Text('啟用此功能'),
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
                      _FlagItem(
                        id: initial?.id ?? key,
                        key: key,
                        title: title,
                        description: desc,
                        enabled: enabled,
                        order: initial?.order ?? 999,
                      ),
                    );
                  },
                  child: const Text('確定'),
                ),
              ],
            );
          },
        );
      },
    );

    keyCtrl.dispose();
    titleCtrl.dispose();
    descCtrl.dispose();

    if (result == null) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      // ✅ Dart 3 pattern promotion，不需要 initial!
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

  Future<void> _deleteItem(_FlagItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除功能'),
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

  // ---------- UI ----------

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
          e.description.toLowerCase().contains(keyword);
    }).toList()..sort((a, b) => a.order.compareTo(b.order));

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '功能開關管理',
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
                            Expanded(
                              child: Text(
                                '遠端設定已更新。你目前有未儲存變更，建議先儲存或放棄後再刷新。',
                                style: TextStyle(color: cs.onTertiaryContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: '搜尋 key / 名稱 / 描述',
                              filled: true,
                              fillColor: cs.surfaceContainerHighest.withValues(
                                alpha: 0.6,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 260,
                          child: Card(
                            elevation: 0,
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                            child: SwitchListTile(
                              value: _enabled,
                              onChanged: _saving
                                  ? null
                                  : (v) {
                                      setState(() {
                                        _enabled = v;
                                      });
                                      _markDirty();
                                    },
                              title: const Text('啟用功能開關系統'),
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
                  ),
                  Expanded(
                    child: Card(
                      margin: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      child: visible.isEmpty
                          ? const Center(child: Text('沒有符合條件的功能'))
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

                                setState(() {
                                  _items = list;
                                });
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
                                        _KeyPill(text: item.key),
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
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
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

class _KeyPill extends StatelessWidget {
  final String text;
  const _KeyPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FlagItem {
  final String id;
  final String key;
  final String title;
  final String description;
  final bool enabled;
  final int order;

  const _FlagItem({
    required this.id,
    required this.key,
    required this.title,
    required this.description,
    required this.enabled,
    required this.order,
  });

  _FlagItem copyWith({
    String? id,
    String? key,
    String? title,
    String? description,
    bool? enabled,
    int? order,
  }) {
    return _FlagItem(
      id: id ?? this.id,
      key: key ?? this.key,
      title: title ?? this.title,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'key': key,
    'title': title,
    'description': description,
    'enabled': enabled,
    'order': order,
  };

  static _FlagItem fromMap(Map<String, dynamic> m) {
    return _FlagItem(
      id: (m['id'] ?? m['key'] ?? '').toString(),
      key: (m['key'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      enabled: (m['enabled'] as bool?) ?? true,
      order: (m['order'] as int?) ?? 0,
    );
  }
}

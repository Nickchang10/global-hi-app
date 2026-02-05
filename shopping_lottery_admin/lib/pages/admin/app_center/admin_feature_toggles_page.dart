// lib/pages/admin/app_center/admin_feature_toggles_page.dart
//
// ✅ AdminFeatureTogglesPage（A. 基礎專業版｜單檔完整版｜可編譯＋可用）
// ------------------------------------------------------------
// App 功能開關（後台）
// - Firestore：app_config/app_features
// - 功能：
//   1) 初始化文件（不存在時）
//   2) 全域 enabled（總開關）
//   3) Toggle 清單：新增 / 編輯 / 刪除 / 啟用停用
//   4) ReorderableListView 拖曳排序（寫回 order）
//   5) 搜尋（key / title / description / group）
//   6) 分組（group）檢視（例如：Shop / Marketing / SOS）
//   7) 匯出 JSON（複製到剪貼簿）
//
// Firestore 建議結構：app_config/app_features
// {
//   enabled: true,
//   toggles: [
//     {
//       key: "checkout_enabled",
//       title: "下單 / 結帳",
//       description: "控制整體結帳流程入口",
//       group: "Shop",
//       enabled: true,
//       requiresAuth: true,
//       rolloutPercent: 100,        // 0~100（可選）
//       minAppVersion: "",          // 可選
//       platforms: ["android","ios","web"], // 可選
//       order: 0
//     },
//     ...
//   ],
//   updatedAt: Timestamp
// }
//
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminFeatureTogglesPage extends StatefulWidget {
  const AdminFeatureTogglesPage({super.key});

  @override
  State<AdminFeatureTogglesPage> createState() => _AdminFeatureTogglesPageState();
}

class _AdminFeatureTogglesPageState extends State<AdminFeatureTogglesPage> {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('app_features');

  final TextEditingController _search = TextEditingController();
  bool _groupView = true;

  // ✅ 你要的「能下單買東西 / 活動抽獎」：內建 defaults
  static const Map<String, dynamic> _defaults = {
    'enabled': true,
    'toggles': [
      {
        'key': 'shop_enabled',
        'title': '商城模組',
        'description': '控制商城入口（商城頁、商品詳情等）',
        'group': 'Shop',
        'enabled': true,
        'requiresAuth': false,
        'rolloutPercent': 100,
        'minAppVersion': '',
        'platforms': ['android', 'ios', 'web'],
        'order': 0,
      },
      {
        'key': 'checkout_enabled',
        'title': '下單 / 結帳',
        'description': '控制結帳流程入口（購物車→結帳→建立訂單）',
        'group': 'Shop',
        'enabled': true,
        'requiresAuth': true,
        'rolloutPercent': 100,
        'minAppVersion': '',
        'platforms': ['android', 'ios', 'web'],
        'order': 1,
      },
      {
        'key': 'payment_enabled',
        'title': '付款流程',
        'description': '控制付款頁與付款狀態回寫（PaymentPage / PaymentStatus）',
        'group': 'Shop',
        'enabled': true,
        'requiresAuth': true,
        'rolloutPercent': 100,
        'minAppVersion': '',
        'platforms': ['android', 'ios', 'web'],
        'order': 2,
      },
      {
        'key': 'lottery_enabled',
        'title': '活動抽獎',
        'description': '控制抽獎入口（LotteryPage / 活動抽獎流程）',
        'group': 'Marketing',
        'enabled': true,
        'requiresAuth': true,
        'rolloutPercent': 100,
        'minAppVersion': '',
        'platforms': ['android', 'ios', 'web'],
        'order': 3,
      },
    ],
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App 功能開關', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: _groupView ? '切換為清單檢視' : '切換為分組檢視',
            icon: Icon(_groupView ? Icons.view_list_outlined : Icons.view_module_outlined),
            onPressed: () => setState(() => _groupView = !_groupView),
          ),
          IconButton(
            tooltip: '匯出 JSON（複製）',
            icon: const Icon(Icons.code),
            onPressed: _exportJson,
          ),
          IconButton(
            tooltip: '重置為預設',
            icon: const Icon(Icons.restart_alt),
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditDialog(isNew: true),
        icon: const Icon(Icons.add),
        label: const Text('新增 Toggle'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              title: '載入失敗',
              message: snap.error.toString(),
              onRetry: () => setState(() {}),
              hint: '請確認 Firestore 權限：app_config/app_features（admin 才可寫入）。',
            );
          }

          final exists = snap.data?.exists == true;
          final data = <String, dynamic>{
            ..._defaults,
            ...(snap.data?.data() ?? const <String, dynamic>{}),
          };

          final globalEnabled = data['enabled'] == true;
          final updatedAt = _toDateTime(data['updatedAt']);
          final updatedText = updatedAt == null
              ? '—'
              : DateFormat('yyyy/MM/dd HH:mm').format(updatedAt);

          final toggles = _parseToggles(data['toggles']).toList()
            ..sort((a, b) => a.order.compareTo(b.order));

          final filtered = _filter(toggles, _search.text);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _HeaderCard(
                exists: exists,
                globalEnabled: globalEnabled,
                updatedText: updatedText,
                onInit: exists ? null : _initIfMissing,
                onToggleGlobal: (v) => _setGlobalEnabled(v),
              ),
              const SizedBox(height: 12),

              _SectionTitle(
                title: '快速開關',
                subtitle: '提供常用功能快速啟用/停用（不影響其他自訂 toggles）。',
              ),
              const SizedBox(height: 8),
              _QuickCard(
                globalEnabled: globalEnabled,
                toggles: toggles,
                onPatch: _patchToggleByKey,
              ),

              const SizedBox(height: 14),
              _SectionTitle(
                title: 'Toggle 清單',
                subtitle: '支援搜尋、拖曳排序、編輯與刪除。',
              ),
              const SizedBox(height: 8),

              _SearchBar(
                controller: _search,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              if (!exists)
                Card(
                  elevation: 0,
                  color: cs.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '目前尚未建立 app_config/app_features。\n請點上方「初始化設定文件」建立預設 toggles。',
                      style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
                    ),
                  ),
                ),

              if (exists) ...[
                if (filtered.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('沒有符合條件的 Toggle'),
                    ),
                  )
                else
                  _groupView
                      ? _GroupedList(
                          toggles: filtered,
                          onEdit: (t) => _openEditDialog(isNew: false, initial: t),
                          onDelete: (t) => _deleteToggle(t.key),
                          onToggleEnabled: (t, v) =>
                              _patchToggleByKey(t.key, {'enabled': v}),
                          onReorderWithin: _reorderWithinGroup,
                        )
                      : _FlatReorderList(
                          toggles: filtered,
                          onEdit: (t) => _openEditDialog(isNew: false, initial: t),
                          onDelete: (t) => _deleteToggle(t.key),
                          onToggleEnabled: (t, v) =>
                              _patchToggleByKey(t.key, {'enabled': v}),
                          onReorder: (oldIndex, newIndex) =>
                              _reorderAll(filtered, oldIndex, newIndex),
                        ),
              ],

              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'App 端讀取建議：\n'
                    '1) global enabled=false → 全部功能可視為停用（或降級顯示）\n'
                    '2) toggles 依 order 排序\n'
                    '3) requiresAuth=true → 未登入時導向登入或提示\n'
                    '4) rolloutPercent/minAppVersion/platforms 可做灰度與版本/平台條件\n',
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // Filtering
  // ============================================================

  List<FeatureToggle> _filter(List<FeatureToggle> items, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((t) {
      return t.key.toLowerCase().contains(q) ||
          t.title.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          t.group.toLowerCase().contains(q);
    }).toList();
  }

  // ============================================================
  // Firestore ops
  // ============================================================

  Future<void> _initIfMissing() async {
    final ok = await _confirm(
      title: '初始化功能開關',
      message: '將建立 app_config/app_features 並寫入預設 toggles。是否繼續？',
      confirmText: '建立',
    );
    if (ok != true) return;

    try {
      await _ref.set({
        ..._defaults,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已初始化 app_features')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('初始化失敗：$e')),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final ok = await _confirm(
      title: '重置為預設',
      message: '將以預設 toggles 覆蓋目前 toggles（會覆蓋現有自訂）。是否繼續？',
      confirmText: '重置',
    );
    if (ok != true) return;

    try {
      await _ref.set({
        ..._defaults,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重置為預設 toggles')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重置失敗：$e')),
      );
    }
  }

  Future<void> _setGlobalEnabled(bool v) async {
    try {
      await _ref.set({
        'enabled': v,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(v ? '已啟用功能開關模組' : '已停用功能開關模組')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失敗：$e')),
      );
    }
  }

  Future<void> _patchToggleByKey(String key, Map<String, dynamic> patch) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_ref);
      final data = snap.data() ?? <String, dynamic>{};

      final toggles = _parseToggles(data['toggles']).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      final idx = toggles.indexWhere((e) => e.key == key);
      if (idx < 0) return;

      toggles[idx] = toggles[idx].copyWithFromPatch(patch);

      // 保守：重新編號 order，避免排序混亂
      toggles.sort((a, b) => a.order.compareTo(b.order));
      for (int i = 0; i < toggles.length; i++) {
        toggles[i] = toggles[i].copyWith(order: i);
      }

      tx.set(_ref, {
        'toggles': toggles.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _deleteToggle(String key) async {
    final ok = await _confirm(
      title: '刪除 Toggle',
      message: '確定刪除該 Toggle？\nkey: $key\n此操作無法復原。',
      confirmText: '刪除',
      danger: true,
    );
    if (ok != true) return;

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_ref);
        final data = snap.data() ?? <String, dynamic>{};

        final toggles = _parseToggles(data['toggles']).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        toggles.removeWhere((e) => e.key == key);

        for (int i = 0; i < toggles.length; i++) {
          toggles[i] = toggles[i].copyWith(order: i);
        }

        tx.set(_ref, {
          'toggles': toggles.map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已刪除 Toggle')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗：$e')),
      );
    }
  }

  /// ✅ 平面清單排序：即使有搜尋，也只調整「搜尋命中項目」的相對順序，
  /// 並保持其他項目在全量清單中的位置不變（專業且穩定的做法）。
  Future<void> _reorderAll(List<FeatureToggle> currentFiltered, int oldIndex, int newIndex) async {
    if (currentFiltered.length < 2) return;

    // 先在本地做 reorder（以 key 為準）
    final keys = currentFiltered.map((e) => e.key).toList();
    if (newIndex > oldIndex) newIndex--;
    final movedKey = keys.removeAt(oldIndex);
    keys.insert(newIndex, movedKey);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_ref);
      final data = snap.data() ?? <String, dynamic>{};

      final all = _parseToggles(data['toggles']).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      final byKey = <String, FeatureToggle>{for (final t in all) t.key: t};

      // 找到全量中，filtered 項目的位置
      final filteredSet = keys.toSet();
      final positions = <int>[];
      for (int i = 0; i < all.length; i++) {
        if (filteredSet.contains(all[i].key)) positions.add(i);
      }
      if (positions.length < 2) return;

      // 以最新資料（byKey）重建 reordered toggles
      final reordered = <FeatureToggle>[];
      for (final k in keys) {
        final t = byKey[k];
        if (t != null) reordered.add(t);
      }

      // 將 reordered 依序填回 positions（保持非命中項目位置不變）
      final rebuilt = all.toList();
      for (int i = 0; i < positions.length && i < reordered.length; i++) {
        rebuilt[positions[i]] = reordered[i];
      }

      // 重編 order
      for (int i = 0; i < rebuilt.length; i++) {
        rebuilt[i] = rebuilt[i].copyWith(order: i);
      }

      tx.set(_ref, {
        'toggles': rebuilt.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('排序已更新')),
    );
  }

  /// ✅ 群組內排序：只調整同 group 的相對順序，其他群組位置不變
  Future<void> _reorderWithinGroup(
    String group,
    List<FeatureToggle> groupList,
    int oldIndex,
    int newIndex,
  ) async {
    if (groupList.length < 2) return;

    final keys = groupList.map((e) => e.key).toList();
    if (newIndex > oldIndex) newIndex--;
    final movedKey = keys.removeAt(oldIndex);
    keys.insert(newIndex, movedKey);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_ref);
      final data = snap.data() ?? <String, dynamic>{};

      final all = _parseToggles(data['toggles']).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      final byKey = <String, FeatureToggle>{for (final t in all) t.key: t};

      final positions = <int>[];
      for (int i = 0; i < all.length; i++) {
        if (all[i].group == group) positions.add(i);
      }
      if (positions.length < 2) return;

      final reordered = <FeatureToggle>[];
      for (final k in keys) {
        final t = byKey[k];
        if (t != null) reordered.add(t);
      }

      final rebuilt = all.toList();
      for (int i = 0; i < positions.length && i < reordered.length; i++) {
        rebuilt[positions[i]] = reordered[i];
      }

      for (int i = 0; i < rebuilt.length; i++) {
        rebuilt[i] = rebuilt[i].copyWith(order: i);
      }

      tx.set(_ref, {
        'toggles': rebuilt.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('群組內排序已更新')),
    );
  }

  // ============================================================
  // Add/Edit dialog
  // ============================================================

  Future<void> _openEditDialog({required bool isNew, FeatureToggle? initial}) async {
    final seed = initial ??
        FeatureToggle(
          key: 'toggle_${DateTime.now().millisecondsSinceEpoch}',
          title: '新功能',
          description: '',
          group: 'General',
          enabled: true,
          requiresAuth: false,
          rolloutPercent: 100,
          minAppVersion: '',
          platforms: const ['android', 'ios', 'web'],
          order: 9999,
        );

    final keyCtrl = TextEditingController(text: seed.key);
    final titleCtrl = TextEditingController(text: seed.title);
    final descCtrl = TextEditingController(text: seed.description);
    final groupCtrl = TextEditingController(text: seed.group);
    final minVerCtrl = TextEditingController(text: seed.minAppVersion);

    bool enabled = seed.enabled;
    bool requiresAuth = seed.requiresAuth;
    int rollout = seed.rolloutPercent.clamp(0, 100);

    bool pAndroid = seed.platforms.contains('android');
    bool pIos = seed.platforms.contains('ios');
    bool pWeb = seed.platforms.contains('web');

    bool? ok;
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (_) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              return AlertDialog(
                title: Text(isNew ? '新增 Toggle' : '編輯 Toggle',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: keyCtrl,
                          enabled: isNew, // ✅ 新增可改 key；編輯鎖定 key
                          decoration: const InputDecoration(
                            labelText: 'key（唯一）',
                            helperText: '建議小寫底線：checkout_enabled / lottery_enabled',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(labelText: '標題（title）'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: descCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: '描述（description）'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: groupCtrl,
                          decoration: const InputDecoration(
                            labelText: '群組（group）',
                            helperText: '例如：Shop / Marketing / SOS / General',
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('啟用', style: TextStyle(fontWeight: FontWeight.w800)),
                          value: enabled,
                          onChanged: (v) => setLocal(() => enabled = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('需要登入（requiresAuth）',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          value: requiresAuth,
                          onChanged: (v) => setLocal(() => requiresAuth = v),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('灰度比例（rolloutPercent）：$rollout%',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        Slider(
                          value: rollout.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '$rollout%',
                          onChanged: (v) => setLocal(() => rollout = v.round()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: minVerCtrl,
                          decoration: const InputDecoration(
                            labelText: '最低版本（minAppVersion，可留空）',
                            helperText: '例如：1.2.0（App 端可自行解析）',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('平台（platforms）',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('Android'),
                              selected: pAndroid,
                              onSelected: (v) => setLocal(() => pAndroid = v),
                            ),
                            FilterChip(
                              label: const Text('iOS'),
                              selected: pIos,
                              onSelected: (v) => setLocal(() => pIos = v),
                            ),
                            FilterChip(
                              label: const Text('Web'),
                              selected: pWeb,
                              onSelected: (v) => setLocal(() => pWeb = v),
                            ),
                          ],
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
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('儲存'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // ✅ 不論取消或儲存，都確保釋放 controller
      //（避免在多次開啟 dialog 時造成 memory leak）
      // ignore: unused_local_variable
      final _ = ok;
    }

    if (ok != true) {
      keyCtrl.dispose();
      titleCtrl.dispose();
      descCtrl.dispose();
      groupCtrl.dispose();
      minVerCtrl.dispose();
      return;
    }

    final key = keyCtrl.text.trim();
    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    final group = groupCtrl.text.trim().isEmpty ? 'General' : groupCtrl.text.trim();
    final minVer = minVerCtrl.text.trim();

    if (key.isEmpty || title.isEmpty) {
      keyCtrl.dispose();
      titleCtrl.dispose();
      descCtrl.dispose();
      groupCtrl.dispose();
      minVerCtrl.dispose();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('key / title 不可為空')),
      );
      return;
    }

    // 若全不選，預設視為全平台
    final platforms = <String>[
      if (pAndroid) 'android',
      if (pIos) 'ios',
      if (pWeb) 'web',
    ];
    final finalPlatforms = platforms.isEmpty ? const ['android', 'ios', 'web'] : platforms;

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_ref);
        final data = snap.data() ?? <String, dynamic>{};

        final toggles = _parseToggles(data['toggles']).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        if (isNew && toggles.any((e) => e.key == key)) {
          throw StateError('key 已存在：$key');
        }

        if (isNew) {
          final nextOrder =
              toggles.isEmpty ? 0 : (toggles.map((e) => e.order).reduce(_max) + 1);
          toggles.add(
            FeatureToggle(
              key: key,
              title: title,
              description: desc,
              group: group,
              enabled: enabled,
              requiresAuth: requiresAuth,
              rolloutPercent: rollout,
              minAppVersion: minVer,
              platforms: finalPlatforms,
              order: nextOrder,
            ),
          );
        } else {
          final idx = toggles.indexWhere((e) => e.key == seed.key);
          if (idx < 0) return;
          final old = toggles[idx];
          toggles[idx] = old.copyWith(
            title: title,
            description: desc,
            group: group,
            enabled: enabled,
            requiresAuth: requiresAuth,
            rolloutPercent: rollout,
            minAppVersion: minVer,
            platforms: finalPlatforms,
          );
        }

        toggles.sort((a, b) => a.order.compareTo(b.order));
        for (int i = 0; i < toggles.length; i++) {
          toggles[i] = toggles[i].copyWith(order: i);
        }

        tx.set(_ref, {
          'enabled': (data['enabled'] == true) || (_defaults['enabled'] == true),
          'toggles': toggles.map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNew ? '已新增 Toggle' : '已更新 Toggle')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$e')),
      );
    } finally {
      keyCtrl.dispose();
      titleCtrl.dispose();
      descCtrl.dispose();
      groupCtrl.dispose();
      minVerCtrl.dispose();
    }
  }

  // ============================================================
  // Export JSON
  // ============================================================

  Future<void> _exportJson() async {
    try {
      final snap = await _ref.get();
      final data = snap.data() ?? <String, dynamic>{};

      final safe = _jsonSafe({
        'enabled': data['enabled'] == true,
        'toggles': (data['toggles'] is List) ? data['toggles'] : [],
        'updatedAt': data['updatedAt'],
      });

      final pretty = const JsonEncoder.withIndent('  ').convert(safe);

      await Clipboard.setData(ClipboardData(text: pretty));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已複製 JSON 到剪貼簿')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('匯出失敗：$e')),
      );
    }
  }

  static dynamic _jsonSafe(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is DateTime) return v.toIso8601String();
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _jsonSafe(val)));
    }
    if (v is List) {
      return v.map(_jsonSafe).toList();
    }
    return v;
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
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
              backgroundColor: danger ? cs.error : null,
              foregroundColor: danger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Parse utils
  // ============================================================

  Iterable<FeatureToggle> _parseToggles(dynamic raw) sync* {
    if (raw is! List) return;
    for (final e in raw) {
      if (e is Map) {
        yield FeatureToggle.fromMap(e.map((k, v) => MapEntry(k.toString(), v)));
      }
    }
  }

  static int _max(int a, int b) => a > b ? a : b;

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}

// ============================================================
// Model
// ============================================================

class FeatureToggle {
  final String key;
  final String title;
  final String description;
  final String group;
  final bool enabled;
  final bool requiresAuth;
  final int rolloutPercent; // 0~100
  final String minAppVersion;
  final List<String> platforms; // android/ios/web
  final int order;

  const FeatureToggle({
    required this.key,
    required this.title,
    required this.description,
    required this.group,
    required this.enabled,
    required this.requiresAuth,
    required this.rolloutPercent,
    required this.minAppVersion,
    required this.platforms,
    required this.order,
  });

  FeatureToggle copyWith({
    String? key,
    String? title,
    String? description,
    String? group,
    bool? enabled,
    bool? requiresAuth,
    int? rolloutPercent,
    String? minAppVersion,
    List<String>? platforms,
    int? order,
  }) {
    return FeatureToggle(
      key: key ?? this.key,
      title: title ?? this.title,
      description: description ?? this.description,
      group: group ?? this.group,
      enabled: enabled ?? this.enabled,
      requiresAuth: requiresAuth ?? this.requiresAuth,
      rolloutPercent: rolloutPercent ?? this.rolloutPercent,
      minAppVersion: minAppVersion ?? this.minAppVersion,
      platforms: platforms ?? this.platforms,
      order: order ?? this.order,
    );
  }

  FeatureToggle copyWithFromPatch(Map<String, dynamic> patch) {
    return copyWith(
      title: patch.containsKey('title') ? (patch['title'] ?? '').toString() : null,
      description: patch.containsKey('description')
          ? (patch['description'] ?? '').toString()
          : null,
      group: patch.containsKey('group') ? (patch['group'] ?? '').toString() : null,
      enabled: patch.containsKey('enabled') ? (patch['enabled'] == true) : null,
      requiresAuth:
          patch.containsKey('requiresAuth') ? (patch['requiresAuth'] == true) : null,
      rolloutPercent: patch.containsKey('rolloutPercent')
          ? _asInt(patch['rolloutPercent']).clamp(0, 100)
          : null,
      minAppVersion: patch.containsKey('minAppVersion')
          ? (patch['minAppVersion'] ?? '').toString()
          : null,
      platforms:
          patch.containsKey('platforms') ? _asStringList(patch['platforms']) : null,
      order: patch.containsKey('order') ? _asInt(patch['order']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'key': key,
        'title': title,
        'description': description,
        'group': group,
        'enabled': enabled,
        'requiresAuth': requiresAuth,
        'rolloutPercent': rolloutPercent,
        'minAppVersion': minAppVersion,
        'platforms': platforms,
        'order': order,
      };

  factory FeatureToggle.fromMap(Map<String, dynamic> m) {
    return FeatureToggle(
      key: (m['key'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      group: (m['group'] ?? 'General').toString(),
      enabled: m['enabled'] == true,
      requiresAuth: m['requiresAuth'] == true,
      rolloutPercent: _asInt(m['rolloutPercent']).clamp(0, 100),
      minAppVersion: (m['minAppVersion'] ?? '').toString(),
      platforms: _asStringList(m['platforms']),
      order: _asInt(m['order']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '0').toString()) ?? 0;
    // ignore: dead_code
  }

  static List<String> _asStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    }
    return const <String>['android', 'ios', 'web'];
  }
}

// ============================================================
// UI widgets
// ============================================================

class _HeaderCard extends StatelessWidget {
  final bool exists;
  final bool globalEnabled;
  final String updatedText;
  final VoidCallback? onInit;
  final ValueChanged<bool> onToggleGlobal;

  const _HeaderCard({
    required this.exists,
    required this.globalEnabled,
    required this.updatedText,
    required this.onInit,
    required this.onToggleGlobal,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.tune_outlined, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exists ? '功能開關設定已建立' : '尚未建立設定文件',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '更新時間：$updatedText',
                    style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (!exists && onInit != null)
              FilledButton.tonalIcon(
                onPressed: onInit,
                icon: const Icon(Icons.add),
                label: const Text('初始化設定文件'),
              ),
            if (exists) ...[
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    globalEnabled ? '啟用中' : '停用',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: globalEnabled ? Colors.green.shade800 : cs.onSurfaceVariant,
                    ),
                  ),
                  Switch(value: globalEnabled, onChanged: onToggleGlobal),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!,
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: '搜尋 key / title / description / group',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final bool globalEnabled;
  final List<FeatureToggle> toggles;
  final Future<void> Function(String key, Map<String, dynamic> patch) onPatch;

  const _QuickCard({
    required this.globalEnabled,
    required this.toggles,
    required this.onPatch,
  });

  FeatureToggle? _find(String key) {
    try {
      return toggles.firstWhere((e) => e.key == key);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final tShop = _find('shop_enabled');
    final tCheckout = _find('checkout_enabled');
    final tPayment = _find('payment_enabled');
    final tLottery = _find('lottery_enabled');

    Widget row(String title, FeatureToggle? t) {
      final enabled = t?.enabled == true;
      return Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          Text(
            !globalEnabled ? '（全域停用）' : (enabled ? '啟用' : '停用'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: !globalEnabled
                  ? cs.onSurfaceVariant
                  : (enabled ? Colors.green.shade800 : cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: enabled && globalEnabled,
            onChanged: (!globalEnabled || t == null) ? null : (v) => onPatch(t.key, {'enabled': v}),
          ),
        ],
      );
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            row('商城模組', tShop),
            const Divider(height: 18),
            row('下單 / 結帳', tCheckout),
            row('付款流程', tPayment),
            const Divider(height: 18),
            row('活動抽獎', tLottery),
          ],
        ),
      ),
    );
  }
}

class _FlatReorderList extends StatelessWidget {
  final List<FeatureToggle> toggles;
  final void Function(FeatureToggle t) onEdit;
  final void Function(FeatureToggle t) onDelete;
  final void Function(FeatureToggle t, bool v) onToggleEnabled;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _FlatReorderList({
    required this.toggles,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleEnabled,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: toggles.length,
      onReorder: onReorder,
      itemBuilder: (context, i) {
        final t = toggles[i];
        return _ToggleTile(
          key: ValueKey(t.key),
          t: t,
          onEdit: () => onEdit(t),
          onDelete: () => onDelete(t),
          onToggleEnabled: (v) => onToggleEnabled(t, v),
          dragHandle: ReorderableDragStartListener(
            index: i,
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.drag_handle),
            ),
          ),
        );
      },
    );
  }
}

class _GroupedList extends StatelessWidget {
  final List<FeatureToggle> toggles;
  final void Function(FeatureToggle t) onEdit;
  final void Function(FeatureToggle t) onDelete;
  final void Function(FeatureToggle t, bool v) onToggleEnabled;
  final Future<void> Function(String group, List<FeatureToggle> groupList, int oldIndex, int newIndex)
      onReorderWithin;

  const _GroupedList({
    required this.toggles,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleEnabled,
    required this.onReorderWithin,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<FeatureToggle>>{};
    for (final t in toggles) {
      groups.putIfAbsent(t.group, () => []).add(t);
    }

    final orderedGroupKeys = groups.keys.toList()..sort();

    return Column(
      children: [
        for (final g in orderedGroupKeys) ...[
          _GroupHeader(group: g, count: groups[g]!.length),
          const SizedBox(height: 6),
          _GroupReorderList(
            group: g,
            list: (groups[g]!..sort((a, b) => a.order.compareTo(b.order))),
            onEdit: onEdit,
            onDelete: onDelete,
            onToggleEnabled: onToggleEnabled,
            onReorderWithin: onReorderWithin,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String group;
  final int count;

  const _GroupHeader({required this.group, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(group,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _GroupReorderList extends StatelessWidget {
  final String group;
  final List<FeatureToggle> list;
  final void Function(FeatureToggle t) onEdit;
  final void Function(FeatureToggle t) onDelete;
  final void Function(FeatureToggle t, bool v) onToggleEnabled;
  final Future<void> Function(String group, List<FeatureToggle> groupList, int oldIndex, int newIndex)
      onReorderWithin;

  const _GroupReorderList({
    required this.group,
    required this.list,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleEnabled,
    required this.onReorderWithin,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: list.length,
      onReorder: (oldIndex, newIndex) => onReorderWithin(group, list, oldIndex, newIndex),
      itemBuilder: (context, i) {
        final t = list[i];
        return _ToggleTile(
          key: ValueKey('${group}_${t.key}'),
          t: t,
          onEdit: () => onEdit(t),
          onDelete: () => onDelete(t),
          onToggleEnabled: (v) => onToggleEnabled(t, v),
          dragHandle: ReorderableDragStartListener(
            index: i,
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.drag_handle),
            ),
          ),
        );
      },
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final FeatureToggle t;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleEnabled;
  final Widget dragHandle;

  const _ToggleTile({
    required super.key,
    required this.t,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleEnabled,
    required this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final pillBg = t.enabled ? Colors.green.shade100 : Colors.grey.shade200;
    final pillFg = t.enabled ? Colors.green.shade900 : cs.onSurfaceVariant;

    final isNarrow = MediaQuery.of(context).size.width < 520;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: t.enabled ? cs.primaryContainer : Colors.grey.shade200,
          child: Icon(
            Icons.toggle_on_outlined,
            color: t.enabled ? cs.onPrimaryContainer : Colors.grey.shade600,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                t.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                t.enabled ? '啟用' : '停用',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: pillFg),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${t.key}  •  group=${t.group}  •  auth=${t.requiresAuth ? "Y" : "N"}  •  rollout=${t.rolloutPercent}%'
          '${t.minAppVersion.isNotEmpty ? "  •  min=${t.minAppVersion}" : ""}'
          '${t.platforms.isNotEmpty ? "  •  ${t.platforms.join(",")}" : ""}'
          '\n${t.description.isEmpty ? "（無描述）" : t.description}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, height: 1.25),
        ),
        // ✅ 修正：避免 Row overflow（窄螢幕改用更多選單，寬螢幕保留完整按鈕）
        trailing: isNarrow
            ? SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    dragHandle,
                    Switch(value: t.enabled, onChanged: onToggleEnabled),
                    PopupMenuButton<String>(
                      tooltip: '更多',
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 10),
                              Text('編輯'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: cs.error),
                              const SizedBox(width: 10),
                              Text('刪除', style: TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : SizedBox(
                width: 178,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    dragHandle,
                    Switch(value: t.enabled, onChanged: onToggleEnabled),
                    IconButton(
                      tooltip: '編輯',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      tooltip: '刪除',
                      icon: Icon(Icons.delete_outline, color: cs.error),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
        onTap: onEdit,
      ),
    );
  }
}

// ============================================================
// Error View
// ============================================================

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? hint;

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
        constraints: const BoxConstraints(maxWidth: 720),
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
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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

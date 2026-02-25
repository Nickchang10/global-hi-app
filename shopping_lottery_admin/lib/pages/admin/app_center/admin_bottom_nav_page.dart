import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminBottomNavPage extends StatefulWidget {
  const AdminBottomNavPage({super.key});

  @override
  State<AdminBottomNavPage> createState() => _AdminBottomNavPageState();
}

class _AdminBottomNavPageState extends State<AdminBottomNavPage> {
  /// ✅ 前台與後台「必須」用同一份 doc，才叫串接
  /// 建議固定：app_config/bottom_nav
  final DocumentReference<Map<String, dynamic>> _docRef = FirebaseFirestore
      .instance
      .collection('app_config')
      .doc('bottom_nav');

  @override
  void initState() {
    super.initState();
    _ensureDefaults();
  }

  List<_BottomNavItem> _defaultFiveItems() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      _BottomNavItem(
        id: 'home_$now',
        label: '首頁',
        route: '/home',
        iconKey: 'home',
        enabled: true,
        order: 0,
      ),
      _BottomNavItem(
        id: 'shop_${now + 1}',
        label: '商城',
        route: '/shop',
        iconKey: 'store',
        enabled: true,
        order: 1,
      ),
      _BottomNavItem(
        id: 'task_${now + 2}',
        label: '任務',
        route: '/tasks',
        iconKey: 'task',
        enabled: true,
        order: 2,
      ),
      _BottomNavItem(
        id: 'interaction_${now + 3}',
        label: '互動',
        route: '/interaction',
        iconKey: 'group',
        enabled: true,
        order: 3,
      ),
      _BottomNavItem(
        id: 'me_${now + 4}',
        label: '我的',
        route: '/me',
        iconKey: 'person',
        enabled: true,
        order: 4,
      ),
    ];
  }

  Future<void> _ensureDefaults() async {
    try {
      final snap = await _docRef.get();
      final data = snap.data();
      final enabled = (data?['enabled'] as bool?) ?? true;
      final rawItems = data?['items'];

      // ✅ prefer_is_not_operator + unnecessary_cast 一次處理：
      //    不用 (!(rawItems is List))，也不要 (rawItems as List)
      final itemsEmpty = rawItems is! List || rawItems.isEmpty;

      // ✅ doc 不存在 OR items 空，都補預設（避免你現在畫面空白）
      if (!snap.exists || itemsEmpty) {
        await _docRef.set({
          'enabled': enabled,
          'items': _defaultFiveItems().map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // 這裡不直接噴錯 UI，避免 initState 時干擾畫面
    }
  }

  List<_BottomNavItem> _parseItems(List<dynamic>? raw) {
    final list = <_BottomNavItem>[];
    if (raw == null) return list;

    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        list.add(_BottomNavItem.fromMap(e));
      } else if (e is Map) {
        list.add(_BottomNavItem.fromMap(Map<String, dynamic>.from(e)));
      }
    }
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  Future<void> _saveConfig({
    required bool enabled,
    required List<_BottomNavItem> items,
  }) async {
    final sorted = [...items]..sort((a, b) => a.order.compareTo(b.order));
    await _docRef.set({
      'enabled': enabled,
      'items': sorted.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<_BottomNavItem?> _showEditDialog(
    BuildContext context, {
    _BottomNavItem? initial,
  }) async {
    final labelCtrl = TextEditingController(text: initial?.label ?? '');
    final routeCtrl = TextEditingController(text: initial?.route ?? '');

    String iconKey = initial?.iconKey ?? 'home';
    bool enabled = initial?.enabled ?? true;

    return showDialog<_BottomNavItem?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(initial == null ? '新增底部導覽項目' : '編輯底部導覽項目'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(
                        labelText: '標題（label）',
                        hintText: '例如：首頁 / 商城 / 任務 / 互動 / 我的',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: routeCtrl,
                      decoration: const InputDecoration(
                        labelText: '路由（route）',
                        hintText: '例如：/home /shop /tasks /interaction /me',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _IconPicker(
                      value: iconKey,
                      onChanged: (v) => setStateDialog(() => iconKey = v),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      onChanged: (v) => setStateDialog(() => enabled = v),
                      title: const Text('啟用此項目'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final label = labelCtrl.text.trim();
                    final route = routeCtrl.text.trim();
                    if (label.isEmpty || route.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('label 與 route 不能為空')),
                      );
                      return;
                    }

                    final id =
                        initial?.id ??
                        'item_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

                    Navigator.of(ctx).pop(
                      _BottomNavItem(
                        id: id,
                        label: label,
                        route: route,
                        iconKey: iconKey,
                        enabled: enabled,
                        order: initial?.order ?? 999,
                      ),
                    );
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _docRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('底部導覽管理')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data?.data() ?? <String, dynamic>{};
        final enabled = (data['enabled'] as bool?) ?? true;
        final items = _parseItems(data['items'] as List<dynamic>?);

        final enabledItems = items.where((e) => e.enabled).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        final needMinTwo = enabled && enabledItems.length < 2;

        return Scaffold(
          appBar: AppBar(
            title: const Text('底部導覽管理'),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  // ✅ 一鍵套用預設 5 項，讓你立刻看到「串接」效果
                  await _saveConfig(
                    enabled: enabled,
                    items: _defaultFiveItems(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已套用預設 5 項')));
                  }
                },
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('套用預設'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  final created = await _showEditDialog(context);
                  if (created == null) return;

                  final maxOrder = items.isEmpty
                      ? -1
                      : items.map((e) => e.order).reduce(max);
                  final newItem = created.copyWith(order: maxOrder + 1);

                  await _saveConfig(
                    enabled: enabled,
                    items: [...items, newItem],
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('新增'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: enabled,
                                onChanged: (v) =>
                                    _saveConfig(enabled: v, items: items),
                                title: const Text('啟用底部導覽'),
                                subtitle: const Text(
                                  '啟用時至少要有 2 個啟用項目，避免 BottomNavigationBar assert',
                                ),
                              ),
                              if (needMinTwo)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '啟用底部導覽時，至少要有 2 個「啟用」項目。',
                                          style: TextStyle(
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          child: items.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('尚未設定任何項目，請按右上角「新增」或「套用預設」'),
                                  ),
                                )
                              : ReorderableListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: items.length,
                                  onReorder: (oldIndex, newIndex) async {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final list = [...items];
                                    final moved = list.removeAt(oldIndex);
                                    list.insert(newIndex, moved);

                                    final reOrdered = <_BottomNavItem>[];
                                    for (int i = 0; i < list.length; i++) {
                                      reOrdered.add(list[i].copyWith(order: i));
                                    }
                                    await _saveConfig(
                                      enabled: enabled,
                                      items: reOrdered,
                                    );
                                  },
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return ListTile(
                                      key: ValueKey(item.id),
                                      leading: Checkbox(
                                        value: item.enabled,
                                        onChanged: (v) async {
                                          final list = items
                                              .map(
                                                (e) => e.id == item.id
                                                    ? e.copyWith(
                                                        enabled: v ?? false,
                                                      )
                                                    : e,
                                              )
                                              .toList();
                                          await _saveConfig(
                                            enabled: enabled,
                                            items: list,
                                          );
                                        },
                                      ),
                                      title: Row(
                                        children: [
                                          Icon(_iconFromKey(item.iconKey)),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(item.label)),
                                        ],
                                      ),
                                      subtitle: Text(item.route),
                                      trailing: Wrap(
                                        spacing: 6,
                                        children: [
                                          IconButton(
                                            tooltip: '編輯',
                                            onPressed: () async {
                                              final edited =
                                                  await _showEditDialog(
                                                    context,
                                                    initial: item,
                                                  );
                                              if (edited == null) return;
                                              final list = items
                                                  .map(
                                                    (e) => e.id == item.id
                                                        ? edited.copyWith(
                                                            order: e.order,
                                                          )
                                                        : e,
                                                  )
                                                  .toList();
                                              await _saveConfig(
                                                enabled: enabled,
                                                items: list,
                                              );
                                            },
                                            icon: const Icon(Icons.edit),
                                          ),
                                          IconButton(
                                            tooltip: '刪除',
                                            onPressed: () async {
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('刪除項目'),
                                                  content: Text(
                                                    '確定要刪除「${item.label}」嗎？',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                      child: const Text('取消'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                      child: const Text('刪除'),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (ok != true) return;
                                              final list = items
                                                  .where((e) => e.id != item.id)
                                                  .toList();

                                              final reOrdered =
                                                  <_BottomNavItem>[];
                                              for (
                                                int i = 0;
                                                i < list.length;
                                                i++
                                              ) {
                                                reOrdered.add(
                                                  list[i].copyWith(order: i),
                                                );
                                              }
                                              await _saveConfig(
                                                enabled: enabled,
                                                items: reOrdered,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: _PreviewCard(enabled: enabled, items: items),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreviewCard extends StatefulWidget {
  final bool enabled;
  final List<_BottomNavItem> items;

  const _PreviewCard({required this.enabled, required this.items});

  @override
  State<_PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<_PreviewCard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final enabledItems = widget.items.where((e) => e.enabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final canBuild = widget.enabled && enabledItems.length >= 2;

    if (!canBuild) {
      final reason = !widget.enabled
          ? '目前「底部導覽」已關閉'
          : '目前啟用項目只有 ${enabledItems.length} 個（至少要 2 個）';
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '預覽',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(reason, style: const TextStyle(color: Colors.orange)),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('預覽暫停（避免 BottomNavigationBar assert）'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_index >= enabledItems.length) _index = 0;

    final navItems = enabledItems
        .map(
          (e) => BottomNavigationBarItem(
            icon: Icon(_iconFromKey(e.iconKey)),
            label: e.label,
          ),
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '預覽',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          '目前選中：${enabledItems[_index].label}\nroute: ${enabledItems[_index].route}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    BottomNavigationBar(
                      type: BottomNavigationBarType.fixed,
                      items: navItems,
                      currentIndex: _index,
                      onTap: (i) => setState(() => _index = i),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _IconPicker({required this.value, required this.onChanged});

  static const _keys = <String>[
    'home',
    'store',
    'task',
    'group',
    'person',
    'shopping_bag',
    'favorite',
    'notifications',
    'support',
    'settings',
  ];

  @override
  Widget build(BuildContext context) {
    // ✅ DropdownButtonFormField 的 value 已 deprecated → 改 initialValue
    final initial = _keys.contains(value) ? value : 'home';

    return DropdownButtonFormField<String>(
      initialValue: initial,
      decoration: const InputDecoration(labelText: 'Icon'),
      items: _keys
          .map(
            (k) => DropdownMenuItem(
              value: k,
              child: Row(
                children: [
                  Icon(_iconFromKey(k)),
                  const SizedBox(width: 8),
                  Text(k),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _BottomNavItem {
  final String id;
  final String label;
  final String route;
  final String iconKey;
  final bool enabled;
  final int order;

  const _BottomNavItem({
    required this.id,
    required this.label,
    required this.route,
    required this.iconKey,
    required this.enabled,
    required this.order,
  });

  _BottomNavItem copyWith({
    String? id,
    String? label,
    String? route,
    String? iconKey,
    bool? enabled,
    int? order,
  }) {
    return _BottomNavItem(
      id: id ?? this.id,
      label: label ?? this.label,
      route: route ?? this.route,
      iconKey: iconKey ?? this.iconKey,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'route': route,
    'iconKey': iconKey,
    'enabled': enabled,
    'order': order,
  };

  static _BottomNavItem fromMap(Map<String, dynamic> m) {
    return _BottomNavItem(
      id: (m['id'] ?? '').toString(),
      label: (m['label'] ?? '').toString(),
      route: (m['route'] ?? '').toString(),
      iconKey: (m['iconKey'] ?? 'home').toString(),
      enabled: (m['enabled'] as bool?) ?? true,
      order: (m['order'] as int?) ?? 0,
    );
  }
}

IconData _iconFromKey(String key) {
  switch (key) {
    case 'home':
      return Icons.home;
    case 'store':
      return Icons.store;
    case 'task':
      return Icons.task_alt;
    case 'group':
      return Icons.group;
    case 'person':
      return Icons.person;
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'favorite':
      return Icons.favorite;
    case 'notifications':
      return Icons.notifications;
    case 'support':
      return Icons.support_agent;
    case 'settings':
      return Icons.settings;
    default:
      return Icons.circle;
  }
}

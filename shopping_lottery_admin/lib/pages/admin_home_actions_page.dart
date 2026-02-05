// lib/pages/admin_home_actions_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/auth_service.dart';

class AdminHomeActionsPage extends StatefulWidget {
  const AdminHomeActionsPage({super.key});

  @override
  State<AdminHomeActionsPage> createState() => _AdminHomeActionsPageState();
}

class _AdminHomeActionsPageState extends State<AdminHomeActionsPage> {
  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  bool _savingOrder = false;
  bool _isReordering = false;

  // 使用本地清單做「樂觀更新」，避免拖曳後畫面立刻跳回去
  List<_HomeActionItem> _items = [];

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final authSvc = context.read<AuthService>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        if (_roleFuture == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _roleFuture = gate.ensureAndGetRole(user, forceRefresh: false);
        }

        return FutureBuilder<RoleInfo>(
          future: _roleFuture,
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (roleSnap.hasError) {
              return _SimpleErrorPage(
                title: '讀取角色失敗',
                message: '${roleSnap.error}',
                onRetry: () {
                  setState(() {
                    gate.clearCache();
                    _roleFuture = gate.ensureAndGetRole(user, forceRefresh: true);
                  });
                },
                onLogout: () async {
                  gate.clearCache();
                  await authSvc.signOut();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
              );
            }

            final role = (roleSnap.data?.role ?? '').toString().trim().toLowerCase();
            if (role != 'admin') {
              return _SimpleErrorPage(
                title: '需要 Admin 權限',
                message: '目前角色：$role',
                onRetry: () {
                  setState(() {
                    gate.clearCache();
                    _roleFuture = gate.ensureAndGetRole(user, forceRefresh: true);
                  });
                },
                onLogout: () async {
                  gate.clearCache();
                  await authSvc.signOut();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
              );
            }

            return _buildAdminPage(context);
          },
        );
      },
    );
  }

  Widget _buildAdminPage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final query = FirebaseFirestore.instance.collection('home_actions');

    return Scaffold(
      appBar: AppBar(
        title: const Text('首頁快捷功能（簡單版）'),
        actions: [
          IconButton(
            tooltip: '新增快捷功能',
            onPressed: () => _openEditDialog(context, item: null),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: '建立預設 4 個快捷',
            onPressed: _savingOrder ? null : () => _seedDefaults(context),
            icon: const Icon(Icons.auto_awesome),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final incoming = snap.data!.docs.map((d) => _HomeActionItem.fromDoc(d)).toList();

          // 排序：以 order 為主，未設定的放最後，再用 title 穩定排序
          incoming.sort((a, b) {
            final ao = a.order ?? 999999;
            final bo = b.order ?? 999999;
            final c = ao.compareTo(bo);
            if (c != 0) return c;
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });

          // snapshot 更新時：若不是正在 reorder，就用最新資料覆蓋本地 _items
          if (!_isReordering) {
            _items = incoming;
          }

          if (_items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('目前沒有快捷功能', style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _savingOrder ? null : () => _seedDefaults(context),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('一鍵建立預設 4 個'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '拖曳右側手把排序；點鉛筆編輯；右側開關啟用/停用。',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ✅ ReorderableListView（包在 SizedBox + shrinkWrap）
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                onReorder: _savingOrder ? (_, __) {} : (oldIndex, newIndex) => _onReorder(context, oldIndex, newIndex),
                proxyDecorator: (child, index, animation) {
                  return Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  );
                },
                itemBuilder: (context, i) {
                  final it = _items[i];

                  return Card(
                    key: ValueKey(it.id),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_IconMap.fromName(it.icon), color: cs.primary),
                      ),
                      title: Text(
                        it.title.isEmpty ? '（未命名）' : it.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        'route: ${it.route.isEmpty ? '-' : it.route}\nrole: ${it.role}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: it.isActive,
                            onChanged: _savingOrder
                                ? null
                                : (v) async {
                                    await it.ref.set({'isActive': v}, SetOptions(merge: true));
                                  },
                          ),
                          IconButton(
                            tooltip: '編輯',
                            onPressed: _savingOrder ? null : () => _openEditDialog(context, item: it),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            enabled: !_savingOrder,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),
              if (_savingOrder)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('儲存排序中…'),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onReorder(BuildContext context, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    if (newIndex < 0 || newIndex >= _items.length) return;

    setState(() {
      _isReordering = true;
      final moved = _items.removeAt(oldIndex);
      _items.insert(newIndex, moved);
      _savingOrder = true;
    });

    try {
      // 依目前順序寫回 order（1..n）
      final batch = FirebaseFirestore.instance.batch();
      for (var i = 0; i < _items.length; i++) {
        batch.set(_items[i].ref, {'order': i + 1}, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存排序失敗：$e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _savingOrder = false;
        _isReordering = false;
      });
    }
  }

  Future<void> _seedDefaults(BuildContext context) async {
    final col = FirebaseFirestore.instance.collection('home_actions');

    // 若已有資料，就不重複塞（避免越塞越多）
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已存在快捷功能，不再建立預設資料。')));
      return;
    }

    setState(() => _savingOrder = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 預設四個
      final defaults = [
        {
          'title': '商品管理',
          'icon': 'inventory_2_outlined',
          'route': '/products',
          'role': 'all',
          'order': 1,
          'isActive': true,
        },
        {
          'title': '訂單管理',
          'icon': 'receipt_long_outlined',
          'route': '/orders',
          'role': 'all',
          'order': 2,
          'isActive': true,
        },
        {
          'title': '公告管理',
          'icon': 'campaign_outlined',
          'route': '/announcements',
          'role': 'admin',
          'order': 3,
          'isActive': true,
        },
        {
          'title': '通知中心',
          'icon': 'notifications_outlined',
          'route': '/notifications',
          'role': 'all',
          'order': 4,
          'isActive': true,
        },
      ];

      for (final d in defaults) {
        final ref = col.doc();
        batch.set(ref, d, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已建立預設 4 個快捷功能')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('建立預設資料失敗：$e')));
    } finally {
      if (!mounted) return;
      setState(() => _savingOrder = false);
    }
  }

  Future<void> _openEditDialog(BuildContext context, {required _HomeActionItem? item}) async {
    final isNew = item == null;
    final col = FirebaseFirestore.instance.collection('home_actions');

    final cs = Theme.of(context).colorScheme;

    String title = item?.title ?? '';
    String route = item?.route ?? '';
    String role = item?.role ?? 'all';
    String icon = item?.icon ?? 'apps';
    bool isActive = item?.isActive ?? true;

    // new 預設 order = max(order)+1
    int suggestedOrder = 1;
    if (isNew) {
      final maxOrder = _items
          .map((e) => e.order ?? 0)
          .fold<num>(0, (p, c) => c > p ? c : p);
      suggestedOrder = maxOrder.toInt() + 1;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: Text(isNew ? '新增快捷功能' : '編輯快捷功能'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '標題',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: title),
                    onChanged: (v) => setLocal(() => title = v.trim()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '路由 route（例：/products）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: route),
                    onChanged: (v) => setLocal(() => route = v.trim()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(
                      labelText: '顯示對象 role',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('all（全部）')),
                      DropdownMenuItem(value: 'admin', child: Text('admin')),
                      DropdownMenuItem(value: 'vendor', child: Text('vendor')),
                    ],
                    onChanged: (v) => setLocal(() => role = (v ?? 'all')),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: icon,
                    decoration: const InputDecoration(
                      labelText: '圖示 icon',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _IconMap.supportedNames
                        .map((n) => DropdownMenuItem(
                              value: n,
                              child: Row(
                                children: [
                                  Icon(_IconMap.fromName(n), color: cs.primary),
                                  const SizedBox(width: 10),
                                  Text(n),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setLocal(() => icon = (v ?? 'apps')),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('啟用'),
                      const SizedBox(width: 10),
                      Switch(value: isActive, onChanged: (v) => setLocal(() => isActive = v)),
                      const Spacer(),
                      Text(
                        'order：${isNew ? suggestedOrder : (item?.order?.toInt() ?? '-')}\n（排序用，拖曳即可）',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              if (!isNew)
                TextButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('刪除'),
                        content: const Text('確定要刪除這個快捷功能嗎？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
                        ],
                      ),
                    );
                    if (ok != true) return;

                    await item!.ref.delete();
                    if (context.mounted) Navigator.pop(context); // close dialog
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('刪除'),
                ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              FilledButton(
                onPressed: () async {
                  final t = title.trim();
                  final r = route.trim();

                  if (t.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('標題不能空白')));
                    return;
                  }
                  if (!r.startsWith('/')) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('route 請用 / 開頭，例如 /products')));
                    return;
                  }

                  if (isNew) {
                    final ref = col.doc();
                    await ref.set(
                      {
                        'title': t,
                        'route': r,
                        'role': role,
                        'icon': icon,
                        'isActive': isActive,
                        'order': suggestedOrder,
                        'updatedAt': FieldValue.serverTimestamp(),
                        'createdAt': FieldValue.serverTimestamp(),
                      },
                      SetOptions(merge: true),
                    );
                  } else {
                    await item!.ref.set(
                      {
                        'title': t,
                        'route': r,
                        'role': role,
                        'icon': icon,
                        'isActive': isActive,
                        'updatedAt': FieldValue.serverTimestamp(),
                      },
                      SetOptions(merge: true),
                    );
                  }

                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('儲存'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeActionItem {
  final String id;
  final DocumentReference ref;

  final String title;
  final String route;
  final String role;
  final String icon;
  final bool isActive;
  final num? order;

  _HomeActionItem({
    required this.id,
    required this.ref,
    required this.title,
    required this.route,
    required this.role,
    required this.icon,
    required this.isActive,
    required this.order,
  });

  factory _HomeActionItem.fromDoc(QueryDocumentSnapshot doc) {
    final m = (doc.data() as Map<String, dynamic>);

    String s(dynamic v) => (v ?? '').toString().trim();

    return _HomeActionItem(
      id: doc.id,
      ref: doc.reference,
      title: s(m['title']),
      route: s(m['route']),
      role: s(m['role']).isEmpty ? 'all' : s(m['role']).toLowerCase(),
      icon: s(m['icon']).isEmpty ? 'apps' : s(m['icon']),
      isActive: (m['isActive'] ?? true) == true,
      order: (m['order'] is num) ? (m['order'] as num) : null,
    );
  }
}

/// Icon name -> IconData
class _IconMap {
  static const List<String> supportedNames = [
    'inventory_2_outlined',
    'receipt_long_outlined',
    'campaign_outlined',
    'notifications_outlined',
    'category_outlined',
    'apartment_outlined',
    'settings_outlined',
    'people_outline',
    'person_outline',
    'bar_chart_outlined',
    'assignment_outlined',
    'local_offer_outlined',
    'apps',
  ];

  static IconData fromName(String name) {
    switch (name) {
      case 'inventory_2_outlined':
        return Icons.inventory_2_outlined;
      case 'receipt_long_outlined':
        return Icons.receipt_long_outlined;
      case 'campaign_outlined':
        return Icons.campaign_outlined;
      case 'notifications_outlined':
        return Icons.notifications_outlined;
      case 'category_outlined':
        return Icons.category_outlined;
      case 'apartment_outlined':
        return Icons.apartment_outlined;
      case 'settings_outlined':
        return Icons.settings_outlined;
      case 'people_outline':
        return Icons.people_outline;
      case 'person_outline':
        return Icons.person_outline;
      case 'bar_chart_outlined':
        return Icons.bar_chart_outlined;
      case 'assignment_outlined':
        return Icons.assignment_outlined;
      case 'local_offer_outlined':
        return Icons.local_offer_outlined;
      case 'apps':
      default:
        return Icons.apps;
    }
  }
}

class _SimpleErrorPage extends StatelessWidget {
  const _SimpleErrorPage({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重試'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () async => onLogout(),
                        icon: const Icon(Icons.logout),
                        label: const Text('登出'),
                      ),
                    ],
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

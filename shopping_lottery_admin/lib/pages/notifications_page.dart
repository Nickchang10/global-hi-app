// lib/pages/notifications_page.dart
//
// ✅ NotificationsPage（最終完整版｜與 NotificationService v1.3.x / AdminGate 完整整合｜Web/Chrome OK｜窄螢幕不 overflow｜可編譯）
//
// 功能：
// - 讀取 Firestore：notifications/{uid}/items/{notificationId}
// - 全部 / 未讀 切換
// - 類型 type 篩選（all / system / order / order_update / order_status / order_shipping / general / announcement / lottery）
// - 搜尋（title/body/orderId/extra）
// - 點擊自動 markAsRead（僅限看自己的通知）
// - 一鍵 markAllAsRead（僅限看自己的通知）
// - Admin 可輸入 uid 觀看其他人的通知（read-only，禁用標已讀/全部已讀等寫入）
// - AppBar 顯示「自己的」未讀數（streamUnreadCount）
//
// 依賴：
// - cloud_firestore（Timestamp）
// - firebase_auth
// - provider
// - services/admin_gate.dart（RoleInfo / AdminGate）
// - services/auth_service.dart
// - services/notification_service.dart（AppNotification / NotificationService）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // role cache
  Future<RoleInfo>? _roleFuture;
  String? _lastUid;

  // view mode
  bool _unreadOnly = false;
  String _type = 'all';
  String _q = '';

  final _searchCtrl = TextEditingController();

  // admin: view other uid
  String? _viewUidOverride;
  final _viewUidCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _viewUidCtrl.dispose();
    super.dispose();
  }

  // ----------------------------
  // Helpers
  // ----------------------------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  String _typeLabel(String t) {
    switch (t.toLowerCase()) {
      case 'general':
        return '一般';
      case 'system':
        return '系統';
      case 'order':
        return '訂單';
      case 'order_update':
        return '訂單更新';
      case 'order_status':
        return '狀態';
      case 'order_shipping':
        return '物流';
      case 'announcement':
        return '公告';
      case 'lottery':
        return '抽獎';
      default:
        return t.trim().isEmpty ? '未知' : t;
    }
  }

  Color _typeColor(BuildContext context, String t) {
    final cs = Theme.of(context).colorScheme;
    switch (t.toLowerCase()) {
      case 'announcement':
        return cs.primary;
      case 'order_shipping':
        return Colors.blueGrey;
      case 'order_status':
        return Colors.orange;
      case 'order_update':
        return cs.secondary;
      case 'order':
        return Colors.teal;
      case 'lottery':
        return Colors.purple;
      case 'general':
        return cs.onSurfaceVariant;
      case 'system':
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _orderIdFromExtra(Map<String, dynamic> extra) {
    // 常見 key 容錯（避免資料源不一致）
    final keys = <String>['orderId', 'orderID', 'order_id', 'orderNo', 'orderNO'];
    for (final k in keys) {
      final v = _s(extra[k]);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  bool _matchesFilter(AppNotification n) {
    final type = (n.type).toString().trim().toLowerCase();
    if (_type != 'all' && type != _type) return false;

    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final title = (n.title).toLowerCase();
    final body = (n.body).toLowerCase();
    final orderId = _orderIdFromExtra(n.extra).toLowerCase();
    final extraStr = n.extra.toString().toLowerCase();

    return title.contains(q) || body.contains(q) || orderId.contains(q) || extraStr.contains(q);
  }

  Future<void> _markOneRead({
    required NotificationService notifSvc,
    required String selfUid,
    required String notifId,
    required bool canWrite,
  }) async {
    if (!canWrite) return;
    if (selfUid.trim().isEmpty || notifId.trim().isEmpty) return;

    try {
      await notifSvc.markAsRead(selfUid, notifId);
    } catch (e) {
      _snack('標記已讀失敗：$e');
    }
  }

  Future<void> _markAllRead({
    required NotificationService notifSvc,
    required String selfUid,
    required bool canWrite,
  }) async {
    if (!canWrite) return;
    if (selfUid.trim().isEmpty) return;

    try {
      await notifSvc.markAllAsRead(selfUid);
      _snack('已全部標記為已讀');
    } catch (e) {
      _snack('全部已讀失敗：$e');
    }
  }

  Future<void> _openAdminViewUidDialog(String currentSelfUid) async {
    _viewUidCtrl.text = _viewUidOverride ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Admin：查看其他使用者通知'),
        content: TextField(
          controller: _viewUidCtrl,
          decoration: InputDecoration(
            labelText: '輸入 uid（留空=看自己）',
            hintText: currentSelfUid,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('套用')),
        ],
      ),
    );

    if (ok != true) return;

    final v = _viewUidCtrl.text.trim();
    setState(() {
      _viewUidOverride = v.isEmpty ? null : v;
    });
  }

  void _resetRole(AdminGate gate, User user) {
    setState(() {
      gate.clearCache();
      _roleFuture = gate.ensureAndGetRole(user, forceRefresh: true);
    });
  }

  Future<void> _tryNavigateByRoute(
    BuildContext context,
    String route,
    Map<String, dynamic>? extra,
  ) async {
    if (route.trim().isEmpty) return;
    try {
      if (!mounted) return;
      Navigator.pushNamed(context, route.trim(), arguments: extra);
    } catch (_) {
      _snack('此通知路由不存在：${route.trim()}');
    }
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();
    final authSvc = context.read<AuthService>();
    final notifSvc = context.read<NotificationService>();

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

            // 這裡除了 hasError，也要處理 RoleInfo.errorInfo 這種「資料層錯誤」型態
            if (roleSnap.hasError) {
              return _SimpleErrorPage(
                title: '讀取角色失敗',
                message: '${roleSnap.error}',
                onRetry: () => _resetRole(gate, user),
                onLogout: () async {
                  gate.clearCache();
                  await authSvc.signOut();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
              );
            }

            final RoleInfo? info = roleSnap.data;
            if (info == null) {
              return _SimpleErrorPage(
                title: '讀取角色失敗',
                message: 'RoleInfo 為空',
                onRetry: () => _resetRole(gate, user),
                onLogout: () async {
                  gate.clearCache();
                  await authSvc.signOut();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
              );
            }

            if (info.hasError) {
              return _SimpleErrorPage(
                title: '讀取角色失敗',
                message: info.error ?? '未知錯誤',
                onRetry: () => _resetRole(gate, user),
                onLogout: () async {
                  gate.clearCache();
                  await authSvc.signOut();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
              );
            }

            final role = _s(info.role).toLowerCase();
            final isAdmin = role == 'admin';

            final selfUid = user.uid;
            final targetUid = (isAdmin && (_viewUidOverride ?? '').trim().isNotEmpty)
                ? _viewUidOverride!.trim()
                : selfUid;

            // 只有本人能寫入 isRead（Admin 看別人時禁止）
            final canWriteRead = targetUid == selfUid;

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  targetUid == selfUid ? '通知中心' : '通知中心（查看：$targetUid）',
                  overflow: TextOverflow.ellipsis,
                ),
                centerTitle: true,
                actions: [
                  // 未讀數（顯示自己的）
                  StreamBuilder<int>(
                    stream: notifSvc.streamUnreadCount(selfUid),
                    builder: (_, c) {
                      final n = c.data ?? 0;
                      if (n <= 0) return const SizedBox.shrink();
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.error.withOpacity(0.35),
                              ),
                            ),
                            child: Text(
                              '未讀 $n',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  IconButton(
                    tooltip: '全部已讀（僅自己）',
                    onPressed: canWriteRead
                        ? () => _markAllRead(
                              notifSvc: notifSvc,
                              selfUid: selfUid,
                              canWrite: true,
                            )
                        : null,
                    icon: const Icon(Icons.done_all),
                  ),

                  if (isAdmin)
                    IconButton(
                      tooltip: 'Admin 查看其他 uid',
                      onPressed: () => _openAdminViewUidDialog(selfUid),
                      icon: const Icon(Icons.manage_search),
                    ),

                  IconButton(
                    tooltip: '登出',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      gate.clearCache();
                      await authSvc.signOut();
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Filters
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final isNarrow = c.maxWidth < 520;

                            final searchField = TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText: '搜尋（標題/內容/訂單ID/extra）',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: _q.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: '清除',
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() => _q = '');
                                        },
                                      ),
                              ),
                              onChanged: (v) => setState(() => _q = v),
                            );

                            final typeDropdown = DropdownButtonFormField<String>(
                              value: _type,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: '類型',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('全部')),
                                DropdownMenuItem(value: 'system', child: Text('系統')),
                                DropdownMenuItem(value: 'general', child: Text('一般')),
                                DropdownMenuItem(value: 'order', child: Text('訂單')),
                                DropdownMenuItem(value: 'order_update', child: Text('訂單更新')),
                                DropdownMenuItem(value: 'order_status', child: Text('狀態')),
                                DropdownMenuItem(value: 'order_shipping', child: Text('物流')),
                                DropdownMenuItem(value: 'announcement', child: Text('公告')),
                                DropdownMenuItem(value: 'lottery', child: Text('抽獎')),
                              ],
                              onChanged: (v) => setState(() => _type = v ?? 'all'),
                            );

                            final segment = SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: false, label: Text('全部')),
                                ButtonSegment(value: true, label: Text('未讀')),
                              ],
                              selected: {_unreadOnly},
                              onSelectionChanged: (s) => setState(() => _unreadOnly = s.first),
                            );

                            final hintText = Text(
                              canWriteRead ? '目前：看自己的通知（可標已讀）' : '目前：Admin 查看他人（只讀，不能標已讀）',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            );

                            return Column(
                              children: [
                                if (isNarrow) ...[
                                  searchField,
                                  const SizedBox(height: 10),
                                  typeDropdown,
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(child: searchField),
                                      const SizedBox(width: 10),
                                      SizedBox(width: 240, child: typeDropdown),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),
                                if (isNarrow) ...[
                                  SizedBox(width: double.infinity, child: segment),
                                  const SizedBox(height: 8),
                                  Align(alignment: Alignment.centerLeft, child: hintText),
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(child: segment),
                                      const SizedBox(width: 10),
                                      Flexible(child: hintText),
                                    ],
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // List (用 streamItems：避免 Map 缺 id 造成標已讀失效)
                    Expanded(
                      child: StreamBuilder<List<AppNotification>>(
                        stream: notifSvc.streamItems(
                          targetUid,
                          onlyUnread: _unreadOnly,
                          limit: 300,
                        ),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                '讀取通知失敗：${snap.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          if (!snap.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final raw = snap.data ?? const <AppNotification>[];
                          final list = raw.where(_matchesFilter).toList();

                          if (list.isEmpty) {
                            return const Center(child: Text('目前沒有通知（或篩選後無結果）'));
                          }

                          return ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final n = list[i];

                              final id = _s(n.id);
                              final title = _s(n.title);
                              final body = _s(n.body);
                              final type = _s(n.type).toLowerCase();
                              final isRead = n.isRead;
                              final route = _s(n.route);

                              // service 內已轉 DateTime?，此處再保險兼容
                              final createdAt = _toDate(n.createdAt) ?? n.createdAt;
                              final updatedAt = _toDate(n.updatedAt) ?? n.updatedAt;

                              final extra = n.extra;
                              final orderId = _orderIdFromExtra(extra);

                              final cs = Theme.of(context).colorScheme;
                              final chipColor = _typeColor(context, type);

                              return ListTile(
                                onTap: () async {
                                  if (!isRead && canWriteRead && id.isNotEmpty) {
                                    await _markOneRead(
                                      notifSvc: notifSvc,
                                      selfUid: selfUid,
                                      notifId: id,
                                      canWrite: true,
                                    );
                                  }

                                  if (!mounted) return;

                                  await showModalBottomSheet(
                                    context: context,
                                    showDragHandle: true,
                                    isScrollControlled: true,
                                    builder: (_) => _NotificationDetailSheet(
                                      title: title,
                                      body: body,
                                      typeLabel: _typeLabel(type),
                                      chipColor: chipColor,
                                      createdAt: createdAt,
                                      updatedAt: updatedAt,
                                      isRead: isRead,
                                      orderId: orderId,
                                      route: route,
                                      extra: extra.isEmpty ? null : extra,
                                      footerHint: canWriteRead
                                          ? '點擊列表或按鈕會自動標記已讀'
                                          : '目前為只讀檢視（Admin 查看他人）',
                                      onGoRoute: (route.trim().isEmpty)
                                          ? null
                                          : () => _tryNavigateByRoute(context, route, extra),
                                    ),
                                  );
                                },
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: chipColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: chipColor.withOpacity(0.25)),
                                  ),
                                  child: Icon(
                                    isRead ? Icons.notifications_none : Icons.notifications_active,
                                    color: chipColor,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title.isEmpty ? '（無標題）' : title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: isRead ? FontWeight.w600 : FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      fit: FlexFit.loose,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 110),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: chipColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(color: chipColor.withOpacity(0.25)),
                                          ),
                                          child: Text(
                                            _typeLabel(type),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: chipColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      body.isEmpty ? '（無內容）' : body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          _fmt(createdAt),
                                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                        ),
                                        if (orderId.isNotEmpty)
                                          Text(
                                            '訂單：$orderId',
                                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: canWriteRead
                                    ? (!isRead
                                        ? IconButton(
                                            tooltip: '標已讀',
                                            icon: const Icon(Icons.done),
                                            onPressed: id.isEmpty
                                                ? null
                                                : () => _markOneRead(
                                                      notifSvc: notifSvc,
                                                      selfUid: selfUid,
                                                      notifId: id,
                                                      canWrite: true,
                                                    ),
                                          )
                                        : const Icon(Icons.check, color: Colors.grey))
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ----------------------------
// Detail Sheet
// ----------------------------
class _NotificationDetailSheet extends StatelessWidget {
  const _NotificationDetailSheet({
    required this.title,
    required this.body,
    required this.typeLabel,
    required this.chipColor,
    required this.createdAt,
    required this.updatedAt,
    required this.isRead,
    required this.orderId,
    required this.route,
    required this.extra,
    required this.footerHint,
    required this.onGoRoute,
  });

  final String title;
  final String body;
  final String typeLabel;
  final Color chipColor;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final bool isRead;
  final String orderId;

  final String route;
  final Map<String, dynamic>? extra;

  final String footerHint;
  final VoidCallback? onGoRoute;

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: chipColor.withOpacity(0.25)),
                  ),
                  child: Text(typeLabel, style: TextStyle(color: chipColor, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isRead ? '已讀' : '未讀',
                    style: TextStyle(color: isRead ? Colors.grey : cs.primary, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title.isEmpty ? '（無標題）' : title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(body.isEmpty ? '（無內容）' : body),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            _kv('建立時間', _fmt(createdAt), cs),
            const SizedBox(height: 6),
            _kv('更新時間', _fmt(updatedAt), cs),
            const SizedBox(height: 6),
            if (orderId.isNotEmpty) ...[
              _kv('訂單ID', orderId, cs),
              const SizedBox(height: 6),
            ],
            if (route.trim().isNotEmpty) ...[
              _kv('路由', route.trim(), cs),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onGoRoute,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('前往相關頁面'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (extra != null && extra!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('extra', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(extra.toString()),
              ),
            ],
            const SizedBox(height: 14),
            Text(footerHint, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('關閉'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 72, child: Text(k, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800))),
      ],
    );
  }
}

// ----------------------------
// Error Page
// ----------------------------
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

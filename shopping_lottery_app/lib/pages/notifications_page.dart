// lib/pages/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../utils/haptic_audio_feedback.dart';

/// ======================================================
/// ✅ NotificationsPage（最終相容順流程版）
/// ------------------------------------------------------
/// - 全通知清單顯示、篩選、已讀標記與刪除
/// - 支援下拉刷新、滑動刪除、類型過濾
/// - ✅ 相容 NotificationService.notifications 回傳：
///    1) List<Map<String, dynamic>>
///    2) List<AppNotification>（或其他 model）
/// - ✅ 相容 NotificationService 方法命名差異：
///    clear / clearAll、remove / delete、markAsRead / markRead、refresh / init
/// - ✅ 避免 void 當 expression：一律用 dynamic 呼叫承接回傳
/// ======================================================
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _primary = Colors.blueAccent;

  bool _showUnreadOnly = false;
  String _typeFilterKey = 'all';

  final List<_TypeItem> _types = const [
    _TypeItem(label: '全部', key: 'all'),
    _TypeItem(label: '訂單', key: 'order'),
    _TypeItem(label: '購物', key: 'shop'),
    _TypeItem(label: '抽獎', key: 'lottery'),
    _TypeItem(label: '系統', key: 'system'),
    _TypeItem(label: '錯誤', key: 'error'),
  ];

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NotificationService>();

    final allRaw = _safeNotifications(service);
    final all = allRaw.map((e) => _NotifVM.fromAny(e)).toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    final unreadCount = _safeUnreadCount(service, all);

    final filtered = all.where((n) {
      if (_showUnreadOnly && n.read) return false;
      if (_typeFilterKey != 'all' && n.type != _typeFilterKey) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('通知', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.8,
        actions: [
          IconButton(
            tooltip: '全部設為已讀',
            onPressed: unreadCount == 0
                ? null
                : () async {
                    await _markAllRead(service, all);
                    HapticAudioFeedback.success();
                    _toast('已全部設為已讀');
                  },
            icon: const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            tooltip: '清空通知',
            onPressed: all.isEmpty
                ? null
                : () async {
                    final ok = await _confirmClear();
                    if (!ok) return;
                    await _clearAll(service);
                    if (!mounted) return;
                    HapticAudioFeedback.warning();
                    _toast('已清空通知');
                  },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(service),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildTopControls(unreadCount, all.length)),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            if (filtered.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyState(
                  unreadOnly: _showUnreadOnly,
                  typeLabel: _types.firstWhere((e) => e.key == _typeFilterKey).label,
                  onReset: () {
                    setState(() {
                      _showUnreadOnly = false;
                      _typeFilterKey = 'all';
                    });
                    HapticAudioFeedback.selection();
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final n = filtered[i];
                    final color = _colorForType(service, n.type);

                    return _NotificationTile(
                      n: n,
                      color: color,
                      onTap: () async {
                        if (!n.read) {
                          await _markAsRead(service, n.id);
                          HapticAudioFeedback.feedback();
                        }
                        if (!mounted) return;
                        await _openDetailSheet(n, color);
                      },
                      onDelete: () async {
                        await _remove(service, n.id);
                        if (!mounted) return;
                        HapticAudioFeedback.warning();
                        _toast('已刪除通知');
                      },
                      onToggleRead: () async {
                        if (n.read) {
                          final ok = await _markAsUnread(service, n.id);
                          if (!ok) {
                            HapticAudioFeedback.warning();
                            _toast('此版本通知服務不支援「改回未讀」');
                          } else {
                            HapticAudioFeedback.selection();
                            _toast('已改為未讀');
                          }
                        } else {
                          await _markAsRead(service, n.id);
                          HapticAudioFeedback.success();
                          _toast('已設為已讀');
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // Top controls
  // =====================================================
  Widget _buildTopControls(int unreadCount, int totalCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: _primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('共 $totalCount 則通知',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('未讀 $unreadCount 則',
                          style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                FilterChip(
                  showCheckmark: false,
                  selected: _showUnreadOnly,
                  onSelected: (v) {
                    setState(() => _showUnreadOnly = v);
                    HapticAudioFeedback.selection();
                  },
                  selectedColor: Colors.orangeAccent,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: _showUnreadOnly ? Colors.orangeAccent : Colors.grey.shade200,
                  ),
                  label: Text(
                    _showUnreadOnly ? '只看未讀' : '全部',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _showUnreadOnly ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _types.map((t) {
                  final selected = _typeFilterKey == t.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      showCheckmark: false,
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _typeFilterKey = t.key);
                        HapticAudioFeedback.selection();
                      },
                      selectedColor: Colors.orangeAccent,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected ? Colors.orangeAccent : Colors.grey.shade200,
                      ),
                      label: Text(
                        t.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: selected ? Colors.white : Colors.black87,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Detail sheet
  // =====================================================
  Future<void> _openDetailSheet(_NotifVM n, Color color) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(n.icon ?? Icons.notifications_none_rounded, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      n.title.isEmpty ? '通知' : n.title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                n.message.isEmpty ? '（無內容）' : n.message,
                style: TextStyle(color: Colors.grey.shade800, height: 1.45, fontSize: 14),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    n.formattedTime,
                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      n.typeLabel,
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('關閉', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =====================================================
  // Service compatibility helpers
  // =====================================================
  List<dynamic> _safeNotifications(NotificationService service) {
    try {
      final v = service.notifications;
      if (v is List) return v;
    } catch (_) {}
    try {
      final any = service as dynamic;
      final v = any.list;
      if (v is List) return v;
    } catch (_) {}
    return const [];
  }

  int _safeUnreadCount(NotificationService service, List<_NotifVM> all) {
    try {
      final v = service.unreadCount;
      if (v is int) return v;
    } catch (_) {}
    return all.where((e) => !e.read).length;
  }

  Color _colorForType(NotificationService service, String type) {
    try {
      final c = service.colorForType(type);
      if (c is Color) return c;
    } catch (_) {}

    switch (type) {
      case 'order':
        return Colors.green;
      case 'shop':
        return Colors.orange;
      case 'lottery':
        return Colors.purple;
      case 'error':
        return Colors.redAccent;
      case 'system':
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _refresh(NotificationService service) async {
    // dynamic 呼叫：不管回 void 或 Future 都能接
    try {
      final any = service as dynamic;
      final r = any.refresh();
      if (r is Future) await r;
      return;
    } catch (_) {}
    try {
      final any = service as dynamic;
      final r = any.init();
      if (r is Future) await r;
      return;
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> _markAllRead(NotificationService service, List<_NotifVM> all) async {
    try {
      final any = service as dynamic;
      final r = any.markAllRead();
      if (r is Future) await r;
      return;
    } catch (_) {}
    for (final n in all) {
      if (!n.read) await _markAsRead(service, n.id);
    }
  }

  Future<void> _clearAll(NotificationService service) async {
    try {
      final any = service as dynamic;
      final r = any.clearAll();
      if (r is Future) await r;
      return;
    } catch (_) {}
    try {
      final any = service as dynamic;
      final r = any.clear();
      if (r is Future) await r;
      return;
    } catch (_) {}
  }

  Future<void> _remove(NotificationService service, String id) async {
    try {
      final any = service as dynamic;
      final r = any.remove(id);
      if (r is Future) await r;
      return;
    } catch (_) {}
    try {
      final any = service as dynamic;
      final r = any.delete(id);
      if (r is Future) await r;
      return;
    } catch (_) {}
  }

  Future<void> _markAsRead(NotificationService service, String id) async {
    try {
      final any = service as dynamic;
      final r = any.markAsRead(id);
      if (r is Future) await r;
      return;
    } catch (_) {}
    try {
      final any = service as dynamic;
      final r = any.markRead(id);
      if (r is Future) await r;
      return;
    } catch (_) {}
  }

  Future<bool> _markAsUnread(NotificationService service, String id) async {
    try {
      final any = service as dynamic;
      final r = any.markAsUnread(id);
      if (r is Future) await r;
      return true;
    } catch (_) {}
    try {
      final any = service as dynamic;
      final r = any.markUnread(id);
      if (r is Future) await r;
      return true;
    } catch (_) {}
    return false;
  }

  // =====================================================
  // Dialog / Toast
  // =====================================================
  Future<bool> _confirmClear() async {
    return (await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('清空通知', style: TextStyle(fontWeight: FontWeight.w900)),
            content: const Text('確定要刪除所有通知嗎？此操作無法復原。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('清空', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        )) ??
        false;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ===============================================================
// Tile
// ===============================================================
class _NotificationTile extends StatelessWidget {
  final _NotifVM n;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleRead;

  const _NotificationTile({
    required this.n,
    required this.color,
    required this.onTap,
    required this.onDelete,
    required this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    final bg = n.read ? Colors.white : color.withOpacity(0.06);

    return Dismissible(
      key: ValueKey('notif_${n.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.mark_email_read_outlined, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(
              n.read ? '改為未讀' : '設為已讀',
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return true; // delete
        } else if (direction == DismissDirection.startToEnd) {
          onToggleRead();
          return false; // 不真的移除
        }
        return false;
      },
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  n.icon ?? Icons.notifications_none_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title.isEmpty ? '通知' : n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ),
                        if (!n.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      n.message.isEmpty ? '（無內容）' : n.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(
                          n.formattedTime,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            n.typeLabel,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===============================================================
// Empty state
// ===============================================================
class _EmptyState extends StatelessWidget {
  final bool unreadOnly;
  final String typeLabel;
  final VoidCallback onReset;

  const _EmptyState({
    required this.unreadOnly,
    required this.typeLabel,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final hint = unreadOnly
        ? '目前沒有未讀通知'
        : (typeLabel == '全部' ? '目前沒有通知' : '「$typeLabel」目前沒有通知');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 60, 14, 18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              hint,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              '你可以下拉刷新，或重設篩選條件。',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('重設篩選', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeItem {
  final String label;
  final String key;
  const _TypeItem({required this.label, required this.key});
}

// ===============================================================
// ViewModel
// ===============================================================
class _NotifVM {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool read;
  final IconData? icon;
  final DateTime time;

  const _NotifVM({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.read,
    required this.icon,
    required this.time,
  });

  String get formattedTime {
    String two(int v) => v < 10 ? '0$v' : '$v';
    final t = time;
    return '${t.year}/${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
    }

  String get typeLabel {
    switch (type) {
      case 'order':
        return '訂單';
      case 'shop':
        return '購物';
      case 'lottery':
        return '抽獎';
      case 'error':
        return '錯誤';
      case 'system':
      default:
        return '系統';
    }
  }

  static _NotifVM fromAny(dynamic raw) {
    // Map
    if (raw is Map) {
      final m = raw;
      final id = (m['id'] ?? m['key'] ?? m['uuid'] ?? '').toString().trim();
      final type = (m['type'] ?? 'system').toString().trim();
      final title = (m['title'] ?? '').toString();
      final message = (m['message'] ?? m['body'] ?? '').toString();

      // 兼容 unread / read
      final unread = (m['unread'] == true);
      final read = (m['read'] == true) ? true : (unread ? false : false);

      final icon = m['icon'] is IconData ? (m['icon'] as IconData) : null;
      final dt = _parseTime(m['time'] ?? m['createdAt'] ?? m['timestamp']) ?? DateTime.now();

      return _NotifVM(
        id: id.isEmpty ? 'notif_${DateTime.now().millisecondsSinceEpoch}' : id,
        type: type.isEmpty ? 'system' : type,
        title: title,
        message: message,
        read: read,
        icon: icon,
        time: dt,
      );
    }

    // Model/Object (AppNotification 等)
    final any = raw as dynamic;

    String _str(String name, String fallback) {
      try {
        final v = any[name];
        if (v != null) return v.toString();
      } catch (_) {}
      try {
        final v = (any as dynamic).__getattribute__(name);
        if (v != null) return v.toString();
      } catch (_) {}
      try {
        final v = (any as dynamic).id;
        if (name == 'id' && v != null) return v.toString();
      } catch (_) {}
      try {
        final v = (any as dynamic).type;
        if (name == 'type' && v != null) return v.toString();
      } catch (_) {}
      try {
        final v = (any as dynamic).title;
        if (name == 'title' && v != null) return v.toString();
      } catch (_) {}
      try {
        final v = (any as dynamic).message;
        if (name == 'message' && v != null) return v.toString();
      } catch (_) {}
      return fallback;
    }

    bool _boolRead() {
      try {
        final v = (any as dynamic).read;
        if (v is bool) return v;
      } catch (_) {}
      try {
        final v = any['read'];
        if (v is bool) return v;
      } catch (_) {}
      return false;
    }

    IconData? _icon() {
      try {
        final v = (any as dynamic).icon;
        if (v is IconData) return v;
      } catch (_) {}
      try {
        final v = any['icon'];
        if (v is IconData) return v;
      } catch (_) {}
      return null;
    }

    DateTime _time() {
      try {
        final v = (any as dynamic).createdAt;
        final dt = _parseTime(v);
        if (dt != null) return dt;
      } catch (_) {}
      try {
        final v = (any as dynamic).time;
        if (v is DateTime) return v;
      } catch (_) {}
      return DateTime.now();
    }

    final id = _str('id', 'notif_${DateTime.now().millisecondsSinceEpoch}');
    final type = _str('type', 'system');
    final title = _str('title', '');
    final message = _str('message', '');

    return _NotifVM(
      id: id,
      type: type,
      title: title,
      message: message,
      read: _boolRead(),
      icon: _icon(),
      time: _time(),
    );
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {
        return null;
      }
    }
    if (v is num) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      } catch (_) {
        return null;
      }
    }
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt;
    final ms = int.tryParse(s);
    if (ms != null) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(ms);
      } catch (_) {}
    }
    return null;
  }
}

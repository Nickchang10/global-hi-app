// lib/pages/notification_center_page.dart
// ======================================================
// ✅ NotificationCenterPage（最終穩定版｜Web 不用 snapshots）
// ------------------------------------------------------
// - 不使用 StreamBuilder(Firestore.snapshots)
// - 直接依賴 NotificationService（ChangeNotifier）
// - 未登入也可看本地通知快取
// ======================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../models/app_notification.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  final NotificationService service = NotificationService.instance;

  bool _loading = true;
  String _keyword = '';
  bool _onlyUnread = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await service.init(); // ✅ 這是 Future<void>
    } catch (_) {
      // swallow (避免 UI 崩)
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await service.init(force: true);
  }

  List<AppNotification> _filtered(List<AppNotification> all) {
    var list = all;

    if (_onlyUnread) {
      list = list.where((e) => !e.read).toList();
    }

    final k = _keyword.trim();
    if (k.isNotEmpty) {
      list = list
          .where((e) =>
              e.title.contains(k) ||
              e.message.contains(k) ||
              (e.type).contains(k))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final signedIn = user != null && user.uid.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心'),
        actions: [
          IconButton(
            tooltip: '全部已讀',
            onPressed: () async {
              await service.markAllRead();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已全部標記為已讀')),
              );
            },
            icon: const Icon(Icons.done_all),
          ),
          IconButton(
            tooltip: '清空本地',
            onPressed: () async {
              await service.clearAll();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已清空本地通知')),
              );
            },
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: service,
              builder: (context, _) {
                final all = service.notifications;
                final list = _filtered(all);

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    children: [
                      _header(signedIn: signedIn, total: all.length),
                      const SizedBox(height: 12),
                      _filters(),
                      const SizedBox(height: 12),
                      if (list.isEmpty)
                        _emptyState(signedIn: signedIn)
                      else
                        ...list.map((n) => _tile(n)).toList(),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _header({required bool signedIn, required int total}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            signedIn ? Icons.verified_user : Icons.lock_outline,
            color: signedIn ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              signedIn
                  ? '已登入 • 未讀：${service.unreadCount} • 全部：$total'
                  : '未登入 • 顯示本地快取通知（不會連 Firestore 監聽）',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: '搜尋標題 / 內容 / 類型',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _keyword = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            FilterChip(
              label: const Text('只看未讀'),
              selected: _onlyUnread,
              onSelected: (v) => setState(() => _onlyUnread = v),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                await service.addNotification(
                  type: 'system',
                  title: '測試通知',
                  message: '這是一則測試通知（本地/雲端依登入狀態寫入）',
                );
              },
              icon: const Icon(Icons.add_alert),
              label: const Text('新增測試'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _emptyState({required bool signedIn}) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.notifications_none, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              signedIn ? '目前沒有通知' : '未登入，目前沒有本地通知',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Text(
              signedIn ? '下拉可重新整理' : '登入後才會同步雲端通知',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(AppNotification n) {
    final icon = n.icon ?? service.iconForType(n.type);
    final color = service.colorForType(n.type);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          n.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: n.read ? FontWeight.w500 : FontWeight.w800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              n.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              _timeText(n.createdAt),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'read') {
              await service.markAsRead(n.id);
            } else if (v == 'remove') {
              await service.remove(n.id);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'read', child: Text('標記已讀')),
            const PopupMenuItem(value: 'remove', child: Text('移除（本地）')),
          ],
        ),
        onTap: () async {
          await service.markAsRead(n.id);
        },
      ),
    );
  }

  String _timeText(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours < 24) return '${diff.inHours} 小時前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

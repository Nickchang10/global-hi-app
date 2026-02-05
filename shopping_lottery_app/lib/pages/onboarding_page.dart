// lib/pages/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _selected = '全部';

  /// 可依實際通知類型調整
  final List<String> _filters = <String>[
    '全部',
    '訂單',
    '系統',
    '活動',
    '會員',
    'leaderboard',
  ];

  List<AppNotification> _applyFilter(List<AppNotification> all) {
    if (_selected == '全部') return all;
    return all
        .where((n) =>
            n.type.toLowerCase() == _selected.toLowerCase() ||
            n.type == _selected)
        .toList();
  }

  String _formatTime(DateTime t) {
    return '${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationService>(
      builder: (context, notifier, _) {
        final all = notifier.notifications;
        final list = _applyFilter(all);

        return Scaffold(
          appBar: AppBar(
            title: const Text('通知中心'),
            actions: [
              if (all.isNotEmpty)
                IconButton(
                  tooltip: '全部設為已讀',
                  icon: const Icon(Icons.done_all),
                  onPressed: notifier.markAllRead,
                ),
              if (all.isNotEmpty)
                IconButton(
                  tooltip: '清空通知',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: notifier.clearAll,
                ),
            ],
          ),
          body: Column(
            children: [
              // 篩選 Chips
              SizedBox(
                height: 46,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  itemBuilder: (_, i) {
                    final label = _filters[i];
                    final selected = label == _selected;
                    return ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selected = label);
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                ),
              ),
              const Divider(height: 1),

              // 通知列表
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('目前沒有通知'))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final AppNotification n = list[index];
                          final String id = n.id;
                          final bool read = n.read;

                          return Dismissible(
                            key: ValueKey(id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.redAccent,
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) => notifier.remove(id),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: read
                                    ? Colors.grey.shade200
                                    : Colors.blue.shade50,
                                child: Icon(
                                  n.icon ?? Icons.notifications,
                                  color: read
                                      ? Colors.grey
                                      : Colors.blueAccent,
                                ),
                              ),
                              title: Text(
                                n.title,
                                style: TextStyle(
                                  fontWeight: read
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (n.message.isNotEmpty)
                                    Text(
                                      n.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(n.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: read
                                  ? null
                                  : const Icon(
                                      Icons.brightness_1,
                                      size: 10,
                                      color: Colors.redAccent,
                                    ),
                              onTap: () => notifier.markAsRead(id),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

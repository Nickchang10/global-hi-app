import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RemoteBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// 若後台關閉底部導覽，是否直接隱藏（建議 true）
  final bool hideWhenDisabled;

  /// 若後台設定不足（<2 個啟用項目），是否回退到 fallback
  final bool fallbackWhenInvalid;

  /// fallback 預設（你現在前台 5 個 tabs）
  final List<_NavItem> fallbackItems;

  const RemoteBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.hideWhenDisabled = true,
    this.fallbackWhenInvalid = true,
    this.fallbackItems = const [
      _NavItem(label: '首頁', icon: Icons.home),
      _NavItem(label: '商城', icon: Icons.shopping_cart),
      _NavItem(label: '任務', icon: Icons.task_alt),
      _NavItem(label: '互動', icon: Icons.group),
      _NavItem(label: '我的', icon: Icons.person),
    ],
  });

  DocumentReference<Map<String, dynamic>> get _docRef =>
      FirebaseFirestore.instance.collection('app_config').doc('bottom_nav');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _docRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();

        // 沒資料：直接 fallback
        if (data == null) {
          return _buildBarFromItems(fallbackItems);
        }

        final enabled = (data['enabled'] as bool?) ?? true;
        final raw = data['items'];

        if (!enabled && hideWhenDisabled) {
          return const SizedBox.shrink();
        }

        final items = <_NavItem>[];
        if (raw is List) {
          for (final e in raw) {
            if (e is Map) {
              final m = Map<String, dynamic>.from(e);
              final isEnabled = (m['enabled'] as bool?) ?? true;
              if (!isEnabled) continue;

              final label = (m['label'] ?? '').toString().trim();
              final iconKey = (m['iconKey'] ?? 'home').toString();
              final order = (m['order'] as int?) ?? 999;

              if (label.isEmpty) continue;
              items.add(_NavItem(label: label, icon: _iconFromKey(iconKey), order: order));
            }
          }
        }

        items.sort((a, b) => a.order.compareTo(b.order));

        // BottomNavigationBar 規則：items >= 2
        if (items.length < 2) {
          return fallbackWhenInvalid ? _buildBarFromItems(fallbackItems) : const SizedBox.shrink();
        }

        return _buildBarFromItems(items);
      },
    );
  }

  Widget _buildBarFromItems(List<_NavItem> items) {
    final safeIndex = currentIndex.clamp(0, items.length - 1);

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: safeIndex,
      onTap: onTap,
      items: items
          .map((e) => BottomNavigationBarItem(
                icon: Icon(e.icon),
                label: e.label,
              ))
          .toList(),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final int order;

  const _NavItem({
    required this.label,
    required this.icon,
    this.order = 0,
  });
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

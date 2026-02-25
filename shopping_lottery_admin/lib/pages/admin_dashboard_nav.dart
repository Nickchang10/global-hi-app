// lib/pages/admin_dashboard_nav.dart
//
// ✅ AdminDashboardNav（正式版｜完整版｜可編譯）
// ------------------------------------------------------------
// - 修正：unused_field（_vendorId 會被 UI 實際使用）
// - 依螢幕寬度：窄 => Drawer / 寬 => NavigationRail
// - 支援 vendorId（可選）：顯示 Vendor 標記 + 額外「商家資料」入口
// - 修正 deprecated：withOpacity(...) -> withValues(alpha: ...)
// ------------------------------------------------------------

import 'package:flutter/material.dart';

class AdminDashboardNav extends StatefulWidget {
  const AdminDashboardNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.vendorId,
    this.showLogout = true,
    this.onLogout,
    this.headerTitle = 'Osmile Admin',
  });

  /// 目前選到的 index（由外層 shell 控制）
  final int selectedIndex;

  /// 點擊選單回呼（由外層切頁）
  final ValueChanged<int> onSelect;

  /// 若有 vendorId，會顯示 vendor badge 與額外「商家資料」入口
  final String? vendorId;

  /// 是否顯示登出
  final bool showLogout;

  /// 登出按鈕回呼（若不傳就不顯示按鈕）
  final VoidCallback? onLogout;

  final String headerTitle;

  @override
  State<AdminDashboardNav> createState() => _AdminDashboardNavState();
}

class _AdminDashboardNavState extends State<AdminDashboardNav> {
  // ✅ 這個欄位會被 UI 使用，warning 消失
  late final String? _vendorId = widget.vendorId;

  bool get _hasVendor => (_vendorId ?? '').trim().isNotEmpty;

  List<_NavItem> _buildItems() {
    // 你可以依你實際的 AdminShell 分頁順序調整 index
    final items = <_NavItem>[
      const _NavItem(index: 0, icon: Icons.dashboard, label: '總覽'),
      const _NavItem(index: 1, icon: Icons.shopping_bag, label: '商城'),
      const _NavItem(index: 2, icon: Icons.inventory_2, label: '商品'),
      const _NavItem(index: 3, icon: Icons.receipt_long, label: '訂單'),
      const _NavItem(index: 4, icon: Icons.group, label: '會員'),
      const _NavItem(index: 5, icon: Icons.campaign, label: '行銷'),
      const _NavItem(index: 6, icon: Icons.article, label: '內容'),
      const _NavItem(index: 7, icon: Icons.support_agent, label: '工單/聯絡'),
      const _NavItem(index: 8, icon: Icons.settings, label: '系統'),
    ];

    // ✅ 若 vendorId 存在：增加 vendor 入口（你可對應到你 shell 的某個 index）
    if (_hasVendor) {
      items.insert(
        5,
        _NavItem(
          index: 50, // 建議 vendor 相關用不同區段 index，避免跟既有分頁衝突
          icon: Icons.store,
          label: '商家資料',
          badgeText: _vendorId!,
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    final isWide = MediaQuery.of(context).size.width >= 980;

    if (isWide) {
      return _RailNav(
        headerTitle: widget.headerTitle,
        vendorId: _vendorId,
        items: items,
        selectedIndex: widget.selectedIndex,
        onSelect: widget.onSelect,
        showLogout: widget.showLogout,
        onLogout: widget.onLogout,
      );
    }

    return _DrawerNav(
      headerTitle: widget.headerTitle,
      vendorId: _vendorId,
      items: items,
      selectedIndex: widget.selectedIndex,
      onSelect: widget.onSelect,
      showLogout: widget.showLogout,
      onLogout: widget.onLogout,
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    this.badgeText,
  });

  final int index;
  final IconData icon;
  final String label;

  /// 可選 badge（例如 vendorId）
  final String? badgeText;
}

// =========================
// Drawer (mobile / narrow)
// =========================

class _DrawerNav extends StatelessWidget {
  const _DrawerNav({
    required this.headerTitle,
    required this.vendorId,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.showLogout,
    required this.onLogout,
  });

  final String headerTitle;
  final String? vendorId;
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool showLogout;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _NavHeader(title: headerTitle, vendorId: vendorId),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final it = items[i];
                  final selected = it.index == selectedIndex;

                  return Card(
                    elevation: selected ? 1.2 : 0.2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        it.icon,
                        color: selected ? cs.primary : null,
                      ),
                      title: Text(
                        it.label,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w600,
                        ),
                      ),
                      subtitle: (it.badgeText ?? '').isEmpty
                          ? null
                          : Text(
                              'ID: ${it.badgeText}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      selected: selected,
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(it.index);
                      },
                    ),
                  );
                },
              ),
            ),
            if (showLogout && onLogout != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: Icon(Icons.logout, color: cs.error),
                    label: Text('登出', style: TextStyle(color: cs.error)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =========================
// NavigationRail (wide)
// =========================

class _RailNav extends StatelessWidget {
  const _RailNav({
    required this.headerTitle,
    required this.vendorId,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.showLogout,
    required this.onLogout,
  });

  final String headerTitle;
  final String? vendorId;
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool showLogout;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final destinations = items
        .map(
          (it) => NavigationRailDestination(
            icon: Icon(it.icon),
            selectedIcon: Icon(it.icon, color: cs.primary),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(it.label),
                if ((it.badgeText ?? '').isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _MiniBadge(text: it.badgeText!),
                ],
              ],
            ),
          ),
        )
        .toList();

    int railIndex = items.indexWhere((e) => e.index == selectedIndex);
    if (railIndex < 0) railIndex = 0;

    return Column(
      children: [
        _NavHeader(title: headerTitle, vendorId: vendorId, compact: true),
        Expanded(
          child: NavigationRail(
            selectedIndex: railIndex,
            onDestinationSelected: (i) => onSelect(items[i].index),
            labelType: NavigationRailLabelType.all,
            useIndicator: true,
            leading: const SizedBox(height: 8),
            trailing: showLogout && onLogout != null
                ? Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: IconButton(
                          tooltip: '登出',
                          onPressed: onLogout,
                          icon: Icon(Icons.logout, color: cs.error),
                        ),
                      ),
                    ),
                  )
                : null,
            destinations: destinations,
          ),
        ),
      ],
    );
  }
}

// =========================
// Shared UI
// =========================

class _NavHeader extends StatelessWidget {
  const _NavHeader({
    required this.title,
    required this.vendorId,
    this.compact = false,
  });

  final String title;
  final String? vendorId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasVendor = (vendorId ?? '').trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, compact ? 8 : 12),
      child: Card(
        elevation: 0.6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                // ✅ 修正：withOpacity deprecated
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Icon(Icons.admin_panel_settings, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    if (hasVendor)
                      Row(
                        children: [
                          Icon(Icons.store, size: 14, color: cs.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Vendor: $vendorId',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Admin Mode',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
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

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          // ✅ 修正：withOpacity deprecated
          color: cs.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// lib/pages/admin/system/admin_system_shell_page.dart
//
// ✅ AdminSystemShellPage（系統管理入口｜可編譯完整版）
// ------------------------------------------------------------
// - 左側（寬螢幕）/ 上方（窄螢幕）導航
// - 內含：角色指派 / 角色權限 / 系統設定 / 系統報表（可依你專案增減）
// - ✅ 修正：withOpacity deprecated -> withValues(alpha: ...)
// ------------------------------------------------------------

import 'package:flutter/material.dart';

// ✅ 依你專案實際路徑調整以下 import
import 'package:osmile_admin/pages/admin/system/admin_role_assign_page.dart';
import 'package:osmile_admin/pages/admin/system/admin_roles_permissions_page.dart';
import 'package:osmile_admin/pages/admin/system/admin_system_settings_page.dart';
import 'package:osmile_admin/pages/admin/system/admin_system_reports_page.dart';

class AdminSystemShellPage extends StatefulWidget {
  const AdminSystemShellPage({super.key});

  @override
  State<AdminSystemShellPage> createState() => _AdminSystemShellPageState();
}

class _AdminSystemShellPageState extends State<AdminSystemShellPage> {
  int _index = 0;

  late final List<_NavItem> _items = <_NavItem>[
    _NavItem(
      keyName: 'role_assign',
      title: '角色指派',
      icon: Icons.manage_accounts_outlined,
      builder: (_) => const AdminRoleAssignPage(),
    ),
    _NavItem(
      keyName: 'roles_permissions',
      title: '角色權限',
      icon: Icons.admin_panel_settings_outlined,
      builder: (_) => const AdminRolesPermissionsPage(),
    ),
    _NavItem(
      keyName: 'system_settings',
      title: '系統設定',
      icon: Icons.settings_outlined,
      builder: (_) => const AdminSystemSettingsPage(),
    ),
    _NavItem(
      keyName: 'system_reports',
      title: '系統報表',
      icon: Icons.analytics_outlined,
      builder: (_) => const AdminSystemReportsPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.of(context).size.width;
    final wide = w >= 980;

    final current = _items[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '系統管理｜${current.title}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '快速切換',
            icon: const Icon(Icons.menu_open),
            onPressed: () => _openQuickSwitch(context),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: wide ? _wideLayout(cs) : _narrowLayout(cs),
    );
  }

  // -----------------------------
  // Wide: Side rail + content
  // -----------------------------
  Widget _wideLayout(ColorScheme cs) {
    final bg = cs.surfaceContainerHighest.withValues(
      alpha: 0.35,
    ); // ✅ 替代 withOpacity

    return Row(
      children: [
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: bg,
            border: Border(right: BorderSide(color: cs.outlineVariant)),
          ),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _sectionTitle('System'),
              const SizedBox(height: 8),
              ...List.generate(_items.length, (i) => _navTile(i)),
              const SizedBox(height: 12),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 8),
              _hintCard(cs),
            ],
          ),
        ),
        Expanded(
          child: _BodyHost(
            key: ValueKey(_items[_index].keyName),
            child: _items[_index].builder(context),
          ),
        ),
      ],
    );
  }

  // -----------------------------
  // Narrow: Top tabs + content
  // -----------------------------
  Widget _narrowLayout(ColorScheme cs) {
    final bg = cs.surfaceContainerHighest.withValues(
      alpha: 0.35,
    ); // ✅ 替代 withOpacity

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: bg,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_items.length, (i) {
                final it = _items[i];
                final selected = i == _index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(it.title),
                    avatar: Icon(it.icon, size: 18),
                    onSelected: (_) => setState(() => _index = i),
                  ),
                );
              }),
            ),
          ),
        ),
        Expanded(
          child: _BodyHost(
            key: ValueKey(_items[_index].keyName),
            child: _items[_index].builder(context),
          ),
        ),
      ],
    );
  }

  // -----------------------------
  // Widgets
  // -----------------------------
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _navTile(int i) {
    final cs = Theme.of(context).colorScheme;
    final it = _items[i];
    final selected = i == _index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(
            it.icon,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
          title: Text(
            it.title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? cs.onPrimaryContainer : null,
            ),
          ),
          trailing: selected
              ? Icon(Icons.chevron_right, color: cs.onPrimaryContainer)
              : const Icon(Icons.chevron_right),
          onTap: () => setState(() => _index = i),
        ),
      ),
    );
  }

  Widget _hintCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.surface.withValues(alpha: 0.8),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          '提示：\n'
          '- 角色指派：寫入 user_roles/{uid} 及 users/{uid}.role\n'
          '- 角色權限：system/roles_permissions\n'
          '- 系統設定：app_config/system_settings\n'
          '- 系統報表：統計集合筆數與 CSV 匯出',
          style: TextStyle(height: 1.4),
        ),
      ),
    );
  }

  Future<void> _openQuickSwitch(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final it = _items[i];
            return ListTile(
              leading: Icon(it.icon),
              title: Text(
                it.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () => Navigator.pop(context, i),
            );
          },
        ),
      ),
    );

    if (picked == null) return;
    setState(() => _index = picked);
  }
}

class _NavItem {
  final String keyName;
  final String title;
  final IconData icon;
  final WidgetBuilder builder;

  const _NavItem({
    required this.keyName,
    required this.title,
    required this.icon,
    required this.builder,
  });
}

/// 用來包住子頁，避免每次切換都把 Scaffold theme/動畫弄亂
class _BodyHost extends StatelessWidget {
  final Widget child;
  const _BodyHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: child,
    );
  }
}

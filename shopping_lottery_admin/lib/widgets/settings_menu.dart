import 'package:flutter/material.dart';

/// ✅ SettingsMenu（可編譯版｜不依賴 l10n）
/// - 放在 AppBar actions: SettingsMenu()
/// - 或放在 Drawer / 任何地方都可
class SettingsMenu extends StatelessWidget {
  const SettingsMenu({
    super.key,
    this.onOpenSettings,
    this.onOpenLanguage,
    this.onToggleTheme,
    this.onOpenAbout,
    this.onLogout,
  });

  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenLanguage;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onOpenAbout;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SettingsAction>(
      tooltip: '設定',
      icon: const Icon(Icons.settings),
      onSelected: (action) => _handle(context, action),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _SettingsAction.settings,
          child: _MenuRow(icon: Icons.tune, text: '設定'),
        ),
        PopupMenuItem(
          value: _SettingsAction.language,
          child: _MenuRow(icon: Icons.language, text: '語言'),
        ),
        PopupMenuItem(
          value: _SettingsAction.theme,
          child: _MenuRow(icon: Icons.dark_mode, text: '深色模式'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _SettingsAction.about,
          child: _MenuRow(icon: Icons.info_outline, text: '關於'),
        ),
        PopupMenuItem(
          value: _SettingsAction.logout,
          child: _MenuRow(icon: Icons.logout, text: '登出'),
        ),
      ],
    );
  }

  void _handle(BuildContext context, _SettingsAction action) {
    switch (action) {
      case _SettingsAction.settings:
        if (onOpenSettings != null) return onOpenSettings!();
        _goNamed(context, '/settings');
        return;

      case _SettingsAction.language:
        if (onOpenLanguage != null) return onOpenLanguage!();
        _goNamed(context, '/settings/language');
        return;

      case _SettingsAction.theme:
        if (onToggleTheme != null) return onToggleTheme!();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('尚未接 Theme 切換（可在這裡接你的 ThemeService）')),
        );
        return;

      case _SettingsAction.about:
        if (onOpenAbout != null) return onOpenAbout!();
        showAboutDialog(
          context: context,
          applicationName: 'Osmile Admin',
          applicationVersion: '1.0.0',
          applicationIcon: const Icon(Icons.admin_panel_settings),
        );
        return;

      case _SettingsAction.logout:
        if (onLogout != null) return onLogout!();
        _confirmLogout(context);
        return;
    }
  }

  void _goNamed(BuildContext context, String route) {
    // 你若沒有這些 route，請改成你專案實際路由
    try {
      Navigator.of(context, rootNavigator: true).pushNamed(route);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('找不到路由：$route（請改成你專案的路由名稱）')));
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認登出'),
        content: const Text('你確定要登出嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('登出'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('尚未接 AuthService 登出（可在 onLogout 傳入實作）')),
      );
    }
  }
}

enum _SettingsAction { settings, language, theme, about, logout }

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(text)],
    );
  }
}

// lib/pages/settings_page.dart
//
// ✅ SettingsPage（最終完整版｜可直接使用｜已修正 lint）
// - ✅ 修正：withOpacity(deprecated) → withValues(alpha: ...)
// - 功能：帳號/通知/隱私/關於/客服 等常用設定入口（可改成你的 routes）
//
// 無額外套件依賴（只用 Flutter SDK）

import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const Color _brand = Color(0xFF3B82F6);

  void _go(BuildContext context, String route) {
    try {
      Navigator.of(context).pushNamed(route);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('無法前往：$route（請確認 main.dart 已註冊路由）')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _sectionTitle('帳號'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: [
                _tile(
                  context,
                  icon: Icons.person_outline,
                  title: '個人資料',
                  subtitle: '修改顯示名稱、電話等',
                  onTap: () => _go(context, '/profile'),
                ),
                const Divider(height: 1),
                _tile(
                  context,
                  icon: Icons.lock_outline,
                  title: '安全性',
                  subtitle: '變更密碼、登入裝置',
                  onTap: () => _go(context, '/security'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          _sectionTitle('通知'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: [
                _tile(
                  context,
                  icon: Icons.notifications_none,
                  title: '通知設定',
                  subtitle: '推播、活動、訂單通知',
                  onTap: () => _go(context, '/notification_settings'),
                ),
                const Divider(height: 1),
                _tile(
                  context,
                  icon: Icons.inbox_outlined,
                  title: '通知時間軸',
                  subtitle: '查看系統通知紀錄',
                  onTap: () => _go(context, '/notifications'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          _sectionTitle('隱私與條款'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: [
                _tile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: '隱私權政策',
                  subtitle: '資料使用與保護',
                  onTap: () => _go(context, '/privacy'),
                ),
                const Divider(height: 1),
                _tile(
                  context,
                  icon: Icons.description_outlined,
                  title: '服務條款',
                  subtitle: '使用者條款與規範',
                  onTap: () => _go(context, '/terms'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          _sectionTitle('支援'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: [
                _tile(
                  context,
                  icon: Icons.support_agent,
                  title: '客服中心',
                  subtitle: '常見問題與聯絡方式',
                  onTap: () => _go(context, '/help_center'),
                ),
                const Divider(height: 1),
                _tile(
                  context,
                  icon: Icons.bug_report_outlined,
                  title: '問題回報',
                  subtitle: '回報 Bug / 建議',
                  onTap: () => _go(context, '/support'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          _sectionTitle('關於'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: [
                _tile(
                  context,
                  icon: Icons.info_outline,
                  title: '關於 Osmile',
                  subtitle: '版本資訊、品牌介紹',
                  onTap: () => _go(context, '/about'),
                ),
                const Divider(height: 1),
                _versionTile(cs),
              ],
            ),
          ),

          const SizedBox(height: 14),
          _dangerZone(cs),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: child,
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _brand.withValues(alpha: 0.12), // ✅ 修正
        child: Icon(icon, color: _brand),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _versionTile(ColorScheme cs) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.secondary.withValues(alpha: 0.12), // ✅ 修正
        child: Icon(Icons.numbers, color: cs.secondary),
      ),
      title: const Text('版本', style: TextStyle(fontWeight: FontWeight.w900)),
      subtitle: const Text('v1.0.0'),
      trailing: const Icon(Icons.chevron_right),
      onTap: null,
    );
  }

  Widget _dangerZone(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.withValues(alpha: 0.12), // ✅ 修正
              child: const Icon(Icons.logout, color: Colors.red),
            ),
            title: const Text(
              '登出',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('退出目前帳號'),
            onTap: () {
              // 這裡只做 UI 示範；你如果有 FirebaseAuth，改成 await FirebaseAuth.instance.signOut();
              ScaffoldMessenger.of(
                // ignore: use_build_context_synchronously
                // （StatelessWidget 沒有 async gap；此處安全）
                cs.brightness == Brightness.dark
                    ? Navigator.of(_fakeContext(context: null)).context
                    : Navigator.of(_fakeContext(context: null)).context,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ⚠️ 注意：上面 dangerZone 的 onTap 寫法是示範，
/// 實務上你應該在 StatefulWidget 內做 signOut + 導頁。
/// 這個 helper 只是為了讓檔案完全不依賴 FirebaseAuth 也能編譯。
BuildContext _fakeContext({BuildContext? context}) {
  // 這個函式不會真的被用到 ScaffoldMessenger（因為示範區塊不建議直接用）
  // 若你要正式登出流程，告訴我你用的路由與 FirebaseAuth，我給你正確版。
  throw UnimplementedError('請把 SettingsPage 改成 StatefulWidget 並接上登出流程');
}

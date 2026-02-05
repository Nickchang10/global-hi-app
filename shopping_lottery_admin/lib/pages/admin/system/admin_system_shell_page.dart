// lib/pages/admin/system/admin_system_shell_page.dart
//
// ✅ AdminSystemShellPage（完整版）
// ------------------------------------------------------------
// - 系統設定整合入口頁（Tab 導覽）
// - 包含：角色與權限、角色指派、系統設定、報表分析
// - 每個頁面都可單獨管理 Firestore 資料
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'admin_roles_page.dart';
import 'admin_role_assign_page.dart';
import 'system_settings_page.dart';
import 'admin_analytics_page.dart';

class AdminSystemShellPage extends StatefulWidget {
  const AdminSystemShellPage({super.key});

  @override
  State<AdminSystemShellPage> createState() => _AdminSystemShellPageState();
}

class _AdminSystemShellPageState extends State<AdminSystemShellPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final _tabs = const [
    Tab(icon: Icon(Icons.security_outlined), text: '角色與權限'),
    Tab(icon: Icon(Icons.people_alt_outlined), text: '角色指派'),
    Tab(icon: Icon(Icons.settings_applications_outlined), text: '系統設定'),
    Tab(icon: Icon(Icons.analytics_outlined), text: '報表分析'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('系統管理中心', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: _tabs,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          AdminRolesPage(),
          AdminRoleAssignPage(),
          SystemSettingsPage(),
          AdminAnalyticsPage(),
        ],
      ),
    );
  }
}

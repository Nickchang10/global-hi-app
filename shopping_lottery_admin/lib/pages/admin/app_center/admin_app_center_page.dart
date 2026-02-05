// lib/pages/admin/app_center/admin_app_center_page.dart
//
// ✅ AdminAppCenterPage（單檔完整版｜可直接使用｜可編譯）
// ------------------------------------------------------------
// App 控制中心（後台入口頁）
// - 顯示各模組狀態（從 Firestore 讀取）
// - ✅ 商城首頁設定：AdminShopHomeSettingsPage
// - ✅ Banner 管理：AdminBannerSettingsPage
// - ✅ 底部導覽列：AdminBottomNavPage
// - ✅ App 功能開關：AdminFeatureTogglesPage
// - ✅ 裝置管理：AdminDeviceManagementPage（已接入）
// - ❌ SOS / 健康模組：已移除（不再顯示）
//
// Firestore：app_config/app_center
// {
//   shopHomeEnabled: true,
//   bannerEnabled: true,
//   bottomNavEnabled: true,
//   featureToggleEnabled: true,
//   deviceMgmtEnabled: true,
//   updatedAt: Timestamp,
//   updatedBy: "uid"
// }
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ✅ 商城首頁設定
import '../shop/admin_shop_home_settings_page.dart';
// ✅ Banner 管理
import '../shop/admin_banner_settings_page.dart';
// ✅ 底部導覽列
import 'admin_bottom_nav_page.dart';
// ✅ App 功能開關
import 'admin_feature_toggles_page.dart';
// ✅ 裝置管理（新接入）
import 'admin_device_management_page.dart';

class AdminAppCenterPage extends StatefulWidget {
  const AdminAppCenterPage({super.key});

  @override
  State<AdminAppCenterPage> createState() => _AdminAppCenterPageState();
}

class _AdminAppCenterPageState extends State<AdminAppCenterPage> {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _cfgRef =>
      _db.collection('app_config').doc('app_center');

  static const Map<String, dynamic> _defaults = {
    'shopHomeEnabled': true,
    'bannerEnabled': true,
    'bottomNavEnabled': true,
    'featureToggleEnabled': true,
    'deviceMgmtEnabled': true,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App 控制中心', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _cfgRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              title: '載入失敗',
              message: snap.error.toString(),
              hint: '請確認 Firestore 權限與網路狀態。',
              onRetry: () => setState(() {}),
            );
          }

          final exists = snap.data?.exists == true;
          final data = <String, dynamic>{
            ..._defaults,
            ...(snap.data?.data() ?? const <String, dynamic>{}),
          };

          final updatedAt = _toDateTime(data['updatedAt']);
          final updatedText =
              updatedAt == null ? '—' : DateFormat('yyyy/MM/dd HH:mm').format(updatedAt);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _HeaderCard(
                exists: exists,
                updatedText: updatedText,
                onInit: exists ? null : _initDocIfMissing,
              ),
              const SizedBox(height: 12),

              const _SectionTitle(
                title: '模組總覽',
                subtitle: '集中管理 App 端顯示與功能入口',
              ),
              const SizedBox(height: 8),

              _ModuleTile(
                icon: Icons.home_outlined,
                title: '商城首頁設定',
                subtitle: '首頁區塊與推薦商品顯示策略',
                enabled: _asBool(data['shopHomeEnabled']),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminShopHomeSettingsPage()),
                  );
                },
              ),
              _ModuleTile(
                icon: Icons.photo_library_outlined,
                title: 'Banner 管理',
                subtitle: '輪播圖與跳轉連結設定',
                enabled: _asBool(data['bannerEnabled']),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminBannerSettingsPage()),
                  );
                },
              ),
              _ModuleTile(
                icon: Icons.view_carousel_outlined,
                title: '底部導覽列',
                subtitle: 'Tab 顯示與排序設定',
                enabled: _asBool(data['bottomNavEnabled']),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminBottomNavPage()),
                  );
                },
              ),
              _ModuleTile(
                icon: Icons.tune_outlined,
                title: 'App 功能開關',
                subtitle: '模組開關與灰度控制',
                enabled: _asBool(data['featureToggleEnabled']),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminFeatureTogglesPage()),
                  );
                },
              ),

              // ✅ 裝置管理（已接入真頁面）
              _ModuleTile(
                icon: Icons.watch_outlined,
                title: '裝置管理',
                subtitle: '綁定清單、狀態與韌體版本',
                enabled: _asBool(data['deviceMgmtEnabled']),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminDeviceManagementPage()),
                  );
                },
              ),

              const SizedBox(height: 20),

              const _SectionTitle(
                title: '快速設定',
                subtitle: '快速調整各模組開關狀態（寫入 app_config/app_center）',
              ),
              const SizedBox(height: 8),

              _QuickTogglesCard(
                initial: data,
                onSave: _savePatch,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _initDocIfMissing() async {
    await _cfgRef.set(
      {
        ..._defaults,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _savePatch(Map<String, dynamic> patch) async {
    await _cfgRef.set(
      {
        ...patch,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static bool _asBool(dynamic v) => v == true;

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}

// ============================================================
// Widgets
// ============================================================

class _HeaderCard extends StatelessWidget {
  final bool exists;
  final String updatedText;
  final VoidCallback? onInit;

  const _HeaderCard({
    required this.exists,
    required this.updatedText,
    this.onInit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.settings_applications_outlined, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exists ? 'App 控制中心設定已啟用' : '尚未建立設定文件',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '更新時間：$updatedText',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!exists && onInit != null)
              FilledButton.tonalIcon(
                onPressed: onInit,
                icon: const Icon(Icons.add),
                label: const Text('初始化設定文件'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: enabled ? cs.primaryContainer : Colors.grey.shade200,
          child: Icon(icon, color: enabled ? cs.onPrimaryContainer : Colors.grey),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
        trailing: _StatusPill(enabled: enabled),
        onTap: onTap,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool enabled;

  const _StatusPill({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = enabled ? Colors.green.shade100 : Colors.grey.shade200;
    final fg = enabled ? Colors.green.shade900 : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        enabled ? '啟用' : '停用',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg),
      ),
    );
  }
}

class _QuickTogglesCard extends StatefulWidget {
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _QuickTogglesCard({
    required this.initial,
    required this.onSave,
  });

  @override
  State<_QuickTogglesCard> createState() => _QuickTogglesCardState();
}

class _QuickTogglesCardState extends State<_QuickTogglesCard> {
  late bool shopHome, banner, bottomNav, featureToggle, deviceMgmt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    shopHome = widget.initial['shopHomeEnabled'] == true;
    banner = widget.initial['bannerEnabled'] == true;
    bottomNav = widget.initial['bottomNavEnabled'] == true;
    featureToggle = widget.initial['featureToggleEnabled'] == true;
    deviceMgmt = widget.initial['deviceMgmtEnabled'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _switch('商城首頁設定', shopHome, (v) => setState(() => shopHome = v)),
            _switch('Banner 管理', banner, (v) => setState(() => banner = v)),
            _switch('底部導覽列', bottomNav, (v) => setState(() => bottomNav = v)),
            _switch('App 功能開關', featureToggle, (v) => setState(() => featureToggle = v)),
            _switch('裝置管理', deviceMgmt, (v) => setState(() => deviceMgmt = v)),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await widget.onSave({
                          'shopHomeEnabled': shopHome,
                          'bannerEnabled': banner,
                          'bottomNavEnabled': bottomNav,
                          'featureToggleEnabled': featureToggle,
                          'deviceMgmtEnabled': deviceMgmt,
                        });
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              icon: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '儲存中...' : '儲存設定'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(String t, bool v, ValueChanged<bool> c) {
    return SwitchListTile(
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
      value: v,
      onChanged: c,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? hint;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 44, color: cs.error),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              if (hint != null) ...[
                const SizedBox(height: 6),
                Text(hint!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重試'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

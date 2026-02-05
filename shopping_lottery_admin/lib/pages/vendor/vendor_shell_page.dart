// lib/pages/vendor/vendor_shell_page.dart
//
// ✅ VendorShellPage（最終完整版｜可編譯｜reports 已接 VendorRevenuePage）
// ------------------------------------------------------------
// - Vendor 後台主框架（Bottom Tabs + IndexedStack）
// - 讀取 Firestore：app_config/home_layout
//   - footerTabs: List<Map> 用來動態控制底部 tabs（顯示/順序/文字/圖示）
// - 若 config 不存在或格式錯誤 → fallback 使用預設 tabs
// - 內建：登出
//
// Firestore 建議格式（app_config/home_layout）
// ------------------------------------------------------------
// {
//   "footerTabsEnabled": true,
//   "footerTabs": [
//     {"key":"dashboard","label":"儀表板","icon":"dashboard"},
//     {"key":"products","label":"商品","icon":"inventory_2"},
//     {"key":"orders","label":"訂單","icon":"receipt_long"},
//     {"key":"reports","label":"報表","icon":"bar_chart"},
//     {"key":"settings","label":"設定","icon":"settings"}
//   ]
// }
//
// ✅ reports：已改為 VendorRevenuePage（避免 vendorIds + status 複合查詢索引問題）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ✅ 確認此檔案存在：lib/pages/vendor/vendor_revenue_page.dart
import 'vendor_revenue_page.dart';

class VendorShellPage extends StatefulWidget {
  const VendorShellPage({super.key});

  @override
  State<VendorShellPage> createState() => _VendorShellPageState();
}

class _VendorShellPageState extends State<VendorShellPage> {
  int _index = 0;

  DocumentReference<Map<String, dynamic>> get _layoutRef =>
      FirebaseFirestore.instance.doc('app_config/home_layout');

  // 預設 tabs（當 Firestore 沒配置或格式錯誤）
  List<_FooterTab> _defaultTabs() => const [
        _FooterTab(key: 'dashboard', label: '儀表板', iconName: 'dashboard'),
        _FooterTab(key: 'products', label: '商品', iconName: 'inventory_2'),
        _FooterTab(key: 'orders', label: '訂單', iconName: 'receipt_long'),
        _FooterTab(key: 'reports', label: '報表', iconName: 'bar_chart'),
        _FooterTab(key: 'settings', label: '設定', iconName: 'settings'),
      ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _layoutRef.snapshots(),
      builder: (context, snap) {
        final tabs = _buildTabsFromConfig(snap.data?.data()) ?? _defaultTabs();

        // 防止 index 超出（例如 config 動態減少 tab）
        final safeIndex = _index.clamp(0, (tabs.isEmpty ? 1 : tabs.length) - 1);
        if (safeIndex != _index) _index = safeIndex;

        final current = tabs.isEmpty ? null : tabs[_index];

        return Scaffold(
          appBar: AppBar(
            title: Text(
              current == null ? 'Vendor' : 'Vendor｜${current.label}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              IconButton(
                tooltip: '登出',
                icon: const Icon(Icons.logout),
                onPressed: _signOut,
              ),
            ],
          ),
          body: tabs.isEmpty
              ? const Center(child: Text('尚未配置任何 footerTabs'))
              : IndexedStack(
                  index: _index,
                  children: tabs.map((t) => _buildTabBody(t)).toList(),
                ),
          bottomNavigationBar: tabs.isEmpty
              ? null
              : BottomNavigationBar(
                  currentIndex: _index,
                  type: BottomNavigationBarType.fixed,
                  onTap: (i) => setState(() => _index = i),
                  items: tabs
                      .map(
                        (t) => BottomNavigationBarItem(
                          icon: Icon(_iconFromName(t.iconName)),
                          label: t.label,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // FooterTabs config loader
  // ------------------------------------------------------------

  List<_FooterTab>? _buildTabsFromConfig(Map<String, dynamic>? cfg) {
    try {
      if (cfg == null) return null;

      final enabled = cfg['footerTabsEnabled'];
      if (enabled is bool && enabled == false) {
        // 明確關閉 footerTabs → 回傳空，讓 UI 顯示「未配置」
        return const <_FooterTab>[];
      }

      final raw = cfg['footerTabs'];
      if (raw is! List) return null;

      final out = <_FooterTab>[];
      for (final it in raw) {
        if (it is! Map) continue;
        final m = Map<String, dynamic>.from(it as Map);

        final key = (m['key'] ?? '').toString().trim();
        final label = (m['label'] ?? '').toString().trim();
        final icon = (m['icon'] ?? '').toString().trim();

        if (key.isEmpty) continue;

        out.add(
          _FooterTab(
            key: key,
            label: label.isEmpty ? key : label,
            iconName: icon.isEmpty ? 'circle' : icon,
          ),
        );
      }

      return out;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------
  // Tab bodies
  // ------------------------------------------------------------

  Widget _buildTabBody(_FooterTab tab) {
    switch (tab.key) {
      case 'dashboard':
        return const _VendorDashboardPlaceholder();

      case 'products':
        return const _VendorProductsPlaceholder();

      case 'orders':
        return const _VendorOrdersPlaceholder();

      case 'reports':
        // ✅ 這裡正式接到 VendorRevenuePage
        //    （避免 vendorIds + status 的複合查詢索引）
        return const VendorRevenuePage();

      case 'settings':
        return const _VendorSettingsPlaceholder();

      default:
        return _UnknownTabPlaceholder(keyName: tab.key);
    }
  }

  // ------------------------------------------------------------
  // Auth
  // ------------------------------------------------------------

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (!mounted) return;

    // 交給 VendorGate / AuthRouter 導回登入頁
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已登出')),
    );
  }
}

// ===================================================================
// Models
// ===================================================================

class _FooterTab {
  final String key;
  final String label;
  final String iconName;

  const _FooterTab({
    required this.key,
    required this.label,
    required this.iconName,
  });
}

// ===================================================================
// Icon mapping（字串 → Material icon）
// ===================================================================

IconData _iconFromName(String name) {
  final n = name.trim().toLowerCase();

  const map = <String, IconData>{
    'dashboard': Icons.dashboard_rounded,
    'home': Icons.home_rounded,

    'inventory': Icons.inventory_2_rounded,
    'inventory_2': Icons.inventory_2_rounded,
    'products': Icons.inventory_2_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'store': Icons.store_rounded,

    'orders': Icons.receipt_long_rounded,
    'receipt': Icons.receipt_long_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'list': Icons.list_alt_rounded,

    'reports': Icons.bar_chart_rounded,
    'bar_chart': Icons.bar_chart_rounded,
    'analytics': Icons.analytics_rounded,

    'settings': Icons.settings_rounded,
    'person': Icons.person_rounded,

    'notifications': Icons.notifications_rounded,
    'support': Icons.support_agent_rounded,
    'help': Icons.help_outline_rounded,

    'circle': Icons.circle,
  };

  return map[n] ?? Icons.circle;
}

// ===================================================================
// Placeholders（確保本檔案單獨可編譯）
// 你之後有完整頁面再替換掉即可
// ===================================================================

class _VendorDashboardPlaceholder extends StatelessWidget {
  const _VendorDashboardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScaffold(
      title: 'Vendor 儀表板（Placeholder）',
      desc: '下一步可替換為 vendor_dashboard_page.dart。',
    );
  }
}

class _VendorProductsPlaceholder extends StatelessWidget {
  const _VendorProductsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScaffold(
      title: 'Vendor 商品管理（Placeholder）',
      desc: '下一步可替換為 vendor_products_page.dart。',
    );
  }
}

class _VendorOrdersPlaceholder extends StatelessWidget {
  const _VendorOrdersPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScaffold(
      title: 'Vendor 訂單列表（Placeholder）',
      desc: '下一步可替換為 vendor_orders_page.dart。',
    );
  }
}

class _VendorSettingsPlaceholder extends StatelessWidget {
  const _VendorSettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScaffold(
      title: 'Vendor 設定（Placeholder）',
      desc: '可放：商店資訊、通知測試、客服、登出等。',
    );
  }
}

class _UnknownTabPlaceholder extends StatelessWidget {
  final String keyName;
  const _UnknownTabPlaceholder({required this.keyName});

  @override
  Widget build(BuildContext context) {
    return _PlaceholderScaffold(
      title: '未知 Tab：$keyName',
      desc: '請檢查 app_config/home_layout.footerTabs.key 是否拼錯，或在 VendorShellPage 增加對應頁面。',
    );
  }
}

class _PlaceholderScaffold extends StatelessWidget {
  final String title;
  final String desc;

  const _PlaceholderScaffold({
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(desc),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// ✅ DashboardPage（主控台/首頁殼｜完整版｜修正 categories_page.dart 不存在）
/// ------------------------------------------------------------
/// 修正：移除 `import 'categories_page.dart';`
/// 改成：在本檔案內提供 CategoriesPage（避免缺檔造成編譯失敗）
///
/// 你之後如果真的要獨立檔案：
/// - 再把 CategoriesPage 拆出去成 categories_page.dart
/// - 然後把本檔案內的 CategoriesPage 刪掉再 import 回來
/// ------------------------------------------------------------
class DashboardPage extends StatefulWidget {
  /// 可選：指定預設分頁 index（0=首頁 1=分類 2=購物車 3=我的）
  final int initialIndex;

  const DashboardPage({super.key, this.initialIndex = 0});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardHomePage(),
      const CategoriesPage(),
      const CartPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '首頁'),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            label: '分類',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: '購物車',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

/// ------------------------------
/// 以下是「內建替代頁面」：避免缺檔無法編譯
/// 你可以先用這些占位，之後再換成你專案真正的頁面
/// ------------------------------

class DashboardHomePage extends StatelessWidget {
  const DashboardHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首頁'),
        actions: [
          IconButton(
            tooltip: '搜尋',
            onPressed: () {
              // 你如果有搜尋頁路由，可直接改成 pushNamed
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('尚未接搜尋頁')));
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heroCard(
            title: 'Osmile 商城',
            subtitle: '先把專案修到可編譯，再逐頁補齊功能 ✅',
            icon: Icons.storefront_outlined,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _quickAction(
                context,
                icon: Icons.local_offer_outlined,
                label: '我的優惠券',
                routeName: '/coupons',
              ),
              _quickAction(
                context,
                icon: Icons.checklist_outlined,
                label: '每日任務',
                routeName: '/daily_mission',
              ),
              _quickAction(
                context,
                icon: Icons.chat_bubble_outline,
                label: '聊天室',
                routeName: '/chat',
              ),
              _quickAction(
                context,
                icon: Icons.receipt_long_outlined,
                label: '我的訂單',
                routeName: '/orders',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '提示：如果你還沒建立以上路由，點擊會只顯示提醒，不會崩潰。',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _heroCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              // ✅ 修正：withOpacity → withValues(alpha: ...)
              backgroundColor: Colors.blue.withValues(alpha: 0.10),
              child: Icon(icon, color: Colors.blueGrey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String routeName,
  }) {
    return SizedBox(
      width: 160,
      height: 88,
      child: InkWell(
        onTap: () {
          // ✅ 避免路由不存在導致 runtime error：try-catch
          try {
            Navigator.of(context).pushNamed(routeName);
          } catch (_) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('路由不存在：$routeName')));
          }
        },
        child: Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: Colors.blueGrey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ 修正：prefer_const_declarations
    const demo = [
      {'name': '手錶', 'icon': Icons.watch},
      {'name': '配件', 'icon': Icons.headphones},
      {'name': '保護', 'icon': Icons.shield_outlined},
      {'name': '方案', 'icon': Icons.sim_card_outlined},
      {'name': '活動', 'icon': Icons.campaign_outlined},
      {'name': '抽獎', 'icon': Icons.casino_outlined},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('分類')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.3,
        ),
        itemCount: demo.length,
        itemBuilder: (context, i) {
          final c = demo[i];
          return InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('點選分類：${c['name']}（尚未接商品列表）')),
              );
            },
            child: Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(c['icon'] as IconData, color: Colors.blueGrey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('購物車')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      size: 56,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '購物車頁（占位版）',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '你可以把真正的購物車頁替換進來。',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        try {
                          Navigator.of(context).pushNamed('/checkout');
                        } catch (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('路由不存在：/checkout')),
                          );
                        }
                      },
                      child: const Text('前往結帳（若有路由）'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ 修正：這整張 Card 內容全是常數 → Card 可加 const（解 prefer_const_constructors）
          const Card(
            elevation: 1,
            child: ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                '個人中心（占位版）',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('之後可接：登入狀態、會員等級、積分、訂單'),
            ),
          ),
          const SizedBox(height: 12),
          _menu(
            context,
            icon: Icons.local_offer_outlined,
            title: '我的優惠券',
            route: '/coupons',
          ),
          _menu(
            context,
            icon: Icons.checklist_outlined,
            title: '每日任務',
            route: '/daily_mission',
          ),
          _menu(
            context,
            icon: Icons.credit_card_outlined,
            title: '卡片管理',
            route: '/cards',
          ),
          _menu(
            context,
            icon: Icons.settings_outlined,
            title: '設定',
            route: '/settings',
          ),
        ],
      ),
    );
  }

  Widget _menu(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    return Card(
      elevation: 1,
      child: ListTile(
        leading: Icon(icon, color: Colors.blueGrey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          try {
            Navigator.of(context).pushNamed(route);
          } catch (_) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('路由不存在：$route')));
          }
        },
      ),
    );
  }
}

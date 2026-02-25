// lib/widgets/remote_bottom_nav_bar.dart
//
// ✅ RemoteBottomNavBar（最終可編譯版｜移除 AI｜保留下單所需 3 Tab）
// ------------------------------------------------------------
// 修正：library_private_types_in_public_api
// - public class 的 createState() 回傳 private State 型別會噴警告
// - 解法：State 類別改成 public：RemoteBottomNavBarState ✅
//
// 預設 Tab：商城 / 購物車 / 客服
// - 若你在 Shell 有傳入 destinations，會以傳入的為準

import 'package:flutter/material.dart';

class RemoteBottomNavBar extends StatefulWidget {
  const RemoteBottomNavBar({
    super.key,
    required this.index,
    required this.onChanged,
    this.destinations,
    this.showLabels = true,
  });

  final int index;
  final ValueChanged<int> onChanged;

  /// 允許你自訂 destinations（不傳則用預設 3 個：商城/購物車/客服）
  final List<NavigationDestination>? destinations;

  final bool showLabels;

  @override
  RemoteBottomNavBarState createState() => RemoteBottomNavBarState();
}

// ✅ public State：解掉 library_private_types_in_public_api
class RemoteBottomNavBarState extends State<RemoteBottomNavBar> {
  static const List<NavigationDestination> _defaultDestinations =
      <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: '商城',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_cart_outlined),
          selectedIcon: Icon(Icons.shopping_cart),
          label: '購物車',
        ),
        NavigationDestination(
          icon: Icon(Icons.support_agent_outlined),
          selectedIcon: Icon(Icons.support_agent),
          label: '客服',
        ),
      ];

  List<NavigationDestination> get _destinations =>
      (widget.destinations == null || widget.destinations!.isEmpty)
      ? _defaultDestinations
      : widget.destinations!;

  @override
  Widget build(BuildContext context) {
    final dests = _destinations;
    if (dests.isEmpty) return const SizedBox.shrink();

    final idx = widget.index.clamp(0, dests.length - 1);

    return NavigationBar(
      selectedIndex: idx,
      onDestinationSelected: widget.onChanged,
      destinations: dests,
      labelBehavior: widget.showLabels
          ? NavigationDestinationLabelBehavior.alwaysShow
          : NavigationDestinationLabelBehavior.alwaysHide,
    );
  }
}

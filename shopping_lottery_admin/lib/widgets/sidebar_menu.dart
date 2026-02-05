import 'package:flutter/material.dart';

class SidebarMenu extends StatelessWidget {
  final String selected;
  const SidebarMenu({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final menus = [
      '儀表板',
      '最新消息',
      '商品管理',
      '客服回覆',
      '會員名單',
      '通知中心',
      '設定',
    ];
    return Container(
      width: 220,
      color: Colors.blueGrey.shade900,
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text('Osmile 後台',
              style: TextStyle(color: Colors.white, fontSize: 18)),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView(
              children: menus.map((m) {
                final isSel = m == selected;
                return ListTile(
                  selected: isSel,
                  selectedTileColor: Colors.blueGrey.shade700,
                  title: Text(
                    m,
                    style: TextStyle(
                        color: isSel ? Colors.white : Colors.white70,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                  ),
                  onTap: () {},
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

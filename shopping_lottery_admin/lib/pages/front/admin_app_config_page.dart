// lib/pages/front/admin_app_config_page.dart
//
// ✅ Osmile 商城控制中心（完整版）
// ------------------------------------------------------------
// 功能：
// - 控制商城 App 首頁模組顯示、排序、導覽列、橫幅設定
// - 即時寫入 Firestore（app_config/home_layout）
// - 使用 ReorderableListView 拖曳排序
// - 模組開關 SwitchListTile
// - Banner URL 管理（新增/刪除）
//
// 依賴：cloud_firestore, firebase_auth, flutter/material
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAppConfigPage extends StatefulWidget {
  const AdminAppConfigPage({super.key});

  @override
  State<AdminAppConfigPage> createState() => _AdminAppConfigPageState();
}

class _AdminAppConfigPageState extends State<AdminAppConfigPage> {
  final _db = FirebaseFirestore.instance;
  bool _loading = false;

  Future<void> _updateConfig(Map<String, dynamic> data) async {
    setState(() => _loading = true);
    await _db.collection('app_config').doc('home_layout').set(data);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商城控制中心')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('app_config').doc('home_layout').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('尚未設定商城版面配置'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final banners = List<String>.from(data['banners'] ?? []);
          final modules = List<Map<String, dynamic>>.from(
            (data['modules'] ?? []).map((e) => Map<String, dynamic>.from(e)),
          );
          final footerTabs = List<String>.from(data['footerTabs'] ?? []);

          return _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('首頁橫幅設定',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...banners.map((url) => ListTile(
                          title: Text(url),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              final updated = [...banners]..remove(url);
                              _updateConfig({
                                ...data,
                                'banners': updated,
                              });
                            },
                          ),
                        )),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('新增橫幅 URL'),
                      onPressed: () async {
                        final controller = TextEditingController();
                        final url = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('新增橫幅 URL'),
                            content: TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                  hintText: 'https://example.com/banner.jpg'),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, controller.text),
                                  child: const Text('確定')),
                            ],
                          ),
                        );
                        if (url != null && url.isNotEmpty) {
                          final updated = [...banners, url];
                          _updateConfig({...data, 'banners': updated});
                        }
                      },
                    ),
                    const Divider(height: 32),

                    const Text('首頁模組顯示與排序',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = modules.removeAt(oldIndex);
                          modules.insert(newIndex, item);
                          _updateConfig({...data, 'modules': modules});
                        });
                      },
                      children: [
                        for (final mod in modules)
                          SwitchListTile(
                            key: ValueKey(mod['id']),
                            title: Text(mod['label']),
                            value: mod['enabled'] ?? true,
                            onChanged: (v) {
                              mod['enabled'] = v;
                              _updateConfig({...data, 'modules': modules});
                            },
                            secondary: const Icon(Icons.drag_handle),
                          )
                      ],
                    ),

                    const Divider(height: 32),
                    const Text('底部導覽列控制',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final tab in [
                          'home',
                          'shop',
                          'task',
                          'interact',
                          'mine'
                        ])
                          FilterChip(
                            label: Text(tab),
                            selected: footerTabs.contains(tab),
                            onSelected: (selected) {
                              final updated = [...footerTabs];
                              if (selected) {
                                updated.add(tab);
                              } else {
                                updated.remove(tab);
                              }
                              _updateConfig({
                                ...data,
                                'footerTabs': updated,
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                );
        },
      ),
    );
  }
}

// lib/pages/admin_settings_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _ref = FirebaseFirestore.instance.collection('settings').doc('global');
  bool _loading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await _ref.get();
      setState(() {
        _data = doc.data() ?? {};
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack('讀取設定失敗：$e');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _update(String key, dynamic value) async {
    try {
      await _ref.set({key: value}, SetOptions(merge: true));
      setState(() => _data[key] = value);
      _snack('已更新 $key');
    } catch (e) {
      _snack('更新失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('系統設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('首頁顯示設定',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('顯示公告'),
            subtitle: const Text('控制首頁公告區塊是否顯示'),
            value: (_data['showAnnouncements'] ?? true) == true,
            onChanged: (v) => _update('showAnnouncements', v),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('顯示最新通知'),
            subtitle: const Text('控制首頁通知區是否啟用'),
            value: (_data['showNotifications'] ?? true) == true,
            onChanged: (v) => _update('showNotifications', v),
          ),
          const Divider(),
          ListTile(
            title: const Text('首頁通知顯示數量'),
            subtitle: const Text('設定首頁可顯示的通知筆數'),
            trailing: DropdownButton<int>(
              value: (_data['notificationLimit'] ?? 2) as int,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1')),
                DropdownMenuItem(value: 2, child: Text('2')),
                DropdownMenuItem(value: 3, child: Text('3')),
                DropdownMenuItem(value: 5, child: Text('5')),
              ],
              onChanged: (v) => _update('notificationLimit', v),
            ),
          ),
          const Divider(height: 20),
          const Text('外觀設定',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ListTile(
            title: const Text('主題模式'),
            subtitle: const Text('切換亮色／暗色'),
            trailing: DropdownButton<String>(
              value: (_data['themeMode'] ?? 'light') as String,
              items: const [
                DropdownMenuItem(value: 'light', child: Text('亮色')),
                DropdownMenuItem(value: 'dark', child: Text('暗色')),
              ],
              onChanged: (v) => _update('themeMode', v),
            ),
          ),
          const Divider(height: 20),
          const Text('系統資訊',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            subtitle: Text(_data['appVersion'] ?? '1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: const Text('Firebase 連線狀態'),
            subtitle: Text(
              FirebaseFirestore.instance.app.name.isNotEmpty
                  ? '已連線'
                  : '未連線',
              style: TextStyle(color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

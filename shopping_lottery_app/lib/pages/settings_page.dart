// lib/pages/settings_page.dart
// =======================================================
// ✅ Osmile App - 設定頁（完整版）
// -------------------------------------------------------
// 功能：
// - 開關通知推播
// - 開關觸覺與音效回饋
// - 一鍵清除通知
// - 顯示帳號資訊、隱私條款
// - 模擬登出 / 清除資料
// =======================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../services/firestore_mock_service.dart';
import '../utils/haptic_audio_feedback.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _hapticsEnabled = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('settings_notifications') ?? true;
      _hapticsEnabled = prefs.getBool('settings_haptics') ?? true;
      _initialized = true;
    });
    HapticAudioFeedback.setEnabled(_hapticsEnabled);
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_notifications', _notificationsEnabled);
    await prefs.setBool('settings_haptics', _hapticsEnabled);
  }

  Future<void> _confirmClearNotifications(BuildContext context) async {
    final service = NotificationService.instance;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清除所有通知'),
        content: const Text('確定要刪除所有通知紀錄嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );

    if (result == true) {
      service.clearAll();
      HapticAudioFeedback.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('所有通知已清除'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('登出確認'),
        content: const Text('確定要登出帳號嗎？本地資料將被清空。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('登出'),
          ),
        ],
      ),
    );

    if (result == true) {
      HapticAudioFeedback.warning();
      await FirestoreMockService.instance.reset();
      NotificationService.instance.clearAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已登出並清除本地資料'),
            backgroundColor: Colors.grey,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final notificationService = context.watch<NotificationService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('設定'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          // ======================================================
          // 🔔 通知設定
          // ======================================================
          _buildSectionTitle('通知'),
          SwitchListTile(
            title: const Text('啟用通知中心'),
            subtitle: const Text('控制是否接收應用內通知'),
            value: _notificationsEnabled,
            activeColor: Colors.blueAccent,
            onChanged: (v) {
              setState(() => _notificationsEnabled = v);
              HapticAudioFeedback.feedback();
              _savePrefs();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            title: const Text('清除所有通知'),
            subtitle: Text('目前共 ${notificationService.notifications.length} 筆通知'),
            onTap: () => _confirmClearNotifications(context),
          ),
          const Divider(),

          // ======================================================
          // 🎧 觸覺 / 音效設定
          // ======================================================
          _buildSectionTitle('觸覺與音效'),
          SwitchListTile(
            title: const Text('啟用觸覺回饋'),
            subtitle: const Text('操作時震動與音效提示'),
            value: _hapticsEnabled,
            activeColor: Colors.blueAccent,
            onChanged: (v) {
              setState(() => _hapticsEnabled = v);
              HapticAudioFeedback.setEnabled(v);
              HapticAudioFeedback.feedback();
              _savePrefs();
            },
          ),
          const Divider(),

          // ======================================================
          // 👤 帳號設定
          // ======================================================
          _buildSectionTitle('帳號'),
          ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.teal),
            title: const Text('使用者資訊'),
            subtitle: Text('ID: demo_user\n積分：${FirestoreMockService.instance.userPoints}'),
            onTap: () {
              HapticAudioFeedback.selection();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('使用者資訊'),
                  content: Text(
                    '用戶ID：demo_user\n積分：${FirestoreMockService.instance.userPoints}\n\n資料僅用於本地模擬測試。',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('關閉'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_outlined, color: Colors.redAccent),
            title: const Text('登出並清除資料'),
            onTap: () => _logout(context),
          ),
          const Divider(),

          // ======================================================
          // ⚙️ 系統資訊
          // ======================================================
          _buildSectionTitle('系統'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Colors.grey),
            title: const Text('隱私權政策'),
            onTap: () {
              HapticAudioFeedback.selection();
              showAboutDialog(
                context: context,
                applicationName: 'Osmile Shopping App',
                applicationVersion: 'v1.0.0',
                children: const [
                  Text('本應用為示範用途，所有資料皆為模擬環境。\n不會上傳任何使用者資料。'),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.grey),
            title: const Text('版本資訊'),
            subtitle: const Text('Osmile App v1.0.0 (Stable)'),
            onTap: () {
              HapticAudioFeedback.feedback();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('您已安裝最新版本'),
                  backgroundColor: Colors.blueAccent,
                ),
              );
            },
          ),

          const SizedBox(height: 30),
          Center(
            child: Text(
              '© 2025 Osmile Inc. All rights reserved.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          fontSize: 14,
        ),
      ),
    );
  }
}

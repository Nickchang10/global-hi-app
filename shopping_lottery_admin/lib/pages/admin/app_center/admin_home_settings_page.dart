// lib/pages/admin/app_center/admin_home_settings_page.dart
//
// ✅ AdminHomeSettingsPage（A. 基礎專業版｜可編譯｜Firestore 寫回版）
// ------------------------------------------------------------
// 功能：
// - Firestore 文件位置：app_config/home_settings
// - 管理商城首頁顯示區塊（Banner / 推薦商品 / 活動入口）
// - 即時顯示 Firestore 狀態
// - 可修改標題、顯示順序、開關啟用
// ------------------------------------------------------------
//
// Firestore 結構建議：
// app_config/home_settings
// {
//   bannerSectionEnabled: true,
//   recommendedSectionEnabled: true,
//   eventSectionEnabled: true,
//   bannerTitle: "本週焦點",
//   recommendedTitle: "推薦商品",
//   eventTitle: "活動專區",
//   updatedAt: Timestamp
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminHomeSettingsPage extends StatefulWidget {
  const AdminHomeSettingsPage({super.key});

  @override
  State<AdminHomeSettingsPage> createState() => _AdminHomeSettingsPageState();
}

class _AdminHomeSettingsPageState extends State<AdminHomeSettingsPage> {
  final _db = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('home_settings');

  final _titleControllers = {
    'banner': TextEditingController(),
    'recommended': TextEditingController(),
    'event': TextEditingController(),
  };

  bool _bannerEnabled = true;
  bool _recommendedEnabled = true;
  bool _eventEnabled = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    for (final c in _titleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await _ref.get();
      final d = doc.data() ?? {};

      setState(() {
        _bannerEnabled = d['bannerSectionEnabled'] ?? true;
        _recommendedEnabled = d['recommendedSectionEnabled'] ?? true;
        _eventEnabled = d['eventSectionEnabled'] ?? true;

        _titleControllers['banner']!.text = d['bannerTitle'] ?? '本週焦點';
        _titleControllers['recommended']!.text = d['recommendedTitle'] ?? '推薦商品';
        _titleControllers['event']!.text = d['eventTitle'] ?? '活動專區';
        _updatedAt = (d['updatedAt'] is Timestamp)
            ? (d['updatedAt'] as Timestamp).toDate()
            : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    try {
      await _ref.set({
        'bannerSectionEnabled': _bannerEnabled,
        'recommendedSectionEnabled': _recommendedEnabled,
        'eventSectionEnabled': _eventEnabled,
        'bannerTitle': _titleControllers['banner']!.text.trim(),
        'recommendedTitle': _titleControllers['recommended']!.text.trim(),
        'eventTitle': _titleControllers['event']!.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已儲存設定')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Text('載入失敗：$_error'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('商城首頁設定', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新整理',
            onPressed: _loadConfig,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '上次更新：${DateFormat('yyyy/MM/dd HH:mm').format(_updatedAt!)}',
                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
          _sectionTile(
            icon: Icons.photo_library_outlined,
            title: 'Banner 區塊',
            enabled: _bannerEnabled,
            onToggle: (v) => setState(() => _bannerEnabled = v),
            controller: _titleControllers['banner']!,
          ),
          _sectionTile(
            icon: Icons.recommend_outlined,
            title: '推薦商品區',
            enabled: _recommendedEnabled,
            onToggle: (v) => setState(() => _recommendedEnabled = v),
            controller: _titleControllers['recommended']!,
          ),
          _sectionTile(
            icon: Icons.local_activity_outlined,
            title: '活動專區',
            enabled: _eventEnabled,
            onToggle: (v) => setState(() => _eventEnabled = v),
            controller: _titleControllers['event']!,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _saveConfig,
            icon: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? '儲存中...' : '儲存設定'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTile({
    required IconData icon,
    required String title,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required TextEditingController controller,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                Switch(value: enabled, onChanged: onToggle),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '區塊標題',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

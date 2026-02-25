// lib/pages/admin/sos/admin_sos_notify_settings_page.dart
//
// ✅ AdminSosNotifySettingsPage（SOS 通知設定｜可編譯完整版｜已修正 use_build_context_synchronously）
// ------------------------------------------------------------
// - Firestore 路徑：app_config/sos_notify_settings（可自行改）
// - 讀取 / 編輯 / 儲存（merge）
// - 常見欄位：enabled、notifyEmails、notifyPhones、webhookUrl、updatedAt
//
// ✅ 修正重點：
// - 所有 async gap 後使用 context 的地方：
//   - 先取 messenger / navigator
//   - await 後 if (!mounted) return;
//   - 用 messenger/navigator 顯示 SnackBar 或 pop
//
// 依賴：cloud_firestore
// ------------------------------------------------------------

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSosNotifySettingsPage extends StatefulWidget {
  const AdminSosNotifySettingsPage({super.key});

  @override
  State<AdminSosNotifySettingsPage> createState() =>
      _AdminSosNotifySettingsPageState();
}

class _AdminSosNotifySettingsPageState
    extends State<AdminSosNotifySettingsPage> {
  final _db = FirebaseFirestore.instance;

  // ✅ 依你專案實際路徑調整
  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('sos_notify_settings');

  bool _loading = true;
  bool _busy = false;
  String? _error;

  // data
  bool _enabled = true;
  final _emailsCtrl = TextEditingController(); // 多行，逗號/換行都可
  final _phonesCtrl = TextEditingController(); // 多行
  final _webhookCtrl = TextEditingController(); // 選填
  final _rawJsonCtrl = TextEditingController(); // 檢視用（不長存）

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailsCtrl.dispose();
    _phonesCtrl.dispose();
    _webhookCtrl.dispose();
    _rawJsonCtrl.dispose();
    super.dispose();
  }

  // -----------------------------
  // helpers
  // -----------------------------
  List<String> _splitList(String text) {
    return text
        .split(RegExp(r'[\n,，;；]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  String _prettyJson(Map<String, dynamic> m) =>
      const JsonEncoder.withIndent('  ').convert(m);

  // -----------------------------
  // load / save
  // -----------------------------
  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final doc = await _ref.get();
      final data = doc.data() ?? <String, dynamic>{};

      final enabled = data['enabled'] == true;

      final emails = <String>[];
      final phones = <String>[];

      final rawEmails = data['notifyEmails'];
      final rawPhones = data['notifyPhones'];

      if (rawEmails is List) {
        for (final x in rawEmails) {
          final s = x.toString().trim();
          if (s.isNotEmpty) emails.add(s);
        }
      }
      if (rawPhones is List) {
        for (final x in rawPhones) {
          final s = x.toString().trim();
          if (s.isNotEmpty) phones.add(s);
        }
      }

      final webhook = (data['webhookUrl'] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _emailsCtrl.text = emails.join('\n');
        _phonesCtrl.text = phones.join('\n');
        _webhookCtrl.text = webhook;
        _rawJsonCtrl.text = _prettyJson(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_busy) return;

    // ✅ 先取 messenger，避免 async gap 後再用 context
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      final payload = <String, dynamic>{
        'enabled': _enabled,
        'notifyEmails': _splitList(_emailsCtrl.text),
        'notifyPhones': _splitList(_phonesCtrl.text),
        'webhookUrl': _webhookCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _ref.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已儲存 SOS 通知設定')));
      await _load(); // 重新同步一次
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editRawJson() async {
    final messenger = ScaffoldMessenger.of(context);

    // 先取目前 Firestore 快照（也可以用本地 _rawJsonCtrl.text）
    Map<String, dynamic> current = <String, dynamic>{};
    try {
      final doc = await _ref.get();
      current = doc.data() ?? <String, dynamic>{};
    } catch (_) {}

    if (!mounted) return;

    final ctrl = TextEditingController(text: _prettyJson(current));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '編輯原始 JSON',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 720,
          child: TextField(
            controller: ctrl,
            maxLines: 18,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: '{ ... }',
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('套用'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final parsed = json.decode(ctrl.text) as Map<String, dynamic>;
      await _ref.set(parsed, SetOptions(merge: true));

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('已 merge JSON 到 Firestore')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('JSON 套用失敗：$e')));
    }
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'SOS 通知設定',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Center(child: Text('載入失敗：$_error')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SOS 通知設定',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新載入',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '編輯原始 JSON',
            onPressed: _busy ? null : _editRawJson,
            icon: const Icon(Icons.code),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('儲存'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '總開關',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '啟用 SOS 通知',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      '關閉後，後端仍可寫入 SOS 事件，但此設定可讓前台/後台決定是否發通知',
                    ),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '通知收件人',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailsCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'notifyEmails（每行一個或用逗號分隔）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phonesCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'notifyPhones（每行一個或用逗號分隔）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _webhookCtrl,
                    decoration: const InputDecoration(
                      labelText: 'webhookUrl（可空）',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '原始 JSON（檢視）',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    ),
                    child: Text(
                      _rawJsonCtrl.text,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

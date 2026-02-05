import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSOSNotifySettingsPage extends StatefulWidget {
  const AdminSOSNotifySettingsPage({super.key});

  @override
  State<AdminSOSNotifySettingsPage> createState() =>
      _AdminSOSNotifySettingsPageState();
}

class _AdminSOSNotifySettingsPageState extends State<AdminSOSNotifySettingsPage> {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('sos_notify');

  static const _defaults = <String, dynamic>{
    'enabled': true,
    'fcmEnabled': true,
    'lineEnabled': false,
    'smsEnabled': false,
    'lineNotifyToken': '',
    'smsProvider': 'twilio',
    'twilioFrom': '',
    'notifyAdmins': true,
    'adminUserIds': <String>[],
  };

  final _adminIdsCtrl = TextEditingController();
  final _lineTokenCtrl = TextEditingController();
  final _twilioFromCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _adminIdsCtrl.dispose();
    _lineTokenCtrl.dispose();
    _twilioFromCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS 通知設定', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('載入失敗：${snap.error}'));
          }

          final exists = snap.data?.exists == true;
          final data = <String, dynamic>{
            ..._defaults,
            ...(snap.data?.data() ?? const <String, dynamic>{}),
          };

          bool enabled = data['enabled'] == true;
          bool fcmEnabled = data['fcmEnabled'] == true;
          bool lineEnabled = data['lineEnabled'] == true;
          bool smsEnabled = data['smsEnabled'] == true;
          bool notifyAdmins = data['notifyAdmins'] == true;

          final adminIds = (data['adminUserIds'] is List)
              ? (data['adminUserIds'] as List).map((e) => e.toString()).toList()
              : <String>[];

          _adminIdsCtrl.text = adminIds.join(',');
          _lineTokenCtrl.text = (data['lineNotifyToken'] ?? '').toString();
          _twilioFromCtrl.text = (data['twilioFrom'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exists ? '設定文件已建立' : '尚未建立設定文件',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        onPressed: exists ? null : _initIfMissing,
                        icon: const Icon(Icons.add),
                        label: const Text('初始化設定文件'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _title('總開關'),
              Card(
                elevation: 0,
                child: SwitchListTile(
                  title: const Text('啟用 SOS 通知', style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('關閉後：FCM / Line / SMS 全部不發送',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                  value: enabled,
                  onChanged: (v) => _savePatch({'enabled': v}),
                ),
              ),
              const SizedBox(height: 12),

              _title('通道設定'),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('FCM 推播', style: TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text('對綁定監護人/管理員送推播',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                        value: fcmEnabled,
                        onChanged: enabled ? (v) => _savePatch({'fcmEnabled': v}) : null,
                      ),
                      SwitchListTile(
                        title: const Text('Line Notify', style: TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text('使用 Line Notify Token 發送訊息到指定 Line',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                        value: lineEnabled,
                        onChanged: enabled ? (v) => _savePatch({'lineEnabled': v}) : null,
                      ),
                      if (lineEnabled) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: TextField(
                            controller: _lineTokenCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Line Notify Token',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                        ),
                      ],
                      SwitchListTile(
                        title: const Text('SMS', style: TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text('建議用 Twilio（走 Cloud Functions）',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                        value: smsEnabled,
                        onChanged: enabled ? (v) => _savePatch({'smsEnabled': v}) : null,
                      ),
                      if (smsEnabled) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: TextField(
                            controller: _twilioFromCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Twilio From（例如 +1xxxxxxxxxx）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _title('收件人：管理員'),
              Card(
                elevation: 0,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('通知管理員', style: TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text('將 SOS 發送給 adminUserIds 內的人',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      value: notifyAdmins,
                      onChanged: enabled ? (v) => _savePatch({'notifyAdmins': v}) : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        controller: _adminIdsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'adminUserIds（用逗號分隔）',
                          helperText: '例如：uid1,uid2,uid3',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          final ids = _adminIdsCtrl.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();

                          await _savePatch({
                            'adminUserIds': ids,
                            'lineNotifyToken': _lineTokenCtrl.text.trim(),
                            'twilioFrom': _twilioFromCtrl.text.trim(),
                          });

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已儲存通知設定')),
                          );
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
                label: Text(_saving ? '儲存中...' : '儲存'),
              ),

              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '注意：\n'
                    '1) Line Notify / SMS 必須走 Cloud Functions，App 端不要直接打第三方 API。\n'
                    '2) FCM 需確保 users/{uid}.fcmTokens 有正確寫入。\n'
                    '3) 建議在 SOS 事件建立時，一併寫入 childName / deviceId / location。\n',
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
      );

  Future<void> _initIfMissing() async {
    await _ref.set({
      ..._defaults,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _savePatch(Map<String, dynamic> patch) async {
    await _ref.set({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSOSHealthPage extends StatefulWidget {
  const AdminSOSHealthPage({super.key});

  @override
  State<AdminSOSHealthPage> createState() => _AdminSOSHealthPageState();
}

class _AdminSOSHealthPageState extends State<AdminSOSHealthPage> {
  final _ref =
      FirebaseFirestore.instance.collection('app_config').doc('sos_health');

  static const _defaults = {
    'sosEnabled': true,
    'healthInfoEnabled': true,
    'sosHoldSeconds': 3,
    'notifyParents': true,
    'notifyAdmin': true,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('SOS / 健康模組', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = {
            ..._defaults,
            ...(snap.data?.data() ?? {}),
          };

          bool sosEnabled = data['sosEnabled'] == true;
          bool healthEnabled = data['healthInfoEnabled'] == true;
          bool notifyParents = data['notifyParents'] == true;
          bool notifyAdmin = data['notifyAdmin'] == true;
          int holdSeconds = (data['sosHoldSeconds'] ?? 3).clamp(1, 10);

          Future<void> save(Map<String, dynamic> patch) async {
            await _ref.set(
              {
                ...patch,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section('SOS 功能'),
              SwitchListTile(
                title: const Text('啟用 SOS 功能',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                value: sosEnabled,
                onChanged: (v) => save({'sosEnabled': v}),
              ),
              ListTile(
                title: Text('長按秒數：$holdSeconds 秒',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Slider(
                  min: 1,
                  max: 10,
                  divisions: 9,
                  value: holdSeconds.toDouble(),
                  label: '$holdSeconds',
                  onChanged: sosEnabled
                      ? (v) => save({'sosHoldSeconds': v.round()})
                      : null,
                ),
              ),
              const Divider(),

              _section('通知設定'),
              SwitchListTile(
                title: const Text('通知家長',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                value: notifyParents,
                onChanged: sosEnabled
                    ? (v) => save({'notifyParents': v})
                    : null,
              ),
              SwitchListTile(
                title: const Text('通知管理員',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                value: notifyAdmin,
                onChanged: sosEnabled
                    ? (v) => save({'notifyAdmin': v})
                    : null,
              ),
              const Divider(),

              _section('健康資訊'),
              SwitchListTile(
                title: const Text('顯示健康資訊',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('心率、步數、定位等'),
                value: healthEnabled,
                onChanged: (v) => save({'healthInfoEnabled': v}),
              ),

              const SizedBox(height: 24),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'App 端建議邏輯：\n'
                    '1) sosEnabled=false → 完全隱藏 SOS\n'
                    '2) 長按秒數由後台控制\n'
                    '3) 通知對象依設定推播 / SMS\n',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      ),
    );
  }
}

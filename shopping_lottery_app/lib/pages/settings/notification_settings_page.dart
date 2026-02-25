import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _hydrated = false;
  bool _saving = false;

  bool _order = true;
  bool _lottery = true;
  bool _marketing = false;

  String get _uid => _auth.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> _userRef() =>
      _db.collection('users').doc(_uid);

  void _hydrate(Map<String, dynamic> udoc) {
    if (_hydrated) return;
    final prefs = (udoc['prefs'] is Map)
        ? Map<String, dynamic>.from(udoc['prefs'] as Map)
        : <String, dynamic>{};
    _order = (prefs['notifyOrder'] ?? true) == true;
    _lottery = (prefs['notifyLottery'] ?? true) == true;
    _marketing = (prefs['notifyMarketing'] ?? false) == true;
    _hydrated = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _userRef().set({
        'prefs': {
          'notifyOrder': _order,
          'notifyLottery': _lottery,
          'notifyMarketing': _marketing,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存通知設定')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('通知設定')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userRef().snapshots(),
        builder: (context, snap) {
          final udoc = snap.data?.data() ?? <String, dynamic>{};
          _hydrate(udoc);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _order,
                      onChanged: (v) => setState(() => _order = v),
                      title: const Text('訂單通知'),
                      subtitle: const Text('出貨/到貨/狀態更新'),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: _lottery,
                      onChanged: (v) => setState(() => _lottery = v),
                      title: const Text('抽獎通知'),
                      subtitle: const Text('開獎結果、活動提醒'),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: _marketing,
                      onChanged: (v) => setState(() => _marketing = v),
                      title: const Text('行銷通知'),
                      subtitle: const Text('優惠活動/新品推播'),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('儲存'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

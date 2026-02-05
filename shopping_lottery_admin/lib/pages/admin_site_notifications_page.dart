// lib/pages/admin_site_notifications_page.dart
//
// ✅ AdminSiteNotificationsPage v8.3 Final（通知信 / 聯絡我們管理｜最終完整版）
// ------------------------------------------------------------
// Firestore：
// site_settings/notifications
//   - senderEmail: String
//   - receiverEmail: String
//   - ccEmail: String
//   - subjectTemplate: String
//   - signature: String
//   - autoReplyEnabled: bool
//   - autoReplyMessage: String
//   - updatedAt: Timestamp
//
// mail_logs/{id}
//   - name, email, message, subject
//   - sentAt: Timestamp
//   - status: success/error
//   - errorMsg: String
//
// ------------------------------------------------------------
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminSiteNotificationsPage extends StatefulWidget {
  const AdminSiteNotificationsPage({super.key});

  @override
  State<AdminSiteNotificationsPage> createState() =>
      _AdminSiteNotificationsPageState();
}

class _AdminSiteNotificationsPageState
    extends State<AdminSiteNotificationsPage> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('通知信 / 聯絡我們'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.settings_outlined), text: '郵件設定'),
              Tab(icon: Icon(Icons.mail_outline), text: '寄送記錄'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MailSettingsTab(),
            _MailLogsTab(),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// ✅ 郵件設定
// ------------------------------------------------------------
class _MailSettingsTab extends StatefulWidget {
  const _MailSettingsTab();

  @override
  State<_MailSettingsTab> createState() => _MailSettingsTabState();
}

class _MailSettingsTabState extends State<_MailSettingsTab> {
  final _db = FirebaseFirestore.instance;
  final _senderCtrl = TextEditingController();
  final _receiverCtrl = TextEditingController();
  final _ccCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _signatureCtrl = TextEditingController();
  final _autoReplyCtrl = TextEditingController();
  bool _autoReplyEnabled = false;
  bool _loading = true;
  bool _saving = false;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final doc =
        await _db.collection('site_settings').doc('notifications').get();
    if (doc.exists) {
      final d = doc.data()!;
      _senderCtrl.text = (d['senderEmail'] ?? '').toString();
      _receiverCtrl.text = (d['receiverEmail'] ?? '').toString();
      _ccCtrl.text = (d['ccEmail'] ?? '').toString();
      _subjectCtrl.text = (d['subjectTemplate'] ?? '').toString();
      _signatureCtrl.text = (d['signature'] ?? '').toString();
      _autoReplyCtrl.text = (d['autoReplyMessage'] ?? '').toString();
      _autoReplyEnabled = d['autoReplyEnabled'] == true;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _db.collection('site_settings').doc('notifications').set({
        'senderEmail': _senderCtrl.text.trim(),
        'receiverEmail': _receiverCtrl.text.trim(),
        'ccEmail': _ccCtrl.text.trim(),
        'subjectTemplate': _subjectCtrl.text.trim(),
        'signature': _signatureCtrl.text.trim(),
        'autoReplyEnabled': _autoReplyEnabled,
        'autoReplyMessage': _autoReplyCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('已儲存設定');
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text('通知信基本設定',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),

          TextField(
            controller: _senderCtrl,
            decoration: const InputDecoration(labelText: '寄件信箱'),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _receiverCtrl,
            decoration: const InputDecoration(labelText: '收件信箱（主要客服）'),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _ccCtrl,
            decoration: const InputDecoration(labelText: '副本（CC，可空白）'),
          ),
          const Divider(height: 24),

          const Text('郵件樣式設定',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),

          TextField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
                labelText: '郵件標題模板（例如：Osmile 客服通知 - {{name}}）'),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _signatureCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '簽名 / 結尾文字',
              hintText: '例如：Osmile 客服團隊 敬上',
            ),
          ),

          const Divider(height: 24),

          SwitchListTile(
            title: const Text('啟用自動回覆'),
            value: _autoReplyEnabled,
            onChanged: (v) => setState(() => _autoReplyEnabled = v),
          ),
          TextField(
            controller: _autoReplyCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '自動回覆內容（當啟用時使用）',
              hintText: '例如：感謝您的來信，我們將儘快與您聯繫！',
            ),
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('儲存設定'),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// ✅ 寄送記錄
// ------------------------------------------------------------
class _MailLogsTab extends StatefulWidget {
  const _MailLogsTab();

  @override
  State<_MailLogsTab> createState() => _MailLogsTabState();
}

class _MailLogsTabState extends State<_MailLogsTab> {
  final _db = FirebaseFirestore.instance;
  String _keyword = '';
  String _status = '全部';

  DateTime? _toDate(dynamic v) => v is Timestamp ? v.toDate() : null;
  String _fmt(dynamic v) =>
      v is Timestamp ? DateFormat('yyyy/MM/dd HH:mm').format(v.toDate()) : '-';

  bool _match(Map<String, dynamic> d) {
    final kw = _keyword.trim().toLowerCase();
    final s = _status;
    final name = (d['name'] ?? '').toString().toLowerCase();
    final email = (d['email'] ?? '').toString().toLowerCase();
    final subject = (d['subject'] ?? '').toString().toLowerCase();
    final message = (d['message'] ?? '').toString().toLowerCase();
    final status = (d['status'] ?? '').toString();
    if (kw.isNotEmpty &&
        !name.contains(kw) &&
        !email.contains(kw) &&
        !subject.contains(kw) &&
        !message.contains(kw)) return false;
    if (s != '全部' && status != s) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final stream = _db
        .collection('mail_logs')
        .orderBy('sentAt', descending: true)
        .limit(300)
        .snapshots();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜尋姓名/信箱/主題/內容',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _keyword = v),
                ),
              ),
              DropdownButton<String>(
                value: _status,
                items: const ['全部', 'success', 'error']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? '全部'),
              ),
              IconButton(
                tooltip: '清除搜尋',
                onPressed: () => setState(() {
                  _keyword = '';
                  _status = '全部';
                }),
                icon: const Icon(Icons.clear_all),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final all = snap.data!.docs;
              if (all.isEmpty) return const Center(child: Text('目前沒有寄送紀錄'));

              final filtered = all.where((d) => _match(d.data())).toList();

              if (filtered.isEmpty) return const Center(child: Text('無符合條件的結果'));

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final d = filtered[i].data();
                  final name = (d['name'] ?? '').toString();
                  final email = (d['email'] ?? '').toString();
                  final subject = (d['subject'] ?? '').toString();
                  final status = (d['status'] ?? '').toString();
                  final message = (d['message'] ?? '').toString();
                  final sentAt = _fmt(d['sentAt']);
                  final error = (d['errorMsg'] ?? '').toString();

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: ListTile(
                      leading: Icon(
                        status == 'success'
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: status == 'success' ? Colors.green : Colors.redAccent,
                      ),
                      title: Text(subject.isEmpty ? '(無標題)' : subject,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('寄件人：$name｜信箱：$email'),
                          Text('時間：$sentAt'),
                          Text('狀態：$status'),
                          if (error.isNotEmpty)
                            Text('錯誤：$error',
                                style: const TextStyle(color: Colors.red, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('內容：${message.isEmpty ? '(無)' : message}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

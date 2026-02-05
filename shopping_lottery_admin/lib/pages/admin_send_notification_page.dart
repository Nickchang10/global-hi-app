// lib/pages/admin_send_notification_page.dart
//
// ✅ AdminSendNotificationPage（最終完整版｜整合 NotificationService）
// ------------------------------------------------------------
// 功能：
// - 後台管理員使用，用於手動發送通知
// - 可選擇「發送給全部使用者」或「指定 UID / Email」
// - 可輸入標題、內容、類型(type)、附加資料(extra JSON)
// - 自動寫入 Firestore 結構：notifications/{uid}/items/{notificationId}
// - 與 NotificationService 完全相容
//
// Firestore 結構：
//   notifications/{uid}/items/{id}:
//     - title
//     - body
//     - type
//     - isRead
//     - createdAt
//     - updatedAt
//     - extra
//
// 依賴：
//   - cloud_firestore
//   - firebase_auth
//   - services/notification_service.dart
// ------------------------------------------------------------

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class AdminSendNotificationPage extends StatefulWidget {
  const AdminSendNotificationPage({super.key});

  @override
  State<AdminSendNotificationPage> createState() => _AdminSendNotificationPageState();
}

class _AdminSendNotificationPageState extends State<AdminSendNotificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _notifSvc = NotificationService();

  bool _sending = false;
  bool _sendToAll = false;

  final _uidCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _typeCtrl = TextEditingController(text: 'system');
  final _extraCtrl = TextEditingController();

  @override
  void dispose() {
    _uidCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _typeCtrl.dispose();
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);

    try {
      final title = _titleCtrl.text.trim();
      final body = _bodyCtrl.text.trim();
      final type = _typeCtrl.text.trim().isEmpty ? 'system' : _typeCtrl.text.trim();
      final extraStr = _extraCtrl.text.trim();
      Map<String, dynamic>? extra;

      if (extraStr.isNotEmpty) {
        try {
          extra = jsonDecode(extraStr);
          if (extra is! Map<String, dynamic>) {
            throw const FormatException('extra 必須是 JSON 物件');
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('extra JSON 格式錯誤：$e')),
          );
          setState(() => _sending = false);
          return;
        }
      }

      if (_sendToAll) {
        await _notifSvc.sendNotificationToAll(
          title: title,
          body: body,
          type: type,
          extra: extra,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已成功發送給所有使用者')),
        );
      } else {
        final uid = _uidCtrl.text.trim();
        if (uid.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('請輸入使用者 UID 或 Email')),
          );
          setState(() => _sending = false);
          return;
        }

        // 支援 email → 自動查 UID
        String targetUid = uid;
        if (uid.contains('@')) {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: uid)
              .limit(1)
              .get();
          if (snap.docs.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('找不到 Email 對應的使用者：$uid')),
            );
            setState(() => _sending = false);
            return;
          }
          targetUid = snap.docs.first.id;
        }

        await _notifSvc.sendNotificationToUser(
          uid: targetUid,
          title: title,
          body: body,
          type: type,
          extra: extra,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已成功發送給使用者 $targetUid')),
        );
      }

      _titleCtrl.clear();
      _bodyCtrl.clear();
      _extraCtrl.clear();
      setState(() => _sending = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('發送失敗：$e')),
      );
      setState(() => _sending = false);
    }
  }

  // ------------------------------------------------------------
  // 🔹 UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('發送通知'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '格式說明',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('extra JSON 範例'),
                  content: const Text(
                    '{\n  "orderId": "12345",\n  "coupon": "XMAS2025"\n}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('關閉'),
                    )
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('發送給全部使用者'),
              subtitle: const Text('若開啟，將忽略 UID/Email 欄位'),
              value: _sendToAll,
              onChanged: (v) => setState(() => _sendToAll = v),
            ),
            if (!_sendToAll)
              TextFormField(
                controller: _uidCtrl,
                decoration: const InputDecoration(
                  labelText: '目標使用者 UID 或 Email',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (_sendToAll || (v ?? '').trim().isNotEmpty) ? null : '請輸入 UID 或 Email',
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '通知標題',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '請輸入標題' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '通知內容',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '請輸入內容' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _typeCtrl,
              decoration: const InputDecoration(
                labelText: '通知類型 (type)',
                hintText: 'system / order / coupon / announcement ...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _extraCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '附加資料 (JSON)',
                hintText: '{"key": "value"}',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.send_outlined),
              label: Text(_sending ? '發送中...' : '發送通知'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _sending ? null : _send,
            ),
            if (_sending)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

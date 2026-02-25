// lib/pages/admin_send_notification_page.dart
//
// ✅ AdminSendNotificationPage（單檔完整版｜可編譯可用｜修正 Dropdown value deprecated）
// ------------------------------------------------------------
// Firestore 建議：
// 1) notifications/{id}
// {
//   uid: "xxx" | ""(全體)
//   audience: "all" | "user" | "vendor",
//   vendorId: "v1" | "",
//   title: "...",
//   body: "...",
//   type: "system" | "marketing" | "order" | "campaign",
//   data: { ... } (可空)
//   isRead: false,
//   createdAt: Timestamp,
// }
//
// 2) (可選) users/{uid}/notifications/{id}  (鏡像寫入，前台好讀)
// ------------------------------------------------------------

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSendNotificationPage extends StatefulWidget {
  const AdminSendNotificationPage({super.key});

  @override
  State<AdminSendNotificationPage> createState() =>
      _AdminSendNotificationPageState();
}

class _AdminSendNotificationPageState extends State<AdminSendNotificationPage> {
  final _db = FirebaseFirestore.instance;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _uidCtrl = TextEditingController();
  final _vendorIdCtrl = TextEditingController();
  final _dataCtrl = TextEditingController(text: '{}');

  bool _sending = false;

  Audience _audience = Audience.all; // all / user / vendor
  NotiType _type = NotiType.system;

  // ✅ 可選：是否同步寫入 users/{uid}/notifications
  bool _mirrorToUserSubcollection = true;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _uidCtrl.dispose();
    _vendorIdCtrl.dispose();
    _dataCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _typeValue(NotiType t) {
    switch (t) {
      case NotiType.system:
        return 'system';
      case NotiType.marketing:
        return 'marketing';
      case NotiType.order:
        return 'order';
      case NotiType.campaign:
        return 'campaign';
    }
  }

  String _audienceValue(Audience a) {
    switch (a) {
      case Audience.all:
        return 'all';
      case Audience.user:
        return 'user';
      case Audience.vendor:
        return 'vendor';
    }
  }

  Map<String, dynamic> _parseJsonOrEmpty(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return <String, dynamic>{};
    try {
      final v = jsonDecode(s);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _send() async {
    if (_sending) return;

    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final uid = _uidCtrl.text.trim();
    final vendorId = _vendorIdCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _snack('標題與內容不可為空');
      return;
    }

    if (_audience == Audience.user && uid.isEmpty) {
      _snack('指定使用者模式需要填 uid');
      return;
    }

    if (_audience == Audience.vendor && vendorId.isEmpty) {
      _snack('Vendor 群組模式需要填 vendorId');
      return;
    }

    setState(() => _sending = true);

    try {
      final data = _parseJsonOrEmpty(_dataCtrl.text);

      // 目標 uid 列表
      List<String> targetUids = [];

      if (_audience == Audience.all) {
        // ✅ 全體：只寫一筆全體通知（uid=''），前台自己判斷顯示
        targetUids = [''];
      } else if (_audience == Audience.user) {
        targetUids = [uid];
      } else {
        // vendor：找 users where vendorId == X
        final qs = await _db
            .collection('users')
            .where('vendorId', isEqualTo: vendorId)
            .limit(2000)
            .get();
        targetUids = qs.docs.map((d) => d.id).toList();

        if (targetUids.isEmpty) {
          _snack('找不到 vendorId=$vendorId 的使用者');
          return;
        }
      }

      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();

      for (final tuid in targetUids) {
        final ref = _db.collection('notifications').doc();

        final payload = <String, dynamic>{
          'uid': tuid, // '' => all
          'audience': _audienceValue(_audience),
          'vendorId': _audience == Audience.vendor ? vendorId : '',
          'title': title,
          'body': body,
          'type': _typeValue(_type),
          'data': data,
          'isRead': false,
          'createdAt': now,
        };

        batch.set(ref, payload);

        // 可選：鏡像寫入 users/{uid}/notifications
        if (_mirrorToUserSubcollection && tuid.isNotEmpty) {
          final uref = _db
              .collection('users')
              .doc(tuid)
              .collection('notifications')
              .doc(ref.id);
          batch.set(uref, payload);
        }
      }

      await batch.commit();

      _snack('已送出（${targetUids.length} 筆）');
      _titleCtrl.clear();
      _bodyCtrl.clear();
      // uid/vendorId 不清空，方便連續發
    } catch (e) {
      _snack('送出失敗：$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '發送通知',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '送出',
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '發送對象',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('全體'),
                        selected: _audience == Audience.all,
                        onSelected: (_) =>
                            setState(() => _audience = Audience.all),
                      ),
                      ChoiceChip(
                        label: const Text('指定使用者 uid'),
                        selected: _audience == Audience.user,
                        onSelected: (_) =>
                            setState(() => _audience = Audience.user),
                      ),
                      ChoiceChip(
                        label: const Text('Vendor 群組'),
                        selected: _audience == Audience.vendor,
                        onSelected: (_) =>
                            setState(() => _audience = Audience.vendor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_audience == Audience.user) ...[
                    TextField(
                      controller: _uidCtrl,
                      decoration: const InputDecoration(
                        labelText: 'uid',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_audience == Audience.vendor) ...[
                    TextField(
                      controller: _vendorIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'vendorId',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    children: [
                      const Text(
                        '同步寫入 users/{uid}/notifications',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Switch(
                        value: _mirrorToUserSubcollection,
                        onChanged: (v) =>
                            setState(() => _mirrorToUserSubcollection = v),
                      ),
                    ],
                  ),
                  Text(
                    _mirrorToUserSubcollection
                        ? '開啟：指定/群組通知會同步寫入使用者子集合（前台讀取較快）'
                        : '關閉：只寫 notifications（前台需用 uid 查詢）',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '內容',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),

                  // ✅ 修正：value deprecated -> initialValue + key
                  DropdownButtonFormField<NotiType>(
                    key: ValueKey(_type),
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: '通知類型（type）',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: NotiType.system,
                        child: Text('system（系統）'),
                      ),
                      DropdownMenuItem(
                        value: NotiType.marketing,
                        child: Text('marketing（行銷）'),
                      ),
                      DropdownMenuItem(
                        value: NotiType.order,
                        child: Text('order（訂單）'),
                      ),
                      DropdownMenuItem(
                        value: NotiType.campaign,
                        child: Text('campaign（活動）'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _type = v ?? NotiType.system),
                  ),

                  const SizedBox(height: 10),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: '標題',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _bodyCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '內容',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _dataCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'data（JSON，可空）',
                      helperText:
                          '例如：{"route":"/orders/123","campaignId":"abc"}',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_sending ? '送出中...' : '送出通知'),
          ),
        ],
      ),
    );
  }
}

enum Audience { all, user, vendor }

enum NotiType { system, marketing, order, campaign }

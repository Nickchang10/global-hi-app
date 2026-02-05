// lib/pages/admin/system/system_notifications_page.dart
//
// ✅ SystemNotificationsPage（完整版｜可編譯）
// ------------------------------------------------------------
// 功能摘要：
// - Firestore notifications 集合管理
// - 後台可手動發送推播：
//    • 全部用戶
//    • 指定用戶 UID
//    • 測試通知
// - 類別分類：系統公告 / 活動消息 / 訂單提醒
// - 篩選 / 排序 / 刪除通知
// - Firestore 結構：
//   notifications/{id}
//   {
//     title: "...",
//     body: "...",
//     category: "system" | "campaign" | "order",
//     target: "all" | "user" | "vendor",
//     uid: "", // optional
//     createdAt: Timestamp,
//     sentBy: "adminUid",
//     readBy: [uid...],
//   }
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SystemNotificationsPage extends StatefulWidget {
  const SystemNotificationsPage({super.key});

  @override
  State<SystemNotificationsPage> createState() => _SystemNotificationsPageState();
}

class _SystemNotificationsPageState extends State<SystemNotificationsPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _categoryFilter = 'all';
  bool _sending = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = _searchCtrl.text.trim().toLowerCase();

    Query<Map<String, dynamic>> q = _db.collection('notifications').orderBy('createdAt', descending: true);
    if (_categoryFilter != 'all') {
      q = q.where('category', isEqualTo: _categoryFilter);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(icon: const Icon(Icons.add_alert), tooltip: '發送通知', onPressed: _openSendDialog),
          IconButton(icon: const Icon(Icons.refresh), tooltip: '重新整理', onPressed: () => setState(() {})),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜尋標題 / 內容 / 類別',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _categoryFilter,
                  onChanged: (v) => setState(() => _categoryFilter = v ?? 'all'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部類別')),
                    DropdownMenuItem(value: 'system', child: Text('系統公告')),
                    DropdownMenuItem(value: 'campaign', child: Text('活動消息')),
                    DropdownMenuItem(value: 'order', child: Text('訂單提醒')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.limit(300).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('載入失敗：${snap.error}'));
                }

                var docs = snap.data?.docs ?? [];
                if (query.isNotEmpty) {
                  docs = docs.where((d) {
                    final m = d.data();
                    final t = (m['title'] ?? '').toString().toLowerCase();
                    final b = (m['body'] ?? '').toString().toLowerCase();
                    final c = (m['category'] ?? '').toString().toLowerCase();
                    return t.contains(query) || b.contains(query) || c.contains(query);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(child: Text('目前沒有通知資料'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.grey.shade300),
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final id = docs[i].id;
                    final title = d['title'] ?? '';
                    final body = d['body'] ?? '';
                    final cat = (d['category'] ?? 'system').toString();
                    final target = (d['target'] ?? 'all').toString();
                    final created = (d['createdAt'] as Timestamp?)?.toDate();
                    final fmtTime = created != null ? DateFormat('MM/dd HH:mm').format(created) : '—';

                    return ListTile(
                      leading: _categoryIcon(cat, cs),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(
                        '$body\n類別：$cat  ｜  對象：$target  ｜  時間：$fmtTime',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(id),
                      ),
                      onTap: () => _showDetailDialog(id, d),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // 詳情 Dialog
  // ------------------------------------------------------------
  Future<void> _showDetailDialog(String id, Map<String, dynamic> data) async {
    final created = (data['createdAt'] as Timestamp?)?.toDate();
    final fmt = created != null ? DateFormat('yyyy/MM/dd HH:mm').format(created) : '—';

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['title'] ?? '（無標題）', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('內容：${data['body'] ?? ''}'),
            const SizedBox(height: 6),
            Text('類別：${data['category']}'),
            Text('目標：${data['target']}'),
            if (data['uid'] != null && data['uid'] != '') Text('指定 UID：${data['uid']}'),
            const SizedBox(height: 6),
            Text('建立時間：$fmt'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // 發送通知 Dialog
  // ------------------------------------------------------------
  Future<void> _openSendDialog() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final uidCtrl = TextEditingController();
    String category = 'system';
    String target = 'all';

    await showDialog<void>(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (context, setSB) {
          return AlertDialog(
            title: const Text('發送通知', style: TextStyle(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: '標題',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '內容',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: '類別', border: OutlineInputBorder(), isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'system', child: Text('系統公告')),
                        DropdownMenuItem(value: 'campaign', child: Text('活動消息')),
                        DropdownMenuItem(value: 'order', child: Text('訂單提醒')),
                      ],
                      onChanged: (v) => setSB(() => category = v ?? 'system'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: target,
                      decoration: const InputDecoration(labelText: '目標對象', border: OutlineInputBorder(), isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('全部用戶')),
                        DropdownMenuItem(value: 'user', child: Text('指定用戶（UID）')),
                        DropdownMenuItem(value: 'vendor', child: Text('廠商 / 供應商')),
                      ],
                      onChanged: (v) => setSB(() => target = v ?? 'all'),
                    ),
                    if (target == 'user') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: uidCtrl,
                        decoration: const InputDecoration(
                          labelText: '指定 UID',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              FilledButton.icon(
                onPressed: _sending
                    ? null
                    : () async {
                        if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
                          _toast('請輸入標題與內容');
                          return;
                        }
                        if (target == 'user' && uidCtrl.text.trim().isEmpty) {
                          _toast('請輸入 UID');
                          return;
                        }
                        setState(() => _sending = true);
                        await _sendNotification(
                          titleCtrl.text.trim(),
                          bodyCtrl.text.trim(),
                          category,
                          target,
                          uidCtrl.text.trim(),
                        );
                        if (mounted) Navigator.pop(context);
                        setState(() => _sending = false);
                      },
                icon: const Icon(Icons.send),
                label: Text(_sending ? '發送中...' : '發送'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _sendNotification(
    String title,
    String body,
    String category,
    String target,
    String uid,
  ) async {
    try {
      final ref = _db.collection('notifications').doc();
      await ref.set({
        'title': title,
        'body': body,
        'category': category,
        'target': target,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'sentBy': 'admin',
      });

      _toast('通知已建立（$category/$target）');
    } catch (e) {
      _toast('發送失敗：$e');
    }
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除通知', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('確定要刪除此通知？刪除後無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _db.collection('notifications').doc(id).delete();
      _toast('已刪除通知');
    } catch (e) {
      _toast('刪除失敗：$e');
    }
  }

  Icon _categoryIcon(String category, ColorScheme cs) {
    switch (category) {
      case 'system':
        return Icon(Icons.settings_outlined, color: cs.primary);
      case 'campaign':
        return Icon(Icons.campaign_outlined, color: Colors.orange);
      case 'order':
        return Icon(Icons.shopping_bag_outlined, color: Colors.green);
      default:
        return Icon(Icons.notifications_outlined, color: cs.primary);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// lib/pages/admin_notifications_log_page.dart
//
// ✅ AdminNotificationsLogPage（最終完整版）
// ------------------------------------------------------------
// 功能：
// - 顯示管理員發送的全體通知紀錄（broadcast logs）
// - 每次 sendNotificationToAll() 時自動記錄至 logs/{id}
// - 可篩選、搜尋、查看詳細內容
// - 顯示發送時間、標題、類型、對象數量
// - 支援刪除、複製 JSON、重新發送
// ------------------------------------------------------------
//
// Firestore 結構建議：
// logs/
//   {logId}:
//     title: String
//     body: String
//     type: String
//     createdAt: Timestamp
//     totalUsers: int
//     extra: Map<String, dynamic>
//
// ※ 可由 NotificationService 在 sendNotificationToAll() 時自動記錄
// ------------------------------------------------------------

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class AdminNotificationsLogPage extends StatefulWidget {
  const AdminNotificationsLogPage({super.key});

  @override
  State<AdminNotificationsLogPage> createState() => _AdminNotificationsLogPageState();
}

class _AdminNotificationsLogPageState extends State<AdminNotificationsLogPage> {
  final _db = FirebaseFirestore.instance;
  final _notifSvc = NotificationService();

  String _q = '';
  bool _loading = false;

  String _fmtDate(dynamic v) {
    if (v == null) return '-';
    DateTime? d;
    if (v is Timestamp) d = v.toDate();
    if (v is DateTime) d = v;
    if (d == null) return '-';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _deleteLog(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除紀錄'),
        content: const Text('確定要刪除此發送紀錄嗎？（不可復原）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.collection('logs').doc(id).delete();
      _snack('已刪除紀錄');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  Future<void> _resendLog(Map<String, dynamic> log) async {
    try {
      setState(() => _loading = true);
      await _notifSvc.sendNotificationToAll(
        title: log['title'] ?? '(無標題)',
        body: log['body'] ?? '',
        type: log['type'] ?? 'system',
        extra: (log['extra'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(log['extra'])
            : null,
      );
      _snack('已重新發送此通知');
    } catch (e) {
      _snack('重新發送失敗：$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知發送紀錄'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                hintText: '搜尋（標題、內容、type、ID）',
              ),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('logs')
                  .orderBy('createdAt', descending: true)
                  .limit(500)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                final filtered = docs.where((d) {
                  final data = d.data();
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final body = (data['body'] ?? '').toString().toLowerCase();
                  final type = (data['type'] ?? '').toString().toLowerCase();
                  return _q.isEmpty ||
                      title.contains(_q) ||
                      body.contains(_q) ||
                      type.contains(_q) ||
                      d.id.toLowerCase().contains(_q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('目前沒有發送紀錄'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final doc = filtered[i];
                    final d = doc.data();
                    final title = (d['title'] ?? '(未命名通知)').toString();
                    final body = (d['body'] ?? '').toString();
                    final type = (d['type'] ?? 'system').toString();
                    final total = (d['totalUsers'] ?? 0).toString();
                    final createdAt = _fmtDate(d['createdAt']);

                    return ListTile(
                      leading: const Icon(Icons.campaign_outlined, color: Colors.blue),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$type • 發送對象 $total 人 • $createdAt\n$body',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'delete') {
                            await _deleteLog(doc.id);
                          } else if (v == 'copy') {
                            await Clipboard.setData(ClipboardData(text: jsonEncode(d)));
                            _snack('已複製 JSON');
                          } else if (v == 'resend') {
                            await _resendLog(d);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'copy', child: Text('複製 JSON')),
                          PopupMenuItem(value: 'resend', child: Text('重新發送')),
                          PopupMenuItem(value: 'delete', child: Text('刪除此紀錄')),
                        ],
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(title),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('類型：$type'),
                                  Text('發送對象：$total 人'),
                                  Text('時間：$createdAt'),
                                  const Divider(),
                                  Text(body.isEmpty ? '(無內容)' : body),
                                  const Divider(),
                                  if (d['extra'] != null)
                                    Text('Extra: ${jsonEncode(d['extra'])}'),
                                ],
                              ),
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
                    );
                  },
                );
              },
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminSOSEventsPage extends StatelessWidget {
  const AdminSOSEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('sos_events')
        .orderBy('triggeredAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS 事件紀錄',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('載入失敗：${snap.error}'));
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('目前沒有 SOS 事件'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();

              final handled = data['handled'] == true;
              final time = _fmt(data['triggeredAt']);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        handled ? Colors.grey.shade300 : Colors.red.shade100,
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: handled ? Colors.grey : Colors.red,
                    ),
                  ),
                  title: Text(
                    data['childName'] ?? '未知使用者',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '裝置：${data['deviceId'] ?? '-'}\n'
                    '時間：$time',
                    style: const TextStyle(height: 1.35),
                  ),
                  trailing: _StatusPill(handled: handled),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminSOSEventDetailPage(docId: d.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _fmt(dynamic v) {
    if (v is Timestamp) {
      return DateFormat('yyyy/MM/dd HH:mm').format(v.toDate());
    }
    return '-';
  }
}

class _StatusPill extends StatelessWidget {
  final bool handled;
  const _StatusPill({required this.handled});

  @override
  Widget build(BuildContext context) {
    final bg = handled ? Colors.green.shade100 : Colors.red.shade100;
    final fg = handled ? Colors.green.shade900 : Colors.red.shade900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        handled ? '已處理' : '未處理',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg),
      ),
    );
  }
}

// ✅ AdminVendorDetailPage（可編譯最終版）
// ------------------------------------------------------------
// 顯示單一廠商詳細資訊
// ------------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminVendorDetailPage extends StatefulWidget {
  final String vendorId;
  const AdminVendorDetailPage({super.key, required this.vendorId});

  @override
  State<AdminVendorDetailPage> createState() => _AdminVendorDetailPageState();
}

class _AdminVendorDetailPageState extends State<AdminVendorDetailPage> {
  final _db = FirebaseFirestore.instance;
  String _vendorName = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('廠商詳情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: '查看報表',
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/admin_vendors/report',
                arguments: {'id': widget.vendorId, 'name': _vendorName},
              );
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.collection('vendors').doc(widget.vendorId).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('查無此廠商資料'));
          }

          final data = snap.data!.data()!;
          _vendorName = data['name'] ?? '未命名廠商';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _infoTile(Icons.store, '廠商名稱', data['name']),
              _infoTile(Icons.email_outlined, 'Email', data['email']),
              _infoTile(Icons.phone, '電話', data['phone']),
              _infoTile(Icons.location_on_outlined, '地區', data['region']),
              _infoTile(Icons.info_outline, '狀態', data['status']),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.bar_chart),
                label: const Text('查看營收報表'),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/admin_vendors/report',
                    arguments: {'id': widget.vendorId, 'name': _vendorName},
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, dynamic value) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value?.toString() ?? '—'),
      ),
    );
  }
}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ AdminMemberOrdersManagementPage（會員訂單管理｜可編譯完整版）
/// ------------------------------------------------------------
/// - 入口：從會員列表帶入 initialQuery（通常是 uid）
/// - 查詢：orders 集合，用欄位切換（userId/uid/buyerUid/customerUid）
/// - 顯示：訂單金額、狀態、建立時間、訂單 id
/// - 點進去：顯示 JSON（縮排）
/// ------------------------------------------------------------
class AdminMemberOrdersManagementPage extends StatefulWidget {
  final String? initialQuery;

  const AdminMemberOrdersManagementPage({super.key, this.initialQuery});

  @override
  State<AdminMemberOrdersManagementPage> createState() =>
      _AdminMemberOrdersManagementPageState();
}

class _AdminMemberOrdersManagementPageState
    extends State<AdminMemberOrdersManagementPage> {
  final _db = FirebaseFirestore.instance;
  final _q = TextEditingController();

  String _fieldKey = 'userId'; // userId / uid / buyerUid / customerUid
  bool _desc = true;

  @override
  void initState() {
    super.initState();
    _q.text = (widget.initialQuery ?? '').trim();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> base = _db
        .collection('orders')
        .orderBy('createdAt', descending: _desc);

    final uid = _q.text.trim();
    if (uid.isEmpty) return base.limit(100);

    // Firestore 不支援 OR where，所以用欄位切換
    return base.where(_fieldKey, isEqualTo: uid).limit(200);
  }

  String _money(dynamic v) {
    if (v is num) return NumberFormat('#,###').format(v);
    final n = num.tryParse(v?.toString() ?? '');
    if (n == null) return '0';
    return NumberFormat('#,###').format(n);
  }

  String _ts(dynamic v) {
    if (v is Timestamp) {
      return DateFormat('yyyy/MM/dd HH:mm').format(v.toDate());
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '會員訂單管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _desc = !_desc),
            icon: Icon(_desc ? Icons.south : Icons.north),
            tooltip: _desc ? '時間新到舊' : '時間舊到新',
          ),
        ],
      ),
      body: Column(
        children: [
          _searchBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('查無訂單'));
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();

                    final status = (d['status'] ?? d['orderStatus'] ?? '—')
                        .toString();

                    final total = _money(
                      d['total'] ?? d['amount'] ?? d['payAmount'] ?? 0,
                    );

                    final createdAt = _ts(d['createdAt'] ?? d['created_time']);

                    final title = '訂單 ${doc.id}';
                    final sub = [
                      if (createdAt.isNotEmpty) createdAt,
                      '狀態：$status',
                      '金額：$total',
                    ].join('  •  ');

                    return ListTile(
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(sub),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showOrderDetail(doc),
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

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _q,
              decoration: const InputDecoration(
                labelText: '輸入會員 UID（或對應欄位值）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _fieldKey,
            items: const [
              DropdownMenuItem(value: 'userId', child: Text('userId')),
              DropdownMenuItem(value: 'uid', child: Text('uid')),
              DropdownMenuItem(value: 'buyerUid', child: Text('buyerUid')),
              DropdownMenuItem(
                value: 'customerUid',
                child: Text('customerUid'),
              ),
            ],
            onChanged: (v) => setState(() => _fieldKey = v ?? 'userId'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => setState(() {}),
            child: const Text('查詢'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOrderDetail(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final d = doc.data();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '訂單詳情：${doc.id}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Text(
              const JsonEncoder.withIndent('  ').convert(d),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
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
  }
}

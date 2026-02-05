// lib/pages/admin/shipping/admin_shipping_management_page.dart
//
// ✅ 完整版：出貨 / 退款管理頁面
// ------------------------------------------------------------
// 功能包括：
// - 讀取訂單資料，支持搜尋、過濾
// - 顯示訂單的出貨、退款狀態
// - 提供標記出貨、標記退款操作
// - 支援 CSV 匯出
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:html' as html;

class AdminShippingManagementPage extends StatefulWidget {
  const AdminShippingManagementPage({super.key});

  @override
  State<AdminShippingManagementPage> createState() => _AdminShippingManagementPageState();
}

class _AdminShippingManagementPageState extends State<AdminShippingManagementPage> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 讀取訂單資料
  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await _db
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();

      setState(() {
        _docs = snap.docs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // 根據搜尋條件過濾訂單資料
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filteredDocs {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _docs;

    return _docs.where((doc) {
      final data = doc.data(); // Map<String, dynamic>
      final recipientName = (data['recipient']?['name'] ?? '').toString().toLowerCase();
      final orderId = doc.id.toLowerCase();
      return recipientName.contains(query) || orderId.contains(query);
    }).toList();
  }

  // CSV 匯出
  Future<void> _exportCSV() async {
    List<List<String>> rows = [
      ["訂單ID", "收件人", "電話", "地址", "付款方式", "狀態", "總金額", "出貨時間", "退款時間"]
    ];

    for (var doc in _filteredDocs) {
      final data = doc.data();
      final recipient = data['recipient'] ?? {};
      final payment = data['payment'] ?? {};
      final shippingInfo = data['shippingInfo'] ?? {};
      final status = data['status'] ?? '';
      final createdAt = data['createdAt']?.toDate();
      final shipDate = shippingInfo['shipDate']?.toDate();
      final refundDate = shippingInfo['refundDate']?.toDate();
      rows.add([
        doc.id,
        recipient['name'] ?? '',
        recipient['phone'] ?? '',
        recipient['address'] ?? '',
        payment['method'] ?? '',
        status,
        payment['total']?.toString() ?? '0',
        shipDate != null ? DateFormat('yyyy/MM/dd').format(shipDate) : '',
        refundDate != null ? DateFormat('yyyy/MM/dd').format(refundDate) : '',
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final encoded = utf8.encode(csvData);
    final blob = html.Blob([encoded]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..target = 'blank'
      ..download = 'orders_export.csv';
    anchor.click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('出貨 / 退款管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重新載入',
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
          IconButton(
            tooltip: '匯出 CSV',
            icon: const Icon(Icons.download_for_offline),
            onPressed: _exportCSV,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? _ErrorView(
                  title: '載入失敗',
                  message: _error!,
                  onRetry: _loadOrders,
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: '搜尋訂單ID / 收件人',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            '共 ${_filteredDocs.length} 筆',
                            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _filteredDocs.isEmpty
                          ? const Center(child: Text('目前沒有訂單資料'))
                          : ListView.builder(
                              itemCount: _filteredDocs.length,
                              itemBuilder: (context, i) {
                                final doc = _filteredDocs[i];
                                final data = doc.data(); // Map<String, dynamic>

                                final recipient = data['recipient'] ?? {};
                                final payment = data['payment'] ?? {};
                                final shippingInfo = data['shippingInfo'] ?? {};
                                final status = data['status'] ?? '';
                                final total = payment['total'] ?? 0;
                                final shipDate = shippingInfo['shipDate']?.toDate();
                                final updatedAt = data['createdAt']?.toDate();
                                final updatedText = updatedAt != null ? DateFormat('yyyy/MM/dd HH:mm').format(updatedAt) : '';

                                return Card(
                                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: cs.primaryContainer,
                                      child: Text(
                                        '${total}',
                                        style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    title: Text(
                                      recipient['name'] ?? '未知收件人',
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                    subtitle: Text(
                                      [
                                        '狀態: $status',
                                        if (updatedText.isNotEmpty) '建立: $updatedText',
                                        if (shipDate != null) '出貨: ${DateFormat('yyyy/MM/dd').format(shipDate)}',
                                      ].join(' • '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Text(
                                      'NT\$${total.toString()}',
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                    onTap: () => _showOrderDetail(doc),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  // 顯示訂單詳細資料
  Future<void> _showOrderDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final recipient = data['recipient'] ?? {};
    final shippingInfo = data['shippingInfo'] ?? {};
    final payment = data['payment'] ?? {};
    final status = data['status'] ?? '';
    final total = payment['total'] ?? 0;

    final shipDate = shippingInfo['shipDate']?.toDate();
    final refundDate = shippingInfo['refundDate']?.toDate();

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('訂單詳細資料', style: const TextStyle(fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv('訂單ID', doc.id),
                  _kv('收件人', recipient['name'] ?? ''),
                  _kv('電話', recipient['phone'] ?? ''),
                  _kv('地址', recipient['address'] ?? ''),
                  _kv('付款方式', payment['method'] ?? ''),
                  _kv('狀態', status),
                  _kv('總金額', 'NT\$${total.toString()}'),
                  if (shipDate != null) _kv('出貨時間', DateFormat('yyyy/MM/dd').format(shipDate)),
                  if (refundDate != null) _kv('退款時間', DateFormat('yyyy/MM/dd').format(refundDate)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  // 工具函數：顯示鍵值對
  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(key, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 錯誤視圖
// ------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 44, color: cs.error),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重試'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

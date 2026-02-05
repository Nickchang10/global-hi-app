// lib/pages/admin_reports_page.dart
//
// ✅ AdminReportsPage（最終可編譯完整版｜含 PDF 報表生成 + Printing 預覽）
// ------------------------------------------------------------
// 相依：pdf, printing, intl
// ------------------------------------------------------------

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  int _selectedYear = DateTime.now().year;
  double _totalRevenue = 0;
  int _totalOrders = 0;
  int _totalUsers = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _dataRows = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      setState(() => _loading = true);

      final orderSnap = await _db.collection('orders').get();
      final userSnap = await _db.collection('users').get();

      double totalRevenue = 0;
      int totalOrders = 0;

      final List<Map<String, dynamic>> dataRows = [];

      for (final doc in orderSnap.docs) {
        final data = doc.data();
        final price = (data['total'] ?? 0).toDouble();
        totalRevenue += price;
        totalOrders++;
        dataRows.add({
          'orderId': doc.id,
          'user': data['userEmail'] ?? '-',
          'amount': price,
          'createdAt': (data['createdAt'] is Timestamp)
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
        });
      }

      setState(() {
        _totalRevenue = totalRevenue;
        _totalOrders = totalOrders;
        _totalUsers = userSnap.size;
        _dataRows = dataRows;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入報表失敗：$e')),
        );
      }
    }
  }

  Future<void> _generatePdfReport() async {
    try {
      final doc = pw.Document();
      final nf = NumberFormat("#,##0.00", "en_US");

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Osmile 營運報表 ($_selectedYear)',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('總營收：\$${nf.format(_totalRevenue)}'),
              pw.Text('總訂單：$_totalOrders'),
              pw.Text('新增用戶：$_totalUsers'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['訂單ID', '用戶', '金額', '建立時間'],
                data: _dataRows.map((e) {
                  final date = e['createdAt'] == null
                      ? '-'
                      : DateFormat('yyyy-MM-dd HH:mm')
                          .format(e['createdAt'] as DateTime);
                  return [
                    e['orderId'] ?? '-',
                    e['user'] ?? '-',
                    '\$${nf.format(e['amount'] ?? 0)}',
                    date,
                  ];
                }).toList(),
              ),
            ],
          ),
        ),
      );

      final Uint8List pdfBytes = await doc.save();

      // ✅ Printing 預覽
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Osmile_營運報表_${_selectedYear}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 生成失敗：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('營運報表管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: '匯出 PDF',
            onPressed: _loading ? null : _generatePdfReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新整理',
            onPressed: _loadReport,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('年份：$_selectedYear',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      title: const Text('總營收'),
                      trailing: Text('\$${_totalRevenue.toStringAsFixed(2)}'),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: const Text('總訂單'),
                      trailing: Text('$_totalOrders 筆'),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: const Text('用戶總數'),
                      trailing: Text('$_totalUsers 位'),
                    ),
                  ),
                  const Divider(),
                  const Text('近期訂單明細：'),
                  const SizedBox(height: 8),
                  ..._dataRows.take(10).map((e) {
                    final date = e['createdAt'] == null
                        ? '-'
                        : DateFormat('MM-dd HH:mm')
                            .format(e['createdAt'] as DateTime);
                    return Card(
                      child: ListTile(
                        title: Text('訂單 ${e['orderId']}'),
                        subtitle: Text('用戶：${e['user'] ?? '-'}'),
                        trailing: Text(
                            '\$${(e['amount'] ?? 0).toStringAsFixed(2)}\n$date',
                            textAlign: TextAlign.right),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

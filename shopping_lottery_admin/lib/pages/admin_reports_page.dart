// lib/pages/admin_reports_page.dart
//
// ✅ AdminReportsPage（最終可編譯完整版｜含 PDF 報表生成 + Printing 預覽）
// ------------------------------------------------------------
// 相依：cloud_firestore, intl, pdf, printing
// ------------------------------------------------------------

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  // ✅ 目前沒有年份切換 UI，故改 final 解掉 prefer_final_fields
  final int _selectedYear = DateTime.now().year;

  double _totalRevenue = 0;
  int _totalOrders = 0;
  int _totalUsers = 0;

  bool _loading = true;
  List<Map<String, dynamic>> _dataRows = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  num _num(dynamic v, {num fallback = 0}) {
    if (v is num) return v;
    return fallback;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  Future<void> _loadReport() async {
    if (mounted) setState(() => _loading = true);

    try {
      final orderSnap = await _db.collection('orders').get();
      final userSnap = await _db.collection('users').get();

      double totalRevenue = 0;
      int totalOrders = 0;
      final List<Map<String, dynamic>> dataRows = <Map<String, dynamic>>[];

      for (final doc in orderSnap.docs) {
        final data = doc.data();

        final price = _num(data['total']).toDouble();
        totalRevenue += price;
        totalOrders++;

        dataRows.add({
          'orderId': doc.id,
          'user': (data['userEmail'] ?? '-').toString(),
          'amount': price,
          'createdAt': _toDate(data['createdAt']),
        });
      }

      if (!mounted) return;
      setState(() {
        _totalRevenue = totalRevenue;
        _totalOrders = totalOrders;
        _totalUsers = userSnap.size;
        _dataRows = dataRows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('載入報表失敗：$e')));
    }
  }

  Future<void> _generatePdfReport() async {
    try {
      final pdfDoc = pw.Document();

      final nfMoney = NumberFormat('#,##0.00', 'en_US');
      final df = DateFormat('yyyy-MM-dd HH:mm');

      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) {
            final tableData = _dataRows.map((e) {
              final DateTime? createdAt = e['createdAt'] as DateTime?;
              final dateText = createdAt == null ? '-' : df.format(createdAt);

              return <String>[
                (e['orderId'] ?? '-').toString(),
                (e['user'] ?? '-').toString(),
                '\$${nfMoney.format(_num(e['amount']).toDouble())}',
                dateText,
              ];
            }).toList();

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Osmile 營運報表 ($_selectedYear)',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('總營收：\$${nfMoney.format(_totalRevenue)}'),
                pw.Text('總訂單：$_totalOrders'),
                pw.Text('新增用戶：$_totalUsers'),
                pw.SizedBox(height: 16),

                // ✅ 修正：pw.Table.fromTextArray deprecated -> pw.TableHelper.fromTextArray
                pw.TableHelper.fromTextArray(
                  headers: const ['訂單ID', '用戶', '金額', '建立時間'],
                  data: tableData,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  cellAlignment: pw.Alignment.centerLeft,
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2.2),
                    1: pw.FlexColumnWidth(2.2),
                    2: pw.FlexColumnWidth(1.3),
                    3: pw.FlexColumnWidth(2.0),
                  },
                ),
              ],
            );
          },
        ),
      );

      final Uint8List pdfBytes = await pdfDoc.save();

      await Printing.layoutPdf(
        name: 'Osmile_營運報表_$_selectedYear.pdf',
        onLayout: (_) async => pdfBytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF 生成失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final moneyText = '\$${_totalRevenue.toStringAsFixed(2)}';

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
                  Text(
                    '年份：$_selectedYear',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      title: const Text('總營收'),
                      trailing: Text(moneyText),
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
                    final DateTime? createdAt = e['createdAt'] as DateTime?;
                    final dateText = createdAt == null
                        ? '-'
                        : DateFormat('MM-dd HH:mm').format(createdAt);

                    final amount = _num(e['amount']).toDouble();

                    return Card(
                      child: ListTile(
                        title: Text('訂單 ${(e['orderId'] ?? '-').toString()}'),
                        subtitle: Text('用戶：${(e['user'] ?? '-').toString()}'),
                        trailing: Text(
                          '\$${amount.toStringAsFixed(2)}\n$dateText',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

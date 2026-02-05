// lib/pages/admin/reports/admin_sales_export_page.dart
//
// ✅ AdminSalesExportPage（完整版 V5｜最終整合版）
// ------------------------------------------------------------

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

import 'package:osmile_admin/services/report_service.dart';
import 'package:osmile_admin/utils/report_file_saver.dart';

class AdminSalesExportPage extends StatefulWidget {
  const AdminSalesExportPage({super.key});

  @override
  State<AdminSalesExportPage> createState() => _AdminSalesExportPageState();
}

class _AdminSalesExportPageState extends State<AdminSalesExportPage> {
  final _report = ReportService();

  bool exporting = false;
  bool loadingSummary = false;

  String exportFormat = 'csv'; // csv / pdf
  DateTimeRange? selectedRange;

  ReportStats? summary; // 匯出前摘要
  Object? summaryError;

  String? exportResult; // web: 文字訊息, io: file path
  bool _didInitArgs = false;

  /// 匯出欄位（key -> enabled）
  final Map<String, bool> _fieldOptions = {
    'orderId': true,
    'createdAt': true,
    'customer': true,
    'amount': true,
    'status': true,
    'payment': true,

    'discount': false,
    'vendor': false,
    'products': false,

    'shippingFee': false,
    'couponCode': false,
    'note': false,
  };

  /// 預設推薦欄位
  final Set<String> _defaultSelectedKeys = const {
    'orderId',
    'createdAt',
    'customer',
    'amount',
    'status',
    'payment',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitArgs) return;
    _didInitArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    DateTimeRange? incoming;
    if (args is DateTimeRange) {
      incoming = args;
    } else if (args is Map && args['range'] is DateTimeRange) {
      incoming = args['range'] as DateTimeRange;
    }

    if (incoming != null && selectedRange == null) {
      selectedRange = _normalizeRange(incoming);
      _loadSummary();
    }
  }

  DateTimeRange _normalizeRange(DateTimeRange r) {
    return DateTimeRange(
      start: DateTime(r.start.year, r.start.month, r.start.day),
      end: DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59),
    );
  }

  List<String> get _selectedFieldKeys =>
      _fieldOptions.entries.where((e) => e.value).map((e) => e.key).toList();

  @override
  Widget build(BuildContext context) {
    final fmtDate = DateFormat('yyyy/MM/dd');
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    final rangeText = selectedRange == null
        ? '尚未選擇'
        : '${fmtDate.format(selectedRange!.start)} - ${fmtDate.format(selectedRange!.end)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('營收報表匯出', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '重新載入摘要',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadSummary(showToast: true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _rangeTile(rangeText),
          const SizedBox(height: 8),

          _summaryCard(fmtMoney),
          const SizedBox(height: 12),

          _fieldsCard(),
          const SizedBox(height: 12),

          _formatSelector(),
          const SizedBox(height: 12),

          Center(child: _exportButton()),
          const SizedBox(height: 18),

          if (exportResult != null) _resultCard(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ==========================================================
  // 日期區間
  // ==========================================================
  Widget _rangeTile(String rangeText) {
    return ListTile(
      leading: const Icon(Icons.date_range),
      title: const Text('匯出日期區間'),
      subtitle: Text(rangeText),
      trailing: TextButton(
        onPressed: _pickRange,
        child: const Text('變更'),
      ),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final init = selectedRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      initialDateRange: init,
    );

    if (picked != null) {
      setState(() {
        selectedRange = _normalizeRange(picked);
        exportResult = null;
      });
      await _loadSummary(showToast: true);
    }
  }

  // ==========================================================
  // 摘要卡（匯出前確認）
  // ==========================================================
  Widget _summaryCard(NumberFormat fmtMoney) {
    if (selectedRange == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('請先選擇日期區間，再顯示匯出摘要。'),
        ),
      );
    }

    if (loadingSummary) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('載入匯出摘要中...'),
            ],
          ),
        ),
      );
    }

    if (summaryError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('匯出摘要載入失敗', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('$summaryError', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => _loadSummary(showToast: true),
                icon: const Icon(Icons.refresh),
                label: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    final s = summary;
    if (s == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('尚未載入匯出摘要。'),
        ),
      );
    }

    final aov = s.orderCount == 0 ? 0 : (s.totalRevenue / s.orderCount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('匯出前摘要（確認用）', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat('訂單數', s.orderCount.toString()),
                _miniStat('總營收', fmtMoney.format(s.totalRevenue)),
                _miniStat('AOV', fmtMoney.format(aov)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '狀態納入 paid / shipping / completed；營收加總 finalAmount。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
      ],
    );
  }

  Future<void> _loadSummary({bool showToast = false}) async {
    final r = selectedRange;
    if (r == null) {
      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先選擇日期區間'))); 
      }
      return;
    }

    setState(() {
      loadingSummary = true;
      summaryError = null;
      summary = null;
      exportResult = null;
    });

    try {
      final s = await _report.getSalesReport(range: r);
      setState(() {
        summary = s;
        loadingSummary = false;
      });
      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('摘要已更新')));
      }
    } catch (e) {
      setState(() {
        summaryError = e;
        loadingSummary = false;
      });
      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('摘要載入失敗：$e')));
      }
    }
  }

  // ==========================================================
  // 欄位選擇（Quick chips + Dialog）
  // ==========================================================
  Widget _fieldsCard() {
    final selectedCount = _selectedFieldKeys.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('匯出欄位', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                Text('已選 $selectedCount', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _openFieldsDialog,
                  icon: const Icon(Icons.tune),
                  label: const Text('欄位選擇（含預覽）'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _fieldOptions.keys.map((k) {
                return FilterChip(
                  label: Text(_fieldLabel(k)),
                  selected: _fieldOptions[k] ?? false,
                  onSelected: (v) {
                    setState(() => _fieldOptions[k] = v);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _selectAllFields,
                  icon: const Icon(Icons.done_all),
                  label: const Text('全選'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _selectNoneFields,
                  icon: const Icon(Icons.remove_done),
                  label: const Text('全不選'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _resetDefaultFields,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('恢復預設'),
                ),
              ],
            ),

            const SizedBox(height: 8),
            const Text(
              '提示：欄位越多、商品明細越長，CSV/PDF 會越大且匯出時間更久。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAllFields() {
    setState(() {
      for (final k in _fieldOptions.keys) {
        _fieldOptions[k] = true;
      }
    });
  }

  void _selectNoneFields() {
    setState(() {
      for (final k in _fieldOptions.keys) {
        _fieldOptions[k] = false;
      }
    });
  }

  void _resetDefaultFields() {
    setState(() {
      for (final k in _fieldOptions.keys) {
        _fieldOptions[k] = _defaultSelectedKeys.contains(k);
      }
    });
  }

  Future<void> _openFieldsDialog() async {
    final r = selectedRange;
    if (r == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先選擇日期區間')));
      return;
    }

    final currentSelected = _fieldOptions.entries.where((e) => e.value).map((e) => e.key).toSet();

    final result = await _AdminSalesExportFieldsDialog.show(
      context,
      allFieldKeys: _fieldOptions.keys.toList(),
      initialSelectedKeys: currentSelected,
      defaultSelectedKeys: _defaultSelectedKeys,
      labelOf: _fieldLabel,
      valueOf: (row, key) => _extractField(row, key).toString(),
      loadPreview: () async {
        // 預覽只取前 20 筆，避免壓力
        final orders = await _report.exportOrders(r);
        return orders.take(20).toList();
      },
      previewLimit: 10,
    );

    if (result == null) return;

    setState(() {
      for (final k in _fieldOptions.keys) {
        _fieldOptions[k] = result.contains(k);
      }
    });
  }

  String _fieldLabel(String key) {
    switch (key) {
      case 'orderId':
        return '訂單編號';
      case 'createdAt':
        return '建立時間';
      case 'customer':
        return '顧客';
      case 'amount':
        return '金額';
      case 'status':
        return '狀態';
      case 'payment':
        return '付款方式';
      case 'discount':
        return '折扣資訊';
      case 'vendor':
        return '廠商';
      case 'products':
        return '商品明細';
      case 'shippingFee':
        return '運費';
      case 'couponCode':
        return '優惠碼';
      case 'note':
        return '備註';
      default:
        return key;
    }
  }

  // ==========================================================
  // 匯出格式
  // ==========================================================
  Widget _formatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('匯出格式', style: TextStyle(fontWeight: FontWeight.w900)),
        RadioListTile<String>(
          title: const Text('CSV（Excel 開啟）'),
          value: 'csv',
          groupValue: exportFormat,
          onChanged: (v) => setState(() => exportFormat = v!),
        ),
        RadioListTile<String>(
          title: const Text('PDF（列印用）'),
          value: 'pdf',
          groupValue: exportFormat,
          onChanged: (v) => setState(() => exportFormat = v!),
        ),
      ],
    );
  }

  // ==========================================================
  // 匯出按鈕
  // ==========================================================
  Widget _exportButton() {
    return ElevatedButton.icon(
      icon: exporting
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.download),
      label: Text(exporting ? '匯出中...' : '開始匯出'),
      onPressed: exporting ? null : _startExport,
    );
  }

  // ==========================================================
  // 結果顯示
  // ==========================================================
  Widget _resultCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('匯出完成', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            Text(exportResult ?? ''),
            const SizedBox(height: 12),
            if (!kIsWeb && exportResult != null && exportResult!.isNotEmpty) ...[
              ElevatedButton.icon(
                onPressed: () => Share.shareXFiles([XFile(exportResult!)]),
                icon: const Icon(Icons.share),
                label: const Text('分享檔案'),
              ),
            ] else ...[
              const Text('Web 版已自動下載到瀏覽器（Downloads）'),
            ]
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 匯出主流程
  // ==========================================================
  Future<void> _startExport() async {
    final r = selectedRange;
    if (r == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先選擇日期區間')));
      return;
    }

    final fields = _selectedFieldKeys;
    if (fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('至少需選擇 1 個匯出欄位')));
      return;
    }

    setState(() {
      exporting = true;
      exportResult = null;
    });

    try {
      final orders = await _report.exportOrders(r);
      if (orders.isEmpty) throw Exception('選擇期間內無訂單');

      final dateStr =
          '${DateFormat('yyyyMMdd').format(r.start)}_${DateFormat('yyyyMMdd').format(r.end)}';

      if (exportFormat == 'csv') {
        final bytes = _buildCsvBytes(orders, fields);
        final filename = 'sales_report_$dateStr.csv';
        // 轉成 Uint8List（saveReportBytes 常見簽名）
        final u8 = Uint8List.fromList(bytes);
        await saveReportBytes(u8, filename);
        setState(() => exportResult = kIsWeb ? '已下載 $filename' : filename);
      } else {
        final bytes = await _buildPdfBytes(orders, r, fields);
        final filename = 'sales_report_$dateStr.pdf';
        await saveReportBytes(bytes, filename);
        setState(() => exportResult = kIsWeb ? '已下載 $filename' : filename);
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('匯出完成')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    } finally {
      setState(() => exporting = false);
    }
  }

  // ==========================================================
  // CSV（含 BOM） -> 回傳 Uint8List
  // ==========================================================
  Uint8List _buildCsvBytes(List<Map<String, dynamic>> orders, List<String> fields) {
    final csvData = <List<dynamic>>[];

    csvData.add(fields.map(_fieldLabel).toList());

    for (final o in orders) {
      csvData.add(fields.map((f) => _extractField(o, f)).toList());
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    return Uint8List.fromList(utf8.encode('\uFEFF$csvString'));
  }

  // ==========================================================
  // PDF -> 回傳 Uint8List
  // ==========================================================
  Future<Uint8List> _buildPdfBytes(
    List<Map<String, dynamic>> orders,
    DateTimeRange r,
    List<String> fields,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) {
          return [
            pw.Text(
              'Osmile 營收報表',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '期間：${DateFormat('yyyy/MM/dd').format(r.start)} - ${DateFormat('yyyy/MM/dd').format(r.end)}',
            ),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: fields.map(_fieldLabel).toList(),
              data: [
                for (final o in orders)
                  [
                    for (final f in fields) _extractField(o, f).toString(),
                  ]
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================================
  // 欄位抽取（你可依 Firestore 欄位再調整）
  // ==========================================================
  dynamic _extractField(Map<String, dynamic> o, String key) {
    switch (key) {
      case 'orderId':
        return o['orderId'] ?? o['id'] ?? '';
      case 'createdAt':
        final dt = _toDateTime(o['createdAt']);
        return dt == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(dt);
      case 'customer':
        return o['customerName'] ?? o['userName'] ?? o['displayName'] ?? '';
      case 'amount':
        return (o['finalAmount'] ?? 0).toString();
      case 'status':
        return o['status'] ?? '';
      case 'payment':
        return o['paymentMethod'] ?? o['payment'] ?? '';
      case 'discount':
        // 可能是 coupon/discountAmount/discount 等（依你資料結構）
        final code = o['couponCode'] ?? o['coupon'] ?? '';
        final discount = o['discountAmount'] ?? o['discount'] ?? '';
        if ('$code$discount'.isEmpty) return '';
        return 'code:$code discount:$discount';
      case 'vendor':
        final list = (o['vendorIds'] as List?) ?? [];
        return list.join(',');
      case 'products':
        final items = (o['items'] as List?) ?? [];
        return items
            .map((i) {
              final name = (i['name'] ?? '').toString();
              final qty = (i['quantity'] ?? i['qty'] ?? 0).toString();
              return '${name}x$qty';
            })
            .where((s) => s.trim().isNotEmpty)
            .join(', ');
      case 'shippingFee':
        return (o['shippingFee'] ?? o['shipping'] ?? '').toString();
      case 'couponCode':
        return (o['couponCode'] ?? o['coupon'] ?? '').toString();
      case 'note':
        return (o['note'] ?? o['remark'] ?? '').toString();
      default:
        return '';
    }
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      final dynamic d = v;
      final dt = d.toDate();
      if (dt is DateTime) return dt;
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// 欄位選擇 Dialog（含預覽）
// ============================================================================

typedef _FieldLabelOf = String Function(String key);
typedef _FieldValueOf = String Function(Map<String, dynamic> row, String key);
typedef _PreviewLoader = Future<List<Map<String, dynamic>>> Function();

class _AdminSalesExportFieldsDialog extends StatefulWidget {
  final List<String> allFieldKeys;
  final Set<String> initialSelectedKeys;
  final Set<String> defaultSelectedKeys;

  final _FieldLabelOf labelOf;
  final _FieldValueOf valueOf;

  final _PreviewLoader? loadPreview;
  final int previewLimit;

  const _AdminSalesExportFieldsDialog({
    required this.allFieldKeys,
    required this.initialSelectedKeys,
    required this.defaultSelectedKeys,
    required this.labelOf,
    required this.valueOf,
    required this.loadPreview,
    required this.previewLimit,
  });

  static Future<Set<String>?> show(
    BuildContext context, {
    required List<String> allFieldKeys,
    required Set<String> initialSelectedKeys,
    required Set<String> defaultSelectedKeys,
    required _FieldLabelOf labelOf,
    required _FieldValueOf valueOf,
    required _PreviewLoader loadPreview,
    int previewLimit = 10,
  }) {
    return showDialog<Set<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminSalesExportFieldsDialog(
        allFieldKeys: allFieldKeys,
        initialSelectedKeys: initialSelectedKeys,
        defaultSelectedKeys: defaultSelectedKeys,
        labelOf: labelOf,
        valueOf: valueOf,
        loadPreview: loadPreview,
        previewLimit: previewLimit,
      ),
    );
  }

  @override
  State<_AdminSalesExportFieldsDialog> createState() => _AdminSalesExportFieldsDialogState();
}

class _AdminSalesExportFieldsDialogState extends State<_AdminSalesExportFieldsDialog> {
  late Map<String, bool> selected;
  final TextEditingController _search = TextEditingController();

  bool previewExpanded = false;
  bool previewLoading = false;
  Object? previewError;
  List<Map<String, dynamic>>? preview;

  @override
  void initState() {
    super.initState();
    selected = {
      for (final k in widget.allFieldKeys) k: widget.initialSelectedKeys.contains(k),
    };
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _selectedCount => selected.values.where((v) => v).length;

  List<String> get _filteredKeys {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.allFieldKeys;
    return widget.allFieldKeys
        .where((k) => widget.labelOf(k).toLowerCase().contains(q) || k.toLowerCase().contains(q))
        .toList();
  }

  void _selectAll() => setState(() {
        for (final k in selected.keys) {
          selected[k] = true;
        }
      });

  void _selectNone() => setState(() {
        for (final k in selected.keys) {
          selected[k] = false;
        }
      });

  void _resetDefault() => setState(() {
        for (final k in selected.keys) {
          selected[k] = widget.defaultSelectedKeys.contains(k);
        }
      });

  Set<String> _selectedKeys() => selected.entries.where((e) => e.value).map((e) => e.key).toSet();

  Future<void> _ensurePreviewLoaded() async {
    if (preview != null) return;

    setState(() {
      previewLoading = true;
      previewError = null;
    });

    try {
      final rows = await widget.loadPreview!.call();
      setState(() {
        preview = rows;
        previewLoading = false;
      });
    } catch (e) {
      setState(() {
        previewError = e;
        previewLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filteredKeys;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('欄位選擇（含預覽）', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  Text('已選 $_selectedCount / ${widget.allFieldKeys.length}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: '搜尋欄位（例如：訂單、顧客、金額、payment）',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(onPressed: _selectAll, icon: const Icon(Icons.done_all), label: const Text('全選')),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(onPressed: _selectNone, icon: const Icon(Icons.remove_done), label: const Text('全不選')),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(onPressed: _resetDefault, icon: const Icon(Icons.restart_alt), label: const Text('恢復預設')),
                ],
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Card(
                        elevation: 0,
                        color: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('欄位清單', style: TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Scrollbar(
                                  child: ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (context, i) {
                                      final key = filtered[i];
                                      final label = widget.labelOf(key);
                                      final isOn = selected[key] ?? false;

                                      return CheckboxListTile(
                                        value: isOn,
                                        dense: true,
                                        controlAffinity: ListTileControlAffinity.leading,
                                        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        subtitle: Text(key, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                        onChanged: (v) => setState(() => selected[key] = v ?? false),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      flex: 6,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('匯出預覽', style: TextStyle(fontWeight: FontWeight.w900)),
                                  ),
                                  Switch(
                                    value: previewExpanded,
                                    onChanged: (v) async {
                                      setState(() => previewExpanded = v);
                                      if (v) await _ensurePreviewLoaded();
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                previewExpanded ? '顯示前 ${widget.previewLimit} 筆（依選取欄位）' : '開啟可預覽匯出格式',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: previewExpanded ? _buildPreview(cs) : _previewHint(cs),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Text(
                    _selectedCount == 0 ? '至少需選 1 個欄位' : '確認後將套用到匯出頁',
                    style: TextStyle(
                      color: _selectedCount == 0 ? cs.error : cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _selectedCount == 0 ? null : () => Navigator.pop(context, _selectedKeys()),
                    icon: const Icon(Icons.check),
                    label: const Text('套用'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewHint(ColorScheme cs) {
    return Center(
      child: Text('切換右上開關以載入預覽', style: TextStyle(color: cs.onSurfaceVariant)),
    );
  }

  Widget _buildPreview(ColorScheme cs) {
    if (previewLoading) return const Center(child: CircularProgressIndicator());

    if (previewError != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 42),
              const SizedBox(height: 8),
              Text('預覽載入失敗：$previewError', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _ensurePreviewLoaded,
                icon: const Icon(Icons.refresh),
                label: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    final rows = (preview ?? const <Map<String, dynamic>>[]);
    if (rows.isEmpty) {
      return Center(
        child: Text('目前無可預覽資料（可能此區間無訂單）', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    final keys = _selectedKeys().toList();
    final showRows = rows.take(widget.previewLimit).toList();

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 520),
          child: Scrollbar(
            child: SingleChildScrollView(
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 52,
                columns: [
                  for (final k in keys)
                    DataColumn(
                      label: Text(widget.labelOf(k), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                ],
                rows: [
                  for (final row in showRows)
                    DataRow(
                      cells: [
                        for (final k in keys)
                          DataCell(
                            Text(
                              _ellipsize(widget.valueOf(row, k), 48),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _ellipsize(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}

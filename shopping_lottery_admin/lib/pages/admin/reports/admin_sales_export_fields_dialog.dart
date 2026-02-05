// lib/pages/admin/reports/admin_sales_export_fields_dialog.dart
//
// ✅ AdminSalesExportFieldsDialog（完整版）
// ------------------------------------------------------------
// - 欄位多選 Dialog：搜尋、全選、全不選、恢復預設
// - 內建匯出預覽（DataTable）：可懶載入（loadPreview）
// - 回傳 Set<String>（選取的欄位 keys）
// ------------------------------------------------------------
//
// 使用方式（在 AdminSalesExportPage）：
//
// final selected = await AdminSalesExportFieldsDialog.show(
//   context,
//   allFieldKeys: _fieldOptions.keys.toList(),
//   initialSelectedKeys: _fieldOptions.entries.where((e) => e.value).map((e) => e.key).toSet(),
//   defaultSelectedKeys: {'orderId','createdAt','customer','amount','status','payment'},
//   labelOf: _fieldLabel,
//   valueOf: (order, key) => _extractField(order, key).toString(),
//   loadPreview: () async {
//     final r = selectedRange!;
//     final orders = await _report.exportOrders(r);
//     return orders.take(20).toList();
//   },
// );
//
// if (selected != null) {
//   setState(() {
//     for (final k in _fieldOptions.keys) {
//       _fieldOptions[k] = selected.contains(k);
//     }
//   });
// }
// ------------------------------------------------------------

import 'package:flutter/material.dart';

typedef FieldLabelOf = String Function(String key);
typedef FieldValueOf = String Function(Map<String, dynamic> row, String key);
typedef PreviewLoader = Future<List<Map<String, dynamic>>> Function();

class AdminSalesExportFieldsDialog extends StatefulWidget {
  final List<String> allFieldKeys;
  final Set<String> initialSelectedKeys;
  final Set<String> defaultSelectedKeys;

  final FieldLabelOf labelOf;
  final FieldValueOf valueOf;

  /// 預覽資料：可直接傳進來（已經查好的 sample）
  final List<Map<String, dynamic>>? previewRows;

  /// 懶載入預覽（推薦）：dialog 展開預覽時才去抓資料
  final PreviewLoader? loadPreview;

  /// 預覽最多顯示幾筆
  final int previewLimit;

  const AdminSalesExportFieldsDialog({
    super.key,
    required this.allFieldKeys,
    required this.initialSelectedKeys,
    required this.defaultSelectedKeys,
    required this.labelOf,
    required this.valueOf,
    this.previewRows,
    this.loadPreview,
    this.previewLimit = 12,
  });

  static Future<Set<String>?> show(
    BuildContext context, {
    required List<String> allFieldKeys,
    required Set<String> initialSelectedKeys,
    required Set<String> defaultSelectedKeys,
    required FieldLabelOf labelOf,
    required FieldValueOf valueOf,
    List<Map<String, dynamic>>? previewRows,
    PreviewLoader? loadPreview,
    int previewLimit = 12,
  }) {
    return showDialog<Set<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminSalesExportFieldsDialog(
        allFieldKeys: allFieldKeys,
        initialSelectedKeys: initialSelectedKeys,
        defaultSelectedKeys: defaultSelectedKeys,
        labelOf: labelOf,
        valueOf: valueOf,
        previewRows: previewRows,
        loadPreview: loadPreview,
        previewLimit: previewLimit,
      ),
    );
  }

  @override
  State<AdminSalesExportFieldsDialog> createState() => _AdminSalesExportFieldsDialogState();
}

class _AdminSalesExportFieldsDialogState extends State<AdminSalesExportFieldsDialog> {
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

    preview = widget.previewRows;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _selectedCount => selected.values.where((v) => v).length;

  List<String> get _filteredKeys {
    final q = _search.text.trim().toLowerCase();
    final keys = widget.allFieldKeys;
    if (q.isEmpty) return keys;
    return keys.where((k) => widget.labelOf(k).toLowerCase().contains(q) || k.toLowerCase().contains(q)).toList();
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

  Set<String> _selectedKeys() {
    return selected.entries.where((e) => e.value).map((e) => e.key).toSet();
  }

  Future<void> _ensurePreviewLoaded() async {
    if (preview != null) return;
    if (widget.loadPreview == null) return;

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
                    child: Text(
                      '匯出欄位選擇',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    '已選 $_selectedCount / ${widget.allFieldKeys.length}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
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
                  FilledButton.tonalIcon(
                    onPressed: _selectAll,
                    icon: const Icon(Icons.done_all),
                    label: const Text('全選'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _selectNone,
                    icon: const Icon(Icons.remove_done),
                    label: const Text('全不選'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _resetDefault,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('恢復預設'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Row(
                  children: [
                    // 左：欄位清單
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
                              const Text(
                                '欄位清單',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
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

                    // 右：預覽區
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
                                    child: Text(
                                      '匯出預覽',
                                      style: TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  Switch(
                                    value: previewExpanded,
                                    onChanged: (v) async {
                                      setState(() => previewExpanded = v);
                                      if (v) {
                                        await _ensurePreviewLoaded();
                                      }
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                previewExpanded
                                    ? '顯示前 ${widget.previewLimit} 筆（依選取欄位）'
                                    : '開啟可預覽匯出格式（建議）',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                              ),
                              const SizedBox(height: 10),

                              if (!previewExpanded)
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '切換右上開關以載入預覽',
                                      style: TextStyle(color: cs.onSurfaceVariant),
                                    ),
                                  ),
                                )
                              else
                                Expanded(
                                  child: _buildPreview(cs),
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
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _selectedCount == 0
                        ? null
                        : () {
                            Navigator.pop(context, _selectedKeys());
                          },
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

  Widget _buildPreview(ColorScheme cs) {
    if (previewLoading) {
      return const Center(child: CircularProgressIndicator());
    }
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
                onPressed: () async => _ensurePreviewLoaded(),
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
        child: Text(
          widget.loadPreview == null ? '未提供預覽資料' : '目前無可預覽資料（可能此區間無訂單）',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    final keys = _selectedKeys().toList();
    final showRows = rows.take(widget.previewLimit).toList();

    // DataTable 欄位太多時需要橫向捲動
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
                      label: Text(
                        widget.labelOf(k),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
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

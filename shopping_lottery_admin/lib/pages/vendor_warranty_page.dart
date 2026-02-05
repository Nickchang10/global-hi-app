// lib/pages/vendor_warranty_page.dart
//
// ✅ VendorWarrantyPage（完整版｜可編譯｜Vendor Only｜保固/序號管理｜查詢/新增/更新/作廢｜匯出CSV(複製剪貼簿)｜Web+App）
//
// 目的：
// - 廠商後台管理「保固卡 / 序號」：可查詢、建立、更新狀態（active/expired/void）
// - 與主後台共用同一份資料（同 collection / 同 doc），達到「連動」
//
// Firestore 建議：warranties/{warrantyId}
//   - vendorId: String
//   - serial: String                 // 序號（可用條碼/IMEI/自訂）
//   - productId: String (選用)
//   - productName: String (選用)
//   - customerName: String (選用)
//   - customerPhone: String (選用)
//   - customerEmail: String (選用)
//   - purchaseAt: Timestamp (選用)
//   - expireAt: Timestamp (選用)
//   - status: String                 // active / expired / void
//   - note: String (選用)
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//
// 索引建議：
// - where(vendorId) + orderBy(createdAt)
// - where(vendorId) + where(status) + orderBy(createdAt)
// - 若要支援 serial 精準查詢，可另外建立 field：serialUpper 用於一致化查詢
//
// 依賴：cloud_firestore, flutter/material, flutter/services

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorWarrantyPage extends StatefulWidget {
  const VendorWarrantyPage({
    super.key,
    required this.vendorId,
    this.collection = 'warranties',
  });

  final String vendorId;
  final String collection;

  @override
  State<VendorWarrantyPage> createState() => _VendorWarrantyPageState();
}

class _VendorWarrantyPageState extends State<VendorWarrantyPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _q = '';

  String? _status; // null=全部, active/expired/void
  String? _selectedId;

  bool _busy = false;
  String _busyLabel = '';

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(widget.collection);
  String get _vid => widget.vendorId.trim();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Utils
  // -------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  Future<void> _setBusy(bool v, {String label = ''}) async {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  // -------------------------
  // Stream
  // -------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    Query<Map<String, dynamic>> q = _col
        .where('vendorId', isEqualTo: _vid)
        .orderBy('createdAt', descending: true)
        .limit(800);

    if (_status != null && _status!.trim().isNotEmpty) {
      q = _col
          .where('vendorId', isEqualTo: _vid)
          .where('status', isEqualTo: _status)
          .orderBy('createdAt', descending: true)
          .limit(800);
    }
    return q.snapshots();
  }

  bool _matchLocal(_WarrantyRow r) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final d = r.data;
    final id = r.id.toLowerCase();
    final serial = _s(d['serial']).toLowerCase();
    final productName = _s(d['productName']).toLowerCase();
    final customerName = _s(d['customerName']).toLowerCase();
    final phone = _s(d['customerPhone']).toLowerCase();
    final email = _s(d['customerEmail']).toLowerCase();
    final note = _s(d['note']).toLowerCase();
    final status = _s(d['status']).toLowerCase();

    return id.contains(q) ||
        serial.contains(q) ||
        productName.contains(q) ||
        customerName.contains(q) ||
        phone.contains(q) ||
        email.contains(q) ||
        note.contains(q) ||
        status.contains(q);
  }

  // -------------------------
  // CRUD
  // -------------------------
  Future<void> _openCreateOrEditDialog({String? id, Map<String, dynamic>? data}) async {
    final isCreate = id == null || id.trim().isEmpty;

    final serialCtrl = TextEditingController(text: _s(data?['serial']));
    final productIdCtrl = TextEditingController(text: _s(data?['productId']));
    final productNameCtrl = TextEditingController(text: _s(data?['productName']));
    final customerNameCtrl = TextEditingController(text: _s(data?['customerName']));
    final customerPhoneCtrl = TextEditingController(text: _s(data?['customerPhone']));
    final customerEmailCtrl = TextEditingController(text: _s(data?['customerEmail']));
    final noteCtrl = TextEditingController(text: _s(data?['note']));

    DateTime? purchaseAt = _toDate(data?['purchaseAt']);
    DateTime? expireAt = _toDate(data?['expireAt']);
    String status = _s(data?['status']).isEmpty ? 'active' : _s(data?['status']);

    Future<void> pickPurchase(StateSetter setSt) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 10),
        lastDate: DateTime(now.year + 1),
        initialDate: purchaseAt ?? now,
      );
      if (picked != null) setSt(() => purchaseAt = picked);
    }

    Future<void> pickExpire(StateSetter setSt) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 10),
        lastDate: DateTime(now.year + 20),
        initialDate: expireAt ?? now.add(const Duration(days: 365)),
      );
      if (picked != null) setSt(() => expireAt = picked);
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text(isCreate ? '新增保固/序號' : '編輯保固/序號'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: serialCtrl,
                    decoration: const InputDecoration(
                      labelText: '序號 serial（必填）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: productNameCtrl,
                          decoration: const InputDecoration(
                            labelText: '商品名稱 productName（選用）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: productIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'productId（選用）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customerNameCtrl,
                          decoration: const InputDecoration(
                            labelText: '客戶姓名 customerName（選用）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: customerPhoneCtrl,
                          decoration: const InputDecoration(
                            labelText: '客戶電話 customerPhone（選用）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customerEmailCtrl,
                    decoration: const InputDecoration(
                      labelText: '客戶 Email customerEmail（選用）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickPurchase(setSt),
                          icon: const Icon(Icons.event_outlined),
                          label: Text('購買日：${_fmt(purchaseAt)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickExpire(setSt),
                          icon: const Icon(Icons.event_available_outlined),
                          label: Text('到期日：${_fmt(expireAt)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: '狀態 status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('active')),
                      DropdownMenuItem(value: 'expired', child: Text('expired')),
                      DropdownMenuItem(value: 'void', child: Text('void')),
                    ],
                    onChanged: (v) => setSt(() => status = v ?? 'active'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '備註 note（選用）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '提示：此資料與主後台共用同一 collection，可即時連動。',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('儲存')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final serial = serialCtrl.text.trim();
      if (serial.isEmpty) {
        _snack('序號不可為空');
        serialCtrl.dispose();
        productIdCtrl.dispose();
        productNameCtrl.dispose();
        customerNameCtrl.dispose();
        customerPhoneCtrl.dispose();
        customerEmailCtrl.dispose();
        noteCtrl.dispose();
        return;
      }

      await _setBusy(true, label: '儲存中...');
      try {
        final now = FieldValue.serverTimestamp();
        final payload = <String, dynamic>{
          'vendorId': _vid,
          'serial': serial,
          'serialUpper': serial.toUpperCase(),
          'productId': productIdCtrl.text.trim(),
          'productName': productNameCtrl.text.trim(),
          'customerName': customerNameCtrl.text.trim(),
          'customerPhone': customerPhoneCtrl.text.trim(),
          'customerEmail': customerEmailCtrl.text.trim(),
          'purchaseAt': purchaseAt == null ? null : Timestamp.fromDate(DateTime(purchaseAt!.year, purchaseAt!.month, purchaseAt!.day)),
          'expireAt': expireAt == null ? null : Timestamp.fromDate(DateTime(expireAt!.year, expireAt!.month, expireAt!.day)),
          'status': status,
          'note': noteCtrl.text.trim(),
          'updatedAt': now,
          if (isCreate) 'createdAt': now,
        };

        // 移除 null 欄位避免寫入 null（依你需求可保留）
        payload.removeWhere((k, v) => v == null);

        if (isCreate) {
          final ref = _col.doc();
          await ref.set(payload, SetOptions(merge: true));
          setState(() => _selectedId = ref.id);
          _snack('已新增：${ref.id}');
        } else {
          final docId = id!.trim();
          await _col.doc(docId).set(payload, SetOptions(merge: true));
          _snack('已更新：$docId');
        }
      } catch (e) {
        _snack('儲存失敗：$e');
      } finally {
        await _setBusy(false);
      }
    }

    serialCtrl.dispose();
    productIdCtrl.dispose();
    productNameCtrl.dispose();
    customerNameCtrl.dispose();
    customerPhoneCtrl.dispose();
    customerEmailCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _delete(String id) async {
    final docId = id.trim();
    if (docId.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除保固/序號'),
        content: Text('確定要刪除：$docId 嗎？（不可復原）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (ok != true) return;

    await _setBusy(true, label: '刪除中...');
    try {
      await _col.doc(docId).delete();
      if (_selectedId == docId) setState(() => _selectedId = null);
      _snack('已刪除：$docId');
    } catch (e) {
      _snack('刪除失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _exportCsv(List<_WarrantyRow> rows) async {
    if (rows.isEmpty) return;

    final headers = <String>[
      'warrantyId',
      'serial',
      'productName',
      'productId',
      'customerName',
      'customerPhone',
      'customerEmail',
      'purchaseAt',
      'expireAt',
      'status',
      'note',
      'createdAt',
      'updatedAt',
    ];

    final buffer = StringBuffer()..writeln(headers.join(','));

    for (final r in rows) {
      final d = r.data;
      final line = <String>[
        r.id,
        _s(d['serial']),
        _s(d['productName']),
        _s(d['productId']),
        _s(d['customerName']),
        _s(d['customerPhone']),
        _s(d['customerEmail']),
        (_toDate(d['purchaseAt'])?.toIso8601String() ?? ''),
        (_toDate(d['expireAt'])?.toIso8601String() ?? ''),
        _s(d['status']),
        _s(d['note']),
        (_toDate(d['createdAt'])?.toIso8601String() ?? ''),
        (_toDate(d['updatedAt'])?.toIso8601String() ?? ''),
      ].map((e) => e.replaceAll(',', '，')).toList();

      buffer.writeln(line.join(','));
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    _snack('已複製 CSV 到剪貼簿（可貼到 Excel）');
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    if (_vid.isEmpty) {
      return const Scaffold(body: Center(child: Text('vendorId 不可為空')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('保固/序號管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '新增',
            onPressed: _busy ? null : () => _openCreateOrEditDialog(),
            icon: const Icon(Icons.add_box_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final rows = snap.data!.docs
                  .map((d) => _WarrantyRow(id: d.id, data: d.data()))
                  .where(_matchLocal)
                  .toList();

              // 選取補正
              final ids = rows.map((e) => e.id).toSet();
              if (_selectedId != null && !ids.contains(_selectedId)) _selectedId = null;

              return Column(
                children: [
                  _Filters(
                    searchCtrl: _searchCtrl,
                    status: _status,
                    countLabel: '${rows.length} 筆',
                    onQueryChanged: (v) => setState(() => _q = v),
                    onClearQuery: () {
                      _searchCtrl.clear();
                      setState(() => _q = '');
                    },
                    onStatusChanged: (v) => setState(() => _status = v),
                    onAdd: () => _openCreateOrEditDialog(),
                    onExport: rows.isEmpty || _busy ? null : () => _exportCsv(rows),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth >= 980;

                        final list = ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = rows[i];
                            final d = r.data;

                            final serial = _s(d['serial']).isEmpty ? '（無序號）' : _s(d['serial']);
                            final productName = _s(d['productName']);
                            final status = _s(d['status']).isEmpty ? 'active' : _s(d['status']);
                            final expireAt = _toDate(d['expireAt']);
                            final updatedAt = _toDate(d['updatedAt'] ?? d['createdAt']);

                            return ListTile(
                              selected: r.id == _selectedId,
                              leading: const Icon(Icons.verified_outlined),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      serial,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _Pill(label: status, color: _statusColor(context, status)),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 4,
                                      children: [
                                        Text('ID：${r.id}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        if (productName.isNotEmpty)
                                          Text('商品：$productName', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        Text('到期：${_fmt(expireAt)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        Text('更新：${_fmt(updatedAt)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: '更多',
                                onSelected: _busy
                                    ? null
                                    : (v) async {
                                        if (v == 'copy_id') {
                                          await _copy(r.id, done: '已複製 warrantyId');
                                        } else if (v == 'copy_serial') {
                                          await _copy(serial, done: '已複製 serial');
                                        } else if (v == 'edit') {
                                          await _openCreateOrEditDialog(id: r.id, data: d);
                                        } else if (v == 'json') {
                                          await _copy(jsonEncode(d), done: '已複製 JSON');
                                        } else if (v == 'delete') {
                                          await _delete(r.id);
                                        }
                                      },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'copy_id', child: Text('複製 warrantyId')),
                                  PopupMenuItem(value: 'copy_serial', child: Text('複製 serial')),
                                  PopupMenuDivider(),
                                  PopupMenuItem(value: 'edit', child: Text('編輯')),
                                  PopupMenuItem(value: 'json', child: Text('複製 JSON')),
                                  PopupMenuDivider(),
                                  PopupMenuItem(value: 'delete', child: Text('刪除')),
                                ],
                              ),
                              onTap: () {
                                setState(() => _selectedId = r.id);
                                if (!wide) {
                                  showDialog(
                                    context: context,
                                    builder: (_) => _DetailDialog(
                                      id: r.id,
                                      data: d,
                                      fmt: _fmt,
                                      toDate: _toDate,
                                      onCopy: _copy,
                                      onEdit: () => _openCreateOrEditDialog(id: r.id, data: d),
                                      onDelete: () => _delete(r.id),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        );

                        if (!wide) return list;

                        final selected = _selectedId == null
                            ? null
                            : rows.where((e) => e.id == _selectedId).cast<_WarrantyRow?>().firstOrNull;

                        return Row(
                          children: [
                            Expanded(flex: 3, child: list),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 2,
                              child: selected == null
                                  ? Center(
                                      child: Text(
                                        '請選擇一筆資料查看詳情',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                    )
                                  : _DetailPanel(
                                      id: selected.id,
                                      data: selected.data,
                                      fmt: _fmt,
                                      toDate: _toDate,
                                      onCopy: _copy,
                                      onEdit: () => _openCreateOrEditDialog(id: selected.id, data: selected.data),
                                      onDelete: () => _delete(selected.id),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          if (_busy)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BusyBar(label: _busyLabel.isEmpty ? '處理中...' : _busyLabel),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Models / Extensions
// ------------------------------------------------------------
class _WarrantyRow {
  final String id;
  final Map<String, dynamic> data;
  _WarrantyRow({required this.id, required this.data});
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ------------------------------------------------------------
// Filters UI
// ------------------------------------------------------------
class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchCtrl,
    required this.status,
    required this.countLabel,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onStatusChanged,
    required this.onAdd,
    required this.onExport,
  });

  final TextEditingController searchCtrl;
  final String? status;
  final String countLabel;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String?> onStatusChanged;

  final VoidCallback onAdd;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final search = TextField(
      controller: searchCtrl,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        hintText: '搜尋：serial / 商品 / 客戶 / 電話 / Email / 備註 / ID',
        suffixIcon: searchCtrl.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: '清除',
                onPressed: onClearQuery,
                icon: const Icon(Icons.clear),
              ),
      ),
      onChanged: onQueryChanged,
    );

    final dd = DropdownButtonFormField<String?>(
      value: status,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        labelText: '狀態',
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('全部')),
        DropdownMenuItem(value: 'active', child: Text('active')),
        DropdownMenuItem(value: 'expired', child: Text('expired')),
        DropdownMenuItem(value: 'void', child: Text('void')),
      ],
      onChanged: onStatusChanged,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 980;

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: dd),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('新增'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('匯出CSV'),
                    ),
                    const SizedBox(width: 10),
                    Text('共 $countLabel', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              SizedBox(width: 220, child: dd),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined),
                label: const Text('匯出CSV'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('新增'),
              ),
              const SizedBox(width: 10),
              Text('共 $countLabel', style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Detail Panel / Dialog
// ------------------------------------------------------------
class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.id,
    required this.data,
    required this.fmt,
    required this.toDate,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  final String id;
  final Map<String, dynamic> data;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  final Future<void> Function(String text, {String done}) onCopy;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final serial = _s(data['serial']);
    final status = _s(data['status']).isEmpty ? 'active' : _s(data['status']);
    final productName = _s(data['productName']);
    final productId = _s(data['productId']);
    final customerName = _s(data['customerName']);
    final customerPhone = _s(data['customerPhone']);
    final customerEmail = _s(data['customerEmail']);
    final note = _s(data['note']);

    final purchaseAt = toDate(data['purchaseAt']);
    final expireAt = toDate(data['expireAt']);
    final createdAt = toDate(data['createdAt']);
    final updatedAt = toDate(data['updatedAt']);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(serial.isEmpty ? '（無序號）' : serial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: status, color: _statusColor(context, status)),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'warrantyId', value: id, onCopy: () => onCopy(id, done: '已複製 warrantyId')),
          const SizedBox(height: 6),
          _InfoRow(label: 'serial', value: serial, onCopy: serial.isEmpty ? null : () => onCopy(serial, done: '已複製 serial')),
          const SizedBox(height: 6),
          _InfoRow(label: 'productName', value: productName),
          const SizedBox(height: 6),
          _InfoRow(label: 'productId', value: productId),
          const SizedBox(height: 6),
          _InfoRow(label: 'customerName', value: customerName),
          const SizedBox(height: 6),
          _InfoRow(label: 'customerPhone', value: customerPhone),
          const SizedBox(height: 6),
          _InfoRow(label: 'customerEmail', value: customerEmail),
          const SizedBox(height: 6),
          _InfoRow(label: 'purchaseAt', value: fmt(purchaseAt)),
          const SizedBox(height: 6),
          _InfoRow(label: 'expireAt', value: fmt(expireAt)),
          const SizedBox(height: 6),
          _InfoRow(label: 'createdAt', value: fmt(createdAt)),
          const SizedBox(height: 6),
          _InfoRow(label: 'updatedAt', value: fmt(updatedAt)),
          const SizedBox(height: 12),
          Text('備註', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline.withOpacity(0.18)),
            ),
            child: Text(note.isEmpty ? '（無備註）' : note),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('編輯')),
              OutlinedButton.icon(
                onPressed: () => onCopy(jsonEncode(data), done: '已複製 JSON'),
                icon: const Icon(Icons.code),
                label: const Text('複製 JSON'),
              ),
              TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline), label: const Text('刪除')),
            ],
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              '提示：若你要「序號精準查詢」，建議用 serialUpper 做一致化查詢。',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDialog extends StatelessWidget {
  const _DetailDialog({
    required this.id,
    required this.data,
    required this.fmt,
    required this.toDate,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  final String id;
  final Map<String, dynamic> data;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  final Future<void> Function(String text, {String done}) onCopy;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final serial = _s(data['serial']).isEmpty ? '（無序號）' : _s(data['serial']);
    final status = _s(data['status']).isEmpty ? 'active' : _s(data['status']);

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(
        width: 640,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(serial, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                  _Pill(label: status, color: _statusColor(context, status)),
                  IconButton(
                    tooltip: '複製 warrantyId',
                    onPressed: () => onCopy(id, done: '已複製 warrantyId'),
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _InfoRow(label: 'warrantyId', value: id),
              const SizedBox(height: 6),
              _InfoRow(label: 'expireAt', value: fmt(toDate(data['expireAt']))),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_s(data['note']).isEmpty ? '（無備註）' : _s(data['note'])),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('編輯'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('刪除'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Shared Widgets
// ------------------------------------------------------------
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.onCopy});
  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 108, child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
        Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w800))),
        if (onCopy != null)
          IconButton(
            tooltip: '複製',
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 18),
          ),
      ],
    );
  }
}

class _BusyBar extends StatelessWidget {
  const _BusyBar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(BuildContext context, String status) {
  final s = status.trim().toLowerCase();
  final cs = Theme.of(context).colorScheme;
  switch (s) {
    case 'active':
      return cs.primary;
    case 'expired':
      return cs.tertiary;
    case 'void':
      return cs.error;
    default:
      return cs.primary;
  }
}

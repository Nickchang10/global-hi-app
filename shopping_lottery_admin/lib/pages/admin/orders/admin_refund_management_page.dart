// lib/pages/admin/orders/admin_refund_management_page.dart
//
// ✅ AdminRefundManagementPage（退款管理｜完整版｜可直接編譯）
// -----------------------------------------------------------------------------
// 目的：後台處理退款申請（審核 / 駁回 / 完成）
//
// 支援兩種資料來源（可切換）：
// 1) refunds 集合：refunds/{refundId}
//    建議欄位（可缺省）：
//    - orderId, userId, userEmail, userName, phone
//    - status: pending/approved/rejected/completed
//    - reason, note
//    - amount, currency
//    - createdAt, updatedAt (Timestamp)
//    - paymentMethod, transactionId
//
// 2) orders 集合：orders/{orderId}
//    建議欄位（可缺省）：
//    - refundStatus: pending/approved/rejected/completed
//    - refundReason, refundNote, refundAmount
//    - status（整體訂單狀態，可選）
//
// 功能：
// - 分頁載入
// - 篩選：狀態 pending/approved/rejected/completed/all
// - 搜尋：
//   - 精準查：orderId（docId 或欄位 orderId）
//   - 精準查：userEmail（若有 userEmail）
//   - 列表內關鍵字過濾（local）
// - 明細：顯示申請內容、訂單/付款資訊（能顯示就顯示）
// - 操作：核准 / 駁回 / 標記完成（會更新對應 doc）
//
// ⚠️ Firestore 索引：
// - 若你套用 where(status==...) + orderBy(createdAt) 可能需要複合索引；
//   一旦報錯，Firebase Console 會提供建立索引連結。
// -----------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminRefundManagementPage extends StatefulWidget {
  const AdminRefundManagementPage({super.key});

  @override
  State<AdminRefundManagementPage> createState() => _AdminRefundManagementPageState();
}

class _AdminRefundManagementPageState extends State<AdminRefundManagementPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;

  // Data source: refunds or orders
  String _source = 'refunds'; // refunds / orders

  // Filters
  String _status = 'pending'; // all / pending / approved / rejected / completed
  bool _onlyWithAmount = false;

  // Search
  String _searchMode = 'orderId'; // orderId / email / local
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchValue = '';

  // Pagination
  static const int _pageSize = 25;
  final List<_RefundRow> _rows = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // =============================================================================
  // Load
  // =============================================================================
  Future<void> _load({required bool reset}) async {
    if (!mounted) return;

    setState(() {
      if (reset) _loading = true;
      _error = null;
      if (reset) {
        _rows.clear();
        _lastDoc = null;
        _hasMore = true;
      }
    });

    try {
      // 精準查：orderId
      if (_searchMode == 'orderId' && _searchValue.trim().isNotEmpty) {
        final id = _searchValue.trim();
        final rows = await _fetchByOrderId(id);
        if (!mounted) return;
        setState(() {
          _rows
            ..clear()
            ..addAll(rows);
          _hasMore = false;
          _lastDoc = null;
        });
        return;
      }

      // 精準查：email
      if (_searchMode == 'email' && _searchValue.trim().isNotEmpty) {
        final email = _searchValue.trim();
        final rows = await _fetchByEmail(email);
        if (!mounted) return;
        setState(() {
          _rows
            ..clear()
            ..addAll(rows);
          _hasMore = false;
          _lastDoc = null;
        });
        return;
      }

      // 一般分頁列表
      final page = await _fetchPage(
        startAfter: reset ? null : _lastDoc,
        limit: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _rows.addAll(page.rows);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      if (reset) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      await _load(reset: false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // =============================================================================
  // Queries
  // =============================================================================
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_source == 'refunds' ? 'refunds' : 'orders');

  String get _statusField => _source == 'refunds' ? 'status' : 'refundStatus';

  String get _createdAtField => _source == 'refunds' ? 'createdAt' : 'createdAt';

  Future<List<_RefundRow>> _fetchByOrderId(String orderId) async {
    final localKeyword = (_searchMode == 'local') ? _searchValue.trim().toLowerCase() : '';

    // refunds：可能 orderId 欄位 or docId；兩段查詢
    if (_source == 'refunds') {
      final byDoc = await _col.doc(orderId).get();
      final rows = <_RefundRow>[];

      if (byDoc.exists) {
        final r = _RefundRow(
          id: byDoc.id,
          data: byDoc.data() ?? {},
          source: _source,
        );
        if (await _passesFilters(r, localKeyword: localKeyword)) rows.add(r);
      }

      // 再查 orderId 欄位
      final byField = await _col.where('orderId', isEqualTo: orderId).limit(25).get();
      for (final d in byField.docs) {
        if (rows.any((x) => x.id == d.id)) continue;
        final r = _RefundRow(id: d.id, data: d.data(), source: _source);
        if (await _passesFilters(r, localKeyword: localKeyword)) rows.add(r);
      }

      return rows;
    }

    // orders：docId / orderId 欄位
    final byDoc = await _col.doc(orderId).get();
    final rows = <_RefundRow>[];

    if (byDoc.exists) {
      final r = _RefundRow(id: byDoc.id, data: byDoc.data() ?? {}, source: _source);
      if (await _passesFilters(r, localKeyword: localKeyword)) rows.add(r);
    }

    final byField = await _col.where('orderId', isEqualTo: orderId).limit(25).get();
    for (final d in byField.docs) {
      if (rows.any((x) => x.id == d.id)) continue;
      final r = _RefundRow(id: d.id, data: d.data(), source: _source);
      if (await _passesFilters(r, localKeyword: localKeyword)) rows.add(r);
    }

    return rows;
  }

  Future<List<_RefundRow>> _fetchByEmail(String email) async {
    // refunds：userEmail
    if (_source == 'refunds') {
      Query<Map<String, dynamic>> q = _col.where('userEmail', isEqualTo: email);
      if (_status != 'all') q = q.where(_statusField, isEqualTo: _status);

      // 排序（如果 createdAt 不存在會拋錯）
      q = q.orderBy(_createdAtField, descending: true);

      final snap = await q.limit(50).get();
      final rows = <_RefundRow>[];
      for (final d in snap.docs) {
        final r = _RefundRow(id: d.id, data: d.data(), source: _source);
        if (await _passesFilters(r)) rows.add(r);
      }
      return rows;
    }

    // orders：userEmail
    Query<Map<String, dynamic>> q = _col.where('userEmail', isEqualTo: email);
    if (_status != 'all') q = q.where(_statusField, isEqualTo: _status);
    q = q.orderBy(_createdAtField, descending: true);

    final snap = await q.limit(50).get();
    final rows = <_RefundRow>[];
    for (final d in snap.docs) {
      final r = _RefundRow(id: d.id, data: d.data(), source: _source);
      if (await _passesFilters(r)) rows.add(r);
    }
    return rows;
  }

  Future<_PagedRefunds> _fetchPage({
    required DocumentSnapshot<Map<String, dynamic>>? startAfter,
    required int limit,
  }) async {
    Query<Map<String, dynamic>> q = _col;

    if (_status != 'all') {
      q = q.where(_statusField, isEqualTo: _status);
    }

    // 排序：createdAt desc（若你的資料沒有 createdAt，請改成 updatedAt 或先補欄位）
    q = q.orderBy(_createdAtField, descending: true);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.limit(limit).get();
    final docs = snap.docs;

    final localKeyword = (_searchMode == 'local') ? _searchValue.trim().toLowerCase() : '';
    final rowsAll = docs.map((d) => _RefundRow(id: d.id, data: d.data(), source: _source)).toList();

    final filtered = <_RefundRow>[];
    for (final r in rowsAll) {
      if (await _passesFilters(r, localKeyword: localKeyword)) filtered.add(r);
    }

    final lastDoc = docs.isEmpty ? startAfter : docs.last;
    final hasMore = docs.length == limit;

    return _PagedRefunds(rows: filtered, lastDoc: lastDoc, hasMore: hasMore);
  }

  // =============================================================================
  // Filter rules
  // =============================================================================
  Future<bool> _passesFilters(_RefundRow row, {String localKeyword = ''}) async {
    if (_onlyWithAmount) {
      final amount = _readNum(_refundAmountOf(row));
      if (amount <= 0) return false;
    }

    if (localKeyword.isNotEmpty) {
      final orderId = _orderIdOf(row).toLowerCase();
      final email = _userEmailOf(row).toLowerCase();
      final name = _userNameOf(row).toLowerCase();
      final phone = _userPhoneOf(row).toLowerCase();
      final status = _refundStatusOf(row).toLowerCase();

      final hit = orderId.contains(localKeyword) ||
          email.contains(localKeyword) ||
          name.contains(localKeyword) ||
          phone.contains(localKeyword) ||
          status.contains(localKeyword) ||
          row.id.toLowerCase().contains(localKeyword);

      if (!hit) return false;
    }

    return true;
  }

  // =============================================================================
  // Actions
  // =============================================================================
  Future<void> _setRefundStatus(_RefundRow row, String newStatus, {String? note}) async {
    // refunds：更新 refunds doc
    if (row.source == 'refunds') {
      await _db.collection('refunds').doc(row.id).set(
        {
          'status': newStatus,
          if (note != null) 'note': note,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return;
    }

    // orders：更新 orders doc
    await _db.collection('orders').doc(row.id).set(
      {
        'refundStatus': newStatus,
        if (note != null) 'refundNote': note,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _approve(_RefundRow row) async {
    final note = await _askText(title: '核准退款', hint: '可選：填寫備註（例如退款方式/處理人/原因）');
    try {
      await _setRefundStatus(row, 'approved', note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已核准')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('核准失敗：$e')));
    }
  }

  Future<void> _reject(_RefundRow row) async {
    final reason = await _askText(title: '駁回退款', hint: '請填寫駁回原因（建議必填）');
    if ((reason ?? '').trim().isEmpty) return;

    try {
      await _setRefundStatus(row, 'rejected', note: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已駁回')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('駁回失敗：$e')));
    }
  }

  Future<void> _complete(_RefundRow row) async {
    final ok = await _confirm(
      title: '標記完成',
      message: '確定將此退款標記為 completed？',
      confirmText: '完成',
    );
    if (!ok) return;

    try {
      await _setRefundStatus(row, 'completed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已標記完成')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  // =============================================================================
  // Search helpers
  // =============================================================================
  Future<void> _applySearch() async {
    setState(() => _searchValue = _searchCtrl.text.trim());
    await _load(reset: true);
  }

  Future<void> _clearSearch() async {
    _searchCtrl.clear();
    setState(() => _searchValue = '');
    await _load(reset: true);
  }

  // =============================================================================
  // UI
  // =============================================================================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('退款管理', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _ErrorView(
          title: '載入失敗',
          message: _error!,
          onRetry: () => _load(reset: true),
          hint: '常見原因：createdAt 欄位不存在導致 orderBy 失敗、索引未建立、或權限不足。',
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('退款管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(tooltip: '重新整理', onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _filtersCard(cs),
            const SizedBox(height: 12),
            _summaryBar(cs),
            const SizedBox(height: 12),

            if (_rows.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '目前沒有符合條件的退款資料。\n\n'
                    '提示：若尚未上線或尚未建立 refunds / refundStatus 資料，這是正常狀況。',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              ..._rows.map(_rowCard).toList(),

            const SizedBox(height: 12),

            if (_hasMore && _searchMode != 'orderId' && _searchMode != 'email')
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: _loadingMore
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.expand_more),
                  label: Text(_loadingMore ? '載入中...' : '載入更多'),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _filtersCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('篩選與搜尋', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _dropdown<String>(
                  label: '資料來源',
                  value: _source,
                  items: const [
                    DropdownMenuItem(value: 'refunds', child: Text('refunds 集合')),
                    DropdownMenuItem(value: 'orders', child: Text('orders（refundStatus）')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _source = v);
                    await _load(reset: true);
                  },
                ),
                _dropdown<String>(
                  label: '狀態',
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部')),
                    DropdownMenuItem(value: 'pending', child: Text('pending（待審核）')),
                    DropdownMenuItem(value: 'approved', child: Text('approved（已核准）')),
                    DropdownMenuItem(value: 'rejected', child: Text('rejected（已駁回）')),
                    DropdownMenuItem(value: 'completed', child: Text('completed（已完成）')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _status = v);
                    await _load(reset: true);
                  },
                ),
                FilterChip(
                  label: const Text('只看有退款金額'),
                  selected: _onlyWithAmount,
                  onSelected: (v) async {
                    setState(() => _onlyWithAmount = v);
                    await _load(reset: true);
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _searchMode,
                    items: const [
                      DropdownMenuItem(value: 'orderId', child: Text('精準查 orderId')),
                      DropdownMenuItem(value: 'email', child: Text('精準查 userEmail')),
                      DropdownMenuItem(value: 'local', child: Text('列表內關鍵字過濾')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() {
                        _searchMode = v;
                        _searchValue = _searchCtrl.text.trim();
                      });
                      await _load(reset: true);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.search),
                      hintText: _searchMode == 'orderId'
                          ? '輸入 orderId（docId 或欄位）'
                          : _searchMode == 'email'
                              ? '輸入 userEmail'
                              : '輸入關鍵字（orderId/email/name/phone/status）',
                      suffixIcon: _searchCtrl.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除',
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _applySearch(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _applySearch,
                  icon: const Icon(Icons.search),
                  label: const Text('套用'),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              _searchMode == 'local'
                  ? '提示：此模式只會過濾已載入清單，並非全庫搜尋。'
                  : _searchMode == 'email'
                      ? '提示：需確保資料內有 userEmail 欄位。'
                      : '提示：orderId 最穩定。',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryBar(ColorScheme cs) {
    final total = _rows.length;
    final pending = _rows.where((r) => _refundStatusOf(r) == 'pending').length;
    final approved = _rows.where((r) => _refundStatusOf(r) == 'approved').length;
    final rejected = _rows.where((r) => _refundStatusOf(r) == 'rejected').length;
    final completed = _rows.where((r) => _refundStatusOf(r) == 'completed').length;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _badge('已載入', '$total'),
            _badge('pending', '$pending'),
            _badge('approved', '$approved'),
            _badge('rejected', '$rejected'),
            _badge('completed', '$completed'),
          ],
        ),
      ),
    );
  }

  Widget _rowCard(_RefundRow row) {
    final cs = Theme.of(context).colorScheme;
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    final status = _refundStatusOf(row);
    final orderId = _orderIdOf(row);
    final email = _userEmailOf(row);
    final name = _userNameOf(row);
    final phone = _userPhoneOf(row);

    final createdAt = _readDate(row.data[_createdAtField] ?? row.data['createdAt']);
    final createdText = createdAt == null ? '-' : DateFormat('yyyy/MM/dd HH:mm').format(createdAt);

    final amount = _readNum(_refundAmountOf(row));
    final amountText = amount <= 0 ? '-' : fmtMoney.format(amount);

    final reason = _reasonOf(row);

    Color chipColor;
    if (status == 'pending') chipColor = Colors.orange;
    else if (status == 'approved') chipColor = Colors.blue;
    else if (status == 'rejected') chipColor = cs.error;
    else if (status == 'completed') chipColor = Colors.green;
    else chipColor = Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order：${orderId.isEmpty ? row.id : orderId}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: chipColor.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    status.isEmpty ? 'unknown' : status,
                    style: TextStyle(color: chipColor, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _kv('建立', createdText),
                _kv('金額', amountText),
                _kv('Email', email.isEmpty ? '-' : email),
                _kv('姓名', name.isEmpty ? '-' : name),
                _kv('電話', phone.isEmpty ? '-' : phone),
              ],
            ),

            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('原因：$reason', style: TextStyle(color: cs.onSurfaceVariant)),
            ],

            const Divider(height: 18),

            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _openDetail(row),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('查看明細'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final text = orderId.isNotEmpty ? orderId : row.id;
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製')));
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('複製編號'),
                ),

                if (status == 'pending') ...[
                  OutlinedButton.icon(
                    onPressed: () => _approve(row),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('核准'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _reject(row),
                    icon: Icon(Icons.cancel_outlined, color: cs.error),
                    label: Text('駁回', style: TextStyle(color: cs.error)),
                  ),
                ],

                if (status == 'approved')
                  OutlinedButton.icon(
                    onPressed: () => _complete(row),
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('標記完成'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(_RefundRow row) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminRefundDetailPage(row: row),
      ),
    );
    if (mounted) await _load(reset: true);
  }

  // =============================================================================
  // Field extractors (tolerant)
  // =============================================================================
  String _refundStatusOf(_RefundRow row) {
    final v = row.data[_statusField] ?? row.data['status'] ?? row.data['refundStatus'];
    return (v ?? '').toString();
  }

  String _orderIdOf(_RefundRow row) {
    if (row.source == 'orders') {
      // orders doc id 通常就是 orderId
      return (row.data['orderId'] ?? row.id).toString();
    }
    return (row.data['orderId'] ?? row.data['order'] ?? '').toString();
  }

  dynamic _refundAmountOf(_RefundRow row) {
    if (row.source == 'refunds') {
      return row.data['amount'] ?? row.data['refundAmount'] ?? 0;
    }
    // orders
    return row.data['refundAmount'] ?? row.data['amountRefund'] ?? 0;
  }

  String _reasonOf(_RefundRow row) {
    if (row.source == 'refunds') {
      return (row.data['reason'] ?? row.data['refundReason'] ?? '').toString();
    }
    return (row.data['refundReason'] ?? row.data['reason'] ?? '').toString();
  }

  String _userEmailOf(_RefundRow row) => (row.data['userEmail'] ?? row.data['email'] ?? '').toString();
  String _userNameOf(_RefundRow row) => (row.data['userName'] ?? row.data['displayName'] ?? '').toString();
  String _userPhoneOf(_RefundRow row) => (row.data['phone'] ?? row.data['userPhone'] ?? '').toString();

  // =============================================================================
  // UI helpers
  // =============================================================================
  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label：', style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _badge(String title, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.black.withValues(alpha: 0.06),
          ),
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$k：', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        Text(v, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  DateTime? _readDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  num _readNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmText)),
        ],
      ),
    );
    return res ?? false;
  }

  Future<String?> _askText({required String title, required String hint}) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('確定')),
        ],
      ),
    );
    return res;
  }
}

// =============================================================================
// Detail Page
// =============================================================================
class AdminRefundDetailPage extends StatelessWidget {
  final _RefundRow row;
  const AdminRefundDetailPage({super.key, required this.row});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    String s(dynamic v) => (v ?? '').toString();

    final status = s(row.data[row.source == 'refunds' ? 'status' : 'refundStatus']);
    final orderId = row.source == 'orders' ? s(row.data['orderId'] ?? row.id) : s(row.data['orderId']);
    final createdAt = _readDate(row.data['createdAt']);
    final updatedAt = _readDate(row.data['updatedAt']);
    final amount = _readNum(row.source == 'refunds' ? (row.data['amount'] ?? row.data['refundAmount']) : (row.data['refundAmount']));
    final reason = s(row.source == 'refunds' ? (row.data['reason'] ?? row.data['refundReason']) : row.data['refundReason']);
    final note = s(row.source == 'refunds' ? row.data['note'] : row.data['refundNote']);

    final userEmail = s(row.data['userEmail'] ?? row.data['email']);
    final userName = s(row.data['userName'] ?? row.data['displayName']);
    final phone = s(row.data['phone'] ?? row.data['userPhone']);

    final paymentMethod = s(row.data['paymentMethod'] ?? row.data['payment']);
    final txId = s(row.data['transactionId'] ?? row.data['txId']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('退款明細', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _chip('來源', row.source),
                  _chip('狀態', status.isEmpty ? 'unknown' : status),
                  _chip('orderId', orderId.isEmpty ? row.id : orderId),
                  _chip('金額', amount <= 0 ? '-' : fmtMoney.format(amount)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          _section(
            title: '用戶資訊',
            children: [
              _kv('Email', userEmail.isEmpty ? '-' : userEmail),
              _kv('姓名', userName.isEmpty ? '-' : userName),
              _kv('電話', phone.isEmpty ? '-' : phone),
            ],
          ),
          const SizedBox(height: 12),

          _section(
            title: '申請資訊',
            children: [
              _kv('原因', reason.isEmpty ? '-' : reason),
              _kv('備註', note.isEmpty ? '-' : note),
              _kv('建立時間', createdAt == null ? '-' : DateFormat('yyyy/MM/dd HH:mm').format(createdAt)),
              _kv('更新時間', updatedAt == null ? '-' : DateFormat('yyyy/MM/dd HH:mm').format(updatedAt)),
            ],
          ),
          const SizedBox(height: 12),

          _section(
            title: '付款資訊（若有）',
            children: [
              _kv('付款方式', paymentMethod.isEmpty ? '-' : paymentMethod),
              _kv('交易編號', txId.isEmpty ? '-' : txId),
            ],
          ),
          const SizedBox(height: 18),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '提示：若你尚未上架或測試資料不足，明細可能顯示「-」。\n'
                '你可以先用測試訂單建立 refundStatus / refunds 文件來驗證流程。',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static DateTime? _readDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static num _readNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  Widget _chip(String k, String v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$k：', style: const TextStyle(fontWeight: FontWeight.w900)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.black.withValues(alpha: 0.06),
          ),
          child: Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w900))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

// =============================================================================
// Models
// =============================================================================
class _RefundRow {
  final String id; // docId
  final Map<String, dynamic> data;
  final String source; // refunds / orders

  _RefundRow({
    required this.id,
    required this.data,
    required this.source,
  });
}

class _PagedRefunds {
  final List<_RefundRow> rows;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;

  _PagedRefunds({
    required this.rows,
    required this.lastDoc,
    required this.hasMore,
  });
}

// =============================================================================
// Error View
// =============================================================================
class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? hint;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
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
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
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
      ),
    );
  }
}

// lib/pages/admin/carts/admin_carts_page.dart
//
// ✅ AdminCartsPage（購物車管理｜完整版｜可直接編譯）
// -----------------------------------------------------------------------------
// 功能：
// - 列出 carts（分頁）
// - 篩選：status（all/active/abandoned/converted）
// - 日期區間：updatedAt 範圍
// - 搜尋：
//    1) 精準搜尋（email / userId / cartId）→ 直接打 Firestore where / doc
//    2) 本頁關鍵字過濾（local filter）
// - 進入購物車詳情：
//    - 顯示 items（支援 items array 或 carts/{id}/items 子集合）
//    - 可修改數量 / 刪除品項
//    - 可一鍵清空購物車
// - 匯出 CSV：
//    - 匯出「目前列表（可見）」或「單一購物車明細」
//    - 使用 utils/report_file_saver.dart 的 saveReportBytes（Web / IO 自動分流）
//
// 依賴：
// - cloud_firestore
// - intl
// - csv
// - 你的 lib/utils/report_file_saver.dart（需提供 saveReportBytes）
//
// Firestore 建議資料結構：
// carts/{cartId} fields (建議/常見)：
//  - userId (String)
//  - userEmail (String)
//  - userName (String)
//  - phone (String)
//  - status (String)  // active/abandoned/converted
//  - couponCode (String)
//  - note (String)
//  - subtotal (num)
//  - discountAmount (num)
//  - shippingFee (num)
//  - total (num)
//  - itemsCount (num/int)
//  - createdAt (Timestamp)
//  - updatedAt (Timestamp)  ★本頁依賴 orderBy(updatedAt)
//
// items 支援兩種：
// A) carts/{id}.items = List<Map>（每個 item 建議包含：productId/name/price/qty/vendorId）
// B) carts/{id}/items/{itemId} docs（欄位同上）
// -----------------------------------------------------------------------------


import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:osmile_admin/utils/report_file_saver.dart';

class AdminCartsPage extends StatefulWidget {
  const AdminCartsPage({super.key});

  @override
  State<AdminCartsPage> createState() => _AdminCartsPageState();
}

class _AdminCartsPageState extends State<AdminCartsPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Filters
  String _status = 'all'; // all/active/abandoned/converted
  DateTimeRange? _range; // updatedAt range
  final TextEditingController _searchCtrl = TextEditingController();
  String _localKeyword = '';

  // Loading/Error
  bool _loading = true;
  String? _error;

  // Pagination
  static const int _pageSize = 30;
  final List<_CartRow> _rows = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;

  // Export feedback
  String? _exportResult;

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
  // Query
  // =============================================================================
  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> q = _db.collection('carts');

    if (_status != 'all') {
      q = q.where('status', isEqualTo: _status);
    }

    final r = _range;
    if (r != null) {
      q = q.where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(r.start));
      q = q.where('updatedAt', isLessThanOrEqualTo: Timestamp.fromDate(r.end));
    }

    // 重要：需要 carts 皆有 updatedAt（Timestamp），否則 orderBy 會失敗
    q = q.orderBy('updatedAt', descending: true);
    return q;
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
        _exportResult = null;
      }
    });

    try {
      Query<Map<String, dynamic>> q = _baseQuery();
      if (!reset && _lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }

      final snap = await q.limit(_pageSize).get();
      final docs = snap.docs;

      final pageRows = docs.map((d) => _CartRow(id: d.id, data: d.data())).toList();
      final last = docs.isEmpty ? _lastDoc : docs.last;

      if (!mounted) return;
      setState(() {
        _rows.addAll(pageRows);
        _lastDoc = last;
        _hasMore = docs.length == _pageSize;
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
  // Search
  // =============================================================================
  void _applyLocalSearch() {
    setState(() => _localKeyword = _searchCtrl.text.trim().toLowerCase());
  }

  void _clearLocalSearch() {
    _searchCtrl.clear();
    setState(() => _localKeyword = '');
  }

  /// 精準搜尋：email / userId / cartId
  Future<void> _runExactSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先輸入搜尋條件')));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _rows.clear();
      _lastDoc = null;
      _hasMore = false;
      _exportResult = null;
      _localKeyword = '';
    });

    try {
      // 1) 若像是 document id（cartId），直接抓 doc
      //    （這裡不強判格式，直接先試 get doc）
      final doc = await _db.collection('carts').doc(q).get();
      if (doc.exists) {
        setState(() {
          _rows.add(_CartRow(id: doc.id, data: doc.data() ?? {}));
          _loading = false;
        });
        return;
      }

      // 2) email
      if (q.contains('@')) {
        final snap = await _db.collection('carts').where('userEmail', isEqualTo: q).limit(60).get();
        setState(() {
          _rows.addAll(snap.docs.map((d) => _CartRow(id: d.id, data: d.data())));
          _loading = false;
        });
        return;
      }

      // 3) userId
      final snap = await _db.collection('carts').where('userId', isEqualTo: q).limit(60).get();
      setState(() {
        _rows.addAll(snap.docs.map((d) => _CartRow(id: d.id, data: d.data())));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<_CartRow> get _visibleRows {
    final kw = _localKeyword;
    if (kw.isEmpty) return _rows;

    bool hit(_CartRow r) {
      final id = r.id.toLowerCase();
      final userId = (r.data['userId'] ?? '').toString().toLowerCase();
      final email = (r.data['userEmail'] ?? '').toString().toLowerCase();
      final name = (r.data['userName'] ?? r.data['displayName'] ?? '').toString().toLowerCase();
      final phone = (r.data['phone'] ?? '').toString().toLowerCase();
      final status = (r.data['status'] ?? '').toString().toLowerCase();
      final coupon = (r.data['couponCode'] ?? '').toString().toLowerCase();

      return id.contains(kw) ||
          userId.contains(kw) ||
          email.contains(kw) ||
          name.contains(kw) ||
          phone.contains(kw) ||
          status.contains(kw) ||
          coupon.contains(kw);
    }

    return _rows.where(hit).toList();
  }

  // =============================================================================
  // Filters
  // =============================================================================
  Future<void> _pickRange() async {
    final now = DateTime.now();
    final init = _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      initialDateRange: init,
      helpText: '選擇購物車日期區間（updatedAt）',
      confirmText: '套用',
      cancelText: '取消',
    );

    if (picked == null) return;

    setState(() {
      _range = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    });

    await _load(reset: true);
  }

  Future<void> _clearRange() async {
    setState(() => _range = null);
    await _load(reset: true);
  }

  // =============================================================================
  // Export CSV (visible list)
  // =============================================================================
  Future<void> _exportVisibleCsv() async {
    final rows = _visibleRows;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('目前沒有可匯出的資料')));
      return;
    }

    try {
      final bytes = _buildCartsCsvBytes(rows);
      final filename = 'carts_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
      final saved = await saveReportBytes(
        filename: filename,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      if (!mounted) return;
      setState(() => _exportResult = saved);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV 匯出完成')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    }
  }

  List<int> _buildCartsCsvBytes(List<_CartRow> carts) {
    final csvData = <List<dynamic>>[];

    csvData.add([
      'cartId',
      'userId',
      'userEmail',
      'userName',
      'phone',
      'status',
      'itemsCount',
      'subtotal',
      'discountAmount',
      'shippingFee',
      'total',
      'couponCode',
      'updatedAt',
    ]);

    String fmtTs(dynamic v) {
      if (v is Timestamp) return DateFormat('yyyy-MM-dd HH:mm').format(v.toDate());
      return '';
    }

    num toNum(dynamic v) {
      if (v is num) return v;
      return num.tryParse(v?.toString() ?? '0') ?? 0;
    }

    for (final c in carts) {
      final d = c.data;
      csvData.add([
        c.id,
        (d['userId'] ?? '').toString(),
        (d['userEmail'] ?? '').toString(),
        (d['userName'] ?? d['displayName'] ?? '').toString(),
        (d['phone'] ?? '').toString(),
        (d['status'] ?? '').toString(),
        (d['itemsCount'] ?? d['itemCount'] ?? 0).toString(),
        toNum(d['subtotal']).toString(),
        toNum(d['discountAmount']).toString(),
        toNum(d['shippingFee']).toString(),
        toNum(d['total']).toString(),
        (d['couponCode'] ?? '').toString(),
        fmtTs(d['updatedAt']),
      ]);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    return utf8.encode('\uFEFF$csvString'); // BOM for Excel
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
          title: const Text('購物車管理', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh))],
        ),
        body: _ErrorView(
          title: '載入購物車失敗',
          message: _error!,
          hint: '常見原因：carts 缺少 updatedAt 欄位（Timestamp）導致 orderBy 失敗、或需要建立複合索引。',
          onRetry: () => _load(reset: true),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final visible = _visibleRows;

    // Header stats（列表只是管理 UI，不代表上架後真實銷售）
    final sumTotal = visible.fold<num>(0, (p, e) => p + _toNum(e.data['total']));
    final sumItems = visible.fold<int>(0, (p, e) => p + (_toNum(e.data['itemsCount']).toInt()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('購物車管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(tooltip: '重新整理', onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh)),
          IconButton(tooltip: '匯出目前可見 CSV', onPressed: _exportVisibleCsv, icon: const Icon(Icons.download)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _filtersCard(cs),
            const SizedBox(height: 12),

            _statsCard(cs, cartsCount: visible.length, itemsCount: sumItems, total: sumTotal),
            const SizedBox(height: 12),

            if (_exportResult != null) _exportResultCard(cs),
            if (_exportResult != null) const SizedBox(height: 12),

            if (visible.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '目前沒有符合條件的購物車。\n\n'
                    '提示：尚未上架或尚未建立測試使用者與購物車時，沒有數字是正常狀況。',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...visible.map(_cartTile).toList(),

            const SizedBox(height: 12),

            if (_hasMore)
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: _loadingMore
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.expand_more),
                  label: Text(_loadingMore ? '載入中...' : '載入更多'),
                ),
              ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _filtersCard(ColorScheme cs) {
    final fmt = DateFormat('yyyy/MM/dd');
    final rangeText = _range == null ? '未設定' : '${fmt.format(_range!.start)} - ${fmt.format(_range!.end)}';

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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('狀態：', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('全部')),
                        DropdownMenuItem(value: 'active', child: Text('active')),
                        DropdownMenuItem(value: 'abandoned', child: Text('abandoned')),
                        DropdownMenuItem(value: 'converted', child: Text('converted')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _status = v);
                        await _load(reset: true);
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('更新日期：', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(rangeText),
                    ),
                    if (_range != null) ...[
                      const SizedBox(width: 8),
                      TextButton(onPressed: _clearRange, child: const Text('清除')),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _applyLocalSearch(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜尋（cartId / userId / email 可用「精準搜尋」）或本頁關鍵字',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: _searchCtrl.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除',
                              onPressed: _clearLocalSearch,
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: _runExactSearch,
                  icon: const Icon(Icons.manage_search),
                  label: const Text('精準搜尋'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _applyLocalSearch,
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('本頁過濾'),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              '說明：\n'
              '• 「精準搜尋」會直接查 Firestore（email/userId/cartId）。\n'
              '• 「本頁過濾」只過濾目前已載入的列表（不打 Firestore）。',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsCard(ColorScheme cs, {required int cartsCount, required int itemsCount, required num total}) {
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _miniStat('購物車數', cartsCount.toString()),
            _miniStat('品項總數', itemsCount.toString()),
            _miniStat('總金額（列表合計）', fmtMoney.format(total)),
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

  Widget _exportResultCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('匯出結果', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(_exportResult ?? '-', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _cartTile(_CartRow row) {
    final cs = Theme.of(context).colorScheme;
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    final d = row.data;
    final status = (d['status'] ?? '').toString();
    final total = _toNum(d['total']);
    final itemsCount = _toNum(d['itemsCount'] ?? d['itemCount']).toInt();

    final userEmail = (d['userEmail'] ?? '').toString();
    final userName = (d['userName'] ?? d['displayName'] ?? '').toString();
    final phone = (d['phone'] ?? '').toString();
    final coupon = (d['couponCode'] ?? '').toString();

    String updatedText = '-';
    final updatedAt = d['updatedAt'];
    if (updatedAt is Timestamp) {
      updatedText = DateFormat('yyyy/MM/dd HH:mm').format(updatedAt.toDate());
    }

    Color chipColor;
    if (status == 'active') chipColor = Colors.blue;
    else if (status == 'abandoned') chipColor = Colors.orange;
    else if (status == 'converted') chipColor = Colors.green;
    else chipColor = Colors.grey;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(row.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cart：${row.id}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  _kv('更新', updatedText),
                  _kv('品項', itemsCount.toString()),
                  _kv('金額', fmtMoney.format(total)),
                ],
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _kv('Email', userEmail.isEmpty ? '-' : userEmail),
                  _kv('姓名', userName.isEmpty ? '-' : userName),
                  _kv('電話', phone.isEmpty ? '-' : phone),
                ],
              ),

              if (coupon.isNotEmpty) ...[
                const SizedBox(height: 8),
                _kv('Coupon', coupon),
              ],

              const Divider(height: 18),

              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _openDetail(row.id),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('查看/編輯'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _confirmAndClearCart(row.id),
                    icon: Icon(Icons.delete_outline, color: cs.error),
                    label: Text('清空', style: TextStyle(color: cs.error)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

  // =============================================================================
  // Detail
  // =============================================================================
  Future<void> _openDetail(String cartId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminCartDetailPage(cartId: cartId)),
    );
    // 回來後刷新（避免編輯後列表資料不同步）
    await _load(reset: true);
  }

  Future<void> _confirmAndClearCart(String cartId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認清空購物車', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('確定要清空 cart：$cartId 的所有品項？此動作不可復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final ref = _db.collection('carts').doc(cartId);

      // 同時處理 array / subcollection 兩種
      await _clearCart(ref);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空購物車')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('清空失敗：$e')));
    }
  }

  Future<void> _clearCart(DocumentReference<Map<String, dynamic>> cartRef) async {
    // 1) 先嘗試刪除 subcollection items（最多取 500；若你量更大，可改成分批）
    final itemsSnap = await cartRef.collection('items').limit(500).get();
    if (itemsSnap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final d in itemsSnap.docs) {
        batch.delete(d.reference);
      }
      batch.set(
        cartRef,
        {
          'itemsCount': 0,
          'subtotal': 0,
          'discountAmount': 0,
          'shippingFee': 0,
          'total': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      return;
    }

    // 2) fallback：items array
    await cartRef.set(
      {
        'items': [],
        'itemsCount': 0,
        'subtotal': 0,
        'discountAmount': 0,
        'shippingFee': 0,
        'total': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '0') ?? 0;
  }
}

// =============================================================================
// Detail Page
// =============================================================================
class AdminCartDetailPage extends StatefulWidget {
  final String cartId;
  const AdminCartDetailPage({super.key, required this.cartId});

  @override
  State<AdminCartDetailPage> createState() => _AdminCartDetailPageState();
}

class _AdminCartDetailPageState extends State<AdminCartDetailPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _cart;
  List<Map<String, dynamic>> _items = const [];

  String? _exportResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _exportResult = null;
    });

    try {
      final ref = _db.collection('carts').doc(widget.cartId);
      final doc = await ref.get();
      if (!doc.exists) {
        throw Exception('找不到 cart：${widget.cartId}');
      }

      final data = doc.data() ?? {};
      final items = await _loadItems(ref, data);

      if (!mounted) return;
      setState(() {
        _cart = data;
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadItems(
    DocumentReference<Map<String, dynamic>> cartRef,
    Map<String, dynamic> cartData,
  ) async {
    // A) items subcollection
    final sub = await cartRef.collection('items').limit(500).get();
    if (sub.docs.isNotEmpty) {
      return sub.docs.map((d) => {'_id': d.id, ...d.data()}).toList();
    }

    // B) items array
    final raw = cartData['items'];
    if (raw is List) {
      return raw.map<Map<String, dynamic>>((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    }

    return <Map<String, dynamic>>[];
  }

  // =============================================================================
  // Item operations
  // =============================================================================
  Future<void> _updateQty(int index, int qty) async {
    if (qty < 1) return;

    final cartRef = _db.collection('carts').doc(widget.cartId);
    final doc = await cartRef.get();
    final data = doc.data() ?? {};

    // subcollection mode?
    final sub = await cartRef.collection('items').limit(1).get();
    if (sub.docs.isNotEmpty) {
      final item = _items[index];
      final itemId = (item['_id'] ?? '').toString();
      if (itemId.isEmpty) return;

      await cartRef.collection('items').doc(itemId).set({'qty': qty, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      await cartRef.set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      await _load();
      return;
    }

    // array mode
    final raw = data['items'];
    if (raw is! List) return;

    final list = raw.map<Map<String, dynamic>>((e) {
      if (e is Map<String, dynamic>) return Map<String, dynamic>.from(e);
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{};
    }).toList();

    if (index < 0 || index >= list.length) return;
    list[index]['qty'] = qty;

    await cartRef.set({'items': list, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await _load();
  }

  Future<void> _removeItem(int index) async {
    final cartRef = _db.collection('carts').doc(widget.cartId);

    // subcollection mode?
    final sub = await cartRef.collection('items').limit(1).get();
    if (sub.docs.isNotEmpty) {
      final item = _items[index];
      final itemId = (item['_id'] ?? '').toString();
      if (itemId.isEmpty) return;

      await cartRef.collection('items').doc(itemId).delete();
      await cartRef.set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      await _load();
      return;
    }

    // array mode
    final doc = await cartRef.get();
    final data = doc.data() ?? {};
    final raw = data['items'];
    if (raw is! List) return;

    final list = raw.map<Map<String, dynamic>>((e) {
      if (e is Map<String, dynamic>) return Map<String, dynamic>.from(e);
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{};
    }).toList();

    if (index < 0 || index >= list.length) return;
    list.removeAt(index);

    await cartRef.set({'items': list, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await _load();
  }

  Future<void> _clearCart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認清空購物車', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('確定要清空 cart：${widget.cartId} 的所有品項？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final ref = _db.collection('carts').doc(widget.cartId);

      // 先刪 subcollection items（若存在）
      final itemsSnap = await ref.collection('items').limit(500).get();
      if (itemsSnap.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final d in itemsSnap.docs) {
          batch.delete(d.reference);
        }
        batch.set(ref, {'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        await batch.commit();
      } else {
        // items array
        await ref.set({'items': [], 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('清空失敗：$e')));
    }
  }

  // =============================================================================
  // Export cart detail CSV
  // =============================================================================
  Future<void> _exportCartCsv() async {
    final cart = _cart;
    if (cart == null) return;

    try {
      final bytes = _buildCartDetailCsvBytes(cart, _items);
      final filename = 'cart_${widget.cartId}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
      final saved = await saveReportBytes(filename: filename, bytes: bytes, mimeType: 'text/csv');

      if (!mounted) return;
      setState(() => _exportResult = saved);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV 匯出完成')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    }
  }

  List<int> _buildCartDetailCsvBytes(Map<String, dynamic> cart, List<Map<String, dynamic>> items) {
    final csvData = <List<dynamic>>[];

    csvData.add(['cartId', widget.cartId]);
    csvData.add(['userId', (cart['userId'] ?? '').toString()]);
    csvData.add(['userEmail', (cart['userEmail'] ?? '').toString()]);
    csvData.add(['userName', (cart['userName'] ?? cart['displayName'] ?? '').toString()]);
    csvData.add(['phone', (cart['phone'] ?? '').toString()]);
    csvData.add(['status', (cart['status'] ?? '').toString()]);
    csvData.add(['couponCode', (cart['couponCode'] ?? '').toString()]);
    csvData.add(['subtotal', (cart['subtotal'] ?? 0).toString()]);
    csvData.add(['discountAmount', (cart['discountAmount'] ?? 0).toString()]);
    csvData.add(['shippingFee', (cart['shippingFee'] ?? 0).toString()]);
    csvData.add(['total', (cart['total'] ?? 0).toString()]);
    csvData.add([]);
    csvData.add(['Items']);
    csvData.add(['productId', 'name', 'price', 'qty', 'vendorId']);

    num toNum(dynamic v) => (v is num) ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

    for (final it in items) {
      csvData.add([
        (it['productId'] ?? it['id'] ?? '').toString(),
        (it['name'] ?? it['title'] ?? '').toString(),
        toNum(it['price']).toString(),
        toNum(it['qty'] ?? it['quantity']).toString(),
        (it['vendorId'] ?? '').toString(),
      ]);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    return utf8.encode('\uFEFF$csvString');
  }

  // =============================================================================
  // UI
  // =============================================================================
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('購物車詳情', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
        ),
        body: _ErrorView(
          title: '載入購物車失敗',
          message: _error!,
          onRetry: _load,
          hint: '請確認 carts/{id} 存在，以及 items 欄位/子集合結構。',
        ),
      );
    }

    final cart = _cart ?? {};
    final cs = Theme.of(context).colorScheme;
    final fmtMoney = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

    final status = (cart['status'] ?? '').toString();
    final total = _toNum(cart['total']);
    final itemsCount = _items.fold<int>(0, (p, e) => p + _toNum(e['qty'] ?? e['quantity']).toInt());

    return Scaffold(
      appBar: AppBar(
        title: const Text('購物車詳情', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(tooltip: '重新整理', onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: '匯出明細 CSV', onPressed: _exportCartCsv, icon: const Icon(Icons.download)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cart：${widget.cartId}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        _kv('狀態', status.isEmpty ? '-' : status),
                        _kv('品項數', itemsCount.toString()),
                        _kv('總金額', fmtMoney.format(total)),
                        _kv('Email', (cart['userEmail'] ?? '').toString().isEmpty ? '-' : (cart['userEmail'] ?? '').toString()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _clearCart,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('清空購物車'),
                        ),
                        if (_exportResult != null)
                          Text(_exportResult!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_items.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('此購物車目前沒有品項。', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              )
            else
              ..._items.asMap().entries.map((entry) {
                final idx = entry.key;
                final it = entry.value;

                final name = (it['name'] ?? it['title'] ?? '').toString();
                final productId = (it['productId'] ?? it['id'] ?? '').toString();
                final qty = _toNum(it['qty'] ?? it['quantity']).toInt();
                final price = _toNum(it['price']);
                final subtotal = price * qty;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? '(未命名商品)' : name,
                            style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _kv('productId', productId.isEmpty ? '-' : productId),
                            _kv('單價', fmtMoney.format(price)),
                            _kv('數量', qty.toString()),
                            _kv('小計', fmtMoney.format(subtotal)),
                          ],
                        ),
                        const Divider(height: 18),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                final newQty = await _pickQty(qty);
                                if (newQty == null) return;
                                await _updateQty(idx, newQty);
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('改數量'),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: () => _removeItem(idx),
                              icon: Icon(Icons.delete_outline, color: cs.error),
                              label: Text('刪除', style: TextStyle(color: cs.error)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),

            const SizedBox(height: 30),
          ],
        ),
      ),
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

  Future<int?> _pickQty(int current) async {
    int qty = current;
    final res = await showDialog<int?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('調整數量', style: TextStyle(fontWeight: FontWeight.w900)),
        content: StatefulBuilder(
          builder: (context, setS) => Row(
            children: [
              IconButton(
                onPressed: qty <= 1 ? null : () => setS(() => qty--),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Center(
                  child: Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ),
              IconButton(
                onPressed: () => setS(() => qty++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, qty), child: const Text('確定')),
        ],
      ),
    );
    return res;
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '0') ?? 0;
  }
}

// =============================================================================
// Models
// =============================================================================
class _CartRow {
  final String id;
  final Map<String, dynamic> data;
  _CartRow({required this.id, required this.data});
}

// =============================================================================
// Error View
// =============================================================================
class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;
  final VoidCallback onRetry;

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

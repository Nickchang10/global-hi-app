// lib/pages/vendor_coupons_page.dart
//
// ✅ VendorCouponsPage（完整版｜可編譯）
// 功能：
// - 只顯示自己 vendorId 的 coupons
// - 搜尋（code/title/description/id）
// - 狀態篩選（全部/啟用/停用）
// - CRUD（新增/編輯/刪除）
// - 啟用/停用切換
// - 複製 couponId / code
// - 查看 JSON
//
// Firestore 建議結構：coupons/{couponId}
//   - vendorId: String
//   - code: String                // 例如 SAVE100 / NEW10
//   - title: String               // 顯示名稱
//   - description: String
//   - discountType: String        // 'percent' | 'amount'
//   - discountValue: num          // percent: 10 表示 10% ; amount: 100 表示折 100
//   - minSpend: num               // 最低消費（可選）
//   - maxDiscount: num            // 最高折抵（percent 時可選）
//   - usageLimit: int             // 可用次數上限（可選）
//   - usedCount: int              // 已使用次數（可選）
//   - startAt: Timestamp          // 生效日（可選）
//   - endAt: Timestamp            // 到期日（可選）
//   - isActive: bool
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//
// 依賴：cloud_firestore, flutter/material, flutter/services

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorCouponsPage extends StatefulWidget {
  const VendorCouponsPage({
    super.key,
    required this.vendorId,
  });

  final String vendorId;

  @override
  State<VendorCouponsPage> createState() => _VendorCouponsPageState();
}

class _VendorCouponsPageState extends State<VendorCouponsPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _q = '';
  bool? _isActive; // null=全部, true=啟用, false=停用

  bool _busy = false;
  String _busyLabel = '';

  String get _vid => widget.vendorId.trim();

  static const _discountTypes = <String>['percent', 'amount'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Utils
  // -------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  bool _isTrue(dynamic v) => v == true;

  num _num(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    return num.tryParse(v.toString().trim()) ?? fallback;
  }

  int _int(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? fallback;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtDate(DateTime? d) {
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

  Future<void> _setBusy(bool v, {String label = ''}) async {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  // -------------------------
  // Query
  // -------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamCoupons() {
    // 若你 coupons 未存 createdAt，orderBy 會報錯；建議補上 createdAt
    Query<Map<String, dynamic>> q = _db
        .collection('coupons')
        .where('vendorId', isEqualTo: _vid)
        .orderBy('createdAt', descending: true)
        .limit(800);

    if (_isActive != null) {
      q = _db
          .collection('coupons')
          .where('vendorId', isEqualTo: _vid)
          .where('isActive', isEqualTo: _isActive)
          .orderBy('createdAt', descending: true)
          .limit(800);
    }

    return q.snapshots();
  }

  bool _match(String id, Map<String, dynamic> d) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final code = _s(d['code']).toLowerCase();
    final title = _s(d['title']).toLowerCase();
    final desc = _s(d['description']).toLowerCase();

    return id.toLowerCase().contains(q) ||
        code.contains(q) ||
        title.contains(q) ||
        desc.contains(q);
  }

  // -------------------------
  // Actions
  // -------------------------
  Future<void> _toggleActive(String couponId, bool active) async {
    await _setBusy(true, label: active ? '啟用中...' : '停用中...');
    try {
      await _db.collection('coupons').doc(couponId).set(
        <String, dynamic>{
          'isActive': active,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _snack(active ? '已啟用' : '已停用');
    } catch (e) {
      _snack('操作失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _delete(String couponId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除優惠券'),
        content: Text('確定要刪除 coupon：$couponId 嗎？（不可復原）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;

    await _setBusy(true, label: '刪除中...');
    try {
      await _db.collection('coupons').doc(couponId).delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  String _discountLabel(Map<String, dynamic> d) {
    final type = _s(d['discountType']).isEmpty ? 'amount' : _s(d['discountType']);
    final value = _num(d['discountValue']);
    if (type == 'percent') return '${value.toString().replaceAll('.0', '')}% OFF';
    return '折 ${value.toString().replaceAll('.0', '')}';
  }

  Future<void> _viewJson(String title, Map<String, dynamic> data) async {
    await showDialog(
      context: context,
      builder: (_) => _JsonDialog(
        title: title,
        jsonText: const JsonEncoder.withIndent('  ').convert(data),
      ),
    );
  }

  DateTime? _tryParseDate(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return DateTime.tryParse(t);
  }

  Future<void> _openEditor({String? couponId, Map<String, dynamic>? data}) async {
    final isCreate = couponId == null || couponId.trim().isEmpty;

    final codeCtrl = TextEditingController(text: _s(data?['code']));
    final titleCtrl = TextEditingController(text: _s(data?['title']));
    final descCtrl = TextEditingController(text: _s(data?['description']));

    String discountType = _s(data?['discountType']);
    if (!_discountTypes.contains(discountType)) discountType = 'amount';

    final discountValueCtrl = TextEditingController(
      text: _s(data?['discountValue']).isEmpty ? '' : _s(data?['discountValue']),
    );
    final minSpendCtrl = TextEditingController(
      text: _s(data?['minSpend']).isEmpty ? '' : _s(data?['minSpend']),
    );
    final maxDiscountCtrl = TextEditingController(
      text: _s(data?['maxDiscount']).isEmpty ? '' : _s(data?['maxDiscount']),
    );
    final usageLimitCtrl = TextEditingController(
      text: _s(data?['usageLimit']).isEmpty ? '' : _s(data?['usageLimit']),
    );

    final startAt = _toDate(data?['startAt']);
    final endAt = _toDate(data?['endAt']);
    final startCtrl = TextEditingController(text: startAt == null ? '' : _fmtDate(startAt));
    final endCtrl = TextEditingController(text: endAt == null ? '' : _fmtDate(endAt));

    bool isActive = data == null ? true : _isTrue(data['isActive']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text(isCreate ? '新增優惠券' : '編輯優惠券'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Code（兌換碼）',
                      hintText: '例如：SAVE100 / NEW10',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: '標題（顯示用）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '描述',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: discountType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '折扣型態',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'amount', child: Text('固定金額（amount）')),
                            DropdownMenuItem(value: 'percent', child: Text('百分比（percent）')),
                          ],
                          onChanged: (v) => setInner(() => discountType = (v ?? 'amount')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: discountValueCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '折扣值（discountValue）',
                            hintText: 'amount=100 / percent=10',
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
                          controller: minSpendCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '最低消費（minSpend，可空）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: maxDiscountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '最高折抵（maxDiscount，可空）',
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
                          controller: usageLimitCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '使用上限（usageLimit，可空）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('啟用 isActive'),
                          value: isActive,
                          onChanged: (v) => setInner(() => isActive = v),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startCtrl,
                          decoration: const InputDecoration(
                            labelText: '生效日 startAt（YYYY-MM-DD，可空）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: endCtrl,
                          decoration: const InputDecoration(
                            labelText: '到期日 endAt（YYYY-MM-DD，可空）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '提示：此頁與主後台共用 coupons 集合；主後台更新會即時反映。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
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

    if (ok != true) {
      codeCtrl.dispose();
      titleCtrl.dispose();
      descCtrl.dispose();
      discountValueCtrl.dispose();
      minSpendCtrl.dispose();
      maxDiscountCtrl.dispose();
      usageLimitCtrl.dispose();
      startCtrl.dispose();
      endCtrl.dispose();
      return;
    }

    final code = codeCtrl.text.trim();
    final title = titleCtrl.text.trim();
    if (code.isEmpty) {
      _snack('Code 不可為空');
      return;
    }
    if (title.isEmpty) {
      _snack('標題不可為空');
      return;
    }

    final discountValue = _num(discountValueCtrl.text.trim(), fallback: 0);
    if (discountValue <= 0) {
      _snack('折扣值 discountValue 必須大於 0');
      return;
    }
    if (discountType == 'percent' && discountValue > 100) {
      _snack('percent 折扣值建議 1~100');
      // 仍允許儲存（有些會用 110 代表特殊規則），你若要強制可 return
    }

    final minSpend = minSpendCtrl.text.trim().isEmpty ? null : _num(minSpendCtrl.text.trim());
    final maxDiscount = maxDiscountCtrl.text.trim().isEmpty ? null : _num(maxDiscountCtrl.text.trim());
    final usageLimit = usageLimitCtrl.text.trim().isEmpty ? null : _int(usageLimitCtrl.text.trim());

    final startAtDt = _tryParseDate(startCtrl.text);
    final endAtDt = _tryParseDate(endCtrl.text);

    if (startAtDt != null && endAtDt != null && endAtDt.isBefore(startAtDt)) {
      _snack('到期日不可早於生效日');
      return;
    }

    await _setBusy(true, label: '儲存中...');
    try {
      final payload = <String, dynamic>{
        'vendorId': _vid,
        'code': code,
        'title': title,
        'description': descCtrl.text.trim(),
        'discountType': discountType,
        'discountValue': discountValue,
        'minSpend': minSpend,
        'maxDiscount': maxDiscount,
        'usageLimit': usageLimit,
        'isActive': isActive,
        'startAt': startAtDt == null ? null : Timestamp.fromDate(startAtDt),
        'endAt': endAtDt == null ? null : Timestamp.fromDate(endAtDt),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 清掉 null，避免寫入 null（你若希望保留 null 可移除此段）
      payload.removeWhere((k, v) => v == null);

      if (isCreate) {
        await _db.collection('coupons').add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
          'usedCount': 0,
        });
        _snack('已新增優惠券');
      } else {
        await _db.collection('coupons').doc(couponId!).set(payload, SetOptions(merge: true));
        _snack('已更新優惠券');
      }
    } catch (e) {
      _snack('儲存失敗：$e');
    } finally {
      await _setBusy(false);
    }

    codeCtrl.dispose();
    titleCtrl.dispose();
    descCtrl.dispose();
    discountValueCtrl.dispose();
    minSpendCtrl.dispose();
    maxDiscountCtrl.dispose();
    usageLimitCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_vid.isEmpty) {
      return const Center(child: Text('vendorId 不可為空'));
    }

    return Stack(
      children: [
        Column(
          children: [
            _CouponFilters(
              searchCtrl: _searchCtrl,
              isActive: _isActive,
              onQueryChanged: (v) => setState(() => _q = v),
              onClearQuery: () {
                _searchCtrl.clear();
                setState(() => _q = '');
              },
              onActiveChanged: (v) => setState(() => _isActive = v),
              onAdd: _busy ? null : () => _openEditor(),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _streamCoupons(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('讀取錯誤：${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs
                      .map((e) => (id: e.id, data: e.data()))
                      .where((e) => _match(e.id, e.data))
                      .toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Text('目前沒有資料', style: TextStyle(color: cs.onSurfaceVariant)),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final id = docs[i].id;
                      final d = docs[i].data;

                      final code = _s(d['code']).isEmpty ? '（無 code）' : _s(d['code']);
                      final title = _s(d['title']).isEmpty ? '（未命名）' : _s(d['title']);
                      final active = _isTrue(d['isActive']);

                      final label = _discountLabel(d);
                      final minSpend = d.containsKey('minSpend') ? _num(d['minSpend'], fallback: 0) : null;
                      final usedCount = _int(d['usedCount'], fallback: 0);
                      final usageLimit = d.containsKey('usageLimit') ? _int(d['usageLimit']) : null;

                      final startAt = _toDate(d['startAt']);
                      final endAt = _toDate(d['endAt']);

                      return ListTile(
                        leading: Icon(active ? Icons.confirmation_num_outlined : Icons.confirmation_num),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$code  ·  $title',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _Pill(
                              label: active ? '啟用' : '停用',
                              color: active ? cs.primary : cs.error,
                            ),
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
                                  Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                  if (minSpend != null)
                                    Text('低消：${minSpend.toString().replaceAll('.0', '')}',
                                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                  Text('使用：$usedCount${usageLimit == null ? '' : '/$usageLimit'}',
                                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '期間：${_fmtDate(startAt)} ~ ${_fmtDate(endAt)}',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
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
                                    await _copy(id, done: '已複製 couponId');
                                  } else if (v == 'copy_code') {
                                    await _copy(code, done: '已複製 code');
                                  } else if (v == 'edit') {
                                    await _openEditor(couponId: id, data: d);
                                  } else if (v == 'toggle') {
                                    await _toggleActive(id, !active);
                                  } else if (v == 'json') {
                                    await _viewJson('Coupon JSON', d);
                                  } else if (v == 'delete') {
                                    await _delete(id);
                                  }
                                },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'copy_id', child: Text('複製 couponId')),
                            const PopupMenuItem(value: 'copy_code', child: Text('複製 code')),
                            const PopupMenuItem(value: 'edit', child: Text('編輯')),
                            PopupMenuItem(value: 'toggle', child: Text(active ? '停用' : '啟用')),
                            const PopupMenuItem(value: 'json', child: Text('查看 JSON')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'delete', child: Text('刪除')),
                          ],
                        ),
                        onTap: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => _CouponDetailDialog(
                              couponId: id,
                              data: d,
                              fmtDate: _fmtDate,
                              toDate: _toDate,
                              discountLabel: _discountLabel,
                              onCopyId: () => _copy(id, done: '已複製 couponId'),
                              onCopyCode: () => _copy(code, done: '已複製 code'),
                              onEdit: () => _openEditor(couponId: id, data: d),
                              onToggle: () => _toggleActive(id, !active),
                              onJson: () => _viewJson('Coupon JSON', d),
                              onDelete: () => _delete(id),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        if (_busy)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BusyBar(label: _busyLabel.isEmpty ? '處理中...' : _busyLabel),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Filters UI
// ------------------------------------------------------------
class _CouponFilters extends StatelessWidget {
  const _CouponFilters({
    required this.searchCtrl,
    required this.isActive,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onActiveChanged,
    required this.onAdd,
  });

  final TextEditingController searchCtrl;
  final bool? isActive;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<bool?> onActiveChanged;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final dd = DropdownButtonFormField<bool?>(
      value: isActive,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        labelText: '狀態',
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('全部')),
        DropdownMenuItem(value: true, child: Text('啟用')),
        DropdownMenuItem(value: false, child: Text('停用')),
      ],
      onChanged: onActiveChanged,
    );

    final search = TextField(
      controller: searchCtrl,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        hintText: '搜尋：code / title / description / id',
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

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 980;

          if (isNarrow) {
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
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              SizedBox(width: 220, child: dd),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('新增優惠券'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Detail Dialog
// ------------------------------------------------------------
class _CouponDetailDialog extends StatelessWidget {
  const _CouponDetailDialog({
    required this.couponId,
    required this.data,
    required this.fmtDate,
    required this.toDate,
    required this.discountLabel,
    required this.onCopyId,
    required this.onCopyCode,
    required this.onEdit,
    required this.onToggle,
    required this.onJson,
    required this.onDelete,
  });

  final String couponId;
  final Map<String, dynamic> data;

  final String Function(DateTime?) fmtDate;
  final DateTime? Function(dynamic) toDate;
  final String Function(Map<String, dynamic>) discountLabel;

  final VoidCallback onCopyId;
  final VoidCallback onCopyCode;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onJson;
  final VoidCallback onDelete;

  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _isTrue(dynamic v) => v == true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final code = _s(data['code']);
    final title = _s(data['title']);
    final desc = _s(data['description']);
    final active = _isTrue(data['isActive']);

    final startAt = toDate(data['startAt']);
    final endAt = toDate(data['endAt']);

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
                  Expanded(
                    child: Text(
                      title.isEmpty ? '優惠券詳情' : '優惠券：$title',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  _Pill(
                    label: active ? '啟用' : '停用',
                    color: active ? cs.primary : cs.error,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _InfoRow(label: 'couponId', value: couponId, onCopy: onCopyId),
              const SizedBox(height: 6),
              _InfoRow(label: 'code', value: code, onCopy: onCopyCode),
              const SizedBox(height: 6),
              _InfoRow(label: '折扣', value: discountLabel(data)),
              const SizedBox(height: 6),
              _InfoRow(label: '期間', value: '${fmtDate(startAt)} ~ ${fmtDate(endAt)}'),
              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('描述', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outline.withOpacity(0.18)),
                ),
                child: Text(desc.isEmpty ? '（無描述）' : desc),
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
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onToggle();
                    },
                    icon: Icon(active ? Icons.pause_circle_outline : Icons.play_circle_outline),
                    label: Text(active ? '停用' : '啟用'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onJson();
                    },
                    icon: const Icon(Icons.code),
                    label: const Text('查看 JSON'),
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
        SizedBox(width: 92, child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
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

class _JsonDialog extends StatelessWidget {
  const _JsonDialog({required this.title, required this.jsonText});
  final String title;
  final String jsonText;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(
        width: 760,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
                  IconButton(
                    tooltip: '複製 JSON',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: jsonText));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已複製 JSON')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonText,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('關閉'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

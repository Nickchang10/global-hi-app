// lib/pages/admin/marketing/admin_coupon_edit_page.dart
//
// ✅ AdminCouponEditPage（最終穩定完整版｜可編譯）
// ------------------------------------------------------------
// - 支援 routes arguments 帶入 couponId（Navigator.pushNamed ... arguments: id）
// - 新增/編輯共用
// - 折扣型態：percent / fixed
// - 驗證：名稱/代碼必填、折扣有效、日期區間 end >= start
// - 代碼唯一性檢查（避免重複）
// - startAt/endAt 可留空；留空會刪除欄位
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminCouponEditPage extends StatefulWidget {
  final String? couponId;

  /// ✅ 你可以用 routes:
  /// '/admin/coupons/edit': (_) => const AdminCouponEditPage(),
  ///
  /// 再用 Navigator.pushNamed(context, '/admin/coupons/edit', arguments: id)
  /// 讓頁面自動抓 arguments 當 couponId。
  const AdminCouponEditPage({super.key, this.couponId});

  @override
  State<AdminCouponEditPage> createState() => _AdminCouponEditPageState();
}

class _AdminCouponEditPageState extends State<AdminCouponEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();

  String _discountType = 'percent'; // percent / fixed
  bool _isActive = true;
  bool _autoSend = false;

  DateTime? _startAt;
  DateTime? _endAt;

  bool _loading = true;
  bool _saving = false;

  String? _couponIdResolved;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('coupons');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _codeCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  // =====================================================
  // Bootstrap: resolve couponId from (widget.couponId) OR (ModalRoute.arguments)
  // =====================================================

  Future<void> _bootstrap() async {
    try {
      final arg = ModalRoute.of(context)?.settings.arguments;
      final fromArgs = arg is String ? arg : null;

      _couponIdResolved = widget.couponId ?? fromArgs;

      if (_couponIdResolved != null) {
        await _loadCoupon(_couponIdResolved!);
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('初始化失敗：$e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // =====================================================
  // Load
  // =====================================================

  Future<void> _loadCoupon(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) {
        if (!mounted) return;
        _snack('優惠券不存在或已刪除');
        Navigator.pop(context);
        return;
      }

      final d = doc.data() ?? <String, dynamic>{};

      setState(() {
        _titleCtrl.text = (d['title'] ?? '').toString();
        _codeCtrl.text = (d['code'] ?? '').toString();
        _discountCtrl.text = ((d['discount'] ?? 0) as num).toString();

        _discountType = ((d['discountType'] ?? 'percent').toString().trim());
        if (_discountType != 'percent' && _discountType != 'fixed') {
          _discountType = 'percent';
        }

        _isActive = d['isActive'] == true;
        _autoSend = d['autoSend'] == true;

        _startAt = _toDate(d['startAt']);
        _endAt = _toDate(d['endAt']);

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('讀取失敗：$e');
    }
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  // =====================================================
  // Validate
  // =====================================================

  bool _validateDateRange({bool showSnack = false}) {
    if (_startAt != null && _endAt != null && _endAt!.isBefore(_startAt!)) {
      if (showSnack) _snack('結束日期不可早於開始日期');
      return false;
    }
    return true;
  }

  num? _parseDiscount() {
    final raw = _discountCtrl.text.trim();
    if (raw.isEmpty) return null;
    return num.tryParse(raw);
  }

  String? _validateDiscount(String? v) {
    final n = _parseDiscount();
    if (n == null) return '請輸入有效折扣';

    if (_discountType == 'percent') {
      if (n <= 0 || n > 100) return '百分比需介於 1～100';
    } else {
      // fixed
      if (n <= 0) return '固定金額需大於 0';
    }
    return null;
  }

  // =====================================================
  // Code uniqueness check
  // =====================================================

  Future<bool> _isCodeUnique(String codeUpper) async {
    // 查詢是否存在同 code 的其他券
    final q = await _col.where('code', isEqualTo: codeUpper).limit(5).get();
    if (q.docs.isEmpty) return true;

    // 若是編輯自己那張，視為 OK
    final selfId = _couponIdResolved;
    if (selfId == null) return false;

    for (final d in q.docs) {
      if (d.id != selfId) return false;
    }
    return true;
  }

  // =====================================================
  // Save
  // =====================================================

  Future<void> _save() async {
    if (_saving) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (!_validateDateRange(showSnack: true)) return;

    final title = _titleCtrl.text.trim();
    final codeUpper = _codeCtrl.text.trim().toUpperCase();
    final discount = _parseDiscount() ?? 0;

    setState(() => _saving = true);

    try {
      // ✅ code uniqueness
      final unique = await _isCodeUnique(codeUpper);
      if (!unique) {
        _snack('優惠券代碼已存在，請更換代碼');
        return;
      }

      final now = FieldValue.serverTimestamp();

      // ✅ merge + 可刪欄位
      final data = <String, dynamic>{
        'title': title,
        'code': codeUpper,
        'discount': discount,
        'discountType': _discountType,
        'isActive': _isActive,
        'autoSend': _autoSend,
        'updatedAt': now,
      };

      // 日期可留空：留空就刪欄位（避免舊資料殘留）
      if (_startAt != null) {
        data['startAt'] = _startAt;
      } else if (_couponIdResolved != null) {
        data['startAt'] = FieldValue.delete();
      }

      if (_endAt != null) {
        data['endAt'] = _endAt;
      } else if (_couponIdResolved != null) {
        data['endAt'] = FieldValue.delete();
      }

      if (_couponIdResolved == null) {
        data['createdAt'] = now;
        await _col.add(data);
      } else {
        await _col.doc(_couponIdResolved!).set(data, SetOptions(merge: true));
      }

      if (!mounted) return;
      _snack('儲存成功');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // =====================================================
  // Date picker
  // =====================================================

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_startAt ?? now) : (_endAt ?? _startAt ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startAt = picked;
        if (_endAt != null && _endAt!.isBefore(picked)) {
          _endAt = null;
        }
      } else {
        _endAt = picked;
      }
    });
  }

  void _clearDate({required bool isStart}) {
    setState(() {
      if (isStart) {
        _startAt = null;
      } else {
        _endAt = null;
      }
    });
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd');

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final startText = _startAt == null ? '未設定' : df.format(_startAt!);
    final endText = _endAt == null ? '未設定' : df.format(_endAt!);

    return Scaffold(
      appBar: AppBar(
        title: Text(_couponIdResolved == null ? '新增優惠券' : '編輯優惠券'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('儲存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '優惠券名稱',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '請輸入名稱' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: '代碼（唯一）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '請輸入代碼' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _discountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _discountType == 'percent'
                    ? '折扣百分比 (%)'
                    : '折扣金額 (NT\$)',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.swap_horiz_rounded),
                  tooltip: '切換折扣類型',
                  onSelected: (v) => setState(() => _discountType = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'percent', child: Text('百分比折扣')),
                    PopupMenuItem(value: 'fixed', child: Text('固定金額')),
                  ],
                ),
              ),
              validator: _validateDiscount,
            ),
            const SizedBox(height: 12),

            SwitchListTile(
              title: const Text('啟用優惠券'),
              value: _isActive,
              onChanged: _saving ? null : (v) => setState(() => _isActive = v),
            ),
            SwitchListTile(
              title: const Text('自動派發'),
              value: _autoSend,
              onChanged: _saving ? null : (v) => setState(() => _autoSend = v),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _dateTile(
                    label: '開始日期',
                    value: startText,
                    onTap: _saving ? null : () => _pickDate(isStart: true),
                    onClear: _saving || _startAt == null
                        ? null
                        : () => _clearDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateTile(
                    label: '結束日期',
                    value: endText,
                    onTap: _saving ? null : () => _pickDate(isStart: false),
                    onClear: _saving || _endAt == null
                        ? null
                        : () => _clearDate(isStart: false),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            if (!_validateDateRange())
              const Text('結束日期不可早於開始日期',
                  style: TextStyle(color: Colors.red)),

            const SizedBox(height: 24),

            FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? '儲存中…' : '儲存'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required VoidCallback? onTap,
    required VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  tooltip: '清除',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value),
            const Icon(Icons.date_range, size: 20),
          ],
        ),
      ),
    );
  }
}

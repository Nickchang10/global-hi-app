// lib/pages/vendor_coupons_page.dart
//
// ✅ VendorCouponsPage（最終完整版｜可編譯｜修正 curly braces lint｜修正 use_build_context_synchronously｜移除 unnecessary_this｜避免 deprecated 色彩 API）
// ------------------------------------------------------------
// Firestore collection: coupons
//
// 建議 schema（彈性容錯）：
// coupons/{id} {
//   title: String
//   code: String
//   description: String?
//   active: bool?
//   vendorId: String?
//   type: String?             // percent / fixed / free_shipping
//   percentOff: num?
//   amountOff: num?
//   minSpend: num?
//   maxDiscount: num?
//   startAt: Timestamp|int|string?
//   endAt: Timestamp|int|string?
//   usageLimit: int?
//   usedCount: int?
//   createdAt: Timestamp?
//   updatedAt: Timestamp?
// }
//
// 依賴：cloud_firestore, firebase_auth, flutter/services

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorCouponsPage extends StatefulWidget {
  const VendorCouponsPage({super.key});

  @override
  State<VendorCouponsPage> createState() => _VendorCouponsPageState();
}

class _VendorCouponsPageState extends State<VendorCouponsPage> {
  final _db = FirebaseFirestore.instance;

  final _qCtrl = TextEditingController();
  bool _onlyActive = false;
  bool _onlyInactive = false;

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  // ----------------------------
  // Utils
  // ----------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  num _n(dynamic v, {num fallback = 0}) {
    if (v is num) {
      return v;
    }
    return num.tryParse(_s(v)) ?? fallback;
  }

  int _i(dynamic v, {int fallback = 0}) {
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return int.tryParse(_s(v)) ?? fallback;
  }

  bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) {
      return v;
    }
    final t = _s(v).toLowerCase();
    if (t == 'true' || t == '1' || t == 'yes') {
      return true;
    }
    if (t == 'false' || t == '0' || t == 'no') {
      return false;
    }
    return fallback;
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is Timestamp) {
      return v.toDate();
    }
    if (v is DateTime) {
      return v;
    }

    if (v is int) {
      try {
        if (v < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v * 1000);
        }
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {
        return null;
      }
    }

    if (v is String) {
      final t = v.trim();
      final asInt = int.tryParse(t);
      if (asInt != null) {
        try {
          if (asInt < 10000000000) {
            return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
          }
          return DateTime.fromMillisecondsSinceEpoch(asInt);
        } catch (_) {
          return null;
        }
      }
      return DateTime.tryParse(t);
    }

    return null;
  }

  String _fmtDate(dynamic v) {
    final d = _toDate(v);
    if (d == null) {
      return '';
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(done), duration: const Duration(seconds: 2)),
    );
  }

  String _resolveVendorId(User user) {
    return user.uid;
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    final buf = StringBuffer('OSM');
    for (int i = 0; i < 7; i++) {
      buf.write(chars[r.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  // ----------------------------
  // Firestore
  // ----------------------------
  Query<Map<String, dynamic>> _baseQuery() {
    return _db
        .collection('coupons')
        .orderBy('updatedAt', descending: true)
        .limit(1200);
  }

  bool _belongsToVendor(Map<String, dynamic> d, String vendorId) {
    final v = _s(d['vendorId']);
    if (v.isEmpty) {
      return true; // 舊資料容錯：沒寫 vendorId 就先顯示
    }
    return v == vendorId;
  }

  bool _matchesFilters(Map<String, dynamic> d) {
    final active = _b(d['active'], fallback: true);

    if (_onlyActive && !active) {
      return false;
    }
    if (_onlyInactive && active) {
      return false;
    }

    final q = _qCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }

    final title = _s(d['title']).toLowerCase();
    final code = _s(d['code']).toLowerCase();
    final desc = _s(d['description']).toLowerCase();
    final type = _s(d['type']).toLowerCase();

    return title.contains(q) ||
        code.contains(q) ||
        desc.contains(q) ||
        type.contains(q);
  }

  Future<void> _toggleActive(String id, bool active) async {
    await _db.collection('coupons').doc(id).set({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteCoupon(String id) async {
    await _db.collection('coupons').doc(id).delete();
  }

  // ----------------------------
  // Editor dialog
  // ----------------------------
  Future<void> _openEditor({
    required String vendorId,
    required String docId,
    required Map<String, dynamic> data,
    required bool isNew,
  }) async {
    final titleCtrl = TextEditingController(text: _s(data['title']));
    final codeCtrl = TextEditingController(text: _s(data['code']));
    final descCtrl = TextEditingController(text: _s(data['description']));
    final minSpendCtrl = TextEditingController(
      text: data['minSpend'] == null ? '' : _n(data['minSpend']).toString(),
    );
    final maxDiscCtrl = TextEditingController(
      text: data['maxDiscount'] == null
          ? ''
          : _n(data['maxDiscount']).toString(),
    );
    final usageLimitCtrl = TextEditingController(
      text: data['usageLimit'] == null ? '' : _i(data['usageLimit']).toString(),
    );
    final usedCountCtrl = TextEditingController(
      text: data['usedCount'] == null ? '' : _i(data['usedCount']).toString(),
    );

    String type = _s(data['type']).isEmpty ? 'percent' : _s(data['type']);
    final percentCtrl = TextEditingController(
      text: data['percentOff'] == null ? '' : _n(data['percentOff']).toString(),
    );
    final amountCtrl = TextEditingController(
      text: data['amountOff'] == null ? '' : _n(data['amountOff']).toString(),
    );

    bool active = _b(data['active'], fallback: true);
    DateTime? startAt = _toDate(data['startAt']);
    DateTime? endAt = _toDate(data['endAt']);

    Future<void> pickStart() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: startAt ?? now,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 5),
      );
      if (picked == null) {
        return;
      }
      startAt = DateTime(picked.year, picked.month, picked.day);
    }

    Future<void> pickEnd() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: endAt ?? now,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 5),
      );
      if (picked == null) {
        return;
      }
      endAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
    }

    bool ok = false;
    try {
      ok =
          await showDialog<bool>(
            context: context,
            builder: (dialogCtx) {
              final cs = Theme.of(dialogCtx).colorScheme;

              return StatefulBuilder(
                builder: (dialogCtx, setLocal) {
                  return AlertDialog(
                    title: Text(isNew ? '新增優惠券' : '編輯優惠券'),
                    content: SizedBox(
                      width: 560,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _field(titleCtrl, '名稱*'),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    codeCtrl,
                                    '優惠碼*（code）',
                                    hint: '例如 OSMXXXXXXX',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    codeCtrl.text = _randomCode();
                                  },
                                  icon: const Icon(Icons.auto_fix_high),
                                  label: const Text('產生'),
                                ),
                              ],
                            ),
                            _field(descCtrl, '描述', maxLines: 3),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Text('類型：'),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: type,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'percent',
                                      child: Text('百分比折扣'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'fixed',
                                      child: Text('固定折抵'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'free_shipping',
                                      child: Text('免運（示範）'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) {
                                      return;
                                    }
                                    setLocal(() => type = v);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (type == 'percent') ...[
                              _field(
                                percentCtrl,
                                '折扣百分比（percentOff，例如 10=10%）',
                                keyboardType: TextInputType.number,
                              ),
                            ] else if (type == 'fixed') ...[
                              _field(
                                amountCtrl,
                                '折抵金額（amountOff）',
                                keyboardType: TextInputType.number,
                              ),
                            ] else ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withValues(
                                    alpha: 36,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cs.outlineVariant),
                                ),
                                child: Text(
                                  'free_shipping：示範類型，結帳計算時自行處理運費折扣。',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                              ),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    minSpendCtrl,
                                    '最低消費（minSpend）',
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _field(
                                    maxDiscCtrl,
                                    '折扣上限（maxDiscount，可選）',
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    usageLimitCtrl,
                                    '可用次數上限（usageLimit，可選）',
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _field(
                                    usedCountCtrl,
                                    '已使用次數（usedCount，可選）',
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await pickStart();
                                      setLocal(() {});
                                    },
                                    icon: const Icon(Icons.date_range),
                                    label: Text(
                                      startAt == null
                                          ? '開始日'
                                          : _fmtDate(startAt),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await pickEnd();
                                      setLocal(() {});
                                    },
                                    icon: const Icon(Icons.event),
                                    label: Text(
                                      endAt == null ? '結束日' : _fmtDate(endAt),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              value: active,
                              onChanged: (v) => setLocal(() => active = v),
                              title: const Text('上架（active）'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: const Text('儲存'),
                      ),
                    ],
                  );
                },
              );
            },
          ) ??
          false;
    } finally {
      titleCtrl.dispose();
      codeCtrl.dispose();
      descCtrl.dispose();
      minSpendCtrl.dispose();
      maxDiscCtrl.dispose();
      usageLimitCtrl.dispose();
      usedCountCtrl.dispose();
      percentCtrl.dispose();
      amountCtrl.dispose();
    }

    if (!ok) {
      return;
    }

    if (!mounted) {
      return;
    }

    final title = titleCtrl.text.trim();
    final code = codeCtrl.text.trim().toUpperCase();

    if (title.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('名稱與優惠碼不可空白')));
      return;
    }

    final payload = <String, dynamic>{
      'title': title,
      'code': code,
      'description': descCtrl.text.trim(),
      'type': type,
      'active': active,
      'minSpend': minSpendCtrl.text.trim().isEmpty
          ? null
          : _n(minSpendCtrl.text),
      'maxDiscount': maxDiscCtrl.text.trim().isEmpty
          ? null
          : _n(maxDiscCtrl.text),
      'usageLimit': usageLimitCtrl.text.trim().isEmpty
          ? null
          : _i(usageLimitCtrl.text),
      'usedCount': usedCountCtrl.text.trim().isEmpty
          ? null
          : _i(usedCountCtrl.text),
      'startAt': startAt,
      'endAt': endAt,
      'vendorId': vendorId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (type == 'percent') {
      payload['percentOff'] = percentCtrl.text.trim().isEmpty
          ? null
          : _n(percentCtrl.text);
      payload['amountOff'] = null;
    } else if (type == 'fixed') {
      payload['amountOff'] = amountCtrl.text.trim().isEmpty
          ? null
          : _n(amountCtrl.text);
      payload['percentOff'] = null;
    } else {
      payload['percentOff'] = null;
      payload['amountOff'] = null;
    }

    if (isNew) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await _db
        .collection('coupons')
        .doc(docId)
        .set(payload, SetOptions(merge: true));

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已儲存')));
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  String _discountLabel(Map<String, dynamic> d) {
    final type = _s(d['type']).isEmpty ? 'percent' : _s(d['type']);
    if (type == 'percent') {
      final p = _n(d['percentOff'], fallback: 0);
      if (p <= 0) {
        return '折扣（未設定）';
      }
      return '${p.toStringAsFixed(p % 1 == 0 ? 0 : 2)}% OFF';
    }
    if (type == 'fixed') {
      final a = _n(d['amountOff'], fallback: 0);
      if (a <= 0) {
        return '折抵（未設定）';
      }
      return '折抵 NT\$${a.toStringAsFixed(a % 1 == 0 ? 0 : 2)}';
    }
    if (type == 'free_shipping') {
      return '免運';
    }
    return type;
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('請先登入')));
        }

        final vendorId = _resolveVendorId(user);

        return Scaffold(
          appBar: AppBar(
            title: const Text('我的優惠券'),
            actions: [
              IconButton(
                tooltip: _onlyActive ? '顯示全部' : '只看上架',
                onPressed: () {
                  setState(() {
                    _onlyActive = !_onlyActive;
                    if (_onlyActive) {
                      _onlyInactive = false;
                    }
                  });
                },
                icon: Icon(
                  _onlyActive ? Icons.check_circle : Icons.check_circle_outline,
                ),
              ),
              IconButton(
                tooltip: _onlyInactive ? '顯示全部' : '只看下架',
                onPressed: () {
                  setState(() {
                    _onlyInactive = !_onlyInactive;
                    if (_onlyInactive) {
                      _onlyActive = false;
                    }
                  });
                },
                icon: Icon(
                  _onlyInactive
                      ? Icons.remove_circle
                      : Icons.remove_circle_outline,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final newId = _db.collection('coupons').doc().id;
              await _openEditor(
                vendorId: vendorId,
                docId: newId,
                data: const <String, dynamic>{},
                isNew: true,
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('新增'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: TextField(
                  controller: _qCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: '搜尋：名稱 / code / 描述 / 類型',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 36),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    suffixIcon: IconButton(
                      tooltip: '清除',
                      onPressed: () {
                        _qCtrl.clear();
                        FocusScope.of(context).unfocus();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _baseQuery().snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('讀取失敗：${snap.error}'));
                    }

                    final docs = snap.data?.docs ?? const [];
                    final filtered = docs
                        .map((d) => _DocRow(id: d.id, data: d.data()))
                        .where((r) => _belongsToVendor(r.data, vendorId))
                        .where((r) => _matchesFilters(r.data))
                        .toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          '沒有符合的優惠券',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final r = filtered[i];
                        final d = r.data;

                        final title = _s(d['title']).isEmpty
                            ? '（未命名）'
                            : _s(d['title']);
                        final code = _s(d['code']);
                        final desc = _s(d['description']);
                        final active = _b(d['active'], fallback: true);

                        final minSpend = d['minSpend'] == null
                            ? null
                            : _n(d['minSpend']);
                        final maxDisc = d['maxDiscount'] == null
                            ? null
                            : _n(d['maxDiscount']);
                        final usageLimit = d['usageLimit'] == null
                            ? null
                            : _i(d['usageLimit']);
                        final usedCount = d['usedCount'] == null
                            ? null
                            : _i(d['usedCount']);

                        final startAt = _fmtDate(d['startAt']);
                        final endAt = _fmtDate(d['endAt']);

                        final badgeBg = active
                            ? cs.primary.withValues(alpha: 26)
                            : cs.surfaceContainerHighest.withValues(alpha: 70);
                        final badgeFg = active
                            ? cs.primary
                            : cs.onSurfaceVariant;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: cs.outlineVariant),
                          ),
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: cs.outlineVariant,
                                    ),
                                  ),
                                  child: Text(
                                    active ? '上架' : '下架',
                                    style: TextStyle(
                                      color: badgeFg,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      _Chip(
                                        icon:
                                            Icons.confirmation_number_outlined,
                                        text: code.isEmpty ? '（無 code）' : code,
                                        onTap: code.isEmpty
                                            ? null
                                            : () => _copy(code, done: '已複製優惠碼'),
                                      ),
                                      _Chip(
                                        icon: Icons.discount_outlined,
                                        text: _discountLabel(d),
                                      ),
                                      if (minSpend != null)
                                        _Chip(
                                          icon: Icons.payments_outlined,
                                          text: '低消 $minSpend',
                                        ),
                                      if (maxDisc != null)
                                        _Chip(
                                          icon: Icons.shield_outlined,
                                          text: '上限 $maxDisc',
                                        ),
                                      if (usageLimit != null)
                                        _Chip(
                                          icon: Icons.all_inclusive,
                                          text: '上限 $usageLimit 次',
                                        ),
                                      if (usedCount != null)
                                        _Chip(
                                          icon: Icons.check,
                                          text: '已用 $usedCount 次',
                                        ),
                                    ],
                                  ),
                                  if (startAt.isNotEmpty ||
                                      endAt.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '期間：${startAt.isEmpty ? '未設定' : startAt} ～ ${endAt.isEmpty ? '未設定' : endAt}',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      desc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'copy') {
                                  await _copy(code, done: '已複製優惠碼');
                                } else if (v == 'edit') {
                                  await _openEditor(
                                    vendorId: vendorId,
                                    docId: r.id,
                                    data: d,
                                    isNew: false,
                                  );
                                } else if (v == 'toggle') {
                                  await _toggleActive(r.id, !active);
                                } else if (v == 'delete') {
                                  final ok =
                                      await showDialog<bool>(
                                        context: context,
                                        builder: (dialogCtx) => AlertDialog(
                                          title: const Text('刪除優惠券？'),
                                          content: Text('將刪除：「$title」'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                dialogCtx,
                                                false,
                                              ),
                                              child: const Text('取消'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(
                                                dialogCtx,
                                                true,
                                              ),
                                              child: const Text('刪除'),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;

                                  if (ok) {
                                    await _deleteCoupon(r.id);
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'copy',
                                  child: Text('複製優惠碼'),
                                ),
                                PopupMenuItem(value: 'edit', child: Text('編輯')),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text('上/下架切換'),
                                ),
                                PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('刪除'),
                                ),
                              ],
                            ),
                            onTap: () async {
                              if (!mounted) {
                                return;
                              }
                              await showDialog<void>(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  title: Text(title),
                                  content: SizedBox(
                                    width: 560,
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        const JsonEncoder.withIndent(
                                          '  ',
                                        ).convert(d),
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      child: const Text('關閉'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          _copy(code, done: '已複製優惠碼'),
                                      child: const Text('複製 code'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DocRow {
  final String id;
  final Map<String, dynamic> data;
  _DocRow({required this.id, required this.data});
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 30),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text.isEmpty ? '-' : text,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: child,
    );
  }
}

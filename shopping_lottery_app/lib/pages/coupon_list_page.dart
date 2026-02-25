// lib/pages/coupon_list_page.dart
//
// ✅ CouponListPage（最終完整版｜可直接使用｜已修正 use_build_context_synchronously）
// - 顯示「我的優惠券」清單（Firestore users/{uid}/coupons）
// - 支援：搜尋 / 篩選（可用/已使用/已過期）/ 複製代碼 / 刪除 /（示範）標記已使用
// - 支援：輸入「兌換碼」領券（從 coupons collection 以 code 查詢後寫入 users/{uid}/coupons）
//
// ✅ 同步修正：withOpacity -> withValues(alpha: ...)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';

class CouponListPage extends StatefulWidget {
  const CouponListPage({super.key});

  @override
  State<CouponListPage> createState() => _CouponListPageState();
}

class _CouponListPageState extends State<CouponListPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '全部'; // 全部 / 可用 / 已使用 / 已過期
  bool _sortByExpSoon = true; // true: 到期近優先

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------- helpers --------
  String _s(dynamic v) => v?.toString() ?? '';

  int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_s(v)) ?? 0;
  }

  DateTime? _dt(dynamic v) {
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return null;
  }

  bool _isExpired(Map<String, dynamic> data) {
    final end = _dt(data['endAt']);
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  String _statusLabel(Map<String, dynamic> data) {
    final status = _s(data['status']).trim(); // available/used/expired
    if (status.isNotEmpty) return status;
    if (_isExpired(data)) return 'expired';
    return 'available';
  }

  String _statusText(String status) {
    switch (status) {
      case 'available':
        return '可用';
      case 'used':
        return '已使用';
      case 'expired':
        return '已過期';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'used':
        return Colors.grey;
      case 'expired':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  String _dateText(DateTime? d) {
    if (d == null) return '-';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  NotificationService? _nsTryRead() {
    try {
      return context.read<NotificationService>();
    } catch (_) {
      return null;
    }
  }

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('我的優惠券'),
        actions: [
          IconButton(
            tooltip: '兌換碼領券',
            icon: const Icon(Icons.confirmation_number_outlined),
            onPressed: user == null ? null : _openRedeemDialog,
          ),
        ],
      ),
      body: user == null ? _needLogin() : _body(uid: user.uid),
    );
  }

  Widget _needLogin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('請先登入才能查看優惠券', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/login'),
              child: const Text('前往登入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body({required String uid}) {
    return Column(
      children: [
        _topBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('coupons')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _emptyState(
                  icon: Icons.error_outline,
                  title: '讀取失敗',
                  subtitle: _s(snap.error),
                );
              }
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }

              final docs = snap.data!.docs;
              final List<_CouponRow> items = docs
                  .map((d) => _CouponRow(id: d.id, data: d.data()))
                  .toList();

              // search
              final q = _searchCtrl.text.trim().toLowerCase();
              List<_CouponRow> filtered = items.where((it) {
                if (q.isEmpty) return true;
                final data = it.data;
                final code = _s(data['code']).toLowerCase();
                final title = _s(data['title']).toLowerCase();
                final desc = _s(data['description']).toLowerCase();
                return code.contains(q) ||
                    title.contains(q) ||
                    desc.contains(q);
              }).toList();

              // status filter
              filtered = filtered.where((it) {
                final st = _statusLabel(it.data);
                if (_filter == '可用') return st == 'available';
                if (_filter == '已使用') return st == 'used';
                if (_filter == '已過期') return st == 'expired';
                return true;
              }).toList();

              // sort
              filtered.sort((a, b) {
                final aEnd = _dt(a.data['endAt']);
                final bEnd = _dt(b.data['endAt']);
                if (aEnd == null && bEnd == null) return 0;
                if (aEnd == null) return 1;
                if (bEnd == null) return -1;
                final cmp = aEnd.compareTo(bEnd);
                return _sortByExpSoon ? cmp : -cmp;
              });

              if (filtered.isEmpty) {
                return _emptyState(
                  icon: Icons.local_offer_outlined,
                  title: '沒有符合的優惠券',
                  subtitle: '試試更換篩選或搜尋關鍵字。',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _couponCard(uid: uid, row: filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            // ✅ FIX: Colors.black12 沒有 withValues，改用 Colors.black
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7F9),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: '搜尋優惠碼 / 標題 / 內容',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchCtrl.text.trim().isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _searchCtrl.clear()),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: _sortByExpSoon ? '到期近優先' : '到期遠優先',
                onPressed: () =>
                    setState(() => _sortByExpSoon = !_sortByExpSoon),
                icon: Icon(_sortByExpSoon ? Icons.south : Icons.north),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _chip('全部'),
              const SizedBox(width: 8),
              _chip('可用'),
              const SizedBox(width: 8),
              _chip('已使用'),
              const SizedBox(width: 8),
              _chip('已過期'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    final active = _filter == label;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _filter = label),
      selectedColor: Colors.blue,
      backgroundColor: const Color(0xFFF3F4F6),
      labelStyle: TextStyle(
        color: active ? Colors.white : Colors.black87,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
      ),
      showCheckmark: false,
    );
  }

  Widget _couponCard({required String uid, required _CouponRow row}) {
    final data = row.data;

    final String code = _s(data['code']).trim();
    final title = _s(data['title']).trim();
    final desc = _s(data['description']).trim();
    final discount = _i(data['discountValue']);
    final minSpend = _i(data['minSpend']);

    final startAt = _dt(data['startAt']);
    final endAt = _dt(data['endAt']);

    final status = _statusLabel(data);
    final expired = status == 'expired';
    final stColor = _statusColor(status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.isNotEmpty
                        ? title
                        : (code.isNotEmpty ? '優惠券 $code' : '優惠券'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: stColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusText(status),
                    style: TextStyle(
                      color: stColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (code.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SelectableText(
                      code,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: '複製優惠碼',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (!mounted) return;
                      _toast('已複製：$code');
                    },
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(desc, style: const TextStyle(color: Colors.black87)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _kv('折扣', discount > 0 ? '$discount' : '—'),
                if (minSpend > 0) _kv('低消', 'NT\$$minSpend'),
                _kv('起', _dateText(startAt)),
                _kv('迄', _dateText(endAt)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: expired ? null : () => _toast('已套用（示範）'),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  label: const Text('套用'),
                ),
                const SizedBox(width: 10),
                if (status == 'available')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    onPressed: () => _markUsed(uid: uid, docId: row.id),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('標記已使用'),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    onPressed: null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('已使用'),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: '刪除',
                  onPressed: () => _deleteCoupon(uid: uid, docId: row.id),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$k：$v',
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // -------- actions --------
  Future<void> _markUsed({required String uid, required String docId}) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('coupons')
          .doc(docId)
          .update({'status': 'used', 'usedAt': FieldValue.serverTimestamp()});

      _pushNotice(type: '優惠券', title: '已使用', message: '優惠券已標記為已使用（示範）');

      if (!mounted) return;
      _toast('已標記已使用');
    } catch (e) {
      if (!mounted) return;
      _toast('更新失敗：$e');
    }
  }

  Future<void> _deleteCoupon({
    required String uid,
    required String docId,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('刪除優惠券'),
          content: const Text('確定要刪除這張優惠券嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('coupons')
          .doc(docId)
          .delete();

      _pushNotice(type: '優惠券', title: '已刪除', message: '優惠券已刪除（示範）');

      if (!mounted) return;
      _toast('已刪除');
    } catch (e) {
      if (!mounted) return;
      _toast('刪除失敗：$e');
    }
  }

  Future<void> _openRedeemDialog() async {
    final ctrl = TextEditingController();
    bool loading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('輸入兌換碼'),
              content: TextField(
                controller: ctrl,
                decoration: const InputDecoration(hintText: '例如：OSMILE95'),
                textCapitalization: TextCapitalization.characters,
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final code = ctrl.text.trim().toUpperCase();
                          if (code.isEmpty) return;

                          setLocal(() => loading = true);

                          try {
                            await _redeemCode(code);

                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);

                            if (!mounted) return;
                            _toast('兌換成功（示範）：$code');
                          } catch (e) {
                            if (!mounted) return;
                            _toast('兌換失敗：$e');
                          } finally {
                            if (ctx.mounted) setLocal(() => loading = false);
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('兌換'),
                ),
              ],
            );
          },
        );
      },
    );

    ctrl.dispose();
  }

  Future<void> _redeemCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('尚未登入');
    final uid = user.uid;

    final qs = await FirebaseFirestore.instance
        .collection('coupons')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) throw Exception('找不到此兌換碼');

    final couponDoc = qs.docs.first;
    final data = couponDoc.data();

    final isActive =
        data['isActive'] == true ||
        _s(data['isActive']).toLowerCase() == 'true';
    if (!isActive) throw Exception('此兌換碼已停用');

    final endAt = _dt(data['endAt']);
    if (endAt != null && endAt.isBefore(DateTime.now())) {
      throw Exception('此兌換碼已過期');
    }

    final userCouponRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('coupons')
        .doc(couponDoc.id);

    final exists = await userCouponRef.get();
    if (exists.exists) throw Exception('你已領取過此優惠券');

    await userCouponRef.set({
      'code': code,
      'title': data['title'] ?? '優惠券',
      'description': data['description'] ?? '',
      'discountValue': data['discountValue'] ?? 0,
      'minSpend': data['minSpend'] ?? 0,
      'startAt': data['startAt'],
      'endAt': data['endAt'],
      'status': 'available',
      'createdAt': FieldValue.serverTimestamp(),
      'sourceCouponId': couponDoc.id,
    });

    _pushNotice(type: '優惠券', title: '領取成功', message: '已領取優惠券：$code（示範）');
  }

  void _pushNotice({
    required String type,
    required String title,
    required String message,
  }) {
    if (!mounted) return;
    try {
      final ns = _nsTryRead();
      if (ns == null) return;
      ns.addNotification(type: type, title: title, message: message);
    } catch (_) {}
  }
}

class _CouponRow {
  final String id;
  final Map<String, dynamic> data;
  _CouponRow({required this.id, required this.data});
}

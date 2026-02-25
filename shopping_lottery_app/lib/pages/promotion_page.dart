// lib/pages/promotion_page.dart
//
// ✅ PromotionPage（最終完整版｜修正 invalid_assignment）
// ------------------------------------------------------------
// 你錯誤原因：
//   var q = FirebaseFirestore.instance.collection('promotions');
//   這行 Dart 會把 q 推斷成 CollectionReference<...>
//   後面 q = q.where(...) / q = q.orderBy(...) 回傳 Query<...>
//   -> Query 不能再指派回 CollectionReference 型別（invalid_assignment）
//
// ✅ 修法：一開始就把 q 宣告成 Query<Map<String, dynamic>>（或直接用 Query 變數）
//
// 直接整檔覆蓋即可。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PromotionPage extends StatefulWidget {
  const PromotionPage({super.key});

  @override
  State<PromotionPage> createState() => _PromotionPageState();
}

class _PromotionPageState extends State<PromotionPage> {
  static const Color _brand = Color(0xFF3B82F6);

  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '全部'; // 全部 / 進行中 / 已結束
  bool _onlyFeatured = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => v?.toString() ?? '';

  DateTime? _dt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  bool _isEnded(Map<String, dynamic> m) {
    final endAt = _dt(m['endAt']);
    if (endAt == null) return false;
    return endAt.isBefore(DateTime.now());
  }

  bool _isStarted(Map<String, dynamic> m) {
    final startAt = _dt(m['startAt']);
    if (startAt == null) return true;
    return !startAt.isAfter(DateTime.now());
  }

  String _dateText(DateTime? d) {
    if (d == null) return '-';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  // ✅ 修正：一開始就用 Query 型別
  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
      'promotions',
    );

    if (_onlyFeatured) {
      q = q.where('featured', isEqualTo: true);
    }

    // 若你的資料沒有 updatedAt，改成 createdAt 或移除
    q = q.orderBy('updatedAt', descending: true);

    return q.limit(200);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('活動優惠'),
        actions: [
          IconButton(
            tooltip: _onlyFeatured ? '顯示全部活動' : '只看精選',
            onPressed: () => setState(() => _onlyFeatured = !_onlyFeatured),
            icon: Icon(
              _onlyFeatured ? Icons.star_rounded : Icons.star_border_rounded,
            ),
          ),
          const SizedBox(width: 2),
          _filterMenu(),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _empty(
                    icon: Icons.error_outline,
                    title: '讀取失敗',
                    subtitle: snap.error.toString(),
                  );
                }
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }

                final docs = snap.data!.docs;

                // client search + filter
                final kw = _searchCtrl.text.trim().toLowerCase();
                final filtered = docs.where((d) {
                  final m = d.data();

                  if (kw.isNotEmpty) {
                    final title = _s(m['title']).toLowerCase();
                    final desc = _s(m['description']).toLowerCase();
                    final tag = _s(m['tag']).toLowerCase();
                    if (!(title.contains(kw) ||
                        desc.contains(kw) ||
                        tag.contains(kw))) {
                      return false;
                    }
                  }

                  final started = _isStarted(m);
                  final ended = _isEnded(m);

                  if (_filter == '進行中') return started && !ended;
                  if (_filter == '已結束') return ended;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return _empty(
                    icon: Icons.local_offer_outlined,
                    title: '沒有符合的活動',
                    subtitle: '試試更換篩選或搜尋關鍵字。',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    return _promoCard(d.id, d.data());
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterMenu() {
    return PopupMenuButton<String>(
      tooltip: '篩選',
      initialValue: _filter,
      onSelected: (v) => setState(() => _filter = v),
      itemBuilder: (_) => const [
        PopupMenuItem(value: '全部', child: Text('全部')),
        PopupMenuItem(value: '進行中', child: Text('進行中')),
        PopupMenuItem(value: '已結束', child: Text('已結束')),
      ],
      icon: const Icon(Icons.filter_list_rounded),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8),
        ],
      ),
      child: Row(
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
                        hintText: '搜尋活動標題 / 標籤 / 內容',
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
        ],
      ),
    );
  }

  Widget _promoCard(String id, Map<String, dynamic> m) {
    final title = _s(m['title']).trim().isEmpty
        ? '活動優惠'
        : _s(m['title']).trim();
    final desc = _s(m['description']).trim();
    final tag = _s(m['tag']).trim();
    final cover = _s(m['coverUrl']).trim().isNotEmpty
        ? _s(m['coverUrl']).trim()
        : _s(m['imageUrl']).trim();

    final startAt = _dt(m['startAt']);
    final endAt = _dt(m['endAt']);

    final ended = _isEnded(m);
    final started = _isStarted(m);

    final statusText = ended ? '已結束' : (started ? '進行中' : '未開始');
    final statusColor = ended
        ? Colors.grey
        : (started ? Colors.green : Colors.orange);

    final featured = (m['featured'] == true);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetailDialog(id, m),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cover.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.campaign_outlined,
                  size: 44,
                  color: Colors.grey,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (featured) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.orange,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.25,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _pill(statusText, statusColor),
                      if (tag.isNotEmpty) _pill(tag, Colors.blueGrey),
                      _pill('起：${_dateText(startAt)}', Colors.grey),
                      _pill('迄：${_dateText(endAt)}', Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: ended
                              ? null
                              : () => _redeemPromotionCoupon(id, m),
                          icon: const Icon(
                            Icons.confirmation_number_outlined,
                            size: 18,
                          ),
                          label: const Text('領券'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openDetailDialog(id, m),
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text('詳情'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }

  Future<void> _openDetailDialog(String id, Map<String, dynamic> m) async {
    final title = _s(m['title']).trim().isEmpty
        ? '活動優惠'
        : _s(m['title']).trim();
    final desc = _s(m['description']).trim();
    final rule = _s(m['rule']).trim();
    final tag = _s(m['tag']).trim();

    final startAt = _dt(m['startAt']);
    final endAt = _dt(m['endAt']);
    final ended = _isEnded(m);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tag.isNotEmpty) ...[
                  _pill(tag, Colors.blueGrey),
                  const SizedBox(height: 10),
                ],
                Text(
                  '活動期間：${_dateText(startAt)} ～ ${_dateText(endAt)}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                if (desc.isNotEmpty) ...[
                  Text(desc, style: const TextStyle(height: 1.35)),
                  const SizedBox(height: 12),
                ],
                if (rule.isNotEmpty) ...[
                  const Text(
                    '規則/注意事項',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(rule, style: const TextStyle(height: 1.35)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('關閉'),
            ),
            ElevatedButton(
              onPressed: ended
                  ? null
                  : () async {
                      Navigator.pop(ctx); // ✅ 用 dialog ctx
                      await _redeemPromotionCoupon(id, m);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('領券'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _redeemPromotionCoupon(
    String promoId,
    Map<String, dynamic> m,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final go = await _confirmLogin();
      if (!mounted) return;
      if (go == true) {
        Navigator.of(context, rootNavigator: true).pushNamed('/login');
      }
      return;
    }

    final uid = user.uid;

    final coupon = (m['coupon'] is Map)
        ? Map<String, dynamic>.from(m['coupon'])
        : <String, dynamic>{};

    final code = _s(coupon['code']).trim().isNotEmpty
        ? _s(coupon['code']).trim()
        : 'PROMO-${promoId.substring(0, promoId.length.clamp(0, 6))}'
              .toUpperCase();

    try {
      final userCouponRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('coupons')
          .doc('promo_$promoId');

      final exists = await userCouponRef.get();
      if (exists.exists) {
        if (!mounted) return;
        _toast('你已領取過此優惠券');
        return;
      }

      await userCouponRef.set({
        'code': code,
        'title': coupon['title'] ?? (m['title'] ?? '活動優惠券'),
        'description': coupon['description'] ?? (m['description'] ?? ''),
        'discountValue': coupon['discountValue'] ?? (m['discountValue'] ?? 0),
        'minSpend': coupon['minSpend'] ?? (m['minSpend'] ?? 0),
        'startAt': coupon['startAt'] ?? m['startAt'],
        'endAt': coupon['endAt'] ?? m['endAt'],
        'status': 'available',
        'source': 'promotion',
        'promotionId': promoId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _toast('領券成功：$code');
    } catch (e) {
      if (!mounted) return;
      _toast('領券失敗：$e');
    }
  }

  Future<bool?> _confirmLogin() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('需要登入'),
          content: const Text('此功能需要先登入，是否前往登入？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('前往登入'),
            ),
          ],
        );
      },
    );
  }

  Widget _empty({
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
}

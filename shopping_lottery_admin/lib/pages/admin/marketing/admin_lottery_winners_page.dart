// lib/pages/admin/marketing/admin_lottery_winners_page.dart
//
// ✅ AdminLotteryWinnersPage（正式版｜完整版｜可直接編譯）
// ------------------------------------------------------------
// ✅ 修正：移除未使用的 local variable（anchor）
// ✅ 修正：withOpacity deprecated → 改用 withValues(alpha: ...)
// ✅ Firestore collection: lottery_winners（可透過 constructor 調整）
//
// 期望文件欄位（有就用、沒有就忽略）：
// - lotteryId     String
// - userId        String
// - userName      String
// - prizeName     String
// - prizeId       String
// - prizeValue    double/int
// - fulfilled     bool
// - createdAt     Timestamp
// - meta          Map (可選：例如訂單/收件資料/備註等)
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminLotteryWinnersPage extends StatefulWidget {
  const AdminLotteryWinnersPage({
    super.key,
    this.lotteryId,
    this.collectionName = 'lottery_winners',
  });

  /// 可選：只看某個抽獎活動的中獎名單
  final String? lotteryId;

  final String collectionName;

  @override
  State<AdminLotteryWinnersPage> createState() =>
      _AdminLotteryWinnersPageState();
}

class _AdminLotteryWinnersPageState extends State<AdminLotteryWinnersPage> {
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  bool _onlyUnfulfilled = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final v = _searchCtrl.text.trim();
      if (v == _keyword) return;
      setState(() => _keyword = v);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(widget.collectionName);

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = _col;

    final fixedLotteryId = widget.lotteryId?.trim();
    if (fixedLotteryId != null && fixedLotteryId.isNotEmpty) {
      q = q.where('lotteryId', isEqualTo: fixedLotteryId);
    }

    if (_onlyUnfulfilled) {
      q = q.where('fulfilled', isEqualTo: false);
    }

    // 若你的欄位不是 createdAt，改這行即可
    q = q.orderBy('createdAt', descending: true).limit(300);

    return q;
  }

  bool _matchKeyword(Map<String, dynamic> m) {
    final k = _keyword.trim().toLowerCase();
    if (k.isEmpty) return true;

    final lotteryId = (m['lotteryId'] ?? '').toString().toLowerCase();
    final userId = (m['userId'] ?? '').toString().toLowerCase();
    final userName = (m['userName'] ?? '').toString().toLowerCase();
    final prizeName = (m['prizeName'] ?? '').toString().toLowerCase();

    return lotteryId.contains(k) ||
        userId.contains(k) ||
        userName.contains(k) ||
        prizeName.contains(k);
  }

  Future<void> _toggleFulfilled(
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool next,
  ) async {
    try {
      await doc.reference.update({
        'fulfilled': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除中獎紀錄'),
        content: const Text('確定要刪除這筆中獎紀錄？此操作不可復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await doc.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  String _fmtDate(dynamic v) {
    try {
      DateTime? dt;
      if (v is Timestamp) dt = v.toDate();
      if (v is DateTime) dt = v;
      if (v is String) dt = DateTime.tryParse(v);
      if (dt == null) return '';
      String two(int x) => x.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return '';
    }
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.lotteryId == null || widget.lotteryId!.trim().isEmpty
        ? '抽獎中獎名單'
        : '抽獎中獎名單｜${widget.lotteryId}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '搜尋 lotteryId / userId / userName / prizeName',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _keyword.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除',
                            onPressed: () => _searchCtrl.clear(),
                            icon: const Icon(Icons.clear),
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Switch(
                      value: _onlyUnfulfilled,
                      onChanged: (v) => setState(() => _onlyUnfulfilled = v),
                    ),
                    const SizedBox(width: 6),
                    const Text('只看未發放（fulfilled=false）'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buildQuery().snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorView(
              message:
                  '讀取失敗：${snap.error}\n\n'
                  '若出現索引需求（FAILED_PRECONDITION: requires an index），'
                  '請到 Firebase Console 建立索引（lotteryId/fulfilled/createdAt）。',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          final filtered = docs.where((d) => _matchKeyword(d.data())).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('目前沒有符合條件的中獎紀錄'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final doc = filtered[i];
              final m = doc.data();

              final lotteryId = (m['lotteryId'] ?? '').toString();
              final userId = (m['userId'] ?? '').toString();
              final userName = (m['userName'] ?? '').toString();
              final prizeName = (m['prizeName'] ?? '').toString();
              final prizeId = (m['prizeId'] ?? '').toString();
              final prizeValue = _asDouble(m['prizeValue'] ?? m['value']);
              final fulfilled = (m['fulfilled'] == true);
              final createdAt = _fmtDate(m['createdAt']);

              final meta = _asMap(m['meta']);

              return Card(
                elevation: 0.8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              prizeName.isEmpty ? '(未命名獎品)' : prizeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Tag(
                            text: fulfilled ? '已發放' : '未發放',
                            color: fulfilled ? Colors.green : Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _kv('lotteryId', lotteryId),
                          _kv('userId', userId),
                          _kv('userName', userName),
                          if (prizeId.isNotEmpty) _kv('prizeId', prizeId),
                          if (prizeValue != 0)
                            _kv('value', prizeValue.toStringAsFixed(2)),
                          if (createdAt.isNotEmpty) _kv('time', createdAt),
                        ],
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _MetaBox(meta: meta),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _toggleFulfilled(doc, !fulfilled),
                            icon: Icon(fulfilled ? Icons.undo : Icons.check),
                            label: Text(fulfilled ? '改為未發放' : '標記已發放'),
                          ),
                          TextButton.icon(
                            onPressed: () => _delete(doc),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                              '刪除',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) {
    final text = v.trim().isEmpty ? '-' : v.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '$k：',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}

class _MetaBox extends StatelessWidget {
  const _MetaBox({required this.meta});
  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
    final entries = meta.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        // ✅ FIX: withOpacity deprecated
        color: Colors.black.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Meta', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          ...entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${e.key}: ${e.value}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // ✅ FIX: withOpacity deprecated
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          // ✅ FIX: withOpacity deprecated
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

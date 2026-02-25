// lib/pages/points_history_page.dart
//
// ✅ PointsHistoryPage（點數明細｜最終完整版｜可直接使用｜已修正 lint）
// ------------------------------------------------------------
// ✅ 修正重點：
// - ✅ curly_braces_in_flow_control_structures：所有 if 都加上 {}
// - ✅ withOpacity(deprecated) → withValues(alpha: ...)
// - ✅ 不依賴 FirestoreMockService
// - ✅ 用 FirebaseAuth + Firestore
//
// 建議 Firestore 結構：
// users/{uid}
//   - points: num
//
// users/{uid}/points_ledger/{lid}
//   - type: String        // "earn" | "spend" | "adjust"
//   - title: String       // "每日登入" / "兌換商品" / ...
//   - delta: num          // +10 / -50
//   - balanceAfter: num?  // 可選：記錄異動後餘額
//   - refId: String?      // 可選：關聯訂單/兌換/任務 id
//   - note: String?       // 可選：備註
//   - createdAt: Timestamp
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PointsHistoryPage extends StatefulWidget {
  const PointsHistoryPage({super.key});

  static const routeName = '/points_history';

  @override
  State<PointsHistoryPage> createState() => _PointsHistoryPageState();
}

class _PointsHistoryPageState extends State<PointsHistoryPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _busy = false;
  bool _onlyEarn = false;
  bool _onlySpend = false;

  User? get _user => _auth.currentUser;

  String _s(dynamic v, [String fallback = '']) => (v ?? fallback).toString();

  num _asNum(dynamic v, {num fallback = 0}) {
    if (v == null) {
      return fallback;
    }
    if (v is num) {
      return v;
    }
    if (v is String) {
      return num.tryParse(v) ?? fallback;
    }
    return fallback;
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _fs.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _ledgerRef(String uid) =>
      _fs.collection('users').doc(uid).collection('points_ledger');

  void _goLogin() {
    Navigator.of(context, rootNavigator: true).pushNamed('/login');
  }

  Future<void> _seedDemoLedger(String uid) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);

    try {
      final col = _ledgerRef(uid);
      final snap = await col.limit(1).get();
      if (snap.docs.isNotEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已有明細資料，略過建立示範資料')));
        return;
      }

      final batch = _fs.batch();
      final now = DateTime.now();

      final demo = <Map<String, dynamic>>[
        {
          'type': 'earn',
          'title': '每日登入',
          'delta': 10,
          'note': '示範資料',
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(hours: 2)),
          ),
        },
        {
          'type': 'earn',
          'title': '分享商品',
          'delta': 15,
          'note': '示範資料',
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(days: 1, hours: 1)),
          ),
        },
        {
          'type': 'spend',
          'title': '兌換商品：折價券 50',
          'delta': -50,
          'note': '示範資料',
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(days: 2, hours: 3)),
          ),
        },
        {
          'type': 'adjust',
          'title': '系統調整',
          'delta': 20,
          'note': '示範資料（補點）',
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(days: 3, hours: 5)),
          ),
        },
      ];

      for (final item in demo) {
        final doc = col.doc();
        batch.set(doc, {...item, 'refId': null});
      }

      await batch.commit();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ 已建立示範點數明細：${demo.length} 筆')));
      setState(() {});
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 建立示範明細失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('點數明細'),
        actions: [
          if (u != null)
            IconButton(
              tooltip: '建立示範明細（僅在空集合時）',
              onPressed: _busy ? null : () => _seedDemoLedger(u.uid),
              icon: const Icon(Icons.auto_awesome),
            ),
          IconButton(
            tooltip: '重新整理',
            onPressed: _busy ? null : () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: u == null ? _needLogin() : _content(u.uid),
    );
  }

  Widget _needLogin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    '請先登入才能查看點數明細',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _goLogin, child: const Text('前往登入')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(String uid) {
    final userStream = _userRef(uid).snapshots();
    final ledgerStream = _ledgerRef(
      uid,
    ).orderBy('createdAt', descending: true).limit(200).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, uSnap) {
        if (uSnap.hasError) {
          return _errorBox('讀取點數失敗：${uSnap.error}');
        }
        if (!uSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = uSnap.data!.data() ?? <String, dynamic>{};
        final points = _asNum(userData['points'], fallback: 0);

        return Column(
          children: [
            _top(points: points),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ledgerStream,
                builder: (context, lSnap) {
                  if (lSnap.hasError) {
                    return _errorBox('讀取明細失敗：${lSnap.error}');
                  }
                  if (!lSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = lSnap.data!.docs;

                  final filtered = docs.where((d) {
                    final data = d.data();
                    final type = _s(data['type']).toLowerCase();
                    if (_onlyEarn && type != 'earn') {
                      return false;
                    }
                    if (_onlySpend && type != 'spend') {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _empty(
                          (_onlyEarn || _onlySpend)
                              ? '目前沒有符合篩選條件的明細'
                              : '目前沒有點數明細（可按右上角建立示範資料）',
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final doc = filtered[i];
                      final d = doc.data();

                      final type = _s(d['type'], 'earn');
                      final title = _s(d['title'], '點數異動');
                      final delta = _asNum(d['delta'], fallback: 0);
                      final note = _s(d['note'], '');
                      final refId = _s(d['refId'], '');
                      final balanceAfter = d.containsKey('balanceAfter')
                          ? _asNum(d['balanceAfter'], fallback: 0)
                          : null;

                      DateTime? createdAt;
                      final ts = d['createdAt'];
                      if (ts is Timestamp) {
                        createdAt = ts.toDate();
                      }

                      return _ledgerTile(
                        type: type,
                        title: title,
                        delta: delta,
                        note: note,
                        refId: refId,
                        createdAt: createdAt,
                        balanceAfter: balanceAfter,
                        onTap: () => _openDetail(
                          id: doc.id,
                          type: type,
                          title: title,
                          delta: delta,
                          note: note,
                          refId: refId,
                          createdAt: createdAt,
                          balanceAfter: balanceAfter,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _top({required num points}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            elevation: 0,
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.stars_outlined, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '目前點數：$points',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilterChip(
                label: const Text('只看獲得'),
                selected: _onlyEarn,
                onSelected: (v) {
                  setState(() {
                    _onlyEarn = v;
                    if (v) {
                      _onlySpend = false;
                    }
                  });
                },
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('只看使用'),
                selected: _onlySpend,
                onSelected: (v) {
                  setState(() {
                    _onlySpend = v;
                    if (v) {
                      _onlyEarn = false;
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ledgerTile({
    required String type,
    required String title,
    required num delta,
    required String note,
    required String refId,
    required DateTime? createdAt,
    required num? balanceAfter,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    final isEarn = delta >= 0;
    final sign = isEarn ? '+' : '';
    final deltaText = '$sign${delta.toInt()}';

    IconData icon;
    Color badgeColor;
    String badge;

    switch (type.toLowerCase()) {
      case 'spend':
        icon = Icons.shopping_bag_outlined;
        badgeColor = Colors.red;
        badge = '使用';
        break;
      case 'adjust':
        icon = Icons.tune;
        badgeColor = Colors.purple;
        badge = '調整';
        break;
      case 'earn':
      default:
        icon = Icons.add_circle_outline;
        badgeColor = Colors.green;
        badge = '獲得';
        break;
    }

    final timeText = createdAt == null
        ? '—'
        : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
              '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 1,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: badgeColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          [
            timeText,
            if (note.isNotEmpty) note,
            if (refId.isNotEmpty) 'ref: $refId',
            if (balanceAfter != null) '餘額: ${balanceAfter.toInt()}',
          ].join('  •  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              deltaText,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: isEarn ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail({
    required String id,
    required String type,
    required String title,
    required num delta,
    required String note,
    required String refId,
    required DateTime? createdAt,
    required num? balanceAfter,
  }) {
    final timeText = createdAt == null
        ? '—'
        : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
              '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '點數明細',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 10),
              _kv('ID', id),
              _kv('類型', type),
              _kv('標題', title),
              _kv('異動', delta.toString()),
              _kv('時間', timeText),
              if (refId.isNotEmpty) _kv('refId', refId),
              if (note.isNotEmpty) _kv('備註', note),
              if (balanceAfter != null) _kv('餘額', balanceAfter.toString()),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(k, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

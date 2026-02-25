// lib/pages/points_ecosystem_with_detail.dart
//
// ✅ PointsEcosystemWithDetailPage（最終完整版｜已修正 const_with_non_const）
// ------------------------------------------------------------
// 修正點：DateTime(...) 不是 const，所以 _ledger 不能用 const list / const item
// ✅ 做法：把 _ledger 改成 final（list 非 const），並移除每筆 _PointLedgerItem 前的 const
//
// routes 建議：
// '/points_detail': (_) => const PointsEcosystemWithDetailPage(),

import 'package:flutter/material.dart';

class PointsEcosystemWithDetailPage extends StatefulWidget {
  const PointsEcosystemWithDetailPage({super.key});

  @override
  State<PointsEcosystemWithDetailPage> createState() =>
      _PointsEcosystemWithDetailPageState();
}

class _PointsEcosystemWithDetailPageState
    extends State<PointsEcosystemWithDetailPage> {
  static const Color _brand = Color(0xFF3B82F6);

  // ✅ prefer_final_fields：若沒有被 setState 改動，就用 final
  final int _points = 1280;
  final String _tier = 'Silver';

  String _filter = '全部'; // 全部 / 入帳 / 出帳
  bool _sortNewestFirst = true;

  // ✅ const_with_non_const：DateTime(...) 不是 const → 這裡不能用 const
  final List<_PointLedgerItem> _ledger = [
    _PointLedgerItem(
      id: 'l1',
      title: '每日簽到',
      subtitle: '任務中心',
      delta: 20,
      at: DateTime(2026, 2, 13, 9, 10),
      type: _LedgerType.earn,
    ),
    _PointLedgerItem(
      id: 'l2',
      title: '購物回饋',
      subtitle: '訂單 #A10293',
      delta: 80,
      at: DateTime(2026, 2, 12, 18, 22),
      type: _LedgerType.earn,
    ),
    _PointLedgerItem(
      id: 'l3',
      title: '兌換優惠券',
      subtitle: 'OSMILE95',
      delta: -120,
      at: DateTime(2026, 2, 11, 15, 40),
      type: _LedgerType.spend,
    ),
    _PointLedgerItem(
      id: 'l4',
      title: '直播互動加碼',
      subtitle: 'Live #L8892',
      delta: 30,
      at: DateTime(2026, 2, 10, 21, 5),
      type: _LedgerType.earn,
    ),
  ];

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

  double _tierProgress(String tier) {
    switch (tier) {
      case 'Gold':
        return 0.65;
      case 'Platinum':
        return 0.90;
      case 'Silver':
      default:
        return 0.35;
    }
  }

  String _tierHint(String tier) {
    switch (tier) {
      case 'Gold':
        return '黃金會員：加倍回饋、專屬活動（示範）';
      case 'Platinum':
        return '白金會員：最高回饋、優先客服（示範）';
      case 'Silver':
      default:
        return '白銀會員：累積積分解鎖更高等級（示範）';
    }
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }

  List<_PointLedgerItem> _filteredLedger() {
    List<_PointLedgerItem> list = List.of(_ledger);

    if (_filter == '入帳') {
      list = list.where((e) => e.delta > 0).toList();
    } else if (_filter == '出帳') {
      list = list.where((e) => e.delta < 0).toList();
    }

    list.sort((a, b) {
      final cmp = a.at.compareTo(b.at);
      return _sortNewestFirst ? -cmp : cmp;
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _tierProgress(_tier);
    final list = _filteredLedger();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('積分生態（明細）'),
        actions: [
          IconButton(
            tooltip: '切換排序',
            onPressed: () =>
                setState(() => _sortNewestFirst = !_sortNewestFirst),
            icon: Icon(_sortNewestFirst ? Icons.south : Icons.north),
          ),
          PopupMenuButton<String>(
            tooltip: '篩選',
            initialValue: _filter,
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: '全部', child: Text('全部')),
              PopupMenuItem(value: '入帳', child: Text('入帳')),
              PopupMenuItem(value: '出帳', child: Text('出帳')),
            ],
            icon: const Icon(Icons.filter_list_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 22),
        children: [
          _summaryCard(progress: progress),
          const SizedBox(height: 12),
          _quickActions(),
          const SizedBox(height: 12),
          _ledgerCard(list),
        ],
      ),
    );
  }

  Widget _summaryCard({required double progress}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.stars_rounded, color: _brand),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '目前積分',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Text(
                '$_points',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '等級：$_tier',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(_brand),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _tierHint(_tier),
            style: TextStyle(color: Colors.grey.shade700, height: 1.25),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _toast('前往任務中心（示範）'),
            icon: const Icon(Icons.task_alt_outlined),
            label: const Text(
              '任務',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _toast('前往兌換（示範）'),
            icon: const Icon(Icons.redeem_outlined),
            label: const Text(
              '兌換',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orangeAccent,
              side: const BorderSide(color: Colors.orangeAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ledgerCard(List<_PointLedgerItem> list) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: Colors.blueAccent,
              ),
            ),
            title: const Text(
              '積分明細',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '篩選：$_filter｜排序：${_sortNewestFirst ? '新→舊' : '舊→新'}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const Divider(height: 1),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('沒有符合的明細', style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ledgerRow(list[i]),
            ),
        ],
      ),
    );
  }

  Widget _ledgerRow(_PointLedgerItem it) {
    final isEarn = it.delta >= 0;
    final deltaText = isEarn ? '+${it.delta}' : '${it.delta}';
    final Color accent = isEarn ? Colors.green : Colors.redAccent;
    final IconData icon = isEarn
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetail(it),
      child: Ink(
        padding: const EdgeInsets.all(14),
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
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    it.subtitle ?? '',
                    style: TextStyle(color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _fmtDate(it.at),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              deltaText,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(_PointLedgerItem it) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final isEarn = it.delta >= 0;
        final Color accent = isEarn ? Colors.green : Colors.redAccent;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                it.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                it.subtitle ?? '',
                style: TextStyle(color: Colors.grey.shade700, height: 1.25),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _kv('時間', _fmtDate(it.at)),
                  const SizedBox(width: 10),
                  _kv('類型', isEarn ? '入帳' : '出帳'),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded),
                    const SizedBox(width: 8),
                    Text(
                      '變動：${isEarn ? '+' : ''}${it.delta} 點',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('關閉'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _toast('已複製明細（示範）');
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('複製'),
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
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$k：$v',
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

enum _LedgerType { earn, spend }

class _PointLedgerItem {
  final String id;
  final String title;
  final String? subtitle;
  final int delta;
  final DateTime at;
  final _LedgerType type;

  const _PointLedgerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.delta,
    required this.at,
    required this.type,
  });
}

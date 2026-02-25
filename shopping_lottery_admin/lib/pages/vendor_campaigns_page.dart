// lib/pages/vendor_campaigns_page.dart
//
// ✅ VendorCampaignsPage（廠商活動/行銷活動列表｜可編譯完整版｜已修正 surfaceVariant deprecated）
// ------------------------------------------------------------
// ✅ 修正：避免把欄位命名為 num 造成 Dart 解析「num isn't a type」
// - 將 _CampaignCard 的 num helper 改名為 numOf
//
// ✅ 修正（本次）
// - surfaceVariant deprecated → surfaceContainerHighest
// - withOpacity deprecated → withValues(alpha: ...)
// -（同時避免 curly_braces_in_flow_control_structures）所有 if 都加上區塊 {}
//
// Firestore（容錯讀取，不強制）：
// campaigns/{id}:
//   - title: String
//   - description: String
//   - coverUrl: String
//   - vendorId: String
//   - enabled: bool
//   - startAt: Timestamp
//   - endAt: Timestamp
//   - updatedAt: Timestamp
//   - createdAt: Timestamp
//   - budget/spent/impressions/clicks/conversions: num
//
// 依賴：cloud_firestore, firebase_auth, flutter/services

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorCampaignsPage extends StatefulWidget {
  final String? vendorId;

  const VendorCampaignsPage({super.key, this.vendorId});

  @override
  State<VendorCampaignsPage> createState() => _VendorCampaignsPageState();
}

enum _CampaignFilter { all, active, upcoming, ended }

class _VendorCampaignsPageState extends State<VendorCampaignsPage> {
  String _vendorId = '';
  _CampaignFilter _filter = _CampaignFilter.all;

  @override
  void initState() {
    super.initState();
    _vendorId = (widget.vendorId ?? '').trim();
  }

  // -------------------------
  // VendorId hydration
  // -------------------------
  void _hydrateVendorIdIfNeeded() {
    if (_vendorId.isNotEmpty) {
      return;
    }

    final route = ModalRoute.of(context);
    final args = route?.settings.arguments;

    String vid = '';

    if (args is String) {
      vid = args.trim();
    } else if (args is Map) {
      final v = args['vendorId'] ?? args['vendor_id'] ?? args['uid'];
      if (v != null) {
        vid = v.toString().trim();
      }
    }

    if (vid.isEmpty) {
      vid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    }

    if (vid.isEmpty) {
      return;
    }

    setState(() => _vendorId = vid);
  }

  // -------------------------
  // Helpers
  // -------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  num _num(dynamic v) {
    if (v is num) {
      return v;
    }
    return num.tryParse((v ?? '').toString()) ?? 0;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) {
      return v.toDate();
    }
    if (v is DateTime) {
      return v;
    }
    return null;
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

  String _fmtDate(DateTime? dt) {
    if (dt == null) {
      return '—';
    }
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  // -------------------------
  // Query
  // -------------------------
  Query<Map<String, dynamic>> _query() {
    final db = FirebaseFirestore.instance;
    final base = db
        .collection('campaigns')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );

    return base
        .where('vendorId', isEqualTo: _vendorId)
        .orderBy('updatedAt', descending: true);
  }

  // -------------------------
  // Filter logic
  // -------------------------
  _CampaignStatus _statusOf(Map<String, dynamic> data) {
    final enabled = (data['enabled'] is bool)
        ? (data['enabled'] as bool)
        : true;
    final start = _toDate(data['startAt']);
    final end = _toDate(data['endAt']);
    final now = DateTime.now();

    if (!enabled) {
      return _CampaignStatus.disabled;
    }

    if (start != null && now.isBefore(start)) {
      return _CampaignStatus.upcoming;
    }
    if (end != null && now.isAfter(end)) {
      return _CampaignStatus.ended;
    }

    return _CampaignStatus.active;
  }

  bool _matchFilter(_CampaignStatus s) {
    switch (_filter) {
      case _CampaignFilter.all:
        return true;
      case _CampaignFilter.active:
        return s == _CampaignStatus.active;
      case _CampaignFilter.upcoming:
        return s == _CampaignStatus.upcoming;
      case _CampaignFilter.ended:
        return s == _CampaignStatus.ended;
    }
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    _hydrateVendorIdIfNeeded();

    if (_vendorId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('活動管理')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 44, color: Colors.grey),
                const SizedBox(height: 10),
                const Text('尚未取得 vendorId（請先登入）'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (_) => false,
                  ),
                  child: const Text('前往登入'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('活動/行銷活動'),
        actions: [
          IconButton(
            tooltip: '複製 VendorId',
            onPressed: () => _copy(_vendorId, done: '已複製 VendorId'),
            icon: const Icon(Icons.copy),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            current: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('尚無活動資料'));
                }

                final items = <_CampaignItem>[];
                for (final d in docs) {
                  final data = d.data();
                  final s = _statusOf(data);
                  if (_matchFilter(s)) {
                    items.add(_CampaignItem(id: d.id, data: data, status: s));
                  }
                }

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      '此篩選下無資料',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return _CampaignCard(
                      item: item,
                      fmtDate: _fmtDate,
                      toDate: _toDate,
                      numOf: _num, // ✅ 改名：numOf
                      s: _s,
                      onOpen: () => _openDetail(item),
                      onCopyId: () => _copy(item.id, done: '已複製活動ID'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(_CampaignItem item) {
    final data = item.data;
    final title = _s(data['title']).isNotEmpty ? _s(data['title']) : item.id;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final start = _toDate(data['startAt']);
        final end = _toDate(data['endAt']);
        final cover = _s(data['coverUrl']);
        final desc = _s(data['description']);

        final budget = _num(data['budget']);
        final spent = _num(data['spent']);
        final impressions = _num(data['impressions']);
        final clicks = _num(data['clicks']);
        final conversions = _num(data['conversions']);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusPill(status: item.status),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.tag, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text('活動ID：${item.id}')),
                    TextButton.icon(
                      onPressed: () => _copy(item.id, done: '已複製活動ID'),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('複製'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (cover.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        cover,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 36),
                        ),
                        loadingBuilder: (_, child, ev) {
                          if (ev == null) {
                            return child;
                          }
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _InfoRow(label: '開始時間', value: _fmtDate(start)),
                _InfoRow(label: '結束時間', value: _fmtDate(end)),
                _InfoRow(
                  label: '預算',
                  value: budget == 0 ? '—' : budget.toStringAsFixed(0),
                ),
                _InfoRow(
                  label: '花費',
                  value: spent == 0 ? '—' : spent.toStringAsFixed(0),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '成效指標',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _MetricGrid(
                          impressions: impressions,
                          clicks: clicks,
                          conversions: conversions,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '活動說明',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(desc.isEmpty ? '（無說明）' : desc),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check),
                  label: const Text('關閉'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// UI Components
// ============================================================

class _FilterBar extends StatelessWidget {
  final _CampaignFilter current;
  final ValueChanged<_CampaignFilter> onChanged;

  const _FilterBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: current == _CampaignFilter.all,
            onSelected: (_) => onChanged(_CampaignFilter.all),
          ),
          ChoiceChip(
            label: const Text('進行中'),
            selected: current == _CampaignFilter.active,
            onSelected: (_) => onChanged(_CampaignFilter.active),
          ),
          ChoiceChip(
            label: const Text('即將開始'),
            selected: current == _CampaignFilter.upcoming,
            onSelected: (_) => onChanged(_CampaignFilter.upcoming),
          ),
          ChoiceChip(
            label: const Text('已結束'),
            selected: current == _CampaignFilter.ended,
            onSelected: (_) => onChanged(_CampaignFilter.ended),
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final _CampaignItem item;
  final String Function(DateTime?) fmtDate;
  final DateTime? Function(dynamic) toDate;
  final num Function(dynamic) numOf; // ✅ 改名：numOf
  final String Function(dynamic) s;
  final VoidCallback onOpen;
  final VoidCallback onCopyId;

  const _CampaignCard({
    required this.item,
    required this.fmtDate,
    required this.toDate,
    required this.numOf,
    required this.s,
    required this.onOpen,
    required this.onCopyId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final data = item.data;
    final title = s(data['title']).isNotEmpty ? s(data['title']) : item.id;
    final desc = s(data['description']);
    final cover = s(data['coverUrl']);

    final start = toDate(data['startAt']);
    final end = toDate(data['endAt']);

    final budget = numOf(data['budget']);
    final spent = numOf(data['spent']);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cover.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 92,
                    height: 70,
                    child: Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined, size: 26),
                      ),
                      loadingBuilder: (_, child, ev) {
                        if (ev == null) {
                          return child;
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                )
              else
                Container(
                  width: 92,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    // ✅ surfaceVariant deprecated → surfaceContainerHighest
                    // ✅ withOpacity deprecated → withValues(alpha: ...)
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.30),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: const Icon(Icons.campaign_outlined),
                ),
              const SizedBox(width: 12),
              Expanded(
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
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(status: item.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      )
                    else
                      Text(
                        '（無說明）',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '時間：${fmtDate(start)} → ${fmtDate(end)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '預算/花費：${budget == 0 ? '—' : budget.toStringAsFixed(0)} / ${spent == 0 ? '—' : spent.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: onCopyId,
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('複製ID'),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final num impressions;
  final num clicks;
  final num conversions;

  const _MetricGrid({
    required this.impressions,
    required this.clicks,
    required this.conversions,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile(String name, num val, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 6),
              Text(
                val == 0 ? '—' : val.toStringAsFixed(0),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(name, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tile('曝光', impressions, Icons.visibility_outlined),
        const SizedBox(width: 10),
        tile('點擊', clicks, Icons.ads_click),
        const SizedBox(width: 10),
        tile('轉換', conversions, Icons.task_alt),
      ],
    );
  }
}

enum _CampaignStatus { active, upcoming, ended, disabled }

class _StatusPill extends StatelessWidget {
  final _CampaignStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String text;
    Color bg;
    Color fg;

    switch (status) {
      case _CampaignStatus.active:
        text = '進行中';
        bg = cs.primary.withValues(alpha: 0.10);
        fg = cs.primary;
        break;
      case _CampaignStatus.upcoming:
        text = '即將開始';
        bg = Colors.orange.withValues(alpha: 0.12);
        fg = Colors.orange.shade800;
        break;
      case _CampaignStatus.ended:
        text = '已結束';
        // ✅ surfaceVariant deprecated → surfaceContainerHighest
        bg = cs.surfaceContainerHighest.withValues(alpha: 0.35);
        fg = cs.onSurfaceVariant;
        break;
      case _CampaignStatus.disabled:
        text = '停用';
        bg = Colors.red.withValues(alpha: 0.10);
        fg = Colors.red.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

// ============================================================
// Data holder
// ============================================================

class _CampaignItem {
  final String id;
  final Map<String, dynamic> data;
  final _CampaignStatus status;

  const _CampaignItem({
    required this.id,
    required this.data,
    required this.status,
  });
}

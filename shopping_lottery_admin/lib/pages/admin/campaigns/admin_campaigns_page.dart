// lib/pages/admin/campaigns/admin_campaigns_page.dart
//
// ✅ AdminCampaignsPage（單檔完整版｜可編譯｜已修正：不再使用 campaignId named parameter）
// ------------------------------------------------------------
// - Firestore: campaigns（collection）
// - 功能：
//   1) 活動清單（Stream）
//   2) 搜尋（title/subtitle/type/status/vendorId/couponId）
//   3) 篩選（status/type/featured）
//   4) 新增 / 編輯（導向 AdminCampaignEditPage，透過 RouteSettings.arguments 傳 id）
//   5) 快速切換狀態（draft/active/paused/ended）
//   6) 複製活動（duplicate）
//   7) 刪除活動
//
// 依賴：cloud_firestore, intl
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_campaign_edit_page.dart';

class AdminCampaignsPage extends StatefulWidget {
  const AdminCampaignsPage({super.key});

  @override
  State<AdminCampaignsPage> createState() => _AdminCampaignsPageState();
}

class _AdminCampaignsPageState extends State<AdminCampaignsPage> {
  final _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col = _db.collection(
    'campaigns',
  );

  final _searchCtrl = TextEditingController();

  String _status = 'all';
  String _type = 'all';
  bool _featuredOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ 避免因為 campaigns 尚未補欄位而 query 炸：使用 docId 排序 + client-side sort
    final query = _col.orderBy(FieldPath.documentId).limit(500);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '活動管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '新增活動',
            icon: const Icon(Icons.add),
            onPressed: _openCreate,
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              title: '載入失敗',
              message: snap.error.toString(),
              hint: '請確認 Firestore rules 是否允許 admin 讀取 campaigns。',
              onRetry: () => setState(() {}),
            );
          }

          final docs = snap.data?.docs ?? const [];
          final list = docs.map((d) => AdminCampaign.fromDoc(d)).toList();

          // ✅ client-side sort: updatedAt / createdAt / startAt / docId
          list.sort((a, b) {
            final atA =
                a.updatedAt ??
                a.createdAt ??
                a.startAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final atB =
                b.updatedAt ??
                b.createdAt ??
                b.startAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final c = atB.compareTo(atA);
            if (c != 0) return c;
            return a.id.compareTo(b.id);
          });

          final filtered = _applyFilter(list);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _HeaderBar(
                total: list.length,
                showing: filtered.length,
                searchCtrl: _searchCtrl,
                status: _status,
                type: _type,
                featuredOnly: _featuredOnly,
                onChanged: (s, t, f) {
                  setState(() {
                    _status = s;
                    _type = t;
                    _featuredOnly = f;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '沒有符合條件的活動。',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              else
                ...filtered.map(
                  (c) => _CampaignCard(
                    campaign: c,
                    onEdit: () => _openEdit(c.id),
                    onDuplicate: () => _duplicate(c),
                    onDelete: () => _delete(c.id),
                    onQuickStatus: (next) => _setStatus(c.id, next),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<AdminCampaign> _applyFilter(List<AdminCampaign> input) {
    final q = _searchCtrl.text.trim().toLowerCase();

    Iterable<AdminCampaign> out = input;

    if (_status != 'all') {
      out = out.where((e) => e.status == _status);
    }
    if (_type != 'all') {
      out = out.where((e) => e.type == _type);
    }
    if (_featuredOnly) {
      out = out.where((e) => e.featured == true);
    }
    if (q.isNotEmpty) {
      out = out.where((e) {
        final hay = <String>[
          e.id,
          e.title,
          e.subtitle,
          e.type,
          e.status,
          e.vendorId,
          e.couponId,
          e.deeplink,
        ].join(' ').toLowerCase();
        return hay.contains(q);
      });
    }

    return out.toList();
  }

  // ============================================================
  // Navigation
  // ============================================================

  Future<void> _openCreate() async {
    final res = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const AdminCampaignEditPage()),
    );

    if (!mounted) return;
    if (res != null && res.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已建立活動')));
    }
  }

  Future<void> _openEdit(String campaignId) async {
    // ✅ 透過 RouteSettings.arguments 傳入 id（配合你的 AdminCampaignEditPage 用 ModalRoute.arguments 取值）
    final res = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        settings: RouteSettings(arguments: campaignId),
        builder: (_) => const AdminCampaignEditPage(),
      ),
    );

    if (!mounted) return;
    if (res == '__deleted__') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除活動')));
    } else if (res != null && res.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新活動')));
    }
  }

  // ============================================================
  // Actions
  // ============================================================

  Future<void> _setStatus(String id, String status) async {
    try {
      await _col.doc(id).set({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('狀態已更新：$status')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _duplicate(AdminCampaign c) async {
    final ok = await _confirm(
      title: '複製活動',
      message: '確定要複製這個活動？\n\n${c.title.isEmpty ? c.id : c.title}',
      confirmText: '複製',
    );
    if (ok != true) return;

    try {
      final newRef = _col.doc(); // autoId
      final now = FieldValue.serverTimestamp();

      await newRef.set({
        'title': c.title.isEmpty ? '(複製) ${c.id}' : '(複製) ${c.title}',
        'subtitle': c.subtitle,
        'description': c.description,
        'type': c.type,
        'status': 'draft',
        'featured': false,
        'startAt': c.startAt == null ? null : Timestamp.fromDate(c.startAt!),
        'endAt': c.endAt == null ? null : Timestamp.fromDate(c.endAt!),
        'bannerUrl': c.bannerUrl,
        'deeplink': c.deeplink,
        'couponId': c.couponId,
        'pointsReward': c.pointsReward,
        'budget': c.budget,
        'sortOrder': c.sortOrder,
        'segments': c.segments,
        'vendorId': c.vendorId,
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已複製：${newRef.id}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('複製失敗：$e')));
    }
  }

  Future<void> _delete(String id) async {
    final ok = await _confirm(
      title: '刪除活動',
      message: '確定刪除此活動？\n\nid: $id\n\n此操作無法復原。',
      confirmText: '刪除',
      danger: true,
    );
    if (ok != true) return;

    try {
      await _col.doc(id).delete();
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

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger ? cs.error : null,
              foregroundColor: danger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// UI
// ============================================================

class _HeaderBar extends StatelessWidget {
  final int total;
  final int showing;
  final TextEditingController searchCtrl;

  final String status;
  final String type;
  final bool featuredOnly;

  final void Function(String status, String type, bool featuredOnly) onChanged;

  const _HeaderBar({
    required this.total,
    required this.showing,
    required this.searchCtrl,
    required this.status,
    required this.type,
    required this.featuredOnly,
    required this.onChanged,
  });

  static const _statusOptions = <String>[
    'all',
    'draft',
    'active',
    'paused',
    'ended',
  ];

  static const _typeOptions = <String>[
    'all',
    'coupon',
    'points',
    'lottery',
    'flash_sale',
    'announcement',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(
                    Icons.campaign_outlined,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '活動清單',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '共 $total 筆｜目前顯示 $showing 筆',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: featuredOnly,
                  onChanged: (v) => onChanged(status, type, v),
                ),
                const SizedBox(width: 6),
                Text(
                  '僅精選',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchCtrl,
              onChanged: (_) => onChanged(status, type, featuredOnly),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋 title / type / status / vendorId / couponId ...',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('status_$status'),
                    initialValue: status,
                    items: _statusOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => onChanged(v ?? 'all', type, featuredOnly),
                    decoration: const InputDecoration(
                      labelText: '狀態（status）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('type_$type'),
                    initialValue: type,
                    items: _typeOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        onChanged(status, v ?? 'all', featuredOnly),
                    decoration: const InputDecoration(
                      labelText: '類型（type）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final AdminCampaign campaign;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<String> onQuickStatus;

  const _CampaignCard({
    required this.campaign,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onQuickStatus,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color badgeBg() {
      switch (campaign.status) {
        case 'active':
          return Colors.green.shade100;
        case 'paused':
          return Colors.orange.shade100;
        case 'ended':
          return Colors.grey.shade200;
        case 'draft':
        default:
          return cs.surfaceContainerHighest;
      }
    }

    Color badgeFg() {
      switch (campaign.status) {
        case 'active':
          return Colors.green.shade900;
        case 'paused':
          return Colors.orange.shade900;
        case 'ended':
          return Colors.grey.shade700;
        case 'draft':
        default:
          return cs.onSurfaceVariant;
      }
    }

    String fmt(DateTime? dt) =>
        dt == null ? '—' : DateFormat('yyyy/MM/dd HH:mm').format(dt);

    final title = campaign.title.isEmpty ? '(未命名活動)' : campaign.title;
    final subtitle = campaign.subtitle.trim();
    final timeText =
        'start=${fmt(campaign.startAt)}  •  end=${fmt(campaign.endAt)}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(
            Icons.local_activity_outlined,
            color: cs.onPrimaryContainer,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            if (campaign.featured)
              Icon(Icons.star, color: Colors.amber.shade700, size: 18),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg(),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                campaign.status,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: badgeFg(),
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${campaign.id}\n'
          'type=${campaign.type}'
          '${campaign.vendorId.isNotEmpty ? "  •  vendor=${campaign.vendorId}" : ""}'
          '${campaign.couponId.isNotEmpty ? "  •  couponId=${campaign.couponId}" : ""}'
          '${campaign.pointsReward > 0 ? "  •  points=${campaign.pointsReward}" : ""}'
          '\n$timeText'
          '${subtitle.isNotEmpty ? "\n$subtitle" : ""}',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (v) {
            if (v == 'edit') {
              onEdit();
            } else if (v == 'dup') {
              onDuplicate();
            } else if (v == 'delete') {
              onDelete();
            } else if (v.startsWith('status:')) {
              onQuickStatus(v.replaceFirst('status:', ''));
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 10),
                  Text('編輯'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'dup',
              child: Row(
                children: [
                  Icon(Icons.content_copy),
                  SizedBox(width: 10),
                  Text('複製（duplicate）'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'status:draft',
              child: Row(
                children: [
                  Icon(Icons.edit_note),
                  SizedBox(width: 10),
                  Text('狀態 → draft'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'status:active',
              child: Row(
                children: [
                  Icon(Icons.play_circle_outline),
                  SizedBox(width: 10),
                  Text('狀態 → active'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'status:paused',
              child: Row(
                children: [
                  Icon(Icons.pause_circle_outline),
                  SizedBox(width: 10),
                  Text('狀態 → paused'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'status:ended',
              child: Row(
                children: [
                  Icon(Icons.stop_circle_outlined),
                  SizedBox(width: 10),
                  Text('狀態 → ended'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: cs.error),
                  const SizedBox(width: 10),
                  const Text(
                    '刪除',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? hint;

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
        constraints: const BoxConstraints(maxWidth: 720),
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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

// ============================================================
// Model
// ============================================================

class AdminCampaign {
  final String id;

  final String title;
  final String subtitle;
  final String description;

  final String type;
  final String status;
  final bool featured;

  final DateTime? startAt;
  final DateTime? endAt;

  final String bannerUrl;
  final String deeplink;

  final String couponId;
  final int pointsReward;
  final int budget;
  final int sortOrder;

  final List<String> segments;
  final String vendorId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  AdminCampaign({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.type,
    required this.status,
    required this.featured,
    required this.startAt,
    required this.endAt,
    required this.bannerUrl,
    required this.deeplink,
    required this.couponId,
    required this.pointsReward,
    required this.budget,
    required this.sortOrder,
    required this.segments,
    required this.vendorId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminCampaign.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? <String, dynamic>{};

    DateTime? toDt(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    int toInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    List<String> toStrList(dynamic v) {
      if (v == null) return const [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return AdminCampaign(
      id: doc.id,
      title: (m['title'] ?? '').toString(),
      subtitle: (m['subtitle'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      type: (m['type'] ?? 'coupon').toString(),
      status: (m['status'] ?? 'draft').toString(),
      featured: m['featured'] == true,
      startAt: toDt(m['startAt']),
      endAt: toDt(m['endAt']),
      bannerUrl: (m['bannerUrl'] ?? '').toString(),
      deeplink: (m['deeplink'] ?? '').toString(),
      couponId: (m['couponId'] ?? '').toString(),
      pointsReward: toInt(m['pointsReward'], fallback: 0),
      budget: toInt(m['budget'], fallback: 0),
      sortOrder: toInt(m['sortOrder'], fallback: 0),
      segments: toStrList(m['segments']),
      vendorId: (m['vendorId'] ?? '').toString(),
      createdAt: toDt(m['createdAt']),
      updatedAt: toDt(m['updatedAt']),
    );
  }
}

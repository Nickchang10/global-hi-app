// lib/pages/admin_campaign_participants_page.dart
//
// ✅ AdminCampaignParticipantsPage（最終完整版｜參加者管理｜搜尋｜刪除｜匯出CSV(複製剪貼簿)）
// ------------------------------------------------------------
// Firestore:
// campaigns/{campaignId}/participants/{entryId}
// 建議欄位（可自由增減，本頁會容錯處理）
// - uid: String?
// - name: String?
// - phone: String?
// - email: String?
// - orderId: String?
// - note: String?
// - createdAt: Timestamp?
// - updatedAt: Timestamp?
//
// ✅ 匯出 CSV：使用 csv 套件 ListToCsvConverter（注意：不要 const）
// ✅ Web/手機都可編譯：匯出採「複製到剪貼簿 + 顯示預覽」方式（不使用 dart:html）
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';

class AdminCampaignParticipantsPage extends StatefulWidget {
  final String campaignId;
  const AdminCampaignParticipantsPage({super.key, required this.campaignId});

  @override
  State<AdminCampaignParticipantsPage> createState() =>
      _AdminCampaignParticipantsPageState();
}

class _AdminCampaignParticipantsPageState
    extends State<AdminCampaignParticipantsPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _query = '';

  bool _loadingGate = true;
  bool _allowed = true;
  String _denyReason = '';

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _bootstrapGate();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _normalizeRole(dynamic role) {
    final raw = (role ?? '').toString().toLowerCase().trim();
    // 常見 enum.toString() 會是 "Role.admin" → 抹掉前綴
    if (raw.contains('.')) return raw.split('.').last;
    return raw;
  }

  /// ------------------------------------------------------------
  /// 權限：
  /// - Admin 全可看
  /// - Vendor 只能看「自己 vendorId 的活動」
  ///
  /// ✅ 修正點：
  /// 你專案的 cachedRoleInfo 是 non-nullable，因此不能用 ?.（會出現 invalid_null_aware_operator）
  /// ------------------------------------------------------------
  Future<void> _bootstrapGate() async {
    setState(() {
      _loadingGate = true;
      _allowed = true;
      _denyReason = '';
    });

    try {
      final gate = context.read<AdminGate>();

      // ✅ 關鍵修正：不要用 cachedRoleInfo?.role（你的 cachedRoleInfo 不是 nullable）
      final role = _normalizeRole(gate.cachedRoleInfo.role);
      final myVendorId = _s(gate.cachedVendorId);

      if (role == 'admin') {
        _allowed = true;
        return;
      }

      if (role == 'vendor') {
        if (myVendorId.isEmpty) {
          _allowed = false;
          _denyReason = 'Vendor 帳號缺少 vendorId，請在 users/{uid} 補上 vendorId';
          return;
        }

        // 讀取活動 vendorId，確認是否為自己的活動
        final camp = await _db
            .collection('campaigns')
            .doc(widget.campaignId)
            .get();
        final data = camp.data() ?? <String, dynamic>{};
        final campVendorId = _s(data['vendorId']);

        if (campVendorId.isNotEmpty && campVendorId != myVendorId) {
          _allowed = false;
          _denyReason = '你無權查看其他廠商的活動參加者';
          return;
        }

        // 若活動未設 vendorId：允許（避免舊資料阻擋）
        _allowed = true;
        return;
      }

      _allowed = false;
      _denyReason = '此帳號無後台存取權限';
    } catch (e) {
      _allowed = false;
      _denyReason = '權限檢查失敗：$e';
    } finally {
      if (mounted) setState(() => _loadingGate = false);
    }
  }

  Query<Map<String, dynamic>> _baseQuery() {
    // 參加者子集合
    // 若 createdAt 不存在，orderBy 會出錯；此處保留你的寫法（建議資料都有 createdAt）
    return _db
        .collection('campaigns')
        .doc(widget.campaignId)
        .collection('participants')
        .orderBy('createdAt', descending: true)
        .limit(500);
  }

  bool _matchQuery(Map<String, dynamic> data) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final fields = <String>[
      _s(data['name']),
      _s(data['phone']),
      _s(data['email']),
      _s(data['uid']),
      _s(data['orderId']),
      _s(data['note']),
    ].join(' ').toLowerCase();

    return fields.contains(q);
  }

  Future<void> _deleteParticipant(String entryId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除參加者'),
        content: const Text('確定刪除這筆參加紀錄？此操作不可復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _db
          .collection('campaigns')
          .doc(widget.campaignId)
          .collection('participants')
          .doc(entryId)
          .delete();
      _snack('已刪除');
    } catch (e) {
      _snack('刪除失敗：$e');
    }
  }

  /// ✅ 匯出 CSV：不使用 const ListToCsvConverter（會編譯錯）
  Future<void> _exportCsv(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final rows = <List<dynamic>>[];

      // Header
      rows.add([
        'entryId',
        'uid',
        'name',
        'phone',
        'email',
        'orderId',
        'note',
        'createdAt',
      ]);

      for (final d in docs) {
        final data = d.data();
        final createdAt = _toDate(data['createdAt']);
        rows.add([
          d.id,
          _s(data['uid']),
          _s(data['name']),
          _s(data['phone']),
          _s(data['email']),
          _s(data['orderId']),
          _s(data['note']),
          _fmtDate(createdAt),
        ]);
      }

      // ✅ 關鍵修正：不要 const
      final csv = ListToCsvConverter().convert(rows);

      // 複製到剪貼簿（Web/手機皆可）
      await Clipboard.setData(ClipboardData(text: csv));
      _snack('CSV 已複製到剪貼簿（共 ${docs.length} 筆）');

      // 預覽（避免某些瀏覽器剪貼簿權限限制）
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('CSV 預覽（已複製）'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: SelectableText(
                csv.length > 20000
                    ? '${csv.substring(0, 20000)}\n...\n(內容過長已截斷顯示)'
                    : csv,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        ),
      );
    } catch (e) {
      _snack('匯出失敗：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingGate) {
      return Scaffold(
        appBar: AppBar(title: const Text('參加者管理')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('參加者管理')),
        body: Center(child: Text(_denyReason.isEmpty ? '無權限' : _denyReason)),
      );
    }

    final q = _baseQuery();

    return Scaffold(
      appBar: AppBar(
        title: const Text('參加者管理'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _buildTopBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData) {
                  return const Center(child: Text('尚無參加者資料'));
                }

                final docs = snap.data!.docs;

                // client-side 搜尋
                final filtered = docs
                    .where((d) => _matchQuery(d.data()))
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('沒有符合條件的參加者'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final doc = filtered[i];
                    final data = doc.data();

                    final name = _s(data['name']);
                    final phone = _s(data['phone']);
                    final email = _s(data['email']);
                    final uid = _s(data['uid']);
                    final orderId = _s(data['orderId']);
                    final note = _s(data['note']);
                    final createdAt = _toDate(data['createdAt']);

                    final title = name.isNotEmpty
                        ? name
                        : (phone.isNotEmpty ? phone : doc.id);

                    final subtitle = <String>[
                      if (uid.isNotEmpty) 'uid:$uid',
                      if (phone.isNotEmpty) '手機:$phone',
                      if (email.isNotEmpty) 'Email:$email',
                      if (orderId.isNotEmpty) '訂單:$orderId',
                      '時間:${_fmtDate(createdAt)}',
                      if (note.isNotEmpty) '備註:$note',
                    ].join('｜');

                    return ListTile(
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(subtitle),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'copy_uid') {
                            if (uid.isEmpty) return;
                            await Clipboard.setData(ClipboardData(text: uid));
                            _snack('uid 已複製');
                          } else if (v == 'delete') {
                            await _deleteParticipant(doc.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'copy_uid',
                            child: Text('複製 uid'),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(value: 'delete', child: Text('刪除')),
                        ],
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
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋：姓名/手機/Email/uid/訂單/備註',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Campaign: ${widget.campaignId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _baseQuery().snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? const [];
              final filtered = docs
                  .where((d) => _matchQuery(d.data()))
                  .toList();

              return FilledButton.icon(
                onPressed: _exporting ? null : () => _exportCsv(filtered),
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(_exporting ? '匯出中...' : '匯出CSV（複製）'),
              );
            },
          ),
        ],
      ),
    );
  }
}

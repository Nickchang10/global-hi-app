// lib/pages/admin_campaign_draw_page.dart
//
// ✅ AdminCampaignDrawPage（最終穩定完整版｜抽獎/得獎名單｜依獎項 quantity 抽出｜避免重複｜Admin/Vendor 權限）
// ------------------------------------------------------------
// Firestore：
// campaigns/{cid}
//  - title, vendorId, isActive, startAt, endAt, participantsCount, winnersCount, updatedAt...
//
// campaigns/{cid}/prizes/{pid}
//  - title, description, isActive, quantity(int), weight(double), sortOrder(int), updatedAt...
//
// campaigns/{cid}/participants/{entryId}
//  - uid/userId/buyerUid (任一), name/userName, email, phone, createdAt...
//
// campaigns/{cid}/winners/{wid}
//  - prizeId, prizeTitle
//  - entryId
//  - participantUid, participantName
//  - createdAt, createdByUid
// ------------------------------------------------------------

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/admin_gate.dart';

class AdminCampaignDrawPage extends StatefulWidget {
  final String campaignId;
  const AdminCampaignDrawPage({super.key, required this.campaignId});

  @override
  State<AdminCampaignDrawPage> createState() => _AdminCampaignDrawPageState();
}

class _AdminCampaignDrawPageState extends State<AdminCampaignDrawPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late final TabController _tabCtrl;

  bool _loading = true;
  bool _accessDenied = false;
  bool _drawing = false;

  String _role = '';
  String _myVendorId = '';
  String _campaignVendorId = '';
  String _campaignTitle = '';

  String _winnerPrizeFilter = '全部';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  DocumentReference<Map<String, dynamic>> get _campaignRef =>
      _db.collection('campaigns').doc(widget.campaignId);

  CollectionReference<Map<String, dynamic>> get _prizesCol =>
      _campaignRef.collection('prizes');

  CollectionReference<Map<String, dynamic>> get _participantsCol =>
      _campaignRef.collection('participants');

  CollectionReference<Map<String, dynamic>> get _winnersCol =>
      _campaignRef.collection('winners');

  Future<void> _bootstrap() async {
    final gate = context.read<AdminGate>();
    _role = (gate.cachedRoleInfo?.role ?? '').toLowerCase().trim();
    _myVendorId = (gate.cachedVendorId ?? '').trim();

    await _loadCampaignMetaAndCheckAccess();

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCampaignMetaAndCheckAccess() async {
    try {
      final snap = await _campaignRef.get();
      final data = snap.data();
      if (data == null) {
        _accessDenied = true;
        return;
      }

      _campaignTitle = (data['title'] ?? '').toString().trim();
      _campaignVendorId = (data['vendorId'] ?? '').toString().trim();

      // ✅ Admin 放行
      if (_role == 'admin') {
        _accessDenied = false;
        return;
      }

      // ✅ Vendor：必須 vendorId 存在且相符
      if (_role == 'vendor') {
        if (_myVendorId.isEmpty || _campaignVendorId.isEmpty) {
          _accessDenied = true;
          return;
        }
        if (_campaignVendorId != _myVendorId) {
          _accessDenied = true;
          return;
        }
        _accessDenied = false;
        return;
      }

      _accessDenied = true;
    } catch (_) {
      _accessDenied = true;
    }
  }

  // ------------------------------------------------------------
  // Queries / streams
  // ------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> _prizes$() {
    return _prizesCol
        .orderBy('sortOrder')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _winners$({String? prizeId}) {
    Query<Map<String, dynamic>> q = _winnersCol.orderBy('createdAt', descending: true);
    if (prizeId != null && prizeId.isNotEmpty) {
      q = q.where('prizeId', isEqualTo: prizeId);
    }
    return q.limit(500).snapshots();
  }

  Future<int> _countOnce(Query<Map<String, dynamic>> q) async {
    try {
      final agg = await q.count().get();
      final c = agg.count;
      return (c is int) ? c : int.tryParse('$c') ?? 0;
    } catch (_) {
      final snap = await q.get();
      return snap.size;
    }
  }

  // ------------------------------------------------------------
  // Draw logic
  // ------------------------------------------------------------

  Future<void> _drawAllPrizes() async {
    if (_drawing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('請先登入');
      return;
    }

    setState(() => _drawing = true);
    try {
      // 1) 讀取所有「啟用」獎項
      final prizesSnap = await _prizesCol
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      if (prizesSnap.docs.isEmpty) {
        _snack('沒有啟用中的獎項');
        return;
      }

      // 2) 讀取所有參加者
      final participantsSnap = await _participantsCol.get();
      if (participantsSnap.docs.isEmpty) {
        _snack('沒有參加者');
        return;
      }

      // 3) 讀取現有 winners，用 entryId 去重
      final winnersSnap = await _winnersCol.get();
      final alreadyWonEntryIds = <String>{};
      for (final d in winnersSnap.docs) {
        final entryId = (d.data()['entryId'] ?? '').toString().trim();
        if (entryId.isNotEmpty) alreadyWonEntryIds.add(entryId);
      }

      // 4) 建立可抽名單（排除已得獎 entryId）
      final pool = participantsSnap.docs
          .where((p) => !alreadyWonEntryIds.contains(p.id))
          .toList();

      if (pool.isEmpty) {
        _snack('所有參加者都已得獎（可用「清空得獎名單」重抽）');
        return;
      }

      // 5) 抽獎：依每個 prize.quantity 抽出不重複 entry
      final rng = Random();
      final remaining = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(pool);
      remaining.shuffle(rng);

      int createdCount = 0;
      final batch = _db.batch();

      for (final prizeDoc in prizesSnap.docs) {
        final prize = prizeDoc.data();
        final prizeTitle = (prize['title'] ?? '').toString().trim();
        final qtyRaw = prize['quantity'];
        final qty = _toInt(qtyRaw, fallback: 1);
        if (qty <= 0) continue;

        final take = min(qty, remaining.length);
        if (take <= 0) break;

        for (int i = 0; i < take; i++) {
          final entry = remaining.removeAt(0);
          final pd = entry.data();

          final participantUid = _pickUid(pd, fallback: entry.id);
          final participantName = _pickName(pd);

          final winnerRef = _winnersCol.doc();
          batch.set(winnerRef, <String, dynamic>{
            'campaignId': widget.campaignId,
            'prizeId': prizeDoc.id,
            'prizeTitle': prizeTitle,
            'entryId': entry.id,
            'participantUid': participantUid,
            'participantName': participantName,
            'createdAt': FieldValue.serverTimestamp(),
            'createdByUid': user.uid,
            if (_campaignVendorId.isNotEmpty) 'vendorId': _campaignVendorId,
          });

          createdCount++;
          if (remaining.isEmpty) break;
        }

        if (remaining.isEmpty) break;
      }

      if (createdCount == 0) {
        _snack('沒有抽出任何得獎者（可能獎項 quantity 為 0 或名單不足）');
        return;
      }

      // 6) commit batch
      await batch.commit();

      // 7) 更新 campaign winnersCount / participantsCount（非必要，但建議）
      final pCount = participantsSnap.size;
      final wCount = await _countOnce(_winnersCol);
      await _campaignRef.set(
        <String, dynamic>{
          'participantsCount': pCount,
          'winnersCount': wCount,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _snack('抽獎完成：新增 $createdCount 筆得獎');
      _tabCtrl.animateTo(1);
    } catch (e) {
      _snack('抽獎失敗：$e');
    } finally {
      if (mounted) setState(() => _drawing = false);
    }
  }

  Future<void> _drawSinglePrize(String prizeId, Map<String, dynamic> prize) async {
    if (_drawing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('請先登入');
      return;
    }

    final prizeTitle = (prize['title'] ?? '').toString().trim();
    final qty = _toInt(prize['quantity'], fallback: 1);

    if (qty <= 0) {
      _snack('此獎項 quantity 為 0');
      return;
    }

    setState(() => _drawing = true);
    try {
      final participantsSnap = await _participantsCol.get();
      if (participantsSnap.docs.isEmpty) {
        _snack('沒有參加者');
        return;
      }

      final winnersSnap = await _winnersCol.get();
      final alreadyWonEntryIds = <String>{};
      for (final d in winnersSnap.docs) {
        final entryId = (d.data()['entryId'] ?? '').toString().trim();
        if (entryId.isNotEmpty) alreadyWonEntryIds.add(entryId);
      }

      final pool = participantsSnap.docs
          .where((p) => !alreadyWonEntryIds.contains(p.id))
          .toList();

      if (pool.isEmpty) {
        _snack('所有參加者都已得獎（可用「清空得獎名單」重抽）');
        return;
      }

      final rng = Random();
      pool.shuffle(rng);

      final take = min(qty, pool.length);
      final batch = _db.batch();
      for (int i = 0; i < take; i++) {
        final entry = pool[i];
        final pd = entry.data();
        final participantUid = _pickUid(pd, fallback: entry.id);
        final participantName = _pickName(pd);

        final winnerRef = _winnersCol.doc();
        batch.set(winnerRef, <String, dynamic>{
          'campaignId': widget.campaignId,
          'prizeId': prizeId,
          'prizeTitle': prizeTitle,
          'entryId': entry.id,
          'participantUid': participantUid,
          'participantName': participantName,
          'createdAt': FieldValue.serverTimestamp(),
          'createdByUid': user.uid,
          if (_campaignVendorId.isNotEmpty) 'vendorId': _campaignVendorId,
        });
      }
      await batch.commit();

      final wCount = await _countOnce(_winnersCol);
      await _campaignRef.set(
        <String, dynamic>{
          'participantsCount': participantsSnap.size,
          'winnersCount': wCount,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _snack('已抽出 $take 位：$prizeTitle');
      _tabCtrl.animateTo(1);
    } catch (e) {
      _snack('抽獎失敗：$e');
    } finally {
      if (mounted) setState(() => _drawing = false);
    }
  }

  Future<void> _clearWinners() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空得獎名單'),
        content: const Text('確定要清空此活動 winners？可用於重新抽獎。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _drawing = true);
    try {
      // 分批刪除（每批最多 450）
      while (true) {
        final snap = await _winnersCol.limit(450).get();
        if (snap.docs.isEmpty) break;
        final batch = _db.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }

      final pCount = await _countOnce(_participantsCol);
      await _campaignRef.set(
        <String, dynamic>{
          'participantsCount': pCount,
          'winnersCount': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _snack('已清空得獎名單');
    } catch (e) {
      _snack('清空失敗：$e');
    } finally {
      if (mounted) setState(() => _drawing = false);
    }
  }

  Future<void> _copyWinnersCsvToClipboard(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final rows = <List<String>>[
      ['prizeTitle', 'participantName', 'participantUid', 'entryId', 'createdAt'],
    ];

    for (final d in docs) {
      final data = d.data();
      rows.add([
        (data['prizeTitle'] ?? '').toString(),
        (data['participantName'] ?? '').toString(),
        (data['participantUid'] ?? '').toString(),
        (data['entryId'] ?? '').toString(),
        (data['createdAt'] ?? '').toString(),
      ]);
    }

    // 簡單 CSV（避免額外依賴）
    final csv = rows.map((r) => r.map(_escapeCsv).join(',')).join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    _snack('已複製 CSV 到剪貼簿');
  }

  String _escapeCsv(String s) {
    final v = s.replaceAll('"', '""');
    // 含逗號/換行/引號就包起來
    if (v.contains(',') || v.contains('\n') || v.contains('"')) {
      return '"$v"';
    }
    return v;
  }

  int _toInt(dynamic v, {required int fallback}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? fallback;
  }

  String _pickUid(Map<String, dynamic> d, {required String fallback}) {
    final keys = ['uid', 'userId', 'buyerUid'];
    for (final k in keys) {
      final s = (d[k] ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  String _pickName(Map<String, dynamic> d) {
    final keys = ['name', 'userName', 'buyerName', 'displayName'];
    for (final k in keys) {
      final s = (d[k] ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '(未填姓名)';
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_accessDenied) {
      return Scaffold(
        appBar: AppBar(title: const Text('抽獎/得獎名單')),
        body: const Center(child: Text('無權限存取此活動抽獎功能')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_campaignTitle.isEmpty ? '抽獎/得獎名單' : '抽獎｜$_campaignTitle'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '抽獎'),
            Tab(text: '得獎名單'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          if (_drawing)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildDrawTab(),
          _buildWinnersTab(),
        ],
      ),
    );
  }

  Widget _buildDrawTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _prizes$(),
      builder: (context, snap) {
        final prizes = snap.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildMetaCard(prizesCount: prizes.length),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.casino_outlined),
                    label: const Text('一鍵抽出所有獎項'),
                    onPressed: _drawing ? null : _drawAllPrizes,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('清空得獎名單'),
                  onPressed: _drawing ? null : _clearWinners,
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Text('獎項列表（可單獎抽出）', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),

            if (!snap.hasData)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (prizes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('尚無獎項')),
              )
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: prizes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final doc = prizes[i];
                    final d = doc.data();
                    final title = (d['title'] ?? '').toString().trim();
                    final isActive = d['isActive'] == true;
                    final qty = _toInt(d['quantity'], fallback: 1);
                    final sortOrder = _toInt(d['sortOrder'], fallback: 0);

                    return ListTile(
                      title: Text(
                        title.isEmpty ? '(未命名獎項)' : title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text('狀態：${isActive ? '啟用' : '停用'}｜數量：$qty｜排序：$sortOrder'),
                      trailing: FilledButton(
                        onPressed: (!isActive || _drawing) ? null : () => _drawSinglePrize(doc.id, d),
                        child: const Text('抽此獎'),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMetaCard({required int prizesCount}) {
    return FutureBuilder<List<int>>(
      future: () async {
        final p = await _countOnce(_participantsCol);
        final w = await _countOnce(_winnersCol);
        return [p, w];
      }(),
      builder: (context, snap) {
        final pCount = (snap.data?.isNotEmpty == true) ? snap.data![0] : 0;
        final wCount = (snap.data?.length == 2) ? snap.data![1] : 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _campaignTitle.isEmpty ? '活動資訊' : _campaignTitle,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '獎項：$prizesCount｜參加者：$pCount｜得獎：$wCount',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '角色：${_role.isEmpty ? '-' : _role}${_role == 'vendor' ? '（vendorId: $_myVendorId）' : ''}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWinnersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _prizes$(),
      builder: (context, prizeSnap) {
        final prizes = prizeSnap.data?.docs ?? [];

        // 建立 prizeId->title map，並提供篩選
        final prizeItems = <DropdownMenuItem<String>>[
          const DropdownMenuItem(value: '全部', child: Text('全部')),
          ...prizes.map((p) {
            final t = (p.data()['title'] ?? '').toString().trim();
            return DropdownMenuItem(value: p.id, child: Text(t.isEmpty ? p.id : t));
          }),
        ];

        final filterPrizeId = (_winnerPrizeFilter == '全部') ? null : _winnerPrizeFilter;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('篩選獎項：', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _winnerPrizeFilter,
                    items: prizeItems,
                    onChanged: (v) => setState(() => _winnerPrizeFilter = v ?? '全部'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '複製 CSV（依目前篩選）',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () async {
                      try {
                        // 取目前篩選 winners（一次性）
                        Query<Map<String, dynamic>> q = _winnersCol.orderBy('createdAt', descending: true);
                        if (filterPrizeId != null && filterPrizeId.isNotEmpty) {
                          q = q.where('prizeId', isEqualTo: filterPrizeId);
                        }
                        final snap = await q.limit(500).get();
                        await _copyWinnersCsvToClipboard(snap.docs);
                      } catch (e) {
                        _snack('複製失敗：$e');
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _winners$(prizeId: filterPrizeId),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text('尚無得獎名單'));

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final d = docs[i].data();
                      final prizeTitle = (d['prizeTitle'] ?? '').toString().trim();
                      final name = (d['participantName'] ?? '').toString().trim();
                      final uid = (d['participantUid'] ?? '').toString().trim();
                      final entryId = (d['entryId'] ?? '').toString().trim();

                      return ListTile(
                        leading: const Icon(Icons.emoji_events_outlined),
                        title: Text(
                          prizeTitle.isEmpty ? '(未命名獎項)' : prizeTitle,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text('得獎者：${name.isEmpty ? '(未填姓名)' : name}｜uid：$uid｜entry：$entryId'),
                        trailing: IconButton(
                          tooltip: '刪除此筆得獎',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _drawing
                              ? null
                              : () async {
                                  try {
                                    await docs[i].reference.delete();
                                    _snack('已刪除一筆得獎');
                                  } catch (e) {
                                    _snack('刪除失敗：$e');
                                  }
                                },
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
}

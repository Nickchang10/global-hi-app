// lib/pages/admin_campaign_reports_page.dart
//
// ✅ AdminCampaignReportsPage（最終完整版｜活動報表中心｜summary + participants + orders + 匯出）
// ------------------------------------------------------------
// Firestore:
// - campaigns/{campaignId}/participants
// - orders/{orderId} (with campaignId)
// - coupons/{couponId} (with campaignId)
// ------------------------------------------------------------

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/admin_gate.dart';

class AdminCampaignReportsPage extends StatefulWidget {
  final String campaignId;
  const AdminCampaignReportsPage({super.key, required this.campaignId});

  @override
  State<AdminCampaignReportsPage> createState() => _AdminCampaignReportsPageState();
}

class _AdminCampaignReportsPageState extends State<AdminCampaignReportsPage> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  bool _exporting = false;

  int _participantCount = 0;
  int _orderCount = 0;
  int _couponUsed = 0;
  int _exposureCount = 0;
  double _conversionRate = 0;

  List<_ParticipantRow> _participants = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      await Future.wait([
        _loadSummary(),
        _loadParticipants(),
      ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSummary() async {
    final cid = widget.campaignId;

    // 1. participants count
    final pSnap = await _db.collection('campaigns').doc(cid).collection('participants').get();
    final pCount = pSnap.size;

    // 2. orders count
    final oSnap = await _db.collection('orders').where('campaignId', isEqualTo: cid).get();
    final oCount = oSnap.size;

    // 3. coupons used
    final cSnap = await _db.collection('coupons').where('campaignId', isEqualTo: cid).where('usedAt', isNotEqualTo: null).get();
    final cCount = cSnap.size;

    // 4. exposures (可選：例如 campaign_logs)
    int eCount = 0;
    try {
      final eSnap = await _db.collection('campaign_logs').where('campaignId', isEqualTo: cid).get();
      eCount = eSnap.size;
    } catch (_) {}

    double conversion = 0;
    if (eCount > 0) {
      conversion = oCount / eCount;
    } else if (pCount > 0) {
      conversion = oCount / pCount;
    }

    setState(() {
      _participantCount = pCount;
      _orderCount = oCount;
      _couponUsed = cCount;
      _exposureCount = eCount;
      _conversionRate = conversion;
    });
  }

  Future<void> _loadParticipants() async {
    final cid = widget.campaignId;
    final snap = await _db.collection('campaigns').doc(cid).collection('participants').orderBy('joinedAt', descending: true).limit(1000).get();

    final rows = snap.docs.map((d) {
      final data = d.data();
      return _ParticipantRow(
        uid: d.id,
        source: data['source'] ?? '',
        joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
        couponUsed: data['couponUsed'] == true,
        orderId: data['orderId'],
      );
    }).toList();

    setState(() => _participants = rows);
  }

  Future<void> _exportCSV() async {
    if (_participants.isEmpty) {
      _snack('沒有資料可匯出');
      return;
    }

    setState(() => _exporting = true);
    try {
      final table = <List<dynamic>>[
        ['UserID', '來源', '加入時間', '是否用券', '訂單ID'],
        ..._participants.map((r) => [
              r.uid,
              r.source,
              r.joinedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(r.joinedAt!) : '',
              r.couponUsed ? '是' : '否',
              r.orderId ?? '',
            ]),
      ];

      final csv = const ListToCsvConverter().convert(table);
      final bytes = Uint8List.fromList(utf8.encode(csv));

      await FileSaver.instance.saveFile(
        name: 'campaign_${widget.campaignId}_report_${DateTime.now().millisecondsSinceEpoch}',
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

      _snack('已匯出 ${table.length - 1} 筆參與資料');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = context.read<AdminGate>();

    return FutureBuilder<RoleInfo>(
      future: gate.ensureAndGetRole(),
      builder: (context, snap) {
        final info = snap.data;
        final role = (info?.role ?? '').toLowerCase().trim();

        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('活動報表'),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
              IconButton(icon: const Icon(Icons.download_outlined), onPressed: _exportCSV),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      Text('參加紀錄 (${_participants.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      _buildParticipantTable(),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('活動概況', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Divider(height: 18),
            Wrap(
              spacing: 40,
              runSpacing: 10,
              children: [
                _summaryTile('參加人數', _participantCount.toString()),
                _summaryTile('訂單數', _orderCount.toString()),
                _summaryTile('用券數', _couponUsed.toString()),
                _summaryTile('曝光次數', _exposureCount.toString()),
                _summaryTile('轉換率', '${(_conversionRate * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label),
      ],
    );
  }

  Widget _buildParticipantTable() {
    if (_participants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('尚無參與紀錄')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('UserID')),
            DataColumn(label: Text('來源')),
            DataColumn(label: Text('加入時間')),
            DataColumn(label: Text('用券')),
            DataColumn(label: Text('訂單ID')),
          ],
          rows: _participants
              .map((r) => DataRow(cells: [
                    DataCell(Text(r.uid)),
                    DataCell(Text(r.source)),
                    DataCell(Text(r.joinedAt != null
                        ? DateFormat('yyyy-MM-dd HH:mm').format(r.joinedAt!)
                        : '-')),
                    DataCell(Text(r.couponUsed ? '是' : '否')),
                    DataCell(Text(r.orderId ?? '-')),
                  ]))
              .toList(),
        ),
      ),
    );
  }
}

class _ParticipantRow {
  final String uid;
  final String source;
  final DateTime? joinedAt;
  final bool couponUsed;
  final String? orderId;

  _ParticipantRow({
    required this.uid,
    required this.source,
    this.joinedAt,
    required this.couponUsed,
    this.orderId,
  });
}

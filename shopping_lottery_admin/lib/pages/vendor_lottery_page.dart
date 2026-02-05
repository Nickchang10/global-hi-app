// lib/pages/vendor_lottery_page.dart
//
// ✅ VendorLotteryPage（完整版｜可編譯｜Vendor Only｜抽獎活動管理｜與主後台 Firestore 連動｜CRUD｜抽獎｜中獎名單｜參加名單｜匯出CSV(複製剪貼簿)｜Web+App）
//
// 目的：
// - 廠商後台只管理「自己的抽獎活動」：lotteries.where('vendorId' == currentVendorId)
// - 與主後台共用同一份 Firestore collections → 自然連動
//
// Collections 建議：
// 1) lotteries/{lotteryId}
//   - vendorId: String
//   - vendorName: String (選用)
//   - title: String
//   - status: String           // draft / active / ended
//   - startAt: Timestamp?      // 選用
//   - endAt: Timestamp?        // 選用
//   - prizes: List<String>     // 獎項（可用文字）
//   - totalWinners: int        // 預設抽出人數（可選）
//   - note: String (選用)
//   - createdAt: Timestamp
//   - updatedAt: Timestamp
//
// 2) lottery_entries/{entryId}
//   - lotteryId: String
//   - vendorId: String         // 建議存一份加速查詢（可選）
//   - userId: String
//   - userName: String (選用)
//   - userEmail: String (選用)
//   - entryAt: Timestamp
//
// 3) lottery_winners/{winnerId}
//   - lotteryId: String
//   - vendorId: String         // 建議存一份加速查詢（可選）
//   - userId: String
//   - userName: String (選用)
//   - userEmail: String (選用)
//   - prize: String            // 中獎獎項
//   - wonAt: Timestamp
//
// 索引建議：
// - lotteries: where(vendorId) + orderBy(updatedAt desc)
// - lottery_entries: where(lotteryId) + orderBy(entryAt desc)
// - lottery_winners: where(lotteryId) + orderBy(wonAt desc)
//
// 注意：
// - 本頁不依賴 VendorGate/AdminGate；呼叫時傳入 vendorId 即可。
// - 抽獎採用「從 entries 中隨機挑選未得獎者」，並寫入 lottery_winners。
// - 為避免重複得獎：會先讀 winners userId set，抽獎時排除。
// - CSV 匯出採用「複製到剪貼簿」方式（可貼到 Excel）。
//
// 用法：VendorLotteryPage(vendorId: vendorId, vendorName: vendorName)

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VendorLotteryPage extends StatefulWidget {
  const VendorLotteryPage({
    super.key,
    required this.vendorId,
    this.vendorName,
    this.lotteriesCollection = 'lotteries',
    this.entriesCollection = 'lottery_entries',
    this.winnersCollection = 'lottery_winners',
    this.maxLotteries = 500,
    this.maxEntriesRead = 2000,
  });

  final String vendorId;
  final String? vendorName;

  final String lotteriesCollection;
  final String entriesCollection;
  final String winnersCollection;

  final int maxLotteries;
  final int maxEntriesRead;

  @override
  State<VendorLotteryPage> createState() => _VendorLotteryPageState();
}

class _VendorLotteryPageState extends State<VendorLotteryPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _q = '';

  String? _status; // null=全部
  String? _selectedLotteryId;

  bool _busy = false;
  String _busyLabel = '';

  CollectionReference<Map<String, dynamic>> get _lcol => _db.collection(widget.lotteriesCollection);
  CollectionReference<Map<String, dynamic>> get _ecol => _db.collection(widget.entriesCollection);
  CollectionReference<Map<String, dynamic>> get _wcol => _db.collection(widget.winnersCollection);

  String get _vid => widget.vendorId.trim();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Utils
  // -------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _isTrue(dynamic v) => v == true;

  int _toInt(dynamic v, {int def = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_s(v)) ?? def;
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _copy(String text, {String done = '已複製'}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    _snack(done);
  }

  Future<void> _setBusy(bool v, {String label = ''}) async {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  // -------------------------
  // Streams
  // -------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamLotteries() {
    if (_vid.isEmpty) return const Stream.empty();
    return _lcol
        .where('vendorId', isEqualTo: _vid)
        .orderBy('updatedAt', descending: true)
        .limit(widget.maxLotteries)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamEntries(String lotteryId) {
    final id = lotteryId.trim();
    if (id.isEmpty) return const Stream.empty();
    return _ecol.where('lotteryId', isEqualTo: id).orderBy('entryAt', descending: true).limit(1000).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamWinners(String lotteryId) {
    final id = lotteryId.trim();
    if (id.isEmpty) return const Stream.empty();
    return _wcol.where('lotteryId', isEqualTo: id).orderBy('wonAt', descending: true).limit(1000).snapshots();
  }

  // -------------------------
  // Local filter
  // -------------------------
  bool _matchLottery(_LotteryRow r) {
    final d = r.data;

    if (_status != null && _status!.trim().isNotEmpty) {
      if (_s(d['status']).toLowerCase() != _status!.trim().toLowerCase()) return false;
    }

    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;

    final id = r.id.toLowerCase();
    final title = _s(d['title']).toLowerCase();
    final note = _s(d['note']).toLowerCase();
    final prizes = (d['prizes'] is List) ? (d['prizes'] as List).join(' ').toLowerCase() : '';

    return id.contains(q) || title.contains(q) || note.contains(q) || prizes.contains(q);
  }

  // -------------------------
  // CRUD: lotteries
  // -------------------------
  Future<void> _deleteLottery(String lotteryId) async {
    final id = lotteryId.trim();
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除抽獎活動'),
        content: Text('確定要刪除活動：$id 嗎？（不會自動刪除 entries / winners，需要的話請自行清除）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (ok != true) return;

    await _setBusy(true, label: '刪除中...');
    try {
      await _lcol.doc(id).delete();
      if (_selectedLotteryId == id) _selectedLotteryId = null;
      _snack('已刪除：$id');
    } catch (e) {
      _snack('刪除失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _toggleStatus(String lotteryId, String status) async {
    final id = lotteryId.trim();
    if (id.isEmpty) return;

    await _setBusy(true, label: '更新狀態中...');
    try {
      await _lcol.doc(id).set(
        <String, dynamic>{
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _snack('已更新狀態：$status');
    } catch (e) {
      _snack('更新失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _openEditLotteryDialog({String? lotteryId, Map<String, dynamic>? data}) async {
    final isCreate = lotteryId == null || lotteryId.trim().isEmpty;

    final titleCtrl = TextEditingController(text: _s(data?['title']));
    final noteCtrl = TextEditingController(text: _s(data?['note']));
    final prizesCtrl = TextEditingController(
      text: (data?['prizes'] is List) ? (data!['prizes'] as List).join('\n') : _s(data?['prizes']),
    );

    String status = _s(data?['status']).isEmpty ? 'draft' : _s(data?['status']);
    int totalWinners = _toInt(data?['totalWinners'], def: 1);

    DateTime? startAt = _toDate(data?['startAt']);
    DateTime? endAt = _toDate(data?['endAt']);

    Future<void> pickDate(bool isStart) async {
      final now = DateTime.now();
      final initial = isStart ? (startAt ?? now) : (endAt ?? now);
      final d = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(now.year - 3),
        lastDate: DateTime(now.year + 5),
      );
      if (d == null) return;

      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (t == null) return;

      final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      if (!mounted) return;
      setState(() {
        if (isStart) startAt = dt;
        if (!isStart) endAt = dt;
      });
    }

    // 用 StatefulBuilder 才能在 Dialog 內更新 startAt/endAt label
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(isCreate ? '新增抽獎活動' : '編輯抽獎活動'),
          content: SizedBox(
            width: 820,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: '活動標題 *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '狀態 status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('draft（草稿）')),
                      DropdownMenuItem(value: 'active', child: Text('active（進行中）')),
                      DropdownMenuItem(value: 'ended', child: Text('ended（已結束）')),
                    ],
                    onChanged: (v) => setLocal(() => status = v ?? status),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: prizesCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: '獎項 prizes（每行一個）',
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: '例：\n頭獎：手錶\n二獎：代金券100\n三獎：小禮物',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '預設中獎人數 totalWinners',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          controller: TextEditingController(text: totalWinners.toString()),
                          onChanged: (v) => totalWinners = int.tryParse(v.trim()) ?? totalWinners,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: noteCtrl,
                          decoration: const InputDecoration(
                            labelText: '備註 note（選填）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final initial = startAt ?? now;
                            final d = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: DateTime(now.year - 3),
                              lastDate: DateTime(now.year + 5),
                            );
                            if (d == null) return;
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(initial),
                            );
                            if (t == null) return;
                            setLocal(() => startAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                          },
                          icon: const Icon(Icons.event_available),
                          label: Text(startAt == null ? '設定開始時間' : '開始：${_fmt(startAt)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final initial = endAt ?? now;
                            final d = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: DateTime(now.year - 3),
                              lastDate: DateTime(now.year + 5),
                            );
                            if (d == null) return;
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(initial),
                            );
                            if (t == null) return;
                            setLocal(() => endAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                          },
                          icon: const Icon(Icons.event_busy),
                          label: Text(endAt == null ? '設定結束時間' : '結束：${_fmt(endAt)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '提示：抽獎會從 lottery_entries 中排除已在 lottery_winners 的 userId，避免重複得獎。',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('儲存')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final title = titleCtrl.text.trim();
      if (title.isEmpty) {
        _snack('活動標題不可為空');
        titleCtrl.dispose();
        noteCtrl.dispose();
        prizesCtrl.dispose();
        return;
      }

      final prizes = prizesCtrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (prizes.isEmpty) {
        _snack('至少要填 1 個獎項（prizes）');
        titleCtrl.dispose();
        noteCtrl.dispose();
        prizesCtrl.dispose();
        return;
      }

      if (totalWinners <= 0) totalWinners = 1;

      await _setBusy(true, label: '儲存中...');
      try {
        final now = FieldValue.serverTimestamp();

        final payload = <String, dynamic>{
          'vendorId': _vid,
          'vendorName': (widget.vendorName ?? '').trim(),
          'title': title,
          'status': status,
          'prizes': prizes,
          'totalWinners': totalWinners,
          'note': noteCtrl.text.trim(),
          'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
          'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
          'updatedAt': now,
        };

        if (isCreate) {
          final ref = _lcol.doc();
          await ref.set(
            <String, dynamic>{
              ...payload,
              'createdAt': now,
            },
            SetOptions(merge: true),
          );
          _selectedLotteryId = ref.id;
          _snack('已新增活動：${ref.id}');
        } else {
          final id = lotteryId!.trim();
          await _lcol.doc(id).set(payload, SetOptions(merge: true));
          _snack('已更新：$id');
        }
      } catch (e) {
        _snack('儲存失敗：$e');
      } finally {
        await _setBusy(false);
      }
    }

    titleCtrl.dispose();
    noteCtrl.dispose();
    prizesCtrl.dispose();
  }

  // -------------------------
  // Lottery draw
  // -------------------------
  Future<void> _runDraw({
    required String lotteryId,
    required Map<String, dynamic> lottery,
  }) async {
    final id = lotteryId.trim();
    if (id.isEmpty) return;

    final prizes = (lottery['prizes'] is List) ? (lottery['prizes'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList() : <String>[];
    if (prizes.isEmpty) {
      _snack('此活動沒有 prizes，無法抽獎');
      return;
    }

    final defaultWinners = _toInt(lottery['totalWinners'], def: 1);
    final ctrl = TextEditingController(text: defaultWinners.toString());

    bool preventDuplicateWinners = true;
    bool autoEndAfterDraw = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('立即抽獎'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoRow(label: 'lotteryId', value: id, onCopy: () => _copy(id, done: '已複製 lotteryId')),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '要抽出幾位？',
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: '例如：1、3、5',
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('排除已得獎者（避免重複得獎）'),
                value: preventDuplicateWinners,
                onChanged: (v) => preventDuplicateWinners = v,
              ),
              SwitchListTile(
                title: const Text('抽完後自動將活動狀態設為 ended'),
                value: autoEndAfterDraw,
                onChanged: (v) => autoEndAfterDraw = v,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '獎項指派：會依序取 prizes[0], prizes[1]... 超過獎項數時會循環使用。',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('開始抽獎')),
        ],
      ),
    );

    if (ok != true) {
      ctrl.dispose();
      return;
    }

    final n = int.tryParse(ctrl.text.trim()) ?? defaultWinners;
    ctrl.dispose();

    if (n <= 0) {
      _snack('抽獎人數需大於 0');
      return;
    }

    await _setBusy(true, label: '抽獎中...');
    try {
      // 1) 讀 entry（最多 maxEntriesRead）與 winners
      final entriesSnap = await _ecol.where('lotteryId', isEqualTo: id).orderBy('entryAt', descending: true).limit(widget.maxEntriesRead).get();
      final winnersSnap = await _wcol.where('lotteryId', isEqualTo: id).limit(2000).get();

      final winnersUserIds = <String>{};
      for (final w in winnersSnap.docs) {
        final d = w.data();
        final uid = (d['userId'] ?? '').toString().trim();
        if (uid.isNotEmpty) winnersUserIds.add(uid);
      }

      final entries = <_EntryRow>[];
      for (final e in entriesSnap.docs) {
        final d = e.data();
        final uid = _s(d['userId']);
        if (uid.isEmpty) continue;

        if (preventDuplicateWinners && winnersUserIds.contains(uid)) {
          continue; // 排除已得獎
        }
        entries.add(_EntryRow(id: e.id, data: d));
      }

      if (entries.isEmpty) {
        _snack('沒有可抽的參加者（可能都已得獎或沒有 entries）');
        return;
      }

      // 2) 隨機抽樣
      final rng = Random();
      entries.shuffle(rng);

      final pickCount = min(n, entries.length);
      final picks = entries.take(pickCount).toList();

      // 3) 批次寫入 winners
      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();

      for (int i = 0; i < picks.length; i++) {
        final e = picks[i];
        final d = e.data;

        final uid = _s(d['userId']);
        final userName = _s(d['userName']);
        final userEmail = _s(d['userEmail']);
        final prize = prizes[i % prizes.length];

        final ref = _wcol.doc();
        batch.set(
          ref,
          <String, dynamic>{
            'lotteryId': id,
            'vendorId': _vid,
            'userId': uid,
            'userName': userName,
            'userEmail': userEmail,
            'prize': prize,
            'wonAt': now,
          },
          SetOptions(merge: true),
        );
      }

      if (autoEndAfterDraw) {
        batch.set(
          _lcol.doc(id),
          <String, dynamic>{
            'status': 'ended',
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
      } else {
        // 也更新一下 updatedAt
        batch.set(
          _lcol.doc(id),
          <String, dynamic>{
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      _snack('抽獎完成：抽出 $pickCount 位');
    } catch (e) {
      _snack('抽獎失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  // -------------------------
  // Export winners CSV
  // -------------------------
  Future<void> _exportWinnersCsv(String lotteryId) async {
    final id = lotteryId.trim();
    if (id.isEmpty) return;

    await _setBusy(true, label: '匯出中...');
    try {
      final snap = await _wcol.where('lotteryId', isEqualTo: id).orderBy('wonAt', descending: true).limit(5000).get();

      final headers = <String>[
        'winnerId',
        'lotteryId',
        'userId',
        'userName',
        'userEmail',
        'prize',
        'wonAt',
      ];

      final buffer = StringBuffer()..writeln(headers.join(','));

      for (final d in snap.docs) {
        final m = d.data();
        final wonAt = (m['wonAt'] is Timestamp) ? (m['wonAt'] as Timestamp).toDate().toIso8601String() : '';

        final row = <String>[
          d.id,
          _s(m['lotteryId']),
          _s(m['userId']),
          _s(m['userName']),
          _s(m['userEmail']),
          _s(m['prize']),
          wonAt,
        ].map((e) => e.replaceAll(',', '，')).toList();

        buffer.writeln(row.join(','));
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      _snack('已複製中獎名單 CSV 到剪貼簿');
    } catch (e) {
      _snack('匯出失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  Future<void> _clearWinners(String lotteryId) async {
    final id = lotteryId.trim();
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清除中獎名單'),
        content: const Text('確定要清除這個活動的所有中獎者嗎？（不可復原）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清除')),
        ],
      ),
    );

    if (ok != true) return;

    await _setBusy(true, label: '清除中獎名單中...');
    try {
      final snap = await _wcol.where('lotteryId', isEqualTo: id).limit(5000).get();
      if (snap.docs.isEmpty) {
        _snack('沒有中獎名單可清除');
        return;
      }

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      _snack('已清除中獎名單');
    } catch (e) {
      _snack('清除失敗：$e');
    } finally {
      await _setBusy(false);
    }
  }

  // -------------------------
  // UI: detail dialog
  // -------------------------
  Future<void> _openLotteryDetailDialog({
    required String lotteryId,
    required Map<String, dynamic> lottery,
  }) async {
    final id = lotteryId.trim();
    if (id.isEmpty) return;

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 980,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _LotteryDetail(
              lotteryId: id,
              lottery: lottery,
              entriesStream: _streamEntries(id),
              winnersStream: _streamWinners(id),
              fmt: _fmt,
              toDate: _toDate,
              onCopy: _copy,
              onRunDraw: () => _runDraw(lotteryId: id, lottery: lottery),
              onExportWinners: () => _exportWinnersCsv(id),
              onClearWinners: () => _clearWinners(id),
              onEdit: () {
                Navigator.pop(context);
                _openEditLotteryDialog(lotteryId: id, data: lottery);
              },
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    if (_vid.isEmpty) return const Scaffold(body: Center(child: Text('vendorId 不可為空')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('抽獎活動管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '新增活動',
            onPressed: _busy ? null : () => _openEditLotteryDialog(),
            icon: const Icon(Icons.add_box_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _streamLotteries(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('讀取失敗：${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final rows = snap.data!.docs
                  .map((d) => _LotteryRow(id: d.id, data: d.data()))
                  .where(_matchLottery)
                  .toList();

              final ids = rows.map((e) => e.id).toSet();
              if (_selectedLotteryId != null && !ids.contains(_selectedLotteryId)) _selectedLotteryId = null;

              return Column(
                children: [
                  _LotteryFilters(
                    searchCtrl: _searchCtrl,
                    status: _status,
                    countLabel: '${rows.length} 筆',
                    onQueryChanged: (v) => setState(() => _q = v),
                    onClearQuery: () {
                      _searchCtrl.clear();
                      setState(() => _q = '');
                    },
                    onStatusChanged: (v) => setState(() => _status = v),
                    onAdd: _busy ? null : () => _openEditLotteryDialog(),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth >= 980;

                        final list = ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = rows[i];
                            final d = r.data;

                            final title = _s(d['title']).isEmpty ? '（未命名活動）' : _s(d['title']);
                            final status = _s(d['status']).isEmpty ? 'draft' : _s(d['status']);
                            final updatedAt = _toDate(d['updatedAt'] ?? d['createdAt']);
                            final startAt = _toDate(d['startAt']);
                            final endAt = _toDate(d['endAt']);

                            final prizes = (d['prizes'] is List) ? (d['prizes'] as List).length : 0;
                            final winnersN = _toInt(d['totalWinners'], def: 0);

                            return ListTile(
                              selected: r.id == _selectedLotteryId,
                              leading: const Icon(Icons.emoji_events_outlined),
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
                                  _Pill(label: status, color: _statusColor(context, status)),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 4,
                                      children: [
                                        Text('ID：${r.id}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        Text('獎項：$prizes', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        if (winnersN > 0)
                                          Text('預設中獎：$winnersN', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 4,
                                      children: [
                                        Text('更新：${_fmt(updatedAt)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        if (startAt != null)
                                          Text('開始：${_fmt(startAt)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                        if (endAt != null)
                                          Text('結束：${_fmt(endAt)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: _busy
                                    ? null
                                    : (v) async {
                                        if (v == 'copy') {
                                          await _copy(r.id, done: '已複製 lotteryId');
                                        } else if (v == 'detail') {
                                          setState(() => _selectedLotteryId = r.id);
                                          await _openLotteryDetailDialog(lotteryId: r.id, lottery: d);
                                        } else if (v == 'draw') {
                                          await _runDraw(lotteryId: r.id, lottery: d);
                                        } else if (v == 'edit') {
                                          await _openEditLotteryDialog(lotteryId: r.id, data: d);
                                        } else if (v == 'draft') {
                                          await _toggleStatus(r.id, 'draft');
                                        } else if (v == 'active') {
                                          await _toggleStatus(r.id, 'active');
                                        } else if (v == 'ended') {
                                          await _toggleStatus(r.id, 'ended');
                                        } else if (v == 'delete') {
                                          await _deleteLottery(r.id);
                                        }
                                      },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'detail', child: Text('查看詳情')),
                                  PopupMenuItem(value: 'draw', child: Text('立即抽獎')),
                                  PopupMenuDivider(),
                                  PopupMenuItem(value: 'copy', child: Text('複製 lotteryId')),
                                  PopupMenuItem(value: 'edit', child: Text('編輯')),
                                  PopupMenuDivider(),
                                  PopupMenuItem(value: 'draft', child: Text('設為 draft')),
                                  PopupMenuItem(value: 'active', child: Text('設為 active')),
                                  PopupMenuItem(value: 'ended', child: Text('設為 ended')),
                                  PopupMenuDivider(),
                                  PopupMenuItem(value: 'delete', child: Text('刪除')),
                                ],
                              ),
                              onTap: () async {
                                setState(() => _selectedLotteryId = r.id);
                                if (!wide) {
                                  await _openLotteryDetailDialog(lotteryId: r.id, lottery: d);
                                }
                              },
                            );
                          },
                        );

                        if (!wide) return list;

                        final selected = _selectedLotteryId == null
                            ? null
                            : rows.where((e) => e.id == _selectedLotteryId).cast<_LotteryRow?>().firstOrNull;

                        return Row(
                          children: [
                            Expanded(flex: 3, child: list),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 2,
                              child: selected == null
                                  ? Center(
                                      child: Text(
                                        '請選擇一個活動',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                    )
                                  : _LotterySidePanel(
                                      lotteryId: selected.id,
                                      lottery: selected.data,
                                      fmt: _fmt,
                                      toDate: _toDate,
                                      onCopy: _copy,
                                      onDetail: () => _openLotteryDetailDialog(lotteryId: selected.id, lottery: selected.data),
                                      onDraw: () => _runDraw(lotteryId: selected.id, lottery: selected.data),
                                      onEdit: () => _openEditLotteryDialog(lotteryId: selected.id, data: selected.data),
                                      onExportWinners: () => _exportWinnersCsv(selected.id),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          if (_busy)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BusyBar(label: _busyLabel.isEmpty ? '處理中...' : _busyLabel),
            ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, String s) {
    final cs = Theme.of(context).colorScheme;
    final v = s.trim().toLowerCase();
    if (v == 'active') return cs.primary;
    if (v == 'ended') return cs.secondary;
    return cs.outline; // draft/others
  }
}

// ------------------------------------------------------------
// Models / Extensions
// ------------------------------------------------------------
class _LotteryRow {
  final String id;
  final Map<String, dynamic> data;
  _LotteryRow({required this.id, required this.data});
}

class _EntryRow {
  final String id;
  final Map<String, dynamic> data;
  _EntryRow({required this.id, required this.data});
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ------------------------------------------------------------
// Filters UI
// ------------------------------------------------------------
class _LotteryFilters extends StatelessWidget {
  const _LotteryFilters({
    required this.searchCtrl,
    required this.status,
    required this.countLabel,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onStatusChanged,
    required this.onAdd,
  });

  final TextEditingController searchCtrl;
  final String? status;
  final String countLabel;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String?> onStatusChanged;

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final search = TextField(
      controller: searchCtrl,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        hintText: '搜尋：標題 / 獎項 / 備註 / ID',
        suffixIcon: searchCtrl.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: '清除',
                onPressed: onClearQuery,
                icon: const Icon(Icons.clear),
              ),
      ),
      onChanged: onQueryChanged,
    );

    final dd = DropdownButtonFormField<String?>(
      value: status,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        labelText: '狀態',
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('全部')),
        DropdownMenuItem(value: 'draft', child: Text('draft')),
        DropdownMenuItem(value: 'active', child: Text('active')),
        DropdownMenuItem(value: 'ended', child: Text('ended')),
      ],
      onChanged: onStatusChanged,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 980;

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: dd),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('新增'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('共 $countLabel', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              SizedBox(width: 220, child: dd),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('新增活動'),
              ),
              const SizedBox(width: 10),
              Text('共 $countLabel', style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Side Panel
// ------------------------------------------------------------
class _LotterySidePanel extends StatelessWidget {
  const _LotterySidePanel({
    required this.lotteryId,
    required this.lottery,
    required this.fmt,
    required this.toDate,
    required this.onCopy,
    required this.onDetail,
    required this.onDraw,
    required this.onEdit,
    required this.onExportWinners,
  });

  final String lotteryId;
  final Map<String, dynamic> lottery;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  final Future<void> Function(String text, {String done}) onCopy;

  final Future<void> Function() onDetail;
  final Future<void> Function() onDraw;
  final Future<void> Function() onEdit;
  final Future<void> Function() onExportWinners;

  String _s(dynamic v) => (v ?? '').toString().trim();
  int _toInt(dynamic v, {int def = 0}) => int.tryParse(_s(v)) ?? def;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final title = _s(lottery['title']).isEmpty ? '（未命名活動）' : _s(lottery['title']);
    final status = _s(lottery['status']).isEmpty ? 'draft' : _s(lottery['status']);
    final prizes = (lottery['prizes'] is List) ? (lottery['prizes'] as List).length : 0;
    final winnersN = _toInt(lottery['totalWinners'], def: 0);

    final updatedAt = toDate(lottery['updatedAt'] ?? lottery['createdAt']);
    final startAt = toDate(lottery['startAt']);
    final endAt = toDate(lottery['endAt']);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: status, color: cs.primary),
              _MiniTag(label: '獎項：$prizes'),
              if (winnersN > 0) _MiniTag(label: '預設中獎：$winnersN'),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'lotteryId', value: lotteryId, onCopy: () => onCopy(lotteryId, done: '已複製 lotteryId')),
          const SizedBox(height: 6),
          _InfoRow(label: 'updated', value: fmt(updatedAt)),
          const SizedBox(height: 6),
          _InfoRow(label: 'start', value: fmt(startAt)),
          const SizedBox(height: 6),
          _InfoRow(label: 'end', value: fmt(endAt)),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDraw,
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('立即抽獎'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDetail,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('詳情'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('編輯'),
              ),
              OutlinedButton.icon(
                onPressed: onExportWinners,
                icon: const Icon(Icons.download_outlined),
                label: const Text('匯出中獎CSV'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('備註', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline.withOpacity(0.18)),
              ),
              child: SingleChildScrollView(child: Text(_s(lottery['note']).isEmpty ? '（無備註）' : _s(lottery['note']))),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Detail Dialog Widget
// ------------------------------------------------------------
class _LotteryDetail extends StatelessWidget {
  const _LotteryDetail({
    required this.lotteryId,
    required this.lottery,
    required this.entriesStream,
    required this.winnersStream,
    required this.fmt,
    required this.toDate,
    required this.onCopy,
    required this.onRunDraw,
    required this.onExportWinners,
    required this.onClearWinners,
    required this.onEdit,
  });

  final String lotteryId;
  final Map<String, dynamic> lottery;

  final Stream<QuerySnapshot<Map<String, dynamic>>> entriesStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> winnersStream;

  final String Function(DateTime?) fmt;
  final DateTime? Function(dynamic) toDate;

  final Future<void> Function(String text, {String done}) onCopy;

  final Future<void> Function() onRunDraw;
  final Future<void> Function() onExportWinners;
  final Future<void> Function() onClearWinners;
  final VoidCallback onEdit;

  String _s(dynamic v) => (v ?? '').toString().trim();
  bool _isTrue(dynamic v) => v == true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final title = _s(lottery['title']).isEmpty ? '（未命名活動）' : _s(lottery['title']);
    final status = _s(lottery['status']).isEmpty ? 'draft' : _s(lottery['status']);

    final prizes = (lottery['prizes'] is List)
        ? (lottery['prizes'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    final startAt = toDate(lottery['startAt']);
    final endAt = toDate(lottery['endAt']);
    final updatedAt = toDate(lottery['updatedAt'] ?? lottery['createdAt']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            IconButton(
              tooltip: '複製 lotteryId',
              onPressed: () => onCopy(lotteryId, done: '已複製 lotteryId'),
              icon: const Icon(Icons.copy),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('編輯'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(label: status, color: cs.primary),
            _MiniTag(label: '更新：${fmt(updatedAt)}'),
            if (startAt != null) _MiniTag(label: '開始：${fmt(startAt)}'),
            if (endAt != null) _MiniTag(label: '結束：${fmt(endAt)}'),
          ],
        ),
        const Divider(height: 22),
        Text('獎項', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withOpacity(0.18)),
          ),
          child: Text(prizes.isEmpty ? '（無獎項）' : prizes.map((e) => '• $e').join('\n')),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onRunDraw,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('立即抽獎'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onExportWinners,
                icon: const Icon(Icons.download_outlined),
                label: const Text('匯出中獎CSV'),
              ),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: onClearWinners,
              icon: const Icon(Icons.delete_outline),
              label: const Text('清除中獎名單'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('參加名單 entries', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: entriesStream,
                          builder: (context, snap) {
                            if (snap.hasError) return Center(child: Text('讀取 entries 失敗：${snap.error}'));
                            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                            final docs = snap.data!.docs;
                            if (docs.isEmpty) {
                              return Center(child: Text('尚無參加者', style: TextStyle(color: cs.onSurfaceVariant)));
                            }

                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final doc = docs[i];
                                final d = doc.data();
                                final uid = _s(d['userId']);
                                final name = _s(d['userName']);
                                final email = _s(d['userEmail']);
                                final t = toDate(d['entryAt']);

                                return ListTile(
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(name.isNotEmpty ? name : (email.isNotEmpty ? email : (uid.isNotEmpty ? uid : doc.id)),
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Wrap(
                                    spacing: 10,
                                    runSpacing: 4,
                                    children: [
                                      if (uid.isNotEmpty) Text('uid：$uid', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                      if (email.isNotEmpty) Text(email, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                      Text('entry：${fmt(t)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
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
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Card(
                  elevation: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('中獎名單 winners', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: winnersStream,
                          builder: (context, snap) {
                            if (snap.hasError) return Center(child: Text('讀取 winners 失敗：${snap.error}'));
                            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                            final docs = snap.data!.docs;
                            if (docs.isEmpty) {
                              return Center(child: Text('尚無中獎者', style: TextStyle(color: cs.onSurfaceVariant)));
                            }

                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final doc = docs[i];
                                final d = doc.data();
                                final uid = _s(d['userId']);
                                final name = _s(d['userName']);
                                final email = _s(d['userEmail']);
                                final prize = _s(d['prize']);
                                final t = toDate(d['wonAt']);

                                return ListTile(
                                  leading: const Icon(Icons.emoji_events_outlined),
                                  title: Text(
                                    prize.isEmpty ? '（未填獎項）' : prize,
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  subtitle: Wrap(
                                    spacing: 10,
                                    runSpacing: 4,
                                    children: [
                                      Text(name.isNotEmpty ? name : (email.isNotEmpty ? email : (uid.isNotEmpty ? uid : doc.id)),
                                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                      if (uid.isNotEmpty) Text('uid：$uid', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                      Text('won：${fmt(t)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'copy_uid' && uid.isNotEmpty) {
                                        await onCopy(uid, done: '已複製 uid');
                                      } else if (v == 'copy_email' && email.isNotEmpty) {
                                        await onCopy(email, done: '已複製 email');
                                      } else if (v == 'copy_json') {
                                        await onCopy(jsonEncode(d), done: '已複製 winner JSON');
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'copy_uid', child: Text('複製 uid')),
                                      PopupMenuItem(value: 'copy_email', child: Text('複製 email')),
                                      PopupMenuDivider(),
                                      PopupMenuItem(value: 'copy_json', child: Text('複製 JSON')),
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
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Shared Widgets
// ------------------------------------------------------------
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.onCopy});
  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 90, child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
        Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w800))),
        if (onCopy != null)
          IconButton(
            tooltip: '複製',
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 18),
          ),
      ],
    );
  }
}

class _BusyBar extends StatelessWidget {
  const _BusyBar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }
}

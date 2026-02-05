// lib/pages/admin_prizes_page.dart
//
// ✅ AdminPrizesPage（最終完整版｜中獎名單/派獎管理 + 抽出中獎者 + CSV + 批次狀態）
// ------------------------------------------------------------
// winners: lotteries/{lotteryId}/winners/{winnerId}
// - uid: String
// - name: String?
// - email: String?
// - prize: String
// - status: 'pending' | 'shipped' | 'done' | 'void'
// - createdAt / updatedAt: Timestamp
//
// entries: lotteries/{lotteryId}/entries/{entryId}
// - uid: String
// - name: String?
// - email: String?
// - orderId: String?（選填）
// - createdAt: Timestamp
//
// 備註：
// - 若 entries 不存在，抽獎會提示「尚無抽獎名單」
// - 抽獎採隨機 Fisher-Yates shuffle
// - 批次更新狀態/刪除
// ------------------------------------------------------------

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

class AdminPrizesPage extends StatefulWidget {
  final String lotteryId;
  final String title;
  const AdminPrizesPage({super.key, required this.lotteryId, required this.title});

  @override
  State<AdminPrizesPage> createState() => _AdminPrizesPageState();
}

class _AdminPrizesPageState extends State<AdminPrizesPage> {
  final _db = FirebaseFirestore.instance;

  // filters
  final _searchCtrl = TextEditingController();
  String _q = '';
  String _status = '全部'; // 全部/pending/shipped/done/void

  // pagination
  static const int _pageSize = 30;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loading = false;

  // selection
  final Set<String> _selectedIds = {};

  // cache
  final List<_WinnerRow> _rows = [];

  // busy overlay
  bool _busy = false;
  String _busyLabel = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _setBusy(bool v, {String label = ''}) {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyLabel = label;
    });
  }

  String _s(dynamic v) => (v ?? '').toString().trim();
  DateTime? _toDate(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  CollectionReference<Map<String, dynamic>> get _winnersRef =>
      _db.collection('lotteries').doc(widget.lotteryId).collection('winners');

  CollectionReference<Map<String, dynamic>> get _entriesRef =>
      _db.collection('lotteries').doc(widget.lotteryId).collection('entries');

  DocumentReference<Map<String, dynamic>> get _lotteryRef =>
      _db.collection('lotteries').doc(widget.lotteryId);

  Future<void> _load({bool refresh = false}) async {
    if (_loading || (!_hasMore && !refresh)) return;
    setState(() => _loading = true);

    try {
      if (refresh) {
        _rows.clear();
        _selectedIds.clear();
        _lastDoc = null;
        _hasMore = true;
      }

      Query<Map<String, dynamic>> q = _winnersRef;

      // status filter（避免複合索引：不加 orderBy status；只在同欄位上 where）
      if (_status != '全部') {
        q = q.where('status', isEqualTo: _status);
      }

      // 主排序：createdAt desc（若沒有 createdAt 也不會炸，但建議都有）
      q = q.orderBy('createdAt', descending: true).limit(_pageSize);

      if (_lastDoc != null && !refresh) {
        q = q.startAfterDocument(_lastDoc!);
      }

      final snap = await q.get();
      final docs = snap.docs;

      final list = docs.map((d) {
        final data = d.data();
        return _WinnerRow(
          id: d.id,
          uid: _s(data['uid']),
          name: _s(data['name']),
          email: _s(data['email']),
          prize: _s(data['prize']),
          status: _s(data['status']).isEmpty ? 'pending' : _s(data['status']),
          createdAt: _toDate(data['createdAt']),
          updatedAt: _toDate(data['updatedAt']),
        );
      }).toList();

      // client-side search
      final qtext = _q.trim().toLowerCase();
      final filtered = qtext.isEmpty
          ? list
          : list.where((r) {
              final s = '${r.uid} ${r.name} ${r.email} ${r.prize}'.toLowerCase();
              return s.contains(qtext);
            }).toList();

      if (!mounted) return;
      setState(() {
        _rows.addAll(filtered);
        _hasMore = docs.length == _pageSize;
        _lastDoc = docs.isNotEmpty ? docs.last : _lastDoc;
      });
    } catch (e) {
      _snack('載入中獎名單失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return '待派獎';
      case 'shipped':
        return '已寄出';
      case 'done':
        return '已完成';
      case 'void':
        return '作廢';
      default:
        return s;
    }
  }

  Future<void> _updateStatus(String winnerId, String toStatus) async {
    _setBusy(true, label: '更新狀態中...');
    try {
      await _winnersRef.doc(winnerId).set(
        {'status': toStatus, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      _snack('已更新狀態：${_statusLabel(toStatus)}');
      await _load(refresh: true);
    } catch (e) {
      _snack('更新失敗：$e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _batchUpdateStatus(String toStatus) async {
    if (_selectedIds.isEmpty) return;

    _setBusy(true, label: '批次更新狀態中...');
    try {
      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();
      for (final id in _selectedIds) {
        batch.set(
          _winnersRef.doc(id),
          {'status': toStatus, 'updatedAt': now},
          SetOptions(merge: true),
        );
      }
      await batch.commit();

      _snack('已批次更新 ${_selectedIds.length} 筆狀態 → ${_statusLabel(toStatus)}');
      setState(() => _selectedIds.clear());
      await _load(refresh: true);
    } catch (e) {
      _snack('批次更新失敗：$e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定刪除 ${_selectedIds.length} 筆中獎資料？此動作無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;

    _setBusy(true, label: '批次刪除中...');
    try {
      final batch = _db.batch();
      for (final id in _selectedIds) {
        batch.delete(_winnersRef.doc(id));
      }
      await batch.commit();

      _snack('已刪除 ${_selectedIds.length} 筆');
      setState(() => _selectedIds.clear());
      await _syncWinnersCount();
      await _load(refresh: true);
    } catch (e) {
      _snack('刪除失敗：$e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _exportCSV() async {
    if (_rows.isEmpty) {
      _snack('沒有資料可匯出');
      return;
    }

    final table = <List<dynamic>>[
      ['winnerId', 'uid', 'name', 'email', 'prize', 'status', 'createdAt', 'updatedAt'],
      ..._rows.map((r) => [
            r.id,
            r.uid,
            r.name,
            r.email,
            r.prize,
            r.status,
            r.createdAt?.toIso8601String() ?? '',
            r.updatedAt?.toIso8601String() ?? '',
          ]),
    ];

    final csv = const ListToCsvConverter().convert(table);
    final bytes = Uint8List.fromList(utf8.encode(csv));

    await FileSaver.instance.saveFile(
      name: 'winners_${widget.lotteryId}_${DateTime.now().millisecondsSinceEpoch}',
      bytes: bytes,
      ext: 'csv',
      mimeType: MimeType.csv,
    );

    _snack('已匯出 ${table.length - 1} 筆中獎資料');
  }

  Future<void> _syncWinnersCount() async {
    try {
      final agg = await _winnersRef.count().get();
      final count = agg.count;
      await _lotteryRef.set(
        {'winnersCount': count, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {
      // best effort
    }
  }

  void _shuffle<T>(List<T> list) {
    final rnd = Random();
    for (int i = list.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  Future<void> _drawWinners() async {
    // 先讀 lottery 設定
    _setBusy(true, label: '讀取抽獎設定...');
    try {
      final lotSnap = await _lotteryRef.get();
      if (!lotSnap.exists) {
        _snack('找不到抽獎活動');
        return;
      }
      final lot = lotSnap.data() ?? <String, dynamic>{};

      final totalPrizesRaw = lot['totalPrizes'];
      final totalPrizes = (totalPrizesRaw is int) ? totalPrizesRaw : int.tryParse('$totalPrizesRaw') ?? 0;
      final labels = (lot['prizeLabels'] is List)
          ? (lot['prizeLabels'] as List).map((e) => _s(e)).where((e) => e.isNotEmpty).toList()
          : <String>[];

      // 先查 winners 現況（避免重抽）
      final winnersAgg = await _winnersRef.count().get();
      final existingWinners = winnersAgg.count;

      _setBusy(false);

      final pickedCount = await showDialog<int>(
        context: context,
        builder: (_) {
          final ctrl = TextEditingController(text: '${max(1, totalPrizes - existingWinners)}');
          bool overwrite = false;

          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('抽出中獎者'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (totalPrizes > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('獎項上限：$totalPrizes（目前已產生：$existingWinners）'),
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '本次抽出人數',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: overwrite,
                        onChanged: (v) => setState(() => overwrite = v == true),
                        title: const Text('允許覆寫（先清空全部 winners 再重抽）'),
                        subtitle: const Text('若你要重新抽獎才勾選，否則會在現有名單後追加。'),
                      ),
                      const SizedBox(height: 8),
                      if (labels.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('獎項清單：\n${labels.take(8).join('\n')}${labels.length > 8 ? '\n...' : ''}'),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                  FilledButton(
                    onPressed: () {
                      final n = int.tryParse(ctrl.text.trim()) ?? 0;
                      if (n <= 0) return;
                      // 傳回正數：表示追加；傳回負數：表示覆寫
                      Navigator.pop(context, overwrite ? -n : n);
                    },
                    child: const Text('開始抽獎'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (pickedCount == null) return;

      final overwrite = pickedCount < 0;
      int count = pickedCount.abs();

      // 控制上限：若有 totalPrizes，就不讓超過剩餘名額（除非覆寫）
      if (totalPrizes > 0 && !overwrite) {
        final remain = max(0, totalPrizes - existingWinners);
        if (remain <= 0) {
          _snack('已達獎項上限（$totalPrizes），無法再新增中獎者');
          return;
        }
        if (count > remain) count = remain;
      }

      _setBusy(true, label: overwrite ? '清空舊名單中...' : '準備抽獎中...');

      // 覆寫：先清空 winners
      if (overwrite) {
        // 分批刪除（最多刪 1500，通常足夠；你要更大我再加分頁刪除）
        final snap = await _winnersRef.orderBy('createdAt', descending: true).limit(1500).get();
        if (snap.docs.isNotEmpty) {
          final batch = _db.batch();
          for (final d in snap.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
        }
      }

      // 讀 entries（抽獎母體）
      _setBusy(true, label: '讀取抽獎名單 entries...');
      final entriesSnap = await _entriesRef.orderBy('createdAt', descending: true).limit(5000).get();
      if (entriesSnap.docs.isEmpty) {
        _snack('尚無抽獎名單（entries 為空），請先寫入 lotteries/{id}/entries');
        return;
      }

      final entries = entriesSnap.docs.map((d) {
        final data = d.data();
        return _EntryRow(
          uid: _s(data['uid']),
          name: _s(data['name']),
          email: _s(data['email']),
        );
      }).where((e) => e.uid.isNotEmpty).toList();

      if (entries.isEmpty) {
        _snack('entries 內缺少 uid，無法抽獎');
        return;
      }

      // 避免同一 uid 重複中獎（常見需求）：先去重 uid（保留第一筆）
      final seenUid = <String>{};
      final uniqueEntries = <_EntryRow>[];
      for (final e in entries) {
        if (seenUid.add(e.uid)) uniqueEntries.add(e);
      }

      _shuffle(uniqueEntries);

      if (count > uniqueEntries.length) count = uniqueEntries.length;

      _setBusy(true, label: '寫入 winners（$count 人）...');

      final now = FieldValue.serverTimestamp();
      const batchLimit = 450;

      for (int i = 0; i < count; i += batchLimit) {
        final end = min(i + batchLimit, count);
        final chunk = uniqueEntries.sublist(i, end);

        final batch = _db.batch();
        for (int k = 0; k < chunk.length; k++) {
          final e = chunk[k];
          final idx = i + k; // 全局序號
          final prize = (labels.isNotEmpty && idx < labels.length)
              ? labels[idx]
              : (labels.isNotEmpty ? labels[idx % labels.length] : '獎項 #${idx + 1}');

          final ref = _winnersRef.doc();
          batch.set(ref, {
            'uid': e.uid,
            'name': e.name,
            'email': e.email,
            'prize': prize,
            'status': 'pending',
            'createdAt': now,
            'updatedAt': now,
          });
        }

        await batch.commit();
      }

      await _syncWinnersCount();
      _snack('抽獎完成：已產生 $count 位中獎者');
      await _load(refresh: true);
    } catch (e) {
      _snack('抽獎失敗：$e');
    } finally {
      _setBusy(false);
    }
  }

  void _showBatchMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.hourglass_bottom_outlined),
              title: const Text('批次設為：待派獎'),
              onTap: () {
                Navigator.pop(context);
                _batchUpdateStatus('pending');
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('批次設為：已寄出'),
              onTap: () {
                Navigator.pop(context);
                _batchUpdateStatus('shipped');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('批次設為：已完成'),
              onTap: () {
                Navigator.pop(context);
                _batchUpdateStatus('done');
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('批次設為：作廢'),
              onTap: () {
                Navigator.pop(context);
                _batchUpdateStatus('void');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('批次刪除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _batchDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusItems = const [
      '全部',
      'pending',
      'shipped',
      'done',
      'void',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('派獎管理｜${widget.title}'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(refresh: true),
          ),
          IconButton(
            tooltip: '匯出 CSV',
            icon: const Icon(Icons.download_outlined),
            onPressed: _exportCSV,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: '搜尋 uid / 名稱 / email / 獎項',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          setState(() => _q = v);
                          _load(refresh: true);
                        },
                      ),
                    ),
                    DropdownButton<String>(
                      value: statusItems.contains(_status) ? _status : '全部',
                      items: statusItems
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s == '全部' ? '全部狀態' : _statusLabel(s)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _status = v ?? '全部');
                        _load(refresh: true);
                      },
                    ),
                    Text('共 ${_rows.length} 筆', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _rows.isEmpty
                    ? Center(
                        child: Text(
                          _loading ? '載入中...' : '尚無中獎名單（可按右下角「抽獎」產生）',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _rows.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _rows.length) {
                            if (!_loading) _load();
                            return const Padding(
                              padding: EdgeInsets.all(14),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final r = _rows[i];
                          final selected = _selectedIds.contains(r.id);

                          return ListTile(
                            leading: Checkbox(
                              value: selected,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedIds.add(r.id);
                                  } else {
                                    _selectedIds.remove(r.id);
                                  }
                                });
                              },
                            ),
                            title: Text(
                              r.prize.isEmpty ? '(未設定獎項)' : r.prize,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(
                              [
                                if (r.name.isNotEmpty) r.name,
                                if (r.email.isNotEmpty) r.email,
                                if (r.uid.isNotEmpty) 'uid:${r.uid}',
                                '狀態：${_statusLabel(r.status)}',
                              ].join(' · '),
                            ),
                            isThreeLine: false,
                            trailing: DropdownButton<String>(
                              value: statusItems.contains(r.status) ? r.status : 'pending',
                              items: const [
                                DropdownMenuItem(value: 'pending', child: Text('待派獎')),
                                DropdownMenuItem(value: 'shipped', child: Text('已寄出')),
                                DropdownMenuItem(value: 'done', child: Text('已完成')),
                                DropdownMenuItem(value: 'void', child: Text('作廢')),
                              ],
                              onChanged: (v) {
                                final next = (v ?? 'pending').trim();
                                _updateStatus(r.id, next);
                              },
                            ),
                            tileColor: selected ? Colors.blue.withOpacity(0.08) : null,
                          );
                        },
                      ),
              ),
            ],
          ),

          if (_busy)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                elevation: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _busyLabel.isEmpty ? '處理中...' : _busyLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.edit_note),
              label: Text('批次操作 (${_selectedIds.length})'),
              onPressed: _showBatchMenu,
            )
          : FloatingActionButton.extended(
              icon: const Icon(Icons.casino_outlined),
              label: const Text('抽獎'),
              onPressed: _drawWinners,
            ),
    );
  }
}

class _WinnerRow {
  final String id;
  final String uid;
  final String name;
  final String email;
  final String prize;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  _WinnerRow({
    required this.id,
    required this.uid,
    required this.name,
    required this.email,
    required this.prize,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
}

class _EntryRow {
  final String uid;
  final String name;
  final String email;

  _EntryRow({
    required this.uid,
    required this.name,
    required this.email,
  });
}

// lib/pages/admin/orders/admin_orders_batch_ops_page.dart
//
// ✅ AdminOrdersBatchOpsPage（訂單批次操作｜完整版｜可編譯）
// ------------------------------------------------------------
// - 批次選取訂單（依查詢結果）
// - 批次更新：status
// - 批次補寫：adminNote / trackingNo
// - ✅ FIX: control_flow_in_finally（本檔案完全不使用 finally）
//
// 建議路由：
// '/admin_orders_batch_ops': (_) => const AdminOrdersBatchOpsPage(),
//

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ FIX: withOpacity deprecated → withValues(alpha: 0~1)
Color _withOpacity(Color c, double opacity01) {
  final o = opacity01.clamp(0.0, 1.0).toDouble();
  return c.withValues(alpha: o);
}

class AdminOrdersBatchOpsPage extends StatefulWidget {
  const AdminOrdersBatchOpsPage({super.key});

  @override
  State<AdminOrdersBatchOpsPage> createState() =>
      _AdminOrdersBatchOpsPageState();
}

class _AdminOrdersBatchOpsPageState extends State<AdminOrdersBatchOpsPage> {
  final _db = FirebaseFirestore.instance;

  // Filters
  final _keywordCtrl = TextEditingController();
  Timer? _debounce;
  String _keyword = '';

  String _statusFilter = 'all';
  static const _statusFilterOptions = <String>[
    'all',
    'pending',
    'paid',
    'shipping',
    'shipped',
    'done',
    'cancelled',
  ];

  // Selection
  final Set<String> _selected = <String>{};

  // Batch inputs
  String _targetStatus = 'paid';
  static const _statusOptions = <String>[
    'pending',
    'paid',
    'shipping',
    'shipped',
    'done',
    'cancelled',
  ];

  final _noteCtrl = TextEditingController();
  final _trackingCtrl = TextEditingController();

  bool _busy = false;

  final _df = DateFormat('yyyy/MM/dd HH:mm');
  final _mf = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  @override
  void dispose() {
    _debounce?.cancel();
    _keywordCtrl.dispose();
    _noteCtrl.dispose();
    _trackingCtrl.dispose();
    super.dispose();
  }

  void _onKeywordChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      setState(() => _keyword = v.trim().toLowerCase());
    });
  }

  Query<Map<String, dynamic>> _query() {
    var q = _db.collection('orders').orderBy('createdAt', descending: true);
    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }
    return q.limit(300);
  }

  bool _hit(Map<String, dynamic> d, String id) {
    if (_keyword.isEmpty) {
      return true;
    }
    final userId = (d['userId'] ?? '').toString().toLowerCase();
    final status = (d['status'] ?? '').toString().toLowerCase();
    final trackingNo = (d['trackingNo'] ?? '').toString().toLowerCase();
    final note = (d['adminNote'] ?? '').toString().toLowerCase();
    final orderId = id.toLowerCase();

    return userId.contains(_keyword) ||
        status.contains(_keyword) ||
        trackingNo.contains(_keyword) ||
        note.contains(_keyword) ||
        orderId.contains(_keyword);
  }

  DateTime? _toDt(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is Timestamp) {
      return v.toDate();
    }
    if (v is DateTime) {
      return v;
    }
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    return null;
  }

  num _asNum(dynamic v) {
    if (v is num) {
      return v;
    }
    return num.tryParse((v ?? '').toString()) ?? 0;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmText = '確認',
    bool danger = false,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final res = await showDialog<bool>(
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
    return res == true;
  }

  // ===========================================================
  // Batch (✅ 本方法完全不使用 finally)
  // ===========================================================
  Future<void> _applyBatchUpdate() async {
    if (_selected.isEmpty) {
      _snack('請先選取至少 1 筆訂單');
      return;
    }

    final note = _noteCtrl.text.trim();
    final tracking = _trackingCtrl.text.trim();
    final status = _targetStatus;

    final ok = await _confirm(
      title: '批次套用',
      message:
          '即將更新 ${_selected.length} 筆訂單：\n'
          '- status：$status\n'
          '${note.isEmpty ? '' : '- adminNote：$note\n'}'
          '${tracking.isEmpty ? '' : '- trackingNo：$tracking\n'}'
          '\n確定要套用嗎？',
      confirmText: '套用',
      danger: status == 'cancelled',
    );
    if (!ok) {
      return;
    }

    setState(() => _busy = true);

    Object? err;
    try {
      final ids = _selected.toList(growable: false);

      // Firestore batch 每次最多 500 → 切段
      const chunkSize = 450;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(
          i,
          (i + chunkSize > ids.length) ? ids.length : i + chunkSize,
        );

        final batch = _db.batch();
        for (final id in chunk) {
          final ref = _db.collection('orders').doc(id);

          final payload = <String, dynamic>{
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (note.isNotEmpty) {
            payload['adminNote'] = note;
          }
          if (tracking.isNotEmpty) {
            payload['trackingNo'] = tracking;
          }

          batch.update(ref, payload);
        }

        await batch.commit();
      }
    } catch (e) {
      err = e;
    }

    // ✅ 手動收尾（取代 finally）
    if (mounted) {
      setState(() => _busy = false);
    }

    if (err != null) {
      _snack('批次更新失敗：$err');
      return;
    }

    if (!mounted) {
      return;
    }
    _snack('已批次更新 ${_selected.length} 筆訂單');
    setState(() => _selected.clear());
  }

  void _toggleAll(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool on,
  ) {
    setState(() {
      if (on) {
        for (final d in docs) {
          _selected.add(d.id);
        }
      } else {
        for (final d in docs) {
          _selected.remove(d.id);
        }
      }
    });
  }

  // ===========================================================
  // UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('訂單批次操作'),
        actions: [
          IconButton(
            tooltip: '清空選取',
            onPressed: _busy
                ? null
                : () {
                    setState(() => _selected.clear());
                    _snack('已清空選取');
                  },
            icon: const Icon(Icons.clear_all_rounded),
          ),
          IconButton(
            tooltip: '重新整理',
            onPressed: _busy ? null : () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters + Batch panel
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final isNarrow = c.maxWidth < 720;

                    final keyword = TextField(
                      controller: _keywordCtrl,
                      onChanged: _onKeywordChanged,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText:
                            '搜尋：orderId / userId / status / trackingNo / note',
                        isDense: true,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    );

                    final statusFilter = DropdownButtonFormField<String>(
                      key: ValueKey('statusFilter_$_statusFilter'),
                      initialValue: _statusFilterOptions.contains(_statusFilter)
                          ? _statusFilter
                          : 'all',
                      items: _statusFilterOptions
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) {
                              setState(() => _statusFilter = v ?? 'all');
                            },
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: '狀態篩選',
                        isDense: true,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          keyword,
                          const SizedBox(height: 10),
                          statusFilter,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: keyword),
                        const SizedBox(width: 10),
                        SizedBox(width: 240, child: statusFilter),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  color: _withOpacity(cs.primaryContainer, 0.35),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final isNarrow = c.maxWidth < 820;

                        final targetStatus = DropdownButtonFormField<String>(
                          key: ValueKey('targetStatus_$_targetStatus'),
                          initialValue: _statusOptions.contains(_targetStatus)
                              ? _targetStatus
                              : 'paid',
                          items: _statusOptions
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (v) {
                                  if (v == null) {
                                    return;
                                  }
                                  setState(() => _targetStatus = v);
                                },
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: '批次更新狀態',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );

                        final tracking = TextField(
                          controller: _trackingCtrl,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: 'trackingNo（可留空）',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );

                        final note = TextField(
                          controller: _noteCtrl,
                          enabled: !_busy,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'adminNote（可留空）',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );

                        final applyBtn = FilledButton.icon(
                          onPressed: _busy ? null : _applyBatchUpdate,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.playlist_add_check_rounded),
                          label: Text(
                            _busy ? '套用中…' : '套用到已選取（${_selected.length}）',
                          ),
                        );

                        if (isNarrow) {
                          return Column(
                            children: [
                              targetStatus,
                              const SizedBox(height: 10),
                              tracking,
                              const SizedBox(height: 10),
                              note,
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: applyBtn,
                              ),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: targetStatus),
                            const SizedBox(width: 10),
                            Expanded(child: tracking),
                            const SizedBox(width: 10),
                            Expanded(child: note),
                            const SizedBox(width: 10),
                            Align(
                              alignment: Alignment.topRight,
                              child: applyBtn,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snap.data!.docs;
                final docs = allDocs
                    .where((d) => _hit(d.data(), d.id))
                    .toList(growable: false);

                if (docs.isEmpty) {
                  return const Center(child: Text('沒有符合條件的訂單'));
                }

                final allSelected =
                    docs.isNotEmpty &&
                    docs.every((d) => _selected.contains(d.id));
                final anySelected = docs.any((d) => _selected.contains(d.id));

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: _withOpacity(cs.surfaceContainerHighest, 0.45),
                        border: Border(
                          bottom: BorderSide(
                            color: _withOpacity(cs.outline, 0.25),
                          ),
                        ),
                      ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Checkbox(
                            value: allSelected
                                ? true
                                : (anySelected ? null : false),
                            tristate: true,
                            onChanged: _busy
                                ? null
                                : (v) {
                                    _toggleAll(docs, v == true);
                                  },
                          ),
                          Text(
                            '本頁 ${docs.length} 筆（已選 ${_selected.length}）',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _toggleAll(docs, true),
                            icon: const Icon(Icons.select_all_rounded),
                            label: const Text('全選(本頁)'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _toggleAll(docs, false),
                            icon: const Icon(Icons.deselect_rounded),
                            label: const Text('取消全選(本頁)'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final d = doc.data();

                          final id = doc.id;
                          final selected = _selected.contains(id);

                          final status = (d['status'] ?? '').toString();
                          final userId = (d['userId'] ?? '').toString();

                          final createdAt = _toDt(d['createdAt']);
                          final createdText = createdAt == null
                              ? '-'
                              : _df.format(createdAt);

                          final amount = _asNum(
                            d['finalAmount'] ?? d['total'] ?? d['amount'] ?? 0,
                          );
                          final amountText = _mf.format(amount);

                          final tracking = (d['trackingNo'] ?? '')
                              .toString()
                              .trim();
                          final note = (d['adminNote'] ?? '').toString().trim();

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _busy
                                  ? null
                                  : () {
                                      setState(() {
                                        if (selected) {
                                          _selected.remove(id);
                                        } else {
                                          _selected.add(id);
                                        }
                                      });
                                    },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: selected,
                                      onChanged: _busy
                                          ? null
                                          : (v) {
                                              setState(() {
                                                if (v == true) {
                                                  _selected.add(id);
                                                } else {
                                                  _selected.remove(id);
                                                }
                                              });
                                            },
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '訂單 $id',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _StatusChip(status: status),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'userId: $userId',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '金額：$amountText   建立：$createdText',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          if (tracking.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              'trackingNo: $tracking',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                          if (note.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              'note: $note',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              onPressed: () {
                                                try {
                                                  Navigator.pushNamed(
                                                    context,
                                                    '/admin_order_detail',
                                                    arguments: {'orderId': id},
                                                  );
                                                } catch (_) {
                                                  _snack(
                                                    '尚未註冊路由：/admin_order_detail',
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.open_in_new_rounded,
                                                size: 18,
                                              ),
                                              label: const Text('查看詳情'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  Color _color(String s) {
    final v = s.trim().toLowerCase();
    switch (v) {
      case 'paid':
        return Colors.teal;
      case 'shipping':
      case 'shipped':
        return Colors.indigo;
      case 'done':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _withOpacity(c, 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _withOpacity(c, 0.28)),
      ),
      child: Text(
        status.isEmpty ? '-' : status,
        style: TextStyle(color: c, fontWeight: FontWeight.w900),
      ),
    );
  }
}

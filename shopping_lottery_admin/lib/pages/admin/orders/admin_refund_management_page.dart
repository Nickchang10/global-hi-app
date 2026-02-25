// lib/pages/admin/orders/admin_refund_management_page.dart
//
// ✅ AdminRefundManagementPage（退款管理｜完整版｜可編譯）
// ------------------------------------------------------------
// - 退款申請列表（Firestore: refunds）
// - 篩選：status / keyword（orderId、userId、refundId）
// - 操作：核准 / 拒絕 / 標記已處理
// - 編輯：adminNote 備註
// - ✅ FIX: curly_braces_in_flow_control_structures（所有 if 都加大括號）
// - ✅ FIX: unused_element（移除未使用的 _editAdminNote）
// - 相容 Web / 桌面 / 手機
//
// 建議路由：
// '/admin_refund_management': (_) => const AdminRefundManagementPage(),
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

class AdminRefundManagementPage extends StatefulWidget {
  const AdminRefundManagementPage({super.key});

  @override
  State<AdminRefundManagementPage> createState() =>
      _AdminRefundManagementPageState();
}

class _AdminRefundManagementPageState extends State<AdminRefundManagementPage> {
  final _db = FirebaseFirestore.instance;

  final _kwCtrl = TextEditingController();
  Timer? _debounce;
  String _keyword = '';

  String _statusFilter = 'all';
  static const _statusOptions = <String>[
    'all',
    'pending',
    'approved',
    'rejected',
    'processed',
  ];

  final _df = DateFormat('yyyy/MM/dd HH:mm');
  final _mf = NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$');

  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _kwCtrl.dispose();
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
    var q = _db.collection('refunds').orderBy('createdAt', descending: true);
    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }
    return q.limit(300);
  }

  bool _hit(Map<String, dynamic> d, String id) {
    if (_keyword.isEmpty) {
      return true;
    }

    final orderId = (d['orderId'] ?? '').toString().toLowerCase();
    final userId = (d['userId'] ?? '').toString().toLowerCase();
    final status = (d['status'] ?? '').toString().toLowerCase();
    final reason = (d['reason'] ?? '').toString().toLowerCase();
    final adminNote = (d['adminNote'] ?? '').toString().toLowerCase();
    final rid = id.toLowerCase();

    return rid.contains(_keyword) ||
        orderId.contains(_keyword) ||
        userId.contains(_keyword) ||
        status.contains(_keyword) ||
        reason.contains(_keyword) ||
        adminNote.contains(_keyword);
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

  Future<String?> _askText({
    required String title,
    required String hint,
    String initial = '',
    String confirmText = '儲存',
    bool danger = false,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final c = TextEditingController(text: initial);

    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: c,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger ? cs.error : null,
              foregroundColor: danger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, c.text),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    c.dispose();
    return res;
  }

  // ===========================================================
  // Actions
  // ===========================================================
  Future<void> _updateStatus({
    required String refundId,
    required String nextStatus,
    String? adminNote,
    bool setProcessedAt = false,
  }) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);

    Object? err;
    try {
      final payload = <String, dynamic>{
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (adminNote != null) {
        payload['adminNote'] = adminNote.trim();
      }
      if (setProcessedAt) {
        payload['processedAt'] = FieldValue.serverTimestamp();
      }

      await _db.collection('refunds').doc(refundId).update(payload);
    } catch (e) {
      err = e;
    }

    if (mounted) {
      setState(() => _busy = false);
    }

    if (err != null) {
      _snack('更新失敗：$err');
      return;
    }

    _snack('已更新：$refundId → $nextStatus');
  }

  Future<void> _updateAdminNoteOnly({
    required String refundId,
    required String note,
  }) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);

    Object? err;
    try {
      await _db.collection('refunds').doc(refundId).update({
        'adminNote': note.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      err = e;
    }

    if (mounted) {
      setState(() => _busy = false);
    }

    if (err != null) {
      _snack('更新備註失敗：$err');
      return;
    }
    _snack('備註已更新');
  }

  Future<void> _editNoteFlow({
    required String refundId,
    required String currentNote,
  }) async {
    final text = await _askText(
      title: '編輯 adminNote',
      hint: '輸入退款備註（可留空）',
      initial: currentNote,
      confirmText: '儲存',
    );
    if (text == null) {
      return;
    }
    await _updateAdminNoteOnly(refundId: refundId, note: text);
  }

  // ===========================================================
  // UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('退款管理'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _busy ? null : () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: LayoutBuilder(
              builder: (context, c) {
                final isNarrow = c.maxWidth < 720;

                final kw = TextField(
                  controller: _kwCtrl,
                  onChanged: _onKeywordChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: '搜尋：refundId / orderId / userId / reason / note',
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );

                final status = DropdownButtonFormField<String>(
                  key: ValueKey('refundStatus_$_statusFilter'),
                  initialValue: _statusOptions.contains(_statusFilter)
                      ? _statusFilter
                      : 'all',
                  items: _statusOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
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
                    children: [kw, const SizedBox(height: 10), status],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: kw),
                    const SizedBox(width: 10),
                    SizedBox(width: 240, child: status),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
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

                final docs = snap.data!.docs
                    .where((d) => _hit(d.data(), d.id))
                    .toList(growable: false);

                if (docs.isEmpty) {
                  return const Center(child: Text('沒有符合條件的退款申請'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();

                    final refundId = doc.id;
                    final orderId = (d['orderId'] ?? '').toString().trim();
                    final userId = (d['userId'] ?? '').toString().trim();
                    final status = (d['status'] ?? 'pending').toString().trim();
                    final reason = (d['reason'] ?? '').toString().trim();
                    final adminNote = (d['adminNote'] ?? '').toString().trim();

                    final amount = _asNum(d['amount'] ?? 0);
                    final createdAt = _toDt(d['createdAt']);
                    final updatedAt = _toDt(d['updatedAt']);
                    final processedAt = _toDt(d['processedAt']);

                    final createdText = createdAt == null
                        ? '-'
                        : _df.format(createdAt);
                    final updatedText = updatedAt == null
                        ? '-'
                        : _df.format(updatedAt);
                    final processedText = processedAt == null
                        ? '-'
                        : _df.format(processedAt);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '退款 $refundId',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                              'orderId: ${orderId.isEmpty ? '-' : orderId}   '
                              'userId: ${userId.isEmpty ? '-' : userId}',
                              style: TextStyle(color: Colors.grey.shade700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '金額：${_mf.format(amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (reason.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                '原因：$reason',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                            if (adminNote.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                '備註：$adminNote',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              '建立：$createdText   更新：$updatedText   已處理：$processedText',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _busy || status != 'pending'
                                      ? null
                                      : () async {
                                          final ok = await _confirm(
                                            title: '核准退款',
                                            message:
                                                '確定要核准此筆退款嗎？\nrefundId: $refundId',
                                            confirmText: '核准',
                                          );
                                          if (!ok) {
                                            return;
                                          }
                                          await _updateStatus(
                                            refundId: refundId,
                                            nextStatus: 'approved',
                                          );
                                        },
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('核准'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _busy || status != 'pending'
                                      ? null
                                      : () async {
                                          final reasonReject = await _askText(
                                            title: '拒絕退款',
                                            hint: '輸入拒絕原因（可留空）',
                                            initial: '',
                                            confirmText: '拒絕',
                                            danger: true,
                                          );
                                          if (reasonReject == null) {
                                            return;
                                          }
                                          await _db
                                              .collection('refunds')
                                              .doc(refundId)
                                              .update({
                                                'status': 'rejected',
                                                'rejectReason': reasonReject
                                                    .trim(),
                                                'updatedAt':
                                                    FieldValue.serverTimestamp(),
                                              });
                                          _snack('已拒絕：$refundId');
                                        },
                                  icon: const Icon(Icons.block),
                                  label: const Text('拒絕'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _editNoteFlow(
                                          refundId: refundId,
                                          currentNote: adminNote,
                                        ),
                                  icon: const Icon(Icons.edit_note),
                                  label: const Text('備註'),
                                ),
                                FilledButton.icon(
                                  onPressed: _busy || status == 'processed'
                                      ? null
                                      : () async {
                                          final ok = await _confirm(
                                            title: '標記已處理',
                                            message:
                                                '確定標記此筆退款為 processed 嗎？\nrefundId: $refundId',
                                            confirmText: '標記',
                                          );
                                          if (!ok) {
                                            return;
                                          }
                                          await _updateStatus(
                                            refundId: refundId,
                                            nextStatus: 'processed',
                                            setProcessedAt: true,
                                          );
                                        },
                                  icon: const Icon(Icons.done_all_rounded),
                                  label: const Text('已處理'),
                                ),
                              ],
                            ),
                          ],
                        ),
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
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  Color _color(String s) {
    final v = s.trim().toLowerCase();
    switch (v) {
      case 'approved':
        return Colors.teal;
      case 'processed':
        return Colors.green;
      case 'rejected':
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

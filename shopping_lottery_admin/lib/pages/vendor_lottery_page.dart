// lib/pages/vendor_lottery_page.dart
//
// ✅ VendorLotteryPage（最終完整版｜可直接使用｜可編譯｜已修正 curly_braces_in_flow_control_structures + use_build_context_synchronously）
// ------------------------------------------------------------

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorLotteryPage extends StatefulWidget {
  const VendorLotteryPage({super.key, this.vendorId});

  final String? vendorId;

  @override
  State<VendorLotteryPage> createState() => _VendorLotteryPageState();
}

class _VendorLotteryPageState extends State<VendorLotteryPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _lotteriesRef =>
      _db.collection('lotteries');

  String? get _resolvedVendorId => widget.vendorId ?? _auth.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final vendorId = _resolvedVendorId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('廠商抽獎活動'),
        actions: [
          IconButton(
            tooltip: '新增活動',
            onPressed: vendorId == null
                ? null
                : () => _openEditDialog(vendorId: vendorId),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: vendorId == null ? _buildNeedLogin(context) : _buildList(vendorId),
    );
  }

  Widget _buildNeedLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              '請先登入廠商帳號才能管理抽獎活動',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String vendorId) {
    final query = _lotteriesRef
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildError('讀取失敗：${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _buildEmpty(vendorId);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data();
            return _LotteryCard(
              id: doc.id,
              data: data,
              onEdit: () => _openEditDialog(
                vendorId: vendorId,
                docId: doc.id,
                existing: data,
              ),
              onDelete: () => _deleteLottery(doc.id),
              onToggleActive: (val) => _toggleActive(doc.id, val),
              onDrawWinners: () => _drawWinnersFlow(doc.id),
              db: _db,
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty(String vendorId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.card_giftcard, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('尚未建立抽獎活動', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _openEditDialog(vendorId: vendorId),
              icon: const Icon(Icons.add),
              label: const Text('建立第一個活動'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(msg, style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Future<void> _openEditDialog({
    required String vendorId,
    String? docId,
    Map<String, dynamic>? existing,
  }) async {
    final result = await showDialog<_LotteryEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LotteryEditDialog(existing: existing),
    );

    if (!mounted || result == null) {
      return;
    }

    try {
      final now = FieldValue.serverTimestamp();
      final payload = <String, dynamic>{
        'vendorId': vendorId,
        'title': result.title.trim(),
        'description': result.description.trim(),
        'isActive': result.isActive,
        'startAt': result.startAt == null
            ? null
            : Timestamp.fromDate(result.startAt!),
        'endAt': result.endAt == null
            ? null
            : Timestamp.fromDate(result.endAt!),
        'updatedAt': now,
      };

      if (docId == null) {
        payload['createdAt'] = now;
        await _lotteriesRef.add(payload);
      } else {
        await _lotteriesRef.doc(docId).update(payload);
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(docId == null ? '已建立活動' : '已更新活動')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  Future<void> _deleteLottery(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除活動'),
        content: const Text('確定要刪除此抽獎活動？（不會自動刪除子集合 entries / winners）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (!mounted || ok != true) {
      return;
    }

    try {
      await _lotteriesRef.doc(docId).delete();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除活動')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  Future<void> _toggleActive(String docId, bool isActive) async {
    try {
      await _lotteriesRef.doc(docId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新狀態失敗：$e')));
    }
  }

  Future<void> _drawWinnersFlow(String lotteryId) async {
    final count = await showDialog<int>(
      context: context,
      builder: (_) => const _DrawCountDialog(),
    );
    if (!mounted || count == null || count <= 0) {
      return;
    }

    try {
      final result = await _drawWinners(lotteryId: lotteryId, count: count);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已抽出 ${result.drawn} 名得獎者（可抽：${result.available}）'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('抽獎失敗：$e')));
    }
  }

  Future<_DrawWinnersResult> _drawWinners({
    required String lotteryId,
    required int count,
  }) async {
    final entriesRef = _lotteriesRef.doc(lotteryId).collection('entries');
    final winnersRef = _lotteriesRef.doc(lotteryId).collection('winners');

    final entriesSnap = await entriesRef
        .orderBy('createdAt', descending: false)
        .get();
    final entries = entriesSnap.docs;

    if (entries.isEmpty) {
      return const _DrawWinnersResult(available: 0, drawn: 0);
    }

    final winnersSnap = await winnersRef.get();
    final existingEntryIds = winnersSnap.docs
        .map((d) => (d.data()['entryId'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet();

    final candidates = entries
        .where((e) => !existingEntryIds.contains(e.id))
        .toList();
    final available = candidates.length;

    if (available == 0) {
      return const _DrawWinnersResult(available: 0, drawn: 0);
    }

    final rng = Random();
    candidates.shuffle(rng);

    final take = min(count, candidates.length);
    final now = FieldValue.serverTimestamp();

    final batch = _db.batch();
    for (var i = 0; i < take; i++) {
      final entryDoc = candidates[i];
      final uid = (entryDoc.data()['uid'] ?? '').toString();

      final winnerDoc = winnersRef.doc();
      batch.set(winnerDoc, {
        'uid': uid,
        'entryId': entryDoc.id,
        'createdAt': now,
      });
    }

    await batch.commit();
    return _DrawWinnersResult(available: available, drawn: take);
  }
}

class _LotteryCard extends StatelessWidget {
  const _LotteryCard({
    required this.id,
    required this.data,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onDrawWinners,
    required this.db,
  });

  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDrawWinners;
  final FirebaseFirestore db;

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? '').toString();
    final desc = (data['description'] ?? '').toString();
    final isActive = (data['isActive'] ?? false) == true;

    final startAt = _tsToDateTime(data['startAt']);
    final endAt = _tsToDateTime(data['endAt']);

    final entriesRef = db.collection('lotteries').doc(id).collection('entries');
    final winnersRef = db.collection('lotteries').doc(id).collection('winners');

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? '(未命名活動)' : title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch(value: isActive, onChanged: onToggleActive),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(desc, style: const TextStyle(color: Colors.black87)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: Icons.timer_outlined,
                  text: '開始：${_fmt(startAt)}',
                ),
                _InfoChip(
                  icon: Icons.timer_off_outlined,
                  text: '結束：${_fmt(endAt)}',
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: entriesRef.snapshots(),
                  builder: (context, snap) {
                    final n = snap.data?.docs.length ?? 0;
                    return _InfoChip(
                      icon: Icons.confirmation_number_outlined,
                      text: '參加券：$n',
                    );
                  },
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: winnersRef.snapshots(),
                  builder: (context, snap) {
                    final n = snap.data?.docs.length ?? 0;
                    return _InfoChip(
                      icon: Icons.emoji_events_outlined,
                      text: '得獎：$n',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('編輯'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onDrawWinners,
                  icon: const Icon(Icons.casino_outlined, size: 18),
                  label: const Text('抽出得獎者'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: const Text('刪除', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static DateTime? _tsToDateTime(dynamic ts) {
    if (ts is Timestamp) {
      return ts.toDate();
    }
    return null;
  }

  static String _fmt(DateTime? dt) {
    if (dt == null) {
      return '-';
    }
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 18),
      label: Text(text),
    );
  }
}

class _LotteryEditDialog extends StatefulWidget {
  const _LotteryEditDialog({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_LotteryEditDialog> createState() => _LotteryEditDialogState();
}

class _LotteryEditDialogState extends State<_LotteryEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _desc;

  bool _isActive = false;
  DateTime? _startAt;
  DateTime? _endAt;

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? const <String, dynamic>{};
    _title = TextEditingController(text: (e['title'] ?? '').toString());
    _desc = TextEditingController(text: (e['description'] ?? '').toString());
    _isActive = (e['isActive'] ?? false) == true;

    final s = e['startAt'];
    final ed = e['endAt'];
    _startAt = s is Timestamp ? s.toDate() : null;
    _endAt = ed is Timestamp ? ed.toDate() : null;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? '編輯抽獎活動' : '新增抽獎活動'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: '活動名稱',
                  hintText: '例如：春季滿額抽獎',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '活動說明',
                  hintText: '例如：下單滿 999 送 1 張抽獎券',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('上架狀態'),
                subtitle: Text(_isActive ? '目前：上架' : '目前：下架'),
              ),
              const SizedBox(height: 8),
              _DateTimeRow(
                label: '開始時間',
                value: _startAt,
                onPick: () async {
                  final dt = await _pickDateTime(initial: _startAt);
                  if (!mounted) {
                    return;
                  }
                  setState(() => _startAt = dt);
                },
                onClear: () => setState(() => _startAt = null),
              ),
              const SizedBox(height: 8),
              _DateTimeRow(
                label: '結束時間',
                value: _endAt,
                onPick: () async {
                  final dt = await _pickDateTime(initial: _endAt);
                  if (!mounted) {
                    return;
                  }
                  setState(() => _endAt = dt);
                },
                onClear: () => setState(() => _endAt = null),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '提示：若不填開始/結束時間，代表不限時（由前台自行解讀）。',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('請輸入活動名稱')));
              return;
            }
            if (_startAt != null &&
                _endAt != null &&
                _endAt!.isBefore(_startAt!)) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('結束時間不可早於開始時間')));
              return;
            }
            Navigator.pop(
              context,
              _LotteryEditResult(
                title: title,
                description: _desc.text,
                isActive: _isActive,
                startAt: _startAt,
                endAt: _endAt,
              ),
            );
          },
          child: const Text('儲存'),
        ),
      ],
    );
  }

  // ✅ 改成使用 State.context（不要把外部 BuildContext 跨 await 使用）
  Future<DateTime?> _pickDateTime({DateTime? initial}) async {
    final now = DateTime.now();
    final base = initial ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) {
      return null;
    }

    // ✅ 跨 await 後，使用 State.context 前用 mounted guard（lint 期望的寫法）
    if (!mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '-' : _fmt(value!);
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label)),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(onPressed: onPick, child: const Text('選擇')),
        TextButton(onPressed: onClear, child: const Text('清除')),
      ],
    );
  }

  static String _fmt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _DrawCountDialog extends StatefulWidget {
  const _DrawCountDialog();

  @override
  State<_DrawCountDialog> createState() => _DrawCountDialogState();
}

class _DrawCountDialogState extends State<_DrawCountDialog> {
  final _ctrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('抽出得獎者'),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '抽出人數', hintText: '例如：3'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final n = int.tryParse(_ctrl.text.trim()) ?? 0;
            if (n <= 0) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('請輸入大於 0 的數字')));
              return;
            }
            Navigator.pop(context, n);
          },
          child: const Text('開始抽'),
        ),
      ],
    );
  }
}

class _LotteryEditResult {
  const _LotteryEditResult({
    required this.title,
    required this.description,
    required this.isActive,
    required this.startAt,
    required this.endAt,
  });

  final String title;
  final String description;
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;
}

class _DrawWinnersResult {
  const _DrawWinnersResult({required this.available, required this.drawn});
  final int available;
  final int drawn;
}

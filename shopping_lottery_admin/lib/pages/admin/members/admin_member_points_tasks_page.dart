// lib/pages/admin/members/admin_member_points_tasks_page.dart
//
// ✅ AdminMemberPointsTasksPage（單檔完整版｜可編譯可用｜已使用 _fmtDt 消除 unused_element）
// ------------------------------------------------------------
// 來源 uid：
// 1) 可直接傳入 AdminMemberPointsTasksPage(uid: 'xxx')
// 2) 或從 Navigator.pushNamed arguments 取得：{'uid': 'xxx'}
// ------------------------------------------------------------
//
// Firestore 建議結構（可依你現況調整）
// users/{uid} {
//   points: 1200,
//   displayName: "...",
//   email: "...",
//   updatedAt: Timestamp,
// }
// users/{uid}/points_logs/{logId} {
//   type: "earn" | "spend" | "admin_manual_adjust" | ...
//   delta: 50,
//   before: 1000,
//   after: 1050,
//   reason: "...",
//   createdAt: Timestamp
// }
// users/{uid}/tasks/{taskId} {
//   title: "...",
//   status: "pending"|"done",
//   points: 30,
//   createdAt: Timestamp,
//   doneAt: Timestamp?
// }
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminMemberPointsTasksPage extends StatefulWidget {
  final String? uid;

  const AdminMemberPointsTasksPage({super.key, this.uid});

  @override
  State<AdminMemberPointsTasksPage> createState() =>
      _AdminMemberPointsTasksPageState();
}

class _AdminMemberPointsTasksPageState extends State<AdminMemberPointsTasksPage>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;

  late final TabController _tabCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String _resolveUid(BuildContext context) {
    if (widget.uid != null && widget.uid!.trim().isNotEmpty) {
      return widget.uid!.trim();
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final v = args['uid'];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  // ✅ 修正 unused_element：此方法會在 UI 內實際使用
  String _fmtDt(DateTime? dt) {
    if (dt == null) {
      return '—';
    }
    return DateFormat('yyyy/MM/dd HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = _resolveUid(context);

    if (uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '會員點數/任務',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _EmptyView(
          title: '缺少 uid',
          message:
              '請用 routes arguments 傳入 uid，或直接建立 AdminMemberPointsTasksPage(uid: ...)。',
        ),
      );
    }

    final userDoc = _db.collection('users').doc(uid);
    final logsQuery = userDoc
        .collection('points_logs')
        .orderBy('createdAt', descending: true)
        .limit(200);
    final tasksQuery = userDoc
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .limit(200);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '點數/任務：$uid',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '複製 uid',
            icon: const Icon(Icons.copy),
            onPressed: () => _copy(uid),
          ),
          IconButton(
            tooltip: '手動調整點數',
            icon: const Icon(Icons.tune),
            onPressed: _busy ? null : () => _openAdjustDialog(uid),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.payments_outlined), text: '點數流水'),
            Tab(icon: Icon(Icons.task_alt_outlined), text: '任務'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 顶部概況
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: userDoc.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              if (snap.hasError) {
                return _HintBar(
                  icon: Icons.error_outline,
                  text: '讀取會員資料失敗：${snap.error}',
                  color: cs.errorContainer,
                  textColor: cs.onErrorContainer,
                );
              }

              final data = snap.data?.data() ?? <String, dynamic>{};
              final name = (data['displayName'] ?? data['name'] ?? '')
                  .toString();
              final email = (data['email'] ?? '').toString();
              final points = _toInt(data['points']);
              final updatedAt = _toDt(data['updatedAt']);

              return _SummaryCard(
                uid: uid,
                name: name,
                email: email,
                points: points,
                updatedAtText: _fmtDt(updatedAt), // ✅ 使用 _fmtDt
                busy: _busy,
                onAdjust: () => _openAdjustDialog(uid),
              );
            },
          ),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ----------------- Logs -----------------
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: logsQuery.snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return _ErrorView(
                        title: '載入點數流水失敗',
                        message: snap.error.toString(),
                        onRetry: () => setState(() {}),
                      );
                    }

                    final docs = snap.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return _EmptyView(
                        title: '沒有點數流水',
                        message: 'users/$uid/points_logs 目前沒有資料。',
                      );
                    }

                    final logs = docs
                        .map((d) => _PointsLog.fromDoc(d))
                        .toList();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: logs.length,
                      itemBuilder: (_, i) {
                        final it = logs[i];
                        final deltaColor = it.delta >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700;
                        final badgeBg = it.delta >= 0
                            ? Colors.green.shade100
                            : Colors.red.shade100;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                it.delta >= 0
                                    ? '+${it.delta}'
                                    : it.delta.toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: deltaColor,
                                ),
                              ),
                            ),
                            title: Text(
                              it.type.isEmpty ? '(未分類)' : it.type,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              'before=${it.before}  •  after=${it.after}\n'
                              'time=${_fmtDt(it.createdAt)}'
                              '${it.reason.isNotEmpty ? '\nreason=${it.reason}' : ''}',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                // ----------------- Tasks -----------------
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: tasksQuery.snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return _ErrorView(
                        title: '載入任務失敗',
                        message: snap.error.toString(),
                        onRetry: () => setState(() {}),
                      );
                    }

                    final docs = snap.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return _EmptyView(
                        title: '沒有任務資料',
                        message:
                            'users/$uid/tasks 目前沒有資料（若你用 다른 collection 名稱請自行調整）。',
                      );
                    }

                    final tasks = docs
                        .map((d) => _TaskItem.fromDoc(d))
                        .toList();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: tasks.length,
                      itemBuilder: (_, i) {
                        final t = tasks[i];
                        final done = t.status == 'done';
                        final pillBg = done
                            ? Colors.green.shade100
                            : Colors.orange.shade100;
                        final pillFg = done
                            ? Colors.green.shade900
                            : Colors.orange.shade900;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(
                              done
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: done ? Colors.green : Colors.orange,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.title.isEmpty ? '(未命名任務)' : t.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pillBg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    done ? '已完成' : '未完成',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      color: pillFg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'points=${t.points}\n'
                              'createdAt=${_fmtDt(t.createdAt)}  •  doneAt=${_fmtDt(t.doneAt)}',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Manual adjust points
  // ============================================================

  Future<void> _openAdjustDialog(String uid) async {
    final deltaCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    bool? ok;
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text(
            '手動調整點數',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'uid：$uid',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: deltaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '點數變動（delta）',
                    helperText: '例如：+50 或 -20（會自動解析）',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: '原因 / 備註（可空）'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('確認'),
            ),
          ],
        ),
      );
    } finally {
      // no-op
    }

    if (ok != true) {
      deltaCtrl.dispose();
      reasonCtrl.dispose();
      return;
    }

    final raw = deltaCtrl.text.trim().replaceAll(' ', '');
    final delta = int.tryParse(raw.startsWith('+') ? raw.substring(1) : raw);
    final reason = reasonCtrl.text.trim();

    deltaCtrl.dispose();
    reasonCtrl.dispose();

    if (delta == null) {
      _toast('delta 格式不正確');
      return;
    }

    await _adjustPoints(uid: uid, delta: delta, reason: reason);
  }

  Future<void> _adjustPoints({
    required String uid,
    required int delta,
    required String reason,
  }) async {
    setState(() => _busy = true);

    final userDoc = _db.collection('users').doc(uid);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(userDoc);
        final data = snap.data() ?? <String, dynamic>{};

        final before = _toInt(data['points']);
        final after = (before + delta) < 0 ? 0 : (before + delta);

        tx.set(userDoc, {
          'points': after,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final logRef = userDoc.collection('points_logs').doc();
        tx.set(logRef, {
          'uid': uid,
          'type': 'admin_manual_adjust',
          'delta': delta,
          'before': before,
          'after': after,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      _toast('已調整點數');
    } catch (e) {
      _toast('調整失敗：$e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  // ============================================================
  // Helpers
  // ============================================================

  int _toInt(dynamic v) {
    if (v == null) {
      return 0;
    }
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return int.tryParse(v.toString()) ?? 0;
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

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('已複製：$text');
  }

  void _toast(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ============================================================
// Models
// ============================================================

class _PointsLog {
  final String id;
  final String type;
  final int delta;
  final int before;
  final int after;
  final String reason;
  final DateTime? createdAt;

  _PointsLog({
    required this.id,
    required this.type,
    required this.delta,
    required this.before,
    required this.after,
    required this.reason,
    required this.createdAt,
  });

  factory _PointsLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? <String, dynamic>{};

    int toInt(dynamic v) {
      if (v == null) {
        return 0;
      }
      if (v is int) {
        return v;
      }
      if (v is num) {
        return v.toInt();
      }
      return int.tryParse(v.toString()) ?? 0;
    }

    DateTime? toDt(dynamic v) {
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

    return _PointsLog(
      id: doc.id,
      type: (m['type'] ?? '').toString(),
      delta: toInt(m['delta']),
      before: toInt(m['before']),
      after: toInt(m['after']),
      reason: (m['reason'] ?? '').toString(),
      createdAt: toDt(m['createdAt']),
    );
  }
}

class _TaskItem {
  final String id;
  final String title;
  final String status;
  final int points;
  final DateTime? createdAt;
  final DateTime? doneAt;

  _TaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.points,
    required this.createdAt,
    required this.doneAt,
  });

  factory _TaskItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? <String, dynamic>{};

    int toInt(dynamic v) {
      if (v == null) {
        return 0;
      }
      if (v is int) {
        return v;
      }
      if (v is num) {
        return v.toInt();
      }
      return int.tryParse(v.toString()) ?? 0;
    }

    DateTime? toDt(dynamic v) {
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

    return _TaskItem(
      id: doc.id,
      title: (m['title'] ?? '').toString(),
      status: (m['status'] ?? 'pending').toString(),
      points: toInt(m['points']),
      createdAt: toDt(m['createdAt']),
      doneAt: toDt(m['doneAt']),
    );
  }
}

// ============================================================
// UI
// ============================================================

class _SummaryCard extends StatelessWidget {
  final String uid;
  final String name;
  final String email;
  final int points;
  final String updatedAtText;
  final bool busy;
  final VoidCallback onAdjust;

  const _SummaryCard({
    required this.uid,
    required this.name,
    required this.email,
    required this.points,
    required this.updatedAtText,
    required this.busy,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '會員點數概況',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                'uid：$uid',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '名稱：${name.isEmpty ? "—" : name}',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Email：${email.isEmpty ? "—" : email}',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Points',
                            style: TextStyle(color: cs.onPrimaryContainer),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            points.toString(),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Updated',
                            style: TextStyle(color: cs.onSecondaryContainer),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            updatedAtText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onAdjust,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.tune),
                      label: Text(busy ? '處理中...' : '手動調整點數'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintBar extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color textColor;

  const _HintBar({
    required this.icon,
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyView({required this.title, required this.message});

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
                  Icon(Icons.info_outline, size: 44, color: cs.primary),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
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

// lib/pages/admin/sos/admin_sos_events_page.dart
//
// ✅ AdminSosEventsPage（SOS 事件列表｜單檔完整版｜可編譯）
// -----------------------------------------------------------------------------
// 修正重點：
// - ✅ 修正 undefined_function：AdminSOSEventDetailPage -> AdminSosEventDetailPage
// - ✅ 加上正確 import（同資料夾）：admin_sos_event_detail_page.dart
// - ✅ 不依賴 named route，直接 MaterialPageRoute 進詳情頁，避免路由未註冊造成 runtime error
//
// 功能：
// - Firestore 直連：sos_events（orderBy createdAt desc）
// - 搜尋：eventId / uid / userName / email / phone / deviceId
// - 狀態篩選：all / triggered / processing / resolved / cancelled
// - 複製 eventId / uid
// - 點擊進詳情頁
//
// 依賴：cloud_firestore / intl / flutter/services.dart
// -----------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ✅ 同資料夾 import（請確認檔案路徑：lib/pages/admin/sos/admin_sos_event_detail_page.dart）
import 'admin_sos_event_detail_page.dart';

class AdminSosEventsPage extends StatefulWidget {
  const AdminSosEventsPage({super.key});

  @override
  State<AdminSosEventsPage> createState() => _AdminSosEventsPageState();
}

class _AdminSosEventsPageState extends State<AdminSosEventsPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  SosStatusFilter _filter = SosStatusFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime? _toDt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    try {
      final dynamic d = v;
      final dt = d.toDate();
      return dt is DateTime ? dt : null;
    } catch (_) {
      return null;
    }
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('yyyy/MM/dd HH:mm').format(dt);
  }

  Future<void> _copy(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已複製：$t')));
  }

  Color _statusColor(ColorScheme cs, String status) {
    switch (status) {
      case 'triggered':
        return cs.error;
      case 'processing':
        return cs.tertiary;
      case 'resolved':
        return Colors.green.shade700;
      case 'cancelled':
        return cs.outline;
      default:
        return cs.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'triggered':
        return '已觸發';
      case 'processing':
        return '處理中';
      case 'resolved':
        return '已結案';
      case 'cancelled':
        return '已取消';
      default:
        return status.isEmpty ? 'unknown' : status;
    }
  }

  Query<Map<String, dynamic>> _query() {
    // 先用最穩的查詢：orderBy createdAt desc（避免複合索引地獄）
    // 狀態篩選改用「本頁載入後本地過濾」，穩定不爆 index。
    return _db
        .collection('sos_events')
        .orderBy('createdAt', descending: true)
        .limit(300);
  }

  List<_SosRow> _applyLocalFilter(List<_SosRow> input) {
    final q = _searchCtrl.text.trim().toLowerCase();

    Iterable<_SosRow> out = input;

    // status local filter
    if (_filter != SosStatusFilter.all) {
      out = out.where((e) => e.status == _filter.value);
    }

    // keyword local filter
    if (q.isNotEmpty) {
      out = out.where((e) {
        return e.id.toLowerCase().contains(q) ||
            e.uid.toLowerCase().contains(q) ||
            e.userName.toLowerCase().contains(q) ||
            e.email.toLowerCase().contains(q) ||
            e.phone.toLowerCase().contains(q) ||
            e.deviceId.toLowerCase().contains(q) ||
            e.status.toLowerCase().contains(q);
      });
    }

    return out.toList();
  }

  void _openDetail(String eventId) {
    final id = eventId.trim();
    if (id.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminSosEventDetailPage(eventId: id), // ✅ 正確 class 名稱
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SOS 事件列表',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '清除搜尋',
            onPressed: () {
              _searchCtrl.clear();
              setState(() {});
            },
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText:
                        '搜尋 eventId / uid / 姓名 / email / phone / deviceId / status',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt_outlined),
                          const SizedBox(width: 8),
                          DropdownButton<SosStatusFilter>(
                            value: _filter,
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _filter = v);
                            },
                            items: SosStatusFilter.values
                                .map(
                                  (f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f.label),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重整'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    title: '載入 SOS 事件失敗',
                    message: snap.error.toString(),
                    onRetry: () => setState(() {}),
                  );
                }

                final docs = snap.data?.docs ?? const [];
                final all = docs
                    .map((d) => _SosRow.fromDoc(d, toDt: _toDt))
                    .toList();
                final filtered = _applyLocalFilter(all);

                if (filtered.isEmpty) {
                  return const _EmptyView(
                    title: '沒有符合條件的 SOS 事件',
                    message: '請調整搜尋或篩選條件。',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final e = filtered[i];
                    final statusColor = _statusColor(cs, e.status);

                    // ✅ withOpacity -> withValues(alpha: ...)
                    final pillBg = statusColor.withValues(alpha: 0.12);
                    final pillBorder = statusColor.withValues(alpha: 0.30);

                    final tileBg = cs
                        .surfaceContainerHighest; // 避免 deprecated surfaceVariant

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openDetail(e.id),
                        child: Container(
                          decoration: BoxDecoration(
                            color: tileBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Event：${e.id}',
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
                                      border: Border.all(color: pillBorder),
                                    ),
                                    child: Text(
                                      _statusLabel(e.status),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 14,
                                runSpacing: 6,
                                children: [
                                  _kv('時間', _fmt(e.createdAt), cs),
                                  _kv('uid', e.uid.isEmpty ? '—' : e.uid, cs),
                                  _kv(
                                    '姓名',
                                    e.userName.isEmpty ? '—' : e.userName,
                                    cs,
                                  ),
                                  _kv(
                                    '裝置',
                                    e.deviceId.isEmpty ? '—' : e.deviceId,
                                    cs,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _copy(e.id),
                                    icon: const Icon(Icons.copy, size: 18),
                                    label: const Text('複製 eventId'),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: e.uid.trim().isEmpty
                                        ? null
                                        : () => _copy(e.uid),
                                    icon: const Icon(Icons.copy, size: 18),
                                    label: const Text('複製 uid'),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ],
                          ),
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

  Widget _kv(String k, String v, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$k：',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Models
// =============================================================================
class _SosRow {
  final String id;
  final String uid;
  final String status;
  final DateTime? createdAt;

  final String userName;
  final String email;
  final String phone;
  final String deviceId;

  _SosRow({
    required this.id,
    required this.uid,
    required this.status,
    required this.createdAt,
    required this.userName,
    required this.email,
    required this.phone,
    required this.deviceId,
  });

  static _SosRow fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required DateTime? Function(dynamic v) toDt,
  }) {
    final m = doc.data() ?? <String, dynamic>{};
    return _SosRow(
      id: doc.id,
      uid: (m['uid'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      createdAt: toDt(m['createdAt']),
      userName: (m['userName'] ?? m['displayName'] ?? '').toString(),
      email: (m['userEmail'] ?? m['email'] ?? '').toString(),
      phone: (m['phone'] ?? '').toString(),
      deviceId: (m['deviceId'] ?? m['watchId'] ?? '').toString(),
    );
  }
}

// =============================================================================
// Filters
// =============================================================================
enum SosStatusFilter {
  all('全部', null),
  triggered('triggered（已觸發）', 'triggered'),
  processing('processing（處理中）', 'processing'),
  resolved('resolved（已結案）', 'resolved'),
  cancelled('cancelled（已取消）', 'cancelled');

  final String label;
  final String? value;
  const SosStatusFilter(this.label, this.value);
}

// =============================================================================
// Common Views
// =============================================================================
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
        constraints: const BoxConstraints(maxWidth: 760),
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

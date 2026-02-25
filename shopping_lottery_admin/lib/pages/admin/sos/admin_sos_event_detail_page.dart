// lib/pages/admin/sos/admin_sos_event_detail_page.dart
//
// ✅ AdminSosEventDetailPage（SOS 事件詳情｜單檔完整版｜可編譯）
// -----------------------------------------------------------------------------
// - Firestore 直連：sos_events/{eventId}
// - 顯示：事件基本資料、狀態、時間、定位、裝置/使用者資訊、備註、處理紀錄
// - 支援：複製事件 ID、複製 uid、快速開啟 Google Maps
//
// 依賴：cloud_firestore / intl / flutter/services.dart
//
// Firestore 建議欄位（沒有也不會崩，顯示空值）：
// sos_events/{eventId}
//  - uid: String
//  - status: String (triggered/processing/resolved/cancelled/...)
//  - createdAt: Timestamp
//  - updatedAt: Timestamp
//  - userName/displayName
//  - userEmail
//  - phone
//  - deviceId/watchId
//  - location: { lat, lng, accuracy, address }
//  - note: String?
//  - logs: List<Map>  (或 subcollection logs)
//
// ⚠️ 本檔重點：
// 1) 已移除所有 withOpacity（deprecated） → 改用 withValues(alpha: ...)
// 2) ✅ 已移除 cs.surfaceVariant（deprecated） → 改用 cs.surfaceContainerHighest
// -----------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminSosEventDetailPage extends StatefulWidget {
  final String? eventId;

  const AdminSosEventDetailPage({super.key, this.eventId});

  @override
  State<AdminSosEventDetailPage> createState() =>
      _AdminSosEventDetailPageState();
}

class _AdminSosEventDetailPageState extends State<AdminSosEventDetailPage> {
  final _db = FirebaseFirestore.instance;

  String _resolveEventId(BuildContext context) {
    final direct = widget.eventId?.trim() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.trim().isNotEmpty) {
      return args.trim();
    }
    if (args is Map) {
      final v = args['eventId'] ?? args['id'];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  String _fmtDt(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('yyyy/MM/dd HH:mm:ss').format(dt);
  }

  DateTime? _toDt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asLogList(dynamic v) {
    if (v is List) {
      return v.whereType<dynamic>().map((e) => _asMap(e)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> _copy(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已複製：$text')));
  }

  void _openMaps(num lat, num lng) {
    // 不做 url_launcher 依賴，先複製連結給你（避免缺套件）
    final url = 'https://www.google.com/maps?q=$lat,$lng';
    _copy(url);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已複製 Google Maps 連結（可貼到瀏覽器開啟）')),
    );
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final eventId = _resolveEventId(context);

    if (eventId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'SOS 事件詳情',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: const _EmptyView(
          title: '缺少 eventId',
          message:
              '請透過 arguments 傳入 eventId，或直接建立 AdminSosEventDetailPage(eventId: ...)。',
        ),
      );
    }

    final docRef = _db.collection('sos_events').doc(eventId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SOS 事件詳情',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '複製 eventId',
            icon: const Icon(Icons.copy),
            onPressed: () => _copy(eventId),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              title: '讀取失敗',
              message: snap.error.toString(),
              onRetry: () => setState(() {}),
            );
          }

          final data = snap.data?.data();
          if (data == null) {
            return _EmptyView(
              title: '找不到事件',
              message: 'sos_events/$eventId 不存在或無權限讀取。',
            );
          }

          final uid = (data['uid'] ?? '').toString();
          final status = (data['status'] ?? '').toString();
          final createdAt = _toDt(data['createdAt']);
          final updatedAt = _toDt(data['updatedAt']);

          final userName = (data['userName'] ?? data['displayName'] ?? '')
              .toString();
          final userEmail = (data['userEmail'] ?? data['email'] ?? '')
              .toString();
          final phone = (data['phone'] ?? '').toString();

          final deviceId = (data['deviceId'] ?? data['watchId'] ?? '')
              .toString();

          final loc = _asMap(data['location']);
          final lat = _toNum(loc['lat']);
          final lng = _toNum(loc['lng']);
          final accuracy = _toNum(loc['accuracy']);
          final address = (loc['address'] ?? '').toString();

          final note = (data['note'] ?? '').toString();
          final logs = _asLogList(data['logs']);

          final statusColor = _statusColor(cs, status);

          // ✅ withOpacity -> withValues(alpha: ...)
          final softBg = statusColor.withValues(alpha: 0.10);
          final softBorder = statusColor.withValues(alpha: 0.25);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Event：$eventId',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: softBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: softBorder),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _kv(
                            'uid',
                            uid.isEmpty ? '—' : uid,
                            onCopy: uid.isEmpty ? null : () => _copy(uid),
                          ),
                          _kv('建立時間', _fmtDt(createdAt)),
                          _kv('更新時間', _fmtDt(updatedAt)),
                          _kv(
                            '裝置',
                            deviceId.isEmpty ? '—' : deviceId,
                            onCopy: deviceId.isEmpty
                                ? null
                                : () => _copy(deviceId),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '使用者資訊',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _kv('姓名', userName.isEmpty ? '—' : userName),
                          _kv(
                            'Email',
                            userEmail.isEmpty ? '—' : userEmail,
                            onCopy: userEmail.isEmpty
                                ? null
                                : () => _copy(userEmail),
                          ),
                          _kv(
                            '電話',
                            phone.isEmpty ? '—' : phone,
                            onCopy: phone.isEmpty ? null : () => _copy(phone),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '定位資訊',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _kv(
                            'lat',
                            lat == 0 ? '—' : lat.toString(),
                            onCopy: lat == 0 ? null : () => _copy('$lat'),
                          ),
                          _kv(
                            'lng',
                            lng == 0 ? '—' : lng.toString(),
                            onCopy: lng == 0 ? null : () => _copy('$lng'),
                          ),
                          _kv(
                            'accuracy',
                            accuracy == 0 ? '—' : '${accuracy.toString()}m',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        address.isEmpty ? '地址：—' : '地址：$address',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: (lat == 0 || lng == 0)
                                ? null
                                : () => _openMaps(lat, lng),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('複製 Maps 連結'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '備註',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        note.isEmpty ? '—' : note,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '處理紀錄（logs）',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      if (logs.isEmpty)
                        Text('—', style: TextStyle(color: cs.onSurfaceVariant))
                      else
                        ...logs.map((m) {
                          final t = _toDt(
                            m['at'] ?? m['time'] ?? m['createdAt'],
                          );
                          final actor = (m['actor'] ?? m['by'] ?? '')
                              .toString();
                          final action = (m['action'] ?? m['type'] ?? '')
                              .toString();
                          final msg = (m['message'] ?? m['note'] ?? '')
                              .toString();

                          // ✅ cs.surfaceVariant (deprecated) -> cs.surfaceContainerHighest
                          final tileBg = cs.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: tileBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_fmtDt(t)}  •  ${actor.isEmpty ? '—' : actor}  •  ${action.isEmpty ? '—' : action}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (msg.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    msg,
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v, {VoidCallback? onCopy}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$k：',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
        Text(v, style: const TextStyle(fontSize: 12)),
        if (onCopy != null) ...[
          const SizedBox(width: 6),
          InkWell(onTap: onCopy, child: const Icon(Icons.copy, size: 16)),
        ],
      ],
    );
  }
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

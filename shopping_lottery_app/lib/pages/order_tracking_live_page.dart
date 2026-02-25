// lib/pages/order_tracking_live_page.dart
//
// ✅ OrderTrackingLivePage（最終完整版｜已修正 curly_braces_in_flow_control_structures）
// ------------------------------------------------------------
// - 訂單物流追蹤（示範版 UI）
// - 可選：從 Firestore 讀取 orders/{orderId} 的 tracking / shippingStatus 等欄位
// - ✅ 修正重點：所有 if 單行 statement 一律加上 { } 區塊
// - Web/App 可用（不使用 dart:io）
//
// 你只要覆蓋本檔即可編譯。
// 若你的資料結構不同：
// - collection 預設 orders，可自行改
// - 欄位建議：shippingStatus, shippingMethod, trackingNo, carrier, shippingEvents(List)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OrderTrackingLivePage extends StatelessWidget {
  final String orderId;
  final String collection;

  /// 可選：若你列表頁已帶入訂單資料可直接顯示
  final Map<String, dynamic>? initialData;

  const OrderTrackingLivePage({
    super.key,
    required this.orderId,
    this.collection = 'orders',
    this.initialData,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection(collection).doc(orderId);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(title: const Text('物流追蹤')),
      body: initialData != null
          ? _Body(orderId: orderId, data: initialData!)
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: ref.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _empty(
                    icon: Icons.error_outline,
                    title: '讀取失敗',
                    subtitle: snap.error.toString(),
                  );
                }
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }

                final doc = snap.data!;
                if (!doc.exists) {
                  return _empty(
                    icon: Icons.local_shipping_outlined,
                    title: '找不到訂單',
                    subtitle: '此訂單可能不存在或已刪除。\norderId: $orderId',
                  );
                }

                final data = doc.data() ?? <String, dynamic>{};
                return _Body(orderId: doc.id, data: data);
              },
            ),
    );
  }

  Widget _empty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.grey),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;

  const _Body({required this.orderId, required this.data});

  @override
  Widget build(BuildContext context) {
    final shippingStatus = _s(
      data['shippingStatus'],
      fallback: _s(data['status'], fallback: '—'),
    );
    final shippingMethod = _s(data['shippingMethod'], fallback: '—');
    final carrier = _s(data['carrier'], fallback: '—');
    final trackingNo = _s(data['trackingNo'], fallback: '—');

    final events = _eventsOf(data);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _headerCard(
          orderId: orderId,
          status: shippingStatus,
          method: shippingMethod,
          carrier: carrier,
          trackingNo: trackingNo,
        ),
        const SizedBox(height: 12),

        _sectionTitle('物流節點'),
        if (events.isEmpty) ...[
          _emptyInline(
            icon: Icons.timeline_outlined,
            title: '尚無物流更新',
            subtitle: '物流有更新時會顯示在這裡（示範）。',
          ),
        ] else ...[
          _timeline(events),
        ],

        const SizedBox(height: 12),
        _sectionTitle('操作'),
        _actions(context, trackingNo: trackingNo),
      ],
    );
  }

  Widget _headerCard({
    required String orderId,
    required String status,
    required String method,
    required String carrier,
    required String trackingNo,
  }) {
    final stColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: stColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.local_shipping_outlined, color: stColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '訂單 #$orderId',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _chip('狀態', _statusText(status), stColor),
                    _chip('方式', method, Colors.blueGrey),
                    _chip('物流商', carrier, Colors.blueGrey),
                    _chip('追蹤碼', trackingNo, Colors.blueGrey),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String k, String v, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$k：$v',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: c),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(
        t,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      ),
    );
  }

  Widget _emptyInline({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline(List<_ShipEvent> events) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (int i = 0; i < events.length; i++) ...[
            _timelineRow(
              events[i],
              isFirst: i == 0,
              isLast: i == events.length - 1,
            ),
            if (i != events.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _timelineRow(
    _ShipEvent e, {
    required bool isFirst,
    required bool isLast,
  }) {
    final dotColor = isFirst ? Colors.green : Colors.blueGrey;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            if (!isLast) ...[
              const SizedBox(height: 4),
              Container(width: 2, height: 38, color: Colors.grey.shade300),
            ],
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                e.subtitle,
                style: TextStyle(color: Colors.grey.shade700, height: 1.25),
              ),
              if (e.timeText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  e.timeText,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context, {required String trackingNo}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已重新整理（示範）')));
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新整理'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                // 這裡你可改成開啟物流商追蹤網址 / 或導到客服
                if (trackingNo.trim().isEmpty || trackingNo.trim() == '—') {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('尚無追蹤碼')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('查詢追蹤：$trackingNo（示範）')),
                  );
                }
              },
              icon: const Icon(Icons.search_rounded),
              label: const Text('查詢追蹤'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Data parse
  // ============================================================
  String _s(dynamic v, {String fallback = ''}) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  List<_ShipEvent> _eventsOf(Map<String, dynamic> data) {
    final raw =
        data['shippingEvents'] ?? data['events'] ?? data['trackingEvents'];
    if (raw is! List) {
      return const [];
    }

    final out = <_ShipEvent>[];
    for (final e in raw) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final title = _s(
          m['title'],
          fallback: _s(m['status'], fallback: '物流更新'),
        );
        final subtitle = _s(
          m['subtitle'],
          fallback: _s(m['desc'], fallback: _s(m['message'], fallback: '')),
        );
        final timeText = _timeText(m['time'] ?? m['createdAt'] ?? m['at']);
        out.add(
          _ShipEvent(
            title: title,
            subtitle: subtitle.isEmpty ? '（無內容）' : subtitle,
            timeText: timeText,
          ),
        );
      }
    }

    // 若 events 沒時間，照原順序即可；有時間也不強制排序避免 parse 失敗
    return out;
  }

  String _timeText(dynamic v) {
    DateTime? d;
    if (v is Timestamp) {
      d = v.toDate();
    } else if (v is DateTime) {
      d = v;
    } else if (v is String) {
      // 嘗試 parse ISO
      d = DateTime.tryParse(v);
    }

    if (d == null) {
      return '';
    }

    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }

  String _statusText(String raw) {
    final s = raw.toLowerCase().trim();
    if (s.isEmpty || s == '—') {
      return '—';
    }
    if (s.contains('pending') || s.contains('created')) {
      return '待出貨';
    }
    if (s.contains('ship') || s.contains('shipping')) {
      return '配送中';
    }
    if (s.contains('done') ||
        s.contains('complete') ||
        s.contains('delivered')) {
      return '已送達';
    }
    if (s.contains('cancel')) {
      return '已取消';
    }
    return raw;
  }

  Color _statusColor(String raw) {
    final s = raw.toLowerCase().trim();
    if (s.contains('ship') || s.contains('shipping')) {
      return Colors.blue;
    }
    if (s.contains('done') ||
        s.contains('complete') ||
        s.contains('delivered')) {
      return Colors.green;
    }
    if (s.contains('cancel')) {
      return Colors.redAccent;
    }
    if (s.contains('pending') || s.contains('created')) {
      return Colors.orange;
    }
    return Colors.blueGrey;
  }
}

class _ShipEvent {
  final String title;
  final String subtitle;
  final String timeText;

  const _ShipEvent({
    required this.title,
    required this.subtitle,
    required this.timeText,
  });
}

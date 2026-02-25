// lib/pages/event_plaza_page.dart
//
// ✅ EventPlazaPage（活動廣場｜可編譯完整版）
// - Firestore: campaigns
//   欄位建議：title, description, isActive(bool), startAt, endAt, vendorId, createdAt
// - 搜尋活動標題
// - 只顯示啟用中（可切換）
// - 右上角：進入通知中心（建議走 /notifications route；沒路由就 fallback 直接 push page）
//
// ✅ 修正：
// - NotificationPage 不是 class -> 改用 NotificationsPage
// - withOpacity -> withValues(alpha: ...)
// - if 單行加大括號（避免 curly_braces_in_flow_control_structures）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'notifications/notifications_page.dart';

class EventPlazaPage extends StatefulWidget {
  const EventPlazaPage({super.key});

  @override
  State<EventPlazaPage> createState() => _EventPlazaPageState();
}

class _EventPlazaPageState extends State<EventPlazaPage> {
  final _db = FirebaseFirestore.instance;
  final _search = TextEditingController();

  bool _onlyActive = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  Query<Map<String, dynamic>> _baseQuery() {
    // 盡量用 createdAt 排序；若你 campaigns 沒 createdAt，可改成 startAt 或拿掉 orderBy
    return _db.collection('campaigns').orderBy('createdAt', descending: true);
  }

  bool _match(Map<String, dynamic> d) {
    final q = _search.text.trim().toLowerCase();
    final title = _s(d['title']).toLowerCase();
    final desc = _s(d['description']).toLowerCase();

    final isActive = d['isActive'] == true;

    if (_onlyActive && !isActive) {
      return false;
    }
    if (q.isEmpty) {
      return true;
    }
    return title.contains(q) || desc.contains(q);
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) {
      return v.toDate();
    }
    if (v is DateTime) {
      return v;
    }
    return null;
  }

  String _fmtDate(DateTime? d) {
    if (d == null) {
      return '-';
    }
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y/$m/$day';
  }

  void _goNotifications() {
    // ✅ 最穩：用 route（你 main.dart 若有 '/notifications' 就一定成功）
    try {
      Navigator.of(context).pushNamed('/notifications');
      return;
    } catch (_) {
      // ignore and fallback below
    }

    // ✅ fallback：直接 push page（確保你 import 的 class 名稱正確：NotificationsPage）
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '活動廣場',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '通知中心',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _goNotifications,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜尋活動（標題/描述）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: const Text('只看啟用中'),
                  selected: _onlyActive,
                  onSelected: (v) => setState(() => _onlyActive = v),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('讀取失敗：${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs
                    .where((e) => _match(e.data()))
                    .toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      _onlyActive ? '目前沒有啟用中的活動' : '目前沒有活動',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final d = doc.data();

                    final rawTitle = _s(d['title']);
                    final title = rawTitle.isEmpty ? '(未命名活動)' : rawTitle;

                    final desc = _s(d['description']);
                    final isActive = d['isActive'] == true;

                    final startAt = _toDate(d['startAt']);
                    final endAt = _toDate(d['endAt']);
                    final vendorId = _s(d['vendorId']);

                    return ListTile(
                      leading: Icon(
                        isActive
                            ? Icons.local_activity_outlined
                            : Icons.local_activity,
                        color: isActive ? cs.primary : Colors.grey,
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        [
                          '期間：${_fmtDate(startAt)} ~ ${_fmtDate(endAt)}',
                          if (vendorId.isNotEmpty) 'vendorId: $vendorId',
                          if (desc.isNotEmpty) desc,
                        ].join('\n'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isActive
                          ? Chip(
                              label: const Text('啟用中'),
                              backgroundColor: cs.primaryContainer.withValues(
                                alpha: 0.55,
                              ),
                            )
                          : const Chip(label: Text('未啟用')),
                      onTap: () => _showDetail(
                        context,
                        title: title,
                        data: d,
                        id: doc.id,
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

  void _showDetail(
    BuildContext context, {
    required String title,
    required Map<String, dynamic> data,
    required String id,
  }) {
    final desc = _s(data['description']);
    final startAt = _toDate(data['startAt']);
    final endAt = _toDate(data['endAt']);
    final vendorId = _s(data['vendorId']);
    final isActive = data['isActive'] == true;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text('活動ID：$id'),
            const SizedBox(height: 6),
            Text('狀態：${isActive ? '啟用中' : '未啟用'}'),
            const SizedBox(height: 6),
            Text('期間：${_fmtDate(startAt)} ~ ${_fmtDate(endAt)}'),
            if (vendorId.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('vendorId：$vendorId'),
            ],
            if (desc.isNotEmpty) ...[const SizedBox(height: 10), Text(desc)],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('關閉'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

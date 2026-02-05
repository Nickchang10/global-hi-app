// lib/pages/live/live_list_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LiveListPage extends StatelessWidget {
  const LiveListPage({super.key});

  List<Map<String, dynamic>> _sampleSessions() {
    return [
      {
        'id': 'l1',
        'title': 'Osmile 新產品直播',
        'host': 'Alice',
        'thumbnail': 'https://picsum.photos/seed/live1/800/400',
        'scheduledAt': '今天 14:00',
        'viewers': 125
      },
      {
        'id': 'l2',
        'title': '健身鞋穿搭 & 測評',
        'host': 'Bob',
        'thumbnail': 'https://picsum.photos/seed/live2/800/400',
        'scheduledAt': '明天 19:30',
        'viewers': 82
      },
      {
        'id': 'l3',
        'title': '藍牙耳機深度比較',
        'host': 'Carol',
        'thumbnail': 'https://picsum.photos/seed/live3/800/400',
        'scheduledAt': '本週五 20:00',
        'viewers': 20
      },
    ];
  }

  List<Map<String, dynamic>> _readSessionsFromService(BuildContext context) {
    try {
      final live = Provider.of<dynamic>(context, listen: false);
      if (live == null) return _sampleSessions();
      try {
        final s = live.sessions;
        if (s is List) return List<Map<String, dynamic>>.from(s.map((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          // try convert object to map via known properties
          try {
            return {
              'id': e.id,
              'title': e.title,
              'host': e.host,
              'thumbnail': e.thumbnailUrl ?? e.thumbnail ?? null,
              'scheduledAt': e.scheduledAt?.toString() ?? ''
            };
          } catch (_) {
            return <String, dynamic>{};
          }
        }));
      } catch (_) {}

      // try call method if exists
      try {
        final res = live.getSessions != null ? live.getSessions() : null;
        if (res is List) return List<Map<String, dynamic>>.from(res.map((e) => e is Map ? Map<String,dynamic>.from(e) : <String,dynamic>{}));
      } catch (_) {}
    } catch (_) {}
    return _sampleSessions();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _readSessionsFromService(context);
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: sessions.isEmpty
                ? const Center(child: Text('尚無直播'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: sessions.length,
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      final thumb = s['thumbnail'] ?? s['thumbnailUrl'] ?? 'https://picsum.photos/seed/live${i}/800/400';
                      final title = s['title'] ?? '直播';
                      final host = s['host'] ?? '主持人';
                      final sched = s['scheduledAt'] ?? '';
                      final viewers = s['viewers'] ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 120,
                                  height: 80,
                                  color: Colors.grey[200],
                                  child: Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.live_tv)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text('主持人 $host · $sched', style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  OutlinedButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('提醒我（示範）'))), child: const Text('提醒我')),
                                  const SizedBox(height: 6),
                                  IconButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('追蹤（示範）'))), icon: const Icon(Icons.favorite_border)),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

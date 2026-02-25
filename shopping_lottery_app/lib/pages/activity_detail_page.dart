// lib/pages/activity_detail_page.dart
import 'package:flutter/material.dart';

class ActivityDetailPage extends StatelessWidget {
  const ActivityDetailPage({super.key, this.args});

  final Object? args;

  Map<String, dynamic> _asMap(Object? a) {
    if (a is Map) return Map<String, dynamic>.from(a);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final m = _asMap(args);

    final title = (m['title'] ?? '活動詳情').toString();
    final subtitle = (m['subtitle'] ?? m['message'] ?? '').toString();
    final content = (m['content'] ?? m['body'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('活動詳情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Text(
              content.trim().isEmpty ? '（尚未提供活動內容）' : content,
              style: const TextStyle(height: 1.45),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    try {
                      Navigator.of(context).pushNamed('/lotterys');
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('尚未設定 /lotterys 路由')),
                      );
                    }
                  },
                  child: const Text('前往抽獎'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    try {
                      Navigator.of(context).pushNamed('/shop');
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('尚未設定 /shop 路由')),
                      );
                    }
                  },
                  child: const Text('去逛商店'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

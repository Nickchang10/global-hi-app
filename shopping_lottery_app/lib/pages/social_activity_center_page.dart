import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ✅ 注意：若你的 pubspec name 不是 osmile_shopping_app，
// 這行 package import 請依你的專案名稱調整。
import 'package:osmile_shopping_app/services/social_service.dart';

/// ✅ SocialActivityCenterPage（社群活動中心｜完整版｜可編譯）
/// ------------------------------------------------------------
/// - 修正：withOpacity deprecated → withValues(alpha: ...)
/// - 本頁自帶 ChangeNotifierProvider，避免你忘了在 main 注入
/// - 活動資料來源：SocialService.activities（Firestore / fallback mock）
class SocialActivityCenterPage extends StatelessWidget {
  const SocialActivityCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SocialService>(
      create: (_) => SocialService()..init(),
      child: const _SocialActivityCenterBody(),
    );
  }
}

class _SocialActivityCenterBody extends StatefulWidget {
  const _SocialActivityCenterBody();

  @override
  State<_SocialActivityCenterBody> createState() =>
      _SocialActivityCenterBodyState();
}

class _SocialActivityCenterBodyState extends State<_SocialActivityCenterBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SocialService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('社群活動中心'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '進行中'),
            Tab(text: '即將開始'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => context.read<SocialService>().refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: s.loading
          ? const Center(child: CircularProgressIndicator())
          : (s.error != null && s.activities.isEmpty)
          ? Center(child: Text('讀取失敗：${s.error}'))
          : TabBarView(
              controller: _tab,
              children: <Widget>[
                _list(context, _filterAll(s.activities)),
                _list(context, _filterOngoing(s.activities)),
                _list(context, _filterUpcoming(s.activities)),
              ],
            ),
    );
  }

  List<SocialActivity> _filterAll(List<SocialActivity> list) => list;

  List<SocialActivity> _filterOngoing(List<SocialActivity> list) {
    final now = DateTime.now();
    return list.where((a) {
      final st = a.startAt;
      final ed = a.endAt;
      if (st == null && ed == null) return true;
      if (st != null && now.isBefore(st)) return false;
      if (ed != null && now.isAfter(ed)) return false;
      return true;
    }).toList();
  }

  List<SocialActivity> _filterUpcoming(List<SocialActivity> list) {
    final now = DateTime.now();
    return list
        .where((a) => a.startAt != null && now.isBefore(a.startAt!))
        .toList();
  }

  Widget _list(BuildContext context, List<SocialActivity> items) {
    if (items.isEmpty) {
      return const Center(child: Text('目前沒有資料'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _activityCard(context, items[i]),
    );
  }

  Widget _activityCard(BuildContext context, SocialActivity a) {
    final s = context.read<SocialService>();
    final now = DateTime.now();

    String statusText() {
      if (a.startAt != null && now.isBefore(a.startAt!)) return '即將開始';
      if (a.endAt != null && now.isAfter(a.endAt!)) return '已結束';
      return '進行中';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cover(a.coverUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          // ✅ withOpacity deprecated → withValues(alpha: ...)
                          color: Colors.blueAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusText(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 16,
                        // ✅ withOpacity deprecated → withValues(alpha: ...)
                        color: Colors.redAccent.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${a.likes}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.group, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${a.participants}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => s.likeActivity(a.id),
                        icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                        label: const Text('讚'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: () async {
                          try {
                            await s.joinActivity(a.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已參加：${a.title}')),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('參加失敗：$e')));
                          }
                        },
                        child: const Text('參加'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 84,
        height: 84,
        child: (url != null && url.isNotEmpty)
            ? Image.network(url, fit: BoxFit.cover)
            : Container(
                color: Colors.grey.shade300,
                child: const Center(child: Icon(Icons.campaign_outlined)),
              ),
      ),
    );
  }
}

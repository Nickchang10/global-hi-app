import 'package:flutter/material.dart';
import 'videos_page.dart';

class HealthVideosSection extends StatelessWidget {
  const HealthVideosSection({super.key});

  static final List<Map<String, String>> kVideos = VideosPage.kVideos;

  @override
  Widget build(BuildContext context) {
    final v1 = kVideos.isNotEmpty ? kVideos[0] : null;
    final v2 = kVideos.length > 1 ? kVideos[1] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('健康影片', style: TextStyle(fontWeight: FontWeight.w900)),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/videos'),
              child: const Text('查看更多'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _VideoCard(
                title: v1?['title'] ?? '影片',
                duration: v1?['duration'] ?? '',
                url: v1?['url'] ?? '',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VideoCard(
                title: v2?['title'] ?? '影片',
                duration: v2?['duration'] ?? '',
                url: v2?['url'] ?? '',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  final String title;
  final String duration;
  final String url;

  const _VideoCard({
    required this.title,
    required this.duration,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(
          context,
        ).pushNamed('/video', arguments: {'title': title, 'url': url});
      },
      child: Ink(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              right: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (duration.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        duration,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 底部漸層讓白字更清楚
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.55),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class VideoPlayerPage extends StatefulWidget {
  final Object? args;
  const VideoPlayerPage({super.key, this.args});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final String title;
  late final String url;

  YoutubePlayerController? _yt;

  @override
  void initState() {
    super.initState();
    final m = (widget.args is Map)
        ? Map<String, dynamic>.from(widget.args as Map)
        : <String, dynamic>{};

    title = (m['title'] ?? '影片').toString();
    url = (m['url'] ?? '').toString().trim();

    final vid = _extractYouTubeId(url);
    if (vid != null) {
      _yt = YoutubePlayerController.fromVideoId(
        videoId: vid,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _yt?.close();
    super.dispose();
  }

  String? _extractYouTubeId(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    final m1 = RegExp(r'youtu\.be\/([A-Za-z0-9_-]{6,})').firstMatch(s);
    if (m1 != null) return m1.group(1);

    final m2 = RegExp(r'[?&]v=([A-Za-z0-9_-]{6,})').firstMatch(s);
    if (m2 != null) return m2.group(1);

    final m3 = RegExp(r'embed\/([A-Za-z0-9_-]{6,})').firstMatch(s);
    if (m3 != null) return m3.group(1);

    return null;
  }

  Future<void> _openInBrowser() async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('網址不正確')));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasYouTube = _yt != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '用瀏覽器開啟',
            onPressed: url.isEmpty ? null : _openInBrowser,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: hasYouTube
            ? YoutubePlayerScaffold(
                controller: _yt!,
                builder: (context, player) {
                  return Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: player,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        url,
                        style: TextStyle(color: Colors.grey.shade700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_outline, size: 56),
                    const SizedBox(height: 10),
                    const Text('目前內嵌播放支援 YouTube'),
                    const SizedBox(height: 6),
                    Text(
                      url.isEmpty ? '（未提供影片網址）' : url,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: url.isEmpty ? null : _openInBrowser,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('用瀏覽器開啟'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

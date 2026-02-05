import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoAdminPage extends StatefulWidget {
  const VideoAdminPage({super.key});

  @override
  State<VideoAdminPage> createState() => _VideoAdminPageState();
}

class _VideoAdminPageState extends State<VideoAdminPage> {
  final List<Map<String, String>> videos = [
    {
      "title": "Osmile 品牌形象影片",
      "url": "https://www.youtube.com/watch?v=84WIaK3bl_s",
      "type": "YouTube",
    },
    {
      "title": "ED1000 智慧手錶介紹",
      "url": "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
      "type": "MP4",
    },
  ];

  void _addVideoDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("新增影片"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "影片標題"),
            ),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: "影片網址（YouTube 或 MP4）"),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("取消"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("新增"),
            onPressed: () {
              final title = titleController.text.trim();
              final url = urlController.text.trim();
              if (title.isEmpty || url.isEmpty) return;

              final isYouTube = url.contains("youtube.com") || url.contains("youtu.be");
              setState(() {
                videos.add({
                  "title": title,
                  "url": url,
                  "type": isYouTube ? "YouTube" : "MP4",
                });
              });

              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _deleteVideo(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("刪除影片"),
        content: Text("確定要刪除「${videos[index]["title"]}」嗎？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                videos.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text("刪除"),
          ),
        ],
      ),
    );
  }

  void _openPlayer(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenVideoPlayer(videoUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("影片管理中心"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addVideoDialog,
          ),
        ],
      ),
      body: videos.isEmpty
          ? const Center(child: Text("目前沒有影片"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final v = videos[index];
                final isYouTube = v["type"] == "YouTube";
                final thumb = isYouTube
                    ? "https://img.youtube.com/vi/${YoutubePlayer.convertUrlToId(v["url"] ?? "")}/0.jpg"
                    : "https://cdn.pixabay.com/photo/2016/03/27/21/16/smartwatch-1289198_1280.jpg";

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(thumb,
                          width: 70,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                                width: 70,
                                height: 50,
                                color: Colors.grey[300],
                                child: const Icon(Icons.videocam, color: Colors.grey),
                              )),
                    ),
                    title: Text(v["title"] ?? ""),
                    subtitle: Text(v["type"] ?? "",
                        style: const TextStyle(color: Colors.grey)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: Colors.blueAccent),
                          onPressed: () => _openPlayer(v["url"] ?? ""),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteVideo(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// 🎬 全螢幕播放（共用元件，可放這頁內）
class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _FullScreenVideoPlayer({required this.videoUrl});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isYouTube = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    if (widget.videoUrl.contains("youtube.com") ||
        widget.videoUrl.contains("youtu.be")) {
      _isYouTube = true;
      final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId ?? "",
        flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
      );
    } else {
      _isYouTube = false;
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..initialize().then((_) {
          setState(() {
            _chewieController = ChewieController(
              videoPlayerController: _videoController!,
              autoPlay: true,
              looping: false,
            );
          });
        });
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("影片播放"),
      ),
      body: Center(
        child: _isYouTube
            ? YoutubePlayer(controller: _youtubeController!)
            : (_chewieController != null &&
                    _videoController!.value.isInitialized)
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

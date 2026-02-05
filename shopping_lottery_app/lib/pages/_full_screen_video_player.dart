// ----------------------📺 全螢幕影片播放組件 ----------------------

import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _FullScreenVideoPlayer({required this.videoUrl});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  YoutubePlayerController? _youtubeController;
  bool _isYouTube = false;

  @override
  void initState() {
    super.initState();

    final url = widget.videoUrl;

    // 檢查是不是 YouTube 影片
    if (url.contains("youtube.com") || url.contains("youtu.be")) {
      _isYouTube = true;
      final id = YoutubePlayer.convertUrlToId(url);
      if (id != null) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: id,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
          ),
        );
      }
    } else {
      _isYouTube = false;
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: true,
            looping: false,
          );
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "播放影片",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: _isYouTube
            ? YoutubePlayer(
                controller: _youtubeController!,
                showVideoProgressIndicator: true,
              )
            : (_chewieController != null &&
                    _videoController!.value.isInitialized)
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

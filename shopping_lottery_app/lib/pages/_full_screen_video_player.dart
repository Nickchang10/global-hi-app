// lib/pages/_full_screen_video_player.dart
//
// ✅ FullScreenVideoPlayer（最終完整版｜修正 onPopInvoked deprecated｜控制列即時更新｜修掉 focusScopeNode）
// ------------------------------------------------------------
// - PopScope.onPopInvokedWithResult（取代 deprecated onPopInvoked）
// - 進入全螢幕：鎖定橫向 + 沉浸式 UI（Web 會跳過旋轉）
// - 離開：暫停播放 + 恢復直向 + 恢復系統 UI
// - ✅ 控制列時間/播放狀態即時更新（ValueListenableBuilder 監聽 controller）
// - ✅ 修正：不要用 NavigatorState.focusScopeNode（不存在），改用 FocusScope/FocusManager unfocus
//
// 依賴：video_player

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  /// 用既有 controller 開全螢幕（列表頁常先初始化好 controller）
  const FullScreenVideoPlayer.controller({
    super.key,
    required this.controller,
    this.title,
    this.disposeController = false,
    this.autoPlay = true,
  }) : url = null;

  /// 直接用 url 開全螢幕（內部建立 controller）
  const FullScreenVideoPlayer.url({
    super.key,
    required this.url,
    this.title,
    this.autoPlay = true,
  }) : controller = null,
       disposeController = true;

  final String? title;

  /// 二選一：controller 或 url
  final VideoPlayerController? controller;
  final String? url;

  /// 若 controller 外部傳入通常不要 dispose；若由此頁建立則會 dispose
  final bool disposeController;

  /// 進來是否自動播放
  final bool autoPlay;

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;

  bool _showControls = true;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();

    _controller =
        widget.controller ??
        VideoPlayerController.networkUrl(
          Uri.parse(widget.url!),
          // ⚠️ 這個建構子不是 const，不要加 const
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );

    _initFuture = _ensureInit();

    // ✅ 讓 push 完成後再進全螢幕比較穩
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enterFullScreen();
    });
  }

  Future<void> _ensureInit() async {
    if (!_controller.value.isInitialized) {
      await _controller.initialize();
    }
    if (widget.autoPlay && !_controller.value.isPlaying) {
      await _controller.play();
    }
  }

  void _unfocus() {
    // ✅ 不要用 Navigator.of(context).focusScopeNode（不存在）
    try {
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (_) {}
    try {
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (_) {}
  }

  Future<void> _enterFullScreen() async {
    _unfocus();
    try {
      if (!kIsWeb) {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _exitFullScreen() async {
    _unfocus();

    try {
      if (_controller.value.isPlaying) {
        await _controller.pause();
      }
    } catch (_) {}

    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}

    try {
      if (!kIsWeb) {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    } catch (_) {}
  }

  Future<void> _pop() async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;

    await _exitFullScreen();
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    // 保險：避免被系統強制關閉時沒走到 _pop()
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
    try {
      if (!kIsWeb) {
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    } catch (_) {}

    try {
      if (_controller.value.isPlaying) {
        _controller.pause();
      }
    } catch (_) {}

    if (widget.disposeController) {
      _controller.dispose();
    }
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: false,
          bottom: false,
          child: FutureBuilder<void>(
            future: _initFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white70,
                          size: 42,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '影片初始化失敗',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snap.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _pop,
                          icon: const Icon(Icons.close),
                          label: const Text('關閉'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!_controller.value.isInitialized) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white70,
                        size: 42,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '影片尚未初始化',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _pop,
                        icon: const Icon(Icons.close),
                        label: const Text('關閉'),
                      ),
                    ],
                  ),
                );
              }

              return GestureDetector(
                onTap: () {
                  _unfocus();
                  setState(() {
                    _showControls = !_showControls;
                  });
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: (_controller.value.aspectRatio == 0)
                            ? (16 / 9)
                            : _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),

                    // Controls overlay（✅ 會即時更新）
                    AnimatedOpacity(
                      opacity: _showControls ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: _ControlsOverlay(
                          title: widget.title,
                          controller: _controller,
                          onClose: _pop,
                          fmt: _fmt,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.title,
    required this.controller,
    required this.onClose,
    required this.fmt,
  });

  final String? title;
  final VideoPlayerController controller;
  final VoidCallback onClose;
  final String Function(Duration d) fmt;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, v, _) {
        final dur = v.duration;
        final pos = v.position;
        final isPlaying = v.isPlaying;

        return Stack(
          children: [
            // 上方漸層
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 84,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xAA000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),

            // 下方漸層
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xAA000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),

            // Top bar
            Positioned(
              left: 8,
              right: 8,
              top: 10,
              child: Row(
                children: [
                  IconButton(
                    tooltip: '關閉',
                    onPressed: onClose,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (title ?? '').trim().isEmpty ? '播放中' : title!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Center play/pause
            Center(
              child: InkWell(
                onTap: () async {
                  if (isPlaying) {
                    await controller.pause();
                  } else {
                    await controller.play();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0x66000000),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            ),

            // Bottom bar
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    colors: const VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        fmt(pos),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dur.inMilliseconds > 0 ? fmt(dur) : '--:--',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

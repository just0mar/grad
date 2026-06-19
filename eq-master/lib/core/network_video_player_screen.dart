import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A full-screen, in-app player for a video streamed from the API.
///
/// Streams from [url] (an absolute http(s) URL) using [headers] for
/// authentication. Handles loading, errors, play/pause, scrubbing and a
/// simple auto-hiding control bar.
class NetworkVideoPlayerScreen extends StatefulWidget {
  final String url;
  final Map<String, String> headers;
  final String title;

  const NetworkVideoPlayerScreen({
    super.key,
    required this.url,
    this.headers = const {},
    this.title = '',
  });

  @override
  State<NetworkVideoPlayerScreen> createState() =>
      _NetworkVideoPlayerScreenState();
}

class _NetworkVideoPlayerScreenState extends State<NetworkVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _seeking = false;
  String? _error;
  bool _controlsVisible = true;
  DateTime _lastUiRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    VideoPlayerController? controller;
    try {
      final canSendHeaders = !kIsWeb && widget.headers.isNotEmpty;
      controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: canSendHeaders ? widget.headers : const {},
      );
      await controller.setLooping(false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onControllerUpdate);
      setState(() {
        _controller = controller;
        _initializing = false;
      });
      await controller.play();
    } catch (e) {
      debugPrint('Video player failed for ${widget.url}: $e');
      await controller?.dispose();
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'This video could not be played.';
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final c = _controller;
    if (c != null && c.value.hasError && _error == null) {
      setState(() {
        _error = c.value.errorDescription?.isNotEmpty == true
            ? 'This video could not be played.\n${c.value.errorDescription}'
            : 'This video could not be played.';
      });
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastUiRefresh) < const Duration(milliseconds: 300)) {
      return;
    }
    _lastUiRefresh = now;
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
      _controlsVisible = true;
    });
  }

  Future<void> _seekBy(Duration delta) async {
    final c = _controller;
    if (c == null || _seeking) return;

    final value = c.value;
    final duration = value.duration;
    final wasPlaying = value.isPlaying;
    var target = value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;

    setState(() {
      _seeking = true;
      _controlsVisible = true;
    });

    try {
      if (wasPlaying) await c.pause();
      await c.seekTo(target);
      if (wasPlaying && mounted) await c.play();
    } finally {
      if (mounted) {
        setState(() => _seeking = false);
      }
    }
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  Widget _roundControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    double size = 58,
    double iconSize = 34,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.42),
            foregroundColor: Colors.white,
          ),
          iconSize: iconSize,
          icon: Icon(icon),
          onPressed: onPressed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'SFPro', fontSize: 16),
        ),
      ),
      body: Center(
        child: _initializing
            ? const CircularProgressIndicator(color: Colors.white)
            : _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white70,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'SFPro',
                      ),
                    ),
                  ],
                ),
              )
            : controller == null
            ? const SizedBox.shrink()
            : GestureDetector(
                onTap: () =>
                    setState(() => _controlsVisible = !_controlsVisible),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: controller.value.aspectRatio == 0
                          ? 16 / 9
                          : controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                    if (controller.value.isBuffering || _seeking)
                      const Positioned(
                        top: 24,
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    if (_controlsVisible) ...[
                      Container(color: Colors.black26),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _roundControl(
                            icon: Icons.replay_10,
                            tooltip: 'Back 10 seconds',
                            onPressed: () =>
                                _seekBy(const Duration(seconds: -10)),
                          ),
                          const SizedBox(width: 18),
                          _roundControl(
                            icon: controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            tooltip: controller.value.isPlaying
                                ? 'Pause'
                                : 'Play',
                            size: 70,
                            iconSize: 42,
                            onPressed: _togglePlay,
                          ),
                          const SizedBox(width: 18),
                          _roundControl(
                            icon: Icons.forward_10,
                            tooltip: 'Forward 10 seconds',
                            onPressed: () =>
                                _seekBy(const Duration(seconds: 10)),
                          ),
                        ],
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 42,
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          colors: const VideoProgressColors(
                            playedColor: Colors.green,
                            bufferedColor: Colors.white30,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 16,
                        child: Row(
                          children: [
                            Text(
                              _fmt(controller.value.position),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _fmt(controller.value.duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

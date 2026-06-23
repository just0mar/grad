import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/file_cache_service.dart';

class AppVideoPlayer extends StatefulWidget {
  final String url;
  final bool autoPlay;
  final bool showControls;

  const AppVideoPlayer({
    super.key,
    required this.url,
    this.autoPlay = false,
    this.showControls = true,
  });

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  String? _error;
  bool _controlsVisible = true;
  bool _seeking = false;
  DateTime _lastUiRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(AppVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      setState(() {
        _initializing = true;
        _error = null;
      });
      _initVideo();
    }
  }

    Future<void> _initVideo() async {
    try {
      VideoPlayerController controller;
      final uri = Uri.parse(widget.url);
      final isNetwork = widget.url.startsWith('http') || widget.url.startsWith('blob:');

      if (!isNetwork && !kIsWeb) {
        controller = VideoPlayerController.file(File(widget.url));
      } else {
        if (kIsWeb) {
          controller = VideoPlayerController.networkUrl(uri);
        } else {
          // Use local cache on mobile to bypass streaming auth issues
          try {
            final tempFile = await FileCacheService.instance.getFile(
              widget.url,
              extension: '.mp4',
              contentType: 'video/mp4',
            );
            controller = VideoPlayerController.file(tempFile);
          } catch (e) {
            debugPrint('AppVideoPlayer: Cache fallback failed for ${widget.url}: $e');
            // Fallback to network
            controller = VideoPlayerController.networkUrl(uri);
          }
        }
      }

      _controller = controller;
      controller.addListener(_onControllerUpdate);

      await controller.initialize();
      if (widget.autoPlay) {
        await controller.play();
      }

      if (mounted) {
        setState(() => _initializing = false);
      }
    } catch (e) {
      debugPrint('AppVideoPlayer failed: $e');
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'This video could not be played.';
        });
      }
    }
  }

  void _onControllerUpdate() {
    final c = _controller;
    if (c == null) return;

    if (c.value.hasError && _error == null) {
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
    if (_initializing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
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
        ),
      );
    }
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => setState(() => _controlsVisible = !_controlsVisible),
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
          if (widget.showControls && _controlsVisible) ...[
            Container(color: Colors.black26),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _roundControl(
                  icon: Icons.replay_10,
                  tooltip: 'Back 10 seconds',
                  onPressed: () => _seekBy(const Duration(seconds: -10)),
                ),
                const SizedBox(width: 18),
                _roundControl(
                  icon: controller.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  tooltip: controller.value.isPlaying ? 'Pause' : 'Play',
                  size: 70,
                  iconSize: 42,
                  onPressed: _togglePlay,
                ),
                const SizedBox(width: 18),
                _roundControl(
                  icon: Icons.forward_10,
                  tooltip: 'Forward 10 seconds',
                  onPressed: () => _seekBy(const Duration(seconds: 10)),
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
    );
  }
}

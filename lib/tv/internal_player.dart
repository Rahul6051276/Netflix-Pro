import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:android_intent_plus/android_intent.dart';

class InternalPlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;

  InternalPlayerScreen({
    super.key,
    String? videoUrl,
    String? streamUrl,
    required this.title,
  }) : streamUrl = (streamUrl != null && streamUrl.isNotEmpty)
            ? streamUrl
            : (videoUrl ?? '');

  @override
  State<InternalPlayerScreen> createState() => _InternalPlayerScreenState();
}

typedef TvPlayerScreen = InternalPlayerScreen;

class _InternalPlayerScreenState extends State<InternalPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInit = false;
  bool _showControls = true;
  Timer? _hideTimer;
  int _scaleMode = 0; // 0: Fit (16:9), 1: Stretch, 2: Zoom/Crop

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initVideo();
  }

  void _initVideo() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.streamUrl),
      httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) CinemaTV/1.0',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      },
    );

    try {
      await _controller.initialize();
      _controller.play();
      if (mounted) setState(() => _isInit = true);

      _controller.addListener(() {
        if (mounted) setState(() {});
      });

      _startHideTimer();
    } catch (_) {}
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _launchJustPlayer() async {
    _controller.pause();
    final intent = AndroidIntent(
      action: 'action_view',
      data: widget.streamUrl,
      type: 'video/*',
      package: 'com.brouken.player',
      arguments: {'title': widget.title},
    );
    try {
      await intent.launch();
    } catch (_) {
      final fallback = AndroidIntent(
        action: 'action_view',
        data: widget.streamUrl,
        type: 'video/*',
      );
      await fallback.launch();
    }
  }

  void _cycleScaleMode() {
    setState(() {
      _scaleMode = (_scaleMode + 1) % 3;
    });
  }

  void _handleDpad(LogicalKeyboardKey key) {
    setState(() => _showControls = true);
    _startHideTimer();

    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (_isInit) {
        _controller.value.isPlaying ? _controller.pause() : _controller.play();
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (_isInit) {
        final pos = _controller.value.position + const Duration(seconds: 15);
        _controller.seekTo(pos);
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (_isInit) {
        final pos = _controller.value.position - const Duration(seconds: 15);
        _controller.seekTo(pos > Duration.zero ? pos : Duration.zero);
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _launchJustPlayer();
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _cycleScaleMode();
    } else if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    if (_isInit) _controller.dispose();
    super.dispose();
  }

  Widget _buildVideo() {
    if (!_isInit) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
    }

    if (_scaleMode == 1) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      );
    } else if (_scaleMode == 2) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = _isInit ? _controller.value.position : Duration.zero;
    final dur = _isInit ? _controller.value.duration : Duration.zero;

    return Focus(
      autofocus: true,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          _handleDpad(event.logicalKey);
        }
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          alignment: Alignment.center,
          children: [
            _buildVideo(),

            // Top Header: Title aur Just Player Hint
            if (_showControls)
              Positioned(
                top: 28,
                left: 36,
                right: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '▲ Open in Just Player',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom Progress Bar & TV remote hints
            if (_showControls && _isInit)
              Positioned(
                bottom: 24,
                left: 36,
                right: 36,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: Colors.white24,
                        color: const Color(0xFFE50914),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_formatDuration(pos)} / ${_formatDuration(dur)}',
                              style: const TextStyle(color: Colors.white, fontSize: 14)),
                          Text(
                            _scaleMode == 0 ? 'FIT (16:9)' : (_scaleMode == 1 ? 'STRETCH' : 'ZOOM (CROP)'),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const Text('◀ 15s | OK Play/Pause | 15s ▶',
                              style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

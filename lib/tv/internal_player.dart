// ============================================================================
// MOBILE JUST PLAYER INTERNAL ENGINE (TOUCH GESTURES & SCRUBBER SEEK)
// ============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

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

class _InternalPlayerScreenState extends State<InternalPlayerScreen>
    with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInit = false;
  bool _hasError = false;

  bool _showOverlay = true;
  Timer? _hideTimer;

  int _scaleMode = 0; // 0: FIT, 1: STRETCH, 2: CROP
  String _toastMessage = '';
  Timer? _toastTimer;

  double _touchDragOffset = 0;
  bool _isTouching = false;
  int _seekOffsetSec = 0;
  Duration _targetSeekPos = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _cleanExit();
    }
  }

  void _cleanExit() {
    _hideTimer?.cancel();
    _toastTimer?.cancel();
    if (_isInit) {
      _controller.pause();
      _controller.dispose();
      _isInit = false;
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.streamUrl),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      );

      await _controller.initialize();
      _controller.play();

      if (mounted) setState(() => _isInit = true);

      _controller.addListener(() {
        if (mounted && !_isTouching) setState(() {});
      });

      _startOverlayTimeout();
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _startOverlayTimeout() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying && !_isTouching) {
        setState(() => _showOverlay = false);
      }
    });
  }

  void _cycleScaleMode() {
    final names = ['FIT (16:9)', 'STRETCH (FULL)', 'ZOOM (CROP)'];
    setState(() {
      _scaleMode = (_scaleMode + 1) % 3;
      _toastMessage = names[_scaleMode];
    });

    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toastMessage = '');
    });
  }

  void _commitSeek(Duration target) {
    if (!_isInit) return;
    _controller.seekTo(target).then((_) {
      if (mounted) {
        setState(() {
          _isTouching = false;
          _seekOffsetSec = 0;
          _touchDragOffset = 0;
        });
        _controller.play();
        _startOverlayTimeout();
      }
    });
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!_isInit) return;
    setState(() {
      _isTouching = true;
      _touchDragOffset = 0;
      _targetSeekPos = _controller.value.position;
      _showOverlay = true;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isInit) return;
    _touchDragOffset += details.primaryDelta ?? 0;

    final seekDeltaSeconds = (_touchDragOffset / 8).round();
    final dur = _controller.value.duration;
    Duration calc = _controller.value.position + Duration(seconds: seekDeltaSeconds);

    if (calc < Duration.zero) calc = Duration.zero;
    if (calc > dur) calc = dur;

    setState(() {
      _targetSeekPos = calc;
      _seekOffsetSec = seekDeltaSeconds;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isInit) return;
    _commitSeek(_targetSeekPos);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _toastTimer?.cancel();
    if (_isInit) {
      _controller.dispose();
    }
    super.dispose();
  }

  Widget _buildVideoLayer() {
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
    final Duration currentPos = _isInit ? _controller.value.position : Duration.zero;
    final Duration totalDur = _isInit ? _controller.value.duration : Duration.zero;
    final Duration activeDisplayPos = _isTouching ? _targetSeekPos : currentPos;

    final double progressRatio = totalDur.inMilliseconds > 0
        ? (activeDisplayPos.inMilliseconds / totalDur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _cleanExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () {
            setState(() => _showOverlay = !_showOverlay);
            if (_showOverlay) _startOverlayTimeout();
          },
          onDoubleTap: () {
            if (_isInit) {
              if (_controller.value.isPlaying) {
                _controller.pause();
              } else {
                _controller.play();
              }
            }
          },
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildVideoLayer(),

              if (_toastMessage.isNotEmpty)
                Positioned(
                  top: 30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      _toastMessage,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),

              if (_isTouching)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE50914), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _seekOffsetSec >= 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(_targetSeekPos),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_seekOffsetSec >= 0 ? "+" : ""}${_seekOffsetSec}s',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              if (_showOverlay && _isInit)
                Positioned(
                  top: 14,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: _cleanExit,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white),
                        onPressed: _cycleScaleMode,
                      ),
                    ],
                  ),
                ),

              if ((_showOverlay || _isTouching) && _isInit)
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LayoutBuilder(
                          builder: (ctx, constraints) {
                            final barWidth = constraints.maxWidth;
                            final thumbLeft = (barWidth * progressRatio).clamp(0.0, barWidth - 14.0);

                            return GestureDetector(
                              onHorizontalDragUpdate: (details) {
                                final tapPos = details.localPosition.dx.clamp(0.0, barWidth);
                                final ratio = tapPos / barWidth;
                                final targetMs = (totalDur.inMilliseconds * ratio).round();
                                _commitSeek(Duration(milliseconds: targetMs));
                              },
                              child: SizedBox(
                                height: 20,
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    Container(
                                      height: 5,
                                      width: barWidth,
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    Container(
                                      height: 5,
                                      width: barWidth * progressRatio,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE50914),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    Positioned(
                                      left: thumbLeft,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(activeDisplayPos),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: Icon(
                                _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_controller.value.isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                  }
                                });
                              },
                            ),
                            Text(
                              _formatDuration(totalDur),
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

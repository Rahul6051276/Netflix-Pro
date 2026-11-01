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

class _InternalPlayerScreenState extends State<InternalPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInit = false;
  bool _showControls = true;
  Timer? _hideTimer;

  bool _isTouching = false;
  double _dragOffset = 0;
  Duration _targetPos = Duration.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initVideo();
  }

  void _initVideo() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.streamUrl),
      httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      },
    );

    try {
      await _controller.initialize();
      _controller.play();
      if (mounted) setState(() => _isInit = true);

      _controller.addListener(() {
        if (mounted && !_isTouching) setState(() {});
      });

      _startHideTimer();
    } catch (_) {}
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying && !_isTouching) {
        setState(() => _showControls = false);
      }
    });
  }

  void _cleanExit() {
    _hideTimer?.cancel();
    if (_isInit) _controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
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

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!_isInit) return;
    setState(() {
      _isTouching = true;
      _dragOffset = 0;
      _targetPos = _controller.value.position;
      _showControls = true;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isInit) return;
    _dragOffset += details.primaryDelta ?? 0;
    final int secondsDelta = (_dragOffset / 8).round();
    final dur = _controller.value.duration;
    Duration calc = _controller.value.position + Duration(seconds: secondsDelta);

    if (calc < Duration.zero) calc = Duration.zero;
    if (calc > dur) calc = dur;

    setState(() {
      _targetPos = calc;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isInit) return;
    _controller.seekTo(_targetPos).then((_) {
      if (mounted) {
        setState(() {
          _isTouching = false;
        });
        _controller.play();
        _startHideTimer();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final Duration currentPos = _isInit ? _controller.value.position : Duration.zero;
    final Duration totalDur = _isInit ? _controller.value.duration : Duration.zero;
    final Duration displayPos = _isTouching ? _targetPos : currentPos;

    final double progressRatio = totalDur.inMilliseconds > 0
        ? (displayPos.inMilliseconds / totalDur.inMilliseconds).clamp(0.0, 1.0)
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
            setState(() => _showControls = !_showControls);
            if (_showControls) _startHideTimer();
          },
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isInit)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator(color: Color(0xFFE50914))),

              // Touch Scrub Floating Indicator
              if (_isTouching)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE50914), width: 1.5),
                  ),
                  child: Text(
                    _formatDuration(_targetPos),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),

              // Top Bar
              if (_showControls)
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE50914),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.launch_rounded, size: 16, color: Colors.white),
                        label: const Text('Just Player', style: TextStyle(color: Colors.white, fontSize: 12)),
                        onPressed: _launchJustPlayer,
                      ),
                    ],
                  ),
                ),

              // Bottom Red Scrubber Bar
              if ((_showControls || _isTouching) && _isInit)
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
                                _controller.seekTo(Duration(milliseconds: targetMs));
                              },
                              child: SizedBox(
                                height: 20,
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    Container(
                                      height: 4,
                                      width: barWidth,
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    Container(
                                      height: 4,
                                      width: barWidth * progressRatio,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE50914),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    Positioned(
                                      left: thumbLeft,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFE50914),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(displayPos),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: Icon(
                                _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: () {
                                setState(() {
                                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                                });
                              },
                            ),
                            Text(_formatDuration(totalDur),
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
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

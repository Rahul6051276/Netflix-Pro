import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class InternalPlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;

  const InternalPlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
  });

  @override
  State<InternalPlayerScreen> createState() => _InternalPlayerScreenState();
}

enum VideoFitMode { contain, cover, fill }

class _InternalPlayerScreenState extends State<InternalPlayerScreen> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  Timer? _hideTimer;
  VideoFitMode _fitMode = VideoFitMode.contain;

  // Gestures (Volume & Brightness)
  double _volume = 1.0;
  double _brightness = 0.5;
  String _indicatorText = '';
  IconData _indicatorIcon = Icons.volume_up;
  bool _showIndicator = false;
  Timer? _indicatorTimer;

  @override
  void initState() {
    super.initState();
    // Landscape Mode Lock
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _controller.setVolume(_volume);
        _startHideTimer();
      });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _showOverlayIndicator(String text, IconData icon) {
    _indicatorTimer?.cancel();
    setState(() {
      _indicatorText = text;
      _indicatorIcon = icon;
      _showIndicator = true;
    });
    _indicatorTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showIndicator = false);
    });
  }

  void _cycleFitMode() {
    setState(() {
      if (_fitMode == VideoFitMode.contain) {
        _fitMode = VideoFitMode.cover;
        _showOverlayIndicator('Fit: Crop / Fill', Icons.crop);
      } else if (_fitMode == VideoFitMode.cover) {
        _fitMode = VideoFitMode.fill;
        _showOverlayIndicator('Fit: Stretch', Icons.aspect_ratio);
      } else {
        _fitMode = VideoFitMode.contain;
        _showOverlayIndicator('Fit: Original Fit', Icons.fit_screen);
      }
    });
    _startHideTimer();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. VIDEO SURFACE WITH ASPECT RATIO / CROP LOGIC
          Center(
            child: _controller.value.isInitialized
                ? _buildVideoSurface()
                : const CircularProgressIndicator(color: Color(0xFFE50914)),
          ),

          // 2. BRIGHTNESS OVERLAY
          IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity(1.0 - _brightness),
            ),
          ),

          // 3. TOUCH & SWIPE GESTURE DETECTOR
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleControls,
            onDoubleTapDown: (details) {
              final x = details.localPosition.dx;
              if (x < size.width * 0.4) {
                final current = _controller.value.position;
                _controller.seekTo(current - const Duration(seconds: 10));
                _showOverlayIndicator('-10s', Icons.replay_10);
              } else if (x > size.width * 0.6) {
                final current = _controller.value.position;
                _controller.seekTo(current + const Duration(seconds: 10));
                _showOverlayIndicator('+10s', Icons.forward_10);
              }
            },
            onVerticalDragUpdate: (details) {
              final isLeft = details.localPosition.dx < (size.width / 2);
              final delta = -details.primaryDelta! / 200.0;

              if (isLeft) {
                // LEFT SIDE = BRIGHTNESS
                setState(() {
                  _brightness = (_brightness + delta).clamp(0.1, 1.0);
                });
                _showOverlayIndicator('Brightness ${( _brightness * 100 ).toInt()}%', Icons.brightness_6);
              } else {
                // RIGHT SIDE = VOLUME
                setState(() {
                  _volume = (_volume + delta).clamp(0.0, 1.0);
                  _controller.setVolume(_volume);
                });
                _showOverlayIndicator('Volume ${( _volume * 100 ).toInt()}%', _volume == 0 ? Icons.volume_off : Icons.volume_up);
              }
            },
          ),

          // 4. CENTER GESTURE INDICATOR HUD
          if (_showIndicator)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_indicatorIcon, color: const Color(0xFFE50914), size: 28),
                    const SizedBox(width: 10),
                    Text(
                      _indicatorText,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // 5. TOP BAR & PLAYER CONTROLS
          if (_showControls) ...[
            // Top Header
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Aspect Ratio / Crop Button
                  IconButton(
                    icon: Icon(
                      _fitMode == VideoFitMode.cover
                          ? Icons.crop
                          : (_fitMode == VideoFitMode.fill ? Icons.aspect_ratio : Icons.fit_screen),
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: _cycleFitMode,
                    tooltip: 'Change Aspect Ratio / Crop',
                  ),
                ],
              ),
            ),

            // Center Play / Pause & Seek
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_30, color: Colors.white, size: 44),
                    onPressed: () {
                      _controller.seekTo(_controller.value.position - const Duration(seconds: 30));
                      _startHideTimer();
                    },
                  ),
                  const SizedBox(width: 40),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _controller.value.isPlaying ? _controller.pause() : _controller.play();
                      });
                      _startHideTimer();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  IconButton(
                    icon: const Icon(Icons.forward_30, color: Colors.white, size: 44),
                    onPressed: () {
                      _controller.seekTo(_controller.value.position + const Duration(seconds: 30));
                      _startHideTimer();
                    },
                  ),
                ],
              ),
            ),

            // Bottom Progress Bar & Timers
            Positioned(
              bottom: 14,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFFE50914),
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_controller.value.position),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        _formatDuration(_controller.value.duration),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoSurface() {
    switch (_fitMode) {
      case VideoFitMode.cover:
        // Full screen cropped (No black borders)
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
      case VideoFitMode.fill:
        // Stretched to screen edges
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
      case VideoFitMode.contain:
      default:
        // Original aspect ratio
        return AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        );
    }
  }
}

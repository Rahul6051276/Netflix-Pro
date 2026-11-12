// ============================================================================
// NETFLIX PRO TV INTERNAL PLAYER (RED THEME + FAST HOLD-SEEK & SCRUBBER)
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

typedef TvPlayerScreen = InternalPlayerScreen;

class _InternalPlayerScreenState extends State<InternalPlayerScreen>
    with WidgetsBindingObserver {
  static const Color _netflixRed = Color(0xFFE50914);

  late VideoPlayerController _controller;
  bool _isInit = false;
  bool _hasError = false;
  String _errorMsg = '';

  bool _showOverlay = false;
  Timer? _hideTimer;

  int _scaleMode = 0; // 0: FIT, 1: FILL, 2: CROP
  String _ratioToast = '';
  Timer? _ratioToastTimer;

  Timer? _holdSeekTimer;
  int _seekOffsetSec = 0;
  bool _isHoldingSeek = false;
  int _seekMultiplier = 10;
  Duration _targetSeekPos = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _cleanExitToHome();
    }
  }

  bool _isExiting = false;

  void _cleanExitToHome() {
    if (_isExiting) return;
    _isExiting = true;

    _hideTimer?.cancel();
    _holdSeekTimer?.cancel();
    _ratioToastTimer?.cancel();

    if (_isInit) {
      try {
        _controller.pause();
        _controller.dispose();
      } catch (_) {}
      _isInit = false;
    }

    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.streamUrl),
        httpHeaders: const {
          'User-Agent': 'VLC/3.0.18 LibVLC/3.0.18 (Linux; Android 13)',
          'Accept': '*/*',
          'Connection': 'keep-alive',
          'Icy-MetaData': '1',
        },
      );

      await _controller.initialize();
      _controller.play();

      if (mounted) setState(() => _isInit = true);

      _controller.addListener(() {
        if (mounted && !_isHoldingSeek) setState(() {});
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = e.toString();
        });
      }
    }
  }

  void _triggerOverlay() {
    setState(() => _showOverlay = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _controller.value.isPlaying && !_isHoldingSeek) {
        setState(() => _showOverlay = false);
      }
    });
  }

  void _cycleScaleMode() {
    final names = ['FIT (16:9)', 'FILL (STRETCH)', 'CROP (ZOOM)'];
    setState(() {
      _scaleMode = (_scaleMode + 1) % 3;
      _ratioToast = names[_scaleMode];
    });

    _ratioToastTimer?.cancel();
    _ratioToastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _ratioToast = '');
    });
  }

  void _commitSeek() {
    if (!_isInit) return;
    _controller.seekTo(_targetSeekPos).then((_) {
      if (mounted) {
        setState(() {
          _isHoldingSeek = false;
          _seekOffsetSec = 0;
          _seekMultiplier = 10;
        });
        _controller.play();
        _triggerOverlay();
      }
    });
  }

  void _onDpadKeyDown(LogicalKeyboardKey key) {
    // 1. Back Button Kill
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.backspace) {
      _cleanExitToHome();
      return;
    }

    _triggerOverlay();

    // 2. Play/Pause or Confirm Seek
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      if (_isHoldingSeek) {
        _holdSeekTimer?.cancel();
        _commitSeek();
      } else if (_isInit) {
        if (_controller.value.isPlaying) {
          _controller.pause();
        } else {
          _controller.play();
        }
      }
      return;
    }

    // 3. Aspect Ratio Toggle
    if (key == LogicalKeyboardKey.arrowUp) {
      _cycleScaleMode();
      return;
    }

    // 4. Seek Right (Forward)
    if (key == LogicalKeyboardKey.arrowRight && _holdSeekTimer == null) {
      if (!_isHoldingSeek && _isInit) {
        _targetSeekPos = _controller.value.position;
      }
      _isHoldingSeek = true;
      _seekMultiplier = 10;
      int count = 0;

      _holdSeekTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        count++;
        if (count > 16) {
          _seekMultiplier = 60; // 1 min per tick
        } else if (count > 6) {
          _seekMultiplier = 30; // 30 sec per tick
        } else {
          _seekMultiplier = 10;
        }

        final dur = _controller.value.duration;
        _targetSeekPos = (_targetSeekPos + Duration(seconds: _seekMultiplier)) > dur
            ? dur
            : _targetSeekPos + Duration(seconds: _seekMultiplier);

        setState(() {
          _seekOffsetSec += _seekMultiplier;
        });
      });
      return;
    }

    // 5. Seek Left (Rewind)
    if (key == LogicalKeyboardKey.arrowLeft && _holdSeekTimer == null) {
      if (!_isHoldingSeek && _isInit) {
        _targetSeekPos = _controller.value.position;
      }
      _isHoldingSeek = true;
      _seekMultiplier = 10;
      int count = 0;

      _holdSeekTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        count++;
        if (count > 16) {
          _seekMultiplier = 60;
        } else if (count > 6) {
          _seekMultiplier = 30;
        } else {
          _seekMultiplier = 10;
        }

        _targetSeekPos = (_targetSeekPos - Duration(seconds: _seekMultiplier)) < Duration.zero
            ? Duration.zero
            : _targetSeekPos - Duration(seconds: _seekMultiplier);

        setState(() {
          _seekOffsetSec -= _seekMultiplier;
        });
      });
      return;
    }
  }

  void _onDpadKeyUp(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowLeft) {
      _holdSeekTimer?.cancel();
      _holdSeekTimer = null;

      // Remote release karne ke 0.9 second baad target position par jump
      Future.delayed(const Duration(milliseconds: 900), () {
        if (_isHoldingSeek && _holdSeekTimer == null) {
          _commitSeek();
        }
      });
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
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _holdSeekTimer?.cancel();
    _ratioToastTimer?.cancel();
    if (_isInit) {
      _controller.dispose();
    }
    super.dispose();
  }

  Widget _buildVideoOutput() {
    if (!_isInit) {
      return const Center(child: CircularProgressIndicator(color: _netflixRed));
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
    final Duration activeDisplayPos = _isHoldingSeek ? _targetSeekPos : currentPos;

    final double progressRatio = totalDur.inMilliseconds > 0
        ? (activeDisplayPos.inMilliseconds / totalDur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _cleanExitToHome();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKey: (node, event) {
            if (event is RawKeyDownEvent) {
              _onDpadKeyDown(event.logicalKey);
            } else if (event is RawKeyUpEvent) {
              _onDpadKeyUp(event.logicalKey);
            }
            return KeyEventResult.handled;
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildVideoOutput(),

              // Aspect Ratio Toast (Netflix Red Border)
              if (_ratioToast.isNotEmpty)
                Positioned(
                  top: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _netflixRed, width: 1.5),
                    ),
                    child: Text(
                      _ratioToast,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),

              // Target Time Center Indicator Bubble (Netflix Red Theme)
              if (_isHoldingSeek)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _netflixRed, width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: _netflixRed.withOpacity(0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _seekOffsetSec > 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                        color: _netflixRed,
                        size: 36,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDuration(_targetSeekPos),
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_seekOffsetSec > 0 ? "+" : ""}${_seekOffsetSec}s (Press OK to Play)',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              // Highlighted Red Progress Bar & Bottom Overlay
              if ((_showOverlay || _isHoldingSeek) && _isInit)
                Positioned(
                  bottom: 24,
                  left: 40,
                  right: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        // Interactive Highlighted Netflix Red Progress Bar
                        LayoutBuilder(
                          builder: (ctx, constraints) {
                            final barWidth = constraints.maxWidth;
                            final thumbLeft = (barWidth * progressRatio).clamp(0.0, barWidth - 16.0);

                            return SizedBox(
                              height: 16,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  // Background Grey Line
                                  Container(
                                    height: _isHoldingSeek ? 8 : 5,
                                    width: barWidth,
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  // Active Netflix Red Track
                                  Container(
                                    height: _isHoldingSeek ? 8 : 5,
                                    width: barWidth * progressRatio,
                                    decoration: BoxDecoration(
                                      color: _netflixRed,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: _isHoldingSeek
                                          ? [
                                              BoxShadow(
                                                color: _netflixRed.withOpacity(0.75),
                                                blurRadius: 10,
                                              ),
                                            ]
                                          : [],
                                    ),
                                  ),
                                  // Glowing Red Scrubber Thumb (Visible when seeking)
                                  if (_isHoldingSeek)
                                    Positioned(
                                      left: thumbLeft,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _netflixRed,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _netflixRed.withOpacity(0.9),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(activeDisplayPos),
                              style: TextStyle(
                                color: _isHoldingSeek ? _netflixRed : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              totalDur.inMilliseconds > 0 ? _formatDuration(totalDur) : 'LIVE',
                              style: TextStyle(
                                color: totalDur.inMilliseconds > 0 ? Colors.white54 : _netflixRed,
                                fontSize: 13,
                                fontWeight: totalDur.inMilliseconds > 0 ? FontWeight.normal : FontWeight.bold,
                              ),
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
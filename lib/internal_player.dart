import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class InternalPlayer extends StatefulWidget {
  final String streamUrl;
  final String title;

  const InternalPlayer({
    super.key,
    required this.streamUrl,
    required this.title,
  });

  @override
  State<InternalPlayer> createState() => _InternalPlayerState();
}

class _InternalPlayerState extends State<InternalPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.streamUrl),
      );

      await _controller.initialize();
      _controller.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '${twoDigits(duration.inHours)}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : _hasError
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 48),
                            SizedBox(height: 12),
                            Text(
                              'Unable to play stream.\nServer might be offline or link expired.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        )
                      : const CircularProgressIndicator(color: Color(0xFFE50914)),
            ),
            if (_showControls && _isInitialized)
              Container(
                color: Colors.black45,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 42,
                          icon: const Icon(Icons.replay_10, color: Colors.white),
                          onPressed: () {
                            final current = _controller.value.position;
                            _controller.seekTo(current - const Duration(seconds: 10));
                          },
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          iconSize: 64,
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: const Color(0xFFE50914),
                          ),
                          onPressed: () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                          },
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          iconSize: 42,
                          icon: const Icon(Icons.forward_10, color: Colors.white),
                          onPressed: () {
                            final current = _controller.value.position;
                            _controller.seekTo(current + const Duration(seconds: 10));
                          },
                        ),
                      ],
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, VideoPlayerValue value, child) {
                            final position = value.position;
                            final duration = value.duration;
                            return Row(
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                Expanded(
                                  child: Slider(
                                    activeColor: const Color(0xFFE50914),
                                    inactiveColor: Colors.white30,
                                    value: position.inMilliseconds
                                        .clamp(0, duration.inMilliseconds)
                                        .toDouble(),
                                    min: 0.0,
                                    max: duration.inMilliseconds.toDouble(),
                                    onChanged: (val) {
                                      _controller.seekTo(Duration(milliseconds: val.toInt()));
                                    },
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

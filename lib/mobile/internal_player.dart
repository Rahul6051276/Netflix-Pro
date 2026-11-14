// ============================================================================
// NETFLIX PRO MOBILE PLAYER -> NATIVE KOTLIN MEDIA3 EXOPLAYER BRIDGE
// ============================================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InternalPlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final List<dynamic> sources;
  final int initialIndex;

  InternalPlayerScreen({
    super.key,
    String? videoUrl,
    String? streamUrl,
    required this.title,
    this.sources = const [],
    this.initialIndex = 0,
  }) : streamUrl = (streamUrl != null && streamUrl.isNotEmpty)
            ? streamUrl
            : (videoUrl ?? '');

  @override
  State<InternalPlayerScreen> createState() => _InternalPlayerScreenState();
}

class _InternalPlayerScreenState extends State<InternalPlayerScreen> {
  static const MethodChannel _playerChannel =
      MethodChannel('com.netflixpro.netflix_pro/player');

  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _launchNativeCinemaPlayer();
  }

  Future<void> _restorePortraitMode() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _launchNativeCinemaPlayer() async {
    final cleanUrl = widget.streamUrl.trim();
    final encodedSources =
        widget.sources.isNotEmpty ? jsonEncode(widget.sources) : '';

    if (cleanUrl.isEmpty && encodedSources.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Stream URL खाली या अमान्य है।';
        });
      }
      return;
    }

    try {
      await _playerChannel.invokeMethod('playVideo', {
        'url': cleanUrl,
        'title': widget.title,
        'sourcesJson': encodedSources,
        'initialIndex': widget.initialIndex,
        'userAgent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      });

      await _restorePortraitMode();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on PlatformException catch (e) {
      await _restorePortraitMode();
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.message ?? 'Native player open नहीं हो पाया।';
        });
      }
    } catch (e) {
      await _restorePortraitMode();
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _restorePortraitMode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _hasError
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFE50914),
                      size: 52,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _errorMessage = '';
                            });
                            _launchNativeCinemaPlayer();
                          },
                          child: const Text('Retry'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Color(0xFFE50914)),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tmdb_config.dart';

class InternalPlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final String tmdbId;
  final bool isTv;
  final int season;
  final int episode;

  InternalPlayerScreen({
    super.key,
    String? videoUrl,
    String? streamUrl,
    required this.title,
    this.tmdbId = '',
    this.isTv = false,
    this.season = 1,
    this.episode = 1,
  }) : streamUrl = (streamUrl != null && streamUrl.isNotEmpty)
            ? streamUrl
            : (videoUrl ?? '');

  @override
  State<InternalPlayerScreen> createState() => _InternalPlayerScreenState();
}

typedef TvPlayerScreen = InternalPlayerScreen;

class _InternalPlayerScreenState extends State<InternalPlayerScreen> {
  static const MethodChannel _channel =
      MethodChannel('com.netflixpro/player');
  static const MethodChannel _legacyChannel =
      MethodChannel('com.netflixpro.netflix_pro/player');

  @override
  void initState() {
    super.initState();
    _launchKotlinPlayer();
  }

  Future<void> _launchKotlinPlayer() async {
    final savedGistUrl = await TvConfig.getGistUrl();
    final args = <String, dynamic>{
      'url': widget.streamUrl,
      'title': widget.title,
      'tmdbId': widget.tmdbId,
      'tmdbKey': TvConfig.tmdbKey,
      'gistUrl': savedGistUrl,
      'isTv': widget.isTv,
      'season': widget.season,
      'episode': widget.episode,
      'isTvDevice': true,
      'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) CinemaTV/1.0',
      'seekSeconds': 15,
    };

    try {
      await _channel.invokeMethod('playVideo', args);
    } catch (_) {
      try {
        await _legacyChannel.invokeMethod('playVideo', args);
      } catch (_) {}
    }

    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      ),
    );
  }
}
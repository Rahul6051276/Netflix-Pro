import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const MethodChannel _channel =
      MethodChannel('com.netflixpro.netflix_pro/player');

  @override
  void initState() {
    super.initState();
    _launchKotlinPlayer();
  }

  Future<void> _launchKotlinPlayer() async {
    try {
      await _channel.invokeMethod('playVideo', {
        'url': widget.streamUrl,
        'title': widget.title,
        'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) CinemaTV/1.0',
      });
    } catch (_) {}
    if (mounted) {
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

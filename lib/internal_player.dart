import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';

class InternalPlayer extends StatelessWidget {
  final String streamUrl;
  final String title;

  const InternalPlayer({
    super.key,
    required this.streamUrl,
    required this.title,
  });

  void _openExternalPlayer(BuildContext context) async {
    final intent = AndroidIntent(
      action: 'action_view',
      data: streamUrl,
      type: 'video/*',
    );
    try {
      await intent.launch();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No external video player found')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_fill, size: 80, color: Color(0xFFE50914)),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Stream Ready',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _openExternalPlayer(context),
                icon: const Icon(Icons.open_in_new, color: Colors.black),
                label: const Text(
                  'Play in Video Player',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

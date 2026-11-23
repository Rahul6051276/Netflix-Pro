// ============================================================================
// NETFLIX PRO - ZERO-DELAY DIRECT NATIVE CINEMA PLAYER LAUNCHER
// ============================================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'stream_resolver_sheet.dart';
import 'tmdb_config.dart';

class MediaDetailSheet extends StatelessWidget {
  final dynamic item;
  final List providers;
  final VoidCallback onPlaySaved;

  static const MethodChannel _playerChannel =
      MethodChannel('com.netflixpro.netflix_pro/player');
  static const MethodChannel _altPlayerChannel =
      MethodChannel('com.netflixpro/player');

  const MediaDetailSheet({
    super.key,
    required this.item,
    required this.providers,
    required this.onPlaySaved,
  });

  Future _saveContinueWatching() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('continue_watching_mobile');
      var curr = [];
      if (raw != null && raw.isNotEmpty) {
        curr = jsonDecode(raw) as List;
      }
      curr.removeWhere(
          (c) => c['tmdb_id'].toString() == item['tmdb_id'].toString());
      curr.insert(0, {
        'tmdb_id': item['tmdb_id'],
        'title': item['title'] ?? 'Untitled',
        'backdrop': item['backdrop'] ?? '',
        'year': item['year'] ?? '',
        'rating': item['rating'] ?? '8.0',
        'isTv': item['isTv'] ?? false,
      });
      if (curr.length > 15) curr = curr.sublist(0, 15);
      await prefs.setString('continue_watching_mobile', jsonEncode(curr));
      onPlaySaved();
    } catch (_) {}
  }

  Future _launchPlayerDirectly({int season = 1, int episode = 1}) async {
    await _saveContinueWatching();
    final savedGistUrl = await MobileConfig.getGistUrl();
    final tmdbId = (item['tmdb_id'] ?? '').toString();
    final title = (item['title'] ?? 'Netflix Pro').toString();
    final isTv = item['isTv'] == true;

    final args = <String, dynamic>{
      'url': '',
      'title': title,
      'tmdbId': tmdbId,
      'tmdbKey': MobileConfig.tmdbKey,
      'gistUrl': savedGistUrl,
      'isTv': isTv,
      'season': season,
      'episode': episode,
      'isTvDevice': false,
      'seekSeconds': 30,
      'userAgent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    try {
      await _playerChannel.invokeMethod('playVideo', args);
    } catch (_) {
      try {
        await _altPlayerChannel.invokeMethod('playVideo', args);
      } catch (_) {}
    }
  }

  void _onWatchPressed(BuildContext context) {
    final bool isTv = item['isTv'] == true;
    final navigator = Navigator.of(context);
    navigator.pop();

    if (isTv) {
      showModalBottomSheet(
        context: navigator.context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MobileEpisodeSheet(
          item: item,
          providers: providers,
          onSelected: (season, ep) {
            _launchPlayerDirectly(season: season, episode: ep);
          },
        ),
      );
    } else {
      _launchPlayerDirectly();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTv = item['isTv'] == true;
    final String backdrop = item['backdrop'] ?? item['poster'] ?? '';
    final String title = item['title'] ?? 'Untitled';
    final String rating = item['rating'] ?? '7.5';
    final String year = item['year'] ?? '';
    final String overview =
        item['overview'] ?? 'Storyline details available on playback.';

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 260,
                width: double.infinity,
                child: backdrop.isNotEmpty
                    ? Image.network(backdrop,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.black))
                    : Container(color: Colors.black),
              ),
              Container(
                height: 260,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xFF141414)],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Positioned(
                top: 105,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _onWatchPressed(context),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE50914),
                      ),
                      child: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF222222),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('$rating IMDb',
                            style: const TextStyle(
                                color: Color(0xFF46D369),
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text(year,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.white54)),
                      const SizedBox(width: 8),
                      Text(isTv ? 'Web Series' : 'Movie',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _onWatchPressed(context),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow, size: 20),
                          SizedBox(width: 6),
                          Text('Watch Now',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('STORYLINE',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0)),
                  const SizedBox(height: 6),
                  Text(
                    overview,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
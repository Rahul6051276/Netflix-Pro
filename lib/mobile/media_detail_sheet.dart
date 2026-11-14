// ============================================================================
// HOTSTAR STYLE MEDIA DETAIL SHEET (AUTO-STREAM + NATIVE PLAYER)
// ============================================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'tmdb_config.dart';
import 'stream_resolver_sheet.dart';
import 'internal_player.dart';

class MediaDetailSheet extends StatelessWidget {
  final dynamic item;
  final List<dynamic> providers;
  final VoidCallback onPlaySaved;

  const MediaDetailSheet({
    super.key,
    required this.item,
    required this.providers,
    required this.onPlaySaved,
  });

  void _autoStreamFirstLink(BuildContext context) async {
    final bool isTv = item['isTv'] == true;
    
    if (isTv) {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MobileEpisodeSheet(
          item: item,
          providers: providers,
          onSelected: (season, ep) {
            _resolveAndPlay(context, season: season, episode: ep);
          },
        ),
      );
    } else {
      Navigator.pop(context);
      _resolveAndPlay(context);
    }
  }

  Future<void> _resolveAndPlay(BuildContext context, {int? season, int? episode}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE50914), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Color(0xFFE50914)),
              SizedBox(height: 14),
              Text(
                'Auto-connecting best stream...',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final targetTmdbId = item['tmdb_id']?.toString() ?? '';
      final isTv = item['isTv'] == true;
      final movieTitle = item['title'] ?? 'Untitled';
      final targetSeason = season ?? 1;
      final targetEpisode = episode ?? 1;

      var resolvedStreams = [];

      if (targetTmdbId.isNotEmpty) {
        try {
          final embedType = isTv ? 'series' : 'movie';
          final embedUrl = isTv
              ? 'https://tmdb-embed-api-4.onrender.com/api/streams/$embedType/$targetTmdbId?season=$targetSeason&episode=$targetEpisode'
              : 'https://tmdb-embed-api-4.onrender.com/api/streams/$embedType/$targetTmdbId';
          final res = await http.get(Uri.parse(embedUrl)).timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final list = data is List ? data : (data['streams'] ?? []);
            for (var s in list) {
              if (s['url'] != null) {
                resolvedStreams.add({'url': s['url'], 'title': s['title'] ?? movieTitle});
              }
            }
          }
        } catch (_) {}
      }

      if (context.mounted) Navigator.pop(context);

      if (resolvedStreams.isNotEmpty) {
        final firstStreamUrl = resolvedStreams.first['url'].toString().trim();
        onPlaySaved();

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InternalPlayerScreen(
                streamUrl: firstStreamUrl,
                title: movieTitle,
              ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => MobileStreamSheet(
              item: item,
              season: season,
              episode: episode,
              providers: providers,
              onPlaySaved: onPlaySaved,
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTv = item['isTv'] == true;
    final String backdrop = item['backdrop'] ?? item['poster'] ?? '';
    final String title = item['title'] ?? 'Untitled';
    final String rating = item['rating'] ?? '7.5';
    final String year = item['year'] ?? '';
    final String overview = item['overview'] ?? 'Storyline details available on playback.';

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
                    ? Image.network(backdrop, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.black))
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
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
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
                    onTap: () => _autoStreamFirstLink(context),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE50914),
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
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
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(4)),
                        child: Text('$rating IMDb', style: const TextStyle(color: Color(0xFF46D369), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text(year, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.white54)),
                      const SizedBox(width: 8),
                      Text(isTv ? 'Web Series' : 'Movie', style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _autoStreamFirstLink(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.play_arrow, size: 20),
                          SizedBox(width: 6),
                          Text('Watch Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('STORYLINE', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 6),
                  Text(
                    overview,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
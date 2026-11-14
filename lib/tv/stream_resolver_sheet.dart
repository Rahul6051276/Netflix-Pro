import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_config.dart';

// ============================================================================
// DIRECT NATIVE PLAYER LAUNCHER FOR TV (NO SERVER DIALOG POPUP)
// ============================================================================
Future launchTvDirectNativePlayer({
  required dynamic item,
  int season = 1,
  int episode = 1,
  VoidCallback? onPlaySaved,
}) async {
  const MethodChannel playerChannel =
      MethodChannel('com.netflixpro.netflix_pro/player');

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString('continue_watching_tv');
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
    if (curr.length > 15) {
      curr = curr.sublist(0, 15);
    }
    await prefs.setString('continue_watching_tv', jsonEncode(curr));
    if (onPlaySaved != null) onPlaySaved();
  } catch (_) {}

  final tmdbId = (item['tmdb_id'] ?? '').toString();
  final title = (item['title'] ?? 'Netflix Pro TV').toString();
  final isTv = item['isTv'] == true;

  try {
    await playerChannel.invokeMethod('playVideo', {
      'url': '',
      'title': title,
      'tmdbId': tmdbId,
      'isTv': isTv,
      'season': season,
      'episode': episode,
      'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) CinemaTV/1.0',
    });
  } catch (_) {}
}

// ============================================================================
// TV EPISODE DIALOG (SERIES -> SELECT EPISODE -> DIRECT NATIVE PLAYER)
// ============================================================================
class TvEpisodeDialog extends StatefulWidget {
  final dynamic item;
  final Function(int s, int ep) onSelected;

  const TvEpisodeDialog({
    super.key,
    required this.item,
    required this.onSelected,
  });

  @override
  State createState() => _TvEpisodeDialogState();
}

class _TvEpisodeDialogState extends State<TvEpisodeDialog> {
  int selectedSeason = 1;
  int episodeCount = 12;
  List seasons = [1];

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future _fetchDetails() async {
    try {
      final res = await http
          .get(Uri.parse(
              '${TvConfig.tmdbBase}/tv/${widget.item['tmdb_id']}?api_key=${TvConfig.tmdbKey}'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final raw = (data['seasons'] as List? ?? [])
            .where((s) => (s['season_number'] ?? 0) > 0)
            .map((s) => s['season_number'] as int)
            .toList();
        if (raw.isNotEmpty && mounted) {
          setState(() {
            seasons = raw;
            selectedSeason = raw.first;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item['title'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: seasons.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: s == selectedSeason
                            ? const Color(0xFFE50914)
                            : Colors.white12,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => setState(() => selectedSeason = s),
                      child: Text('Season $s'),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 190,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: episodeCount,
                itemBuilder: (ctx, i) {
                  final ep = i + 1;
                  return ElevatedButton(
                    autofocus: i == 0,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSelected(selectedSeason, ep);
                    },
                    child: Text('EP $ep', style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
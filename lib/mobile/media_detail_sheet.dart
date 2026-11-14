// ============================================================================
// NETFLIX PRO - DIRECT PLAYER AUTO-STREAM LAUNCHER (ZERO CATALOG POPUP)
// ============================================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  void _startDirectPlayback(BuildContext context) {
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
            navigator.push(
              MaterialPageRoute(
                builder: (_) => _DirectAutoStreamLauncherScreen(
                  item: item,
                  season: season,
                  episode: ep,
                  providers: providers,
                  onPlaySaved: onPlaySaved,
                ),
              ),
            );
          },
        ),
      );
    } else {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => _DirectAutoStreamLauncherScreen(
            item: item,
            providers: providers,
            onPlaySaved: onPlaySaved,
          ),
        ),
      );
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
                    onTap: () => _startDirectPlayback(context),
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
                      onPressed: () => _startDirectPlayback(context),
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

// ============================================================================
// FULL-SCREEN BLACK PLAYER LAUNCHER (RESOLVES ALL SERVERS & OPENS NATIVE PLAYER)
// ============================================================================
class _DirectAutoStreamLauncherScreen extends StatefulWidget {
  final dynamic item;
  final int? season;
  final int? episode;
  final List<dynamic> providers;
  final VoidCallback onPlaySaved;

  const _DirectAutoStreamLauncherScreen({
    required this.item,
    this.season,
    this.episode,
    required this.providers,
    required this.onPlaySaved,
  });

  @override
  State<_DirectAutoStreamLauncherScreen> createState() =>
      _DirectAutoStreamLauncherScreenState();
}

class _DirectAutoStreamLauncherScreenState
    extends State<_DirectAutoStreamLauncherScreen> {
  String _statusText = 'Connecting best Hindi server...';
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _resolveAllAndLaunch();
  }

  bool _isHindiStream(String title, {String category = ''}) {
    final lower = '$title $category'.toLowerCase();
    return lower.contains('hindi') ||
        lower.contains('dual') ||
        lower.contains('multi') ||
        lower.contains('dubbed') ||
        lower.contains('hin') ||
        lower.contains('dub');
  }

  String _clean(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();

  Future<List<dynamic>> _getProviders() async {
    if (widget.providers.isNotEmpty) return widget.providers;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_active_providers');
    if (cached != null && cached.isNotEmpty) {
      try {
        final list = jsonDecode(cached);
        if (list is List && list.isNotEmpty) return list;
      } catch (_) {}
    }
    try {
      final freshUrl =
          '${MobileConfig.gistUrl}?t=${DateTime.now().millisecondsSinceEpoch}';
      final res =
          await http.get(Uri.parse(freshUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['active_providers'] ?? decoded['providers'] ?? []);
        if (list is List && list.isNotEmpty) {
          await prefs.setString('cached_active_providers', jsonEncode(list));
          return list;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveContinueWatching() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('continue_watching_mobile');
      var curr = [];
      if (raw != null && raw.isNotEmpty) {
        curr = jsonDecode(raw) as List<dynamic>;
      }
      curr.removeWhere(
          (c) => c['tmdb_id'].toString() == widget.item['tmdb_id'].toString());
      curr.insert(0, {
        'tmdb_id': widget.item['tmdb_id'],
        'title': widget.item['title'] ?? 'Untitled',
        'backdrop': widget.item['backdrop'] ?? '',
        'year': widget.item['year'] ?? '',
        'rating': widget.item['rating'] ?? '8.0',
        'isTv': widget.item['isTv'] ?? false,
      });
      if (curr.length > 15) curr = curr.sublist(0, 15);
      await prefs.setString('continue_watching_mobile', jsonEncode(curr));
      widget.onPlaySaved();
    } catch (_) {}
  }

  Future<void> _resolveAllAndLaunch() async {
    final resolved = >[];
    final activeProvs = await _getProviders();
    final targetTmdbId = widget.item['tmdb_id']?.toString() ?? '';
    final isTv = widget.item['isTv'] == true;
    final movieTitle = (widget.item['title'] ?? 'Untitled').toString();
    final targetSeason = widget.season ?? 1;
    final targetEpisode = widget.episode ?? 1;
    final cleanTarget = _clean(movieTitle);

    String? imdbId;
    if (targetTmdbId.isNotEmpty) {
      try {
        final extType = isTv ? 'tv' : 'movie';
        final extRes = await http
            .get(Uri.parse(
                '${MobileConfig.tmdbBase}/$extType/$targetTmdbId/external_ids?api_key=${MobileConfig.tmdbKey}'))
            .timeout(const Duration(seconds: 4));
        if (extRes.statusCode == 200) {
          imdbId = jsonDecode(extRes.body)['imdb_id'];
        }
      } catch (_) {}
    }

    // 1. Xtream IPTV (Livebox Pro, etc.) - Fastest Direct Links
    for (var prov in activeProvs) {
      if (prov['type'] == 'xtream') {
        final host = (prov['xc_host'] ?? prov['host'] ?? '')
            .toString()
            .replaceAll(RegExp(r'/+$'), '');
        final user = prov['xc_username'] ?? prov['username'] ?? '';
        final pass = prov['xc_password'] ?? prov['password'] ?? '';

        if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
          try {
            if (isTv) {
              final searchApi =
                  '$host/player_api.php?username=$user&password=$pass&action=get_series';
              final xtreamRes = await http
                  .get(Uri.parse(searchApi))
                  .timeout(const Duration(seconds: 6));
              if (xtreamRes.statusCode == 200) {
                final seriesList = jsonDecode(xtreamRes.body);
                if (seriesList is List) {
                  var candidates = [];
                  for (var s in seriesList) {
                    final sTmdb = (s['tmdb_id'] ?? s['tmdb'] ?? '').toString();
                    final rawName = (s['name'] ?? '').toString();
                    final categoryName = (s['category_name'] ?? '').toString();
                    final sClean = _clean(rawName);
                    if ((sTmdb.isNotEmpty && sTmdb == targetTmdbId) ||
                        sClean.contains(cleanTarget) ||
                        cleanTarget.contains(sClean)) {
                      s['is_hindi_detected'] =
                          _isHindiStream(rawName, category: categoryName);
                      candidates.add(s);
                    }
                  }
                  candidates.sort((a, b) =>
                      (b['is_hindi_detected'] == true ? 1 : 0)
                          .compareTo(a['is_hindi_detected'] == true ? 1 : 0));

                  for (var bestSeries in candidates.take(2)) {
                    final sid = bestSeries['series_id'];
                    final infoApi =
                        '$host/player_api.php?username=$user&password=$pass&action=get_series_info&series_id=$sid';
                    final infoRes = await http
                        .get(Uri.parse(infoApi))
                        .timeout(const Duration(seconds: 6));
                    if (infoRes.statusCode == 200) {
                      final epMap = jsonDecode(infoRes.body)['episodes'] ?? {};
                      final epList =
                          (epMap is Map) ? (epMap['$targetSeason'] ?? []) : [];
                      if (epList is List && epList.isNotEmpty) {
                        final match = epList.firstWhere(
                          (e) =>
                              int.tryParse(
                                  (e['episode_num'] ?? 0).toString()) ==
                              targetEpisode,
                          orElse: () => null,
                        );
                        if (match != null) {
                          final isHindi =
                              bestSeries['is_hindi_detected'] == true;
                          resolved.add({
                            'server': prov['name'] ?? 'Livebox Pro',
                            'title': isHindi
                                ? '$movieTitle (Hindi) S$targetSeason:E$targetEpisode'
                                : '$movieTitle S$targetSeason:E$targetEpisode',
                            'url':
                                '$host/series/$user/$pass/${match['id']}.${match['container_extension'] ?? "mp4"}',
                            'isHindi': isHindi,
                          });
                        }
                      }
                    }
                  }
                }
              }
            } else {
              final searchApi =
                  '$host/player_api.php?username=$user&password=$pass&action=get_vod_streams';
              final xtreamRes = await http
                  .get(Uri.parse(searchApi))
                  .timeout(const Duration(seconds: 6));
              if (xtreamRes.statusCode == 200) {
                final streamList = jsonDecode(xtreamRes.body);
                if (streamList is List) {
                  var candidates = [];
                  for (var m in streamList) {
                    final mTmdb = (m['tmdb_id'] ?? m['tmdb'] ?? '').toString();
                    final rawName = (m['name'] ?? '').toString();
                    final categoryName = (m['category_name'] ?? '').toString();
                    final mClean = _clean(rawName);
                    if ((mTmdb.isNotEmpty && mTmdb == targetTmdbId) ||
                        mClean.contains(cleanTarget) ||
                        cleanTarget.contains(mClean)) {
                      candidates.add({
                        'data': m,
                        'isHindi':
                            _isHindiStream(rawName, category: categoryName),
                      });
                    }
                  }
                  candidates.sort((a, b) => (b['isHindi'] == true ? 1 : 0)
                      .compareTo(a['isHindi'] == true ? 1 : 0));

                  for (var cand in candidates.take(4)) {
                    final bestMovie = cand['data'];
                    final isHindi = cand['isHindi'] == true;
                    resolved.add({
                      'server': prov['name'] ?? 'Livebox Pro',
                      'title': (bestMovie['name'] ?? movieTitle).toString(),
                      'url':
                          '$host/movie/$user/$pass/${bestMovie['stream_id']}.${bestMovie['container_extension'] ?? "mp4"}',
                      'isHindi': isHindi,
                    });
                  }
                }
              }
            }
          } catch (_) {}
        }
      }

      // 2. Stremio Addons (HDHub4u, PenguPlay, etc.)
      if (type == 'stremio' && imdbId != null && imdbId.isNotEmpty) {
        final base =
            (prov['url'] ?? '').toString().replaceAll('/manifest.json', '');
        final streamPath = isTv
            ? '$base/stream/series/$imdbId:$targetSeason:$targetEpisode.json'
            : '$base/stream/movie/$imdbId.json';
        try {
          final res = await http
              .get(Uri.parse(streamPath))
              .timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final streamEntries = data['streams'] ?? [];
            if (streamEntries is List) {
              for (var s in streamEntries) {
                final stremioUrl = (s['url'] ?? '').toString();
                if (stremioUrl.isEmpty) continue;
                final titleStr = (s['title'] ?? s['name'] ?? '').toString();
                if (titleStr.toLowerCase().contains('donation') ||
                    titleStr.toLowerCase().contains('discord') ||
                    titleStr.toLowerCase().contains('telegram')) {
                  continue;
                }
                resolved.add({
                  'server': prov['name'] ?? 'HDHub4u',
                  'title': titleStr.isNotEmpty ? titleStr : '$movieTitle HD',
                  'url': stremioUrl,
                  'isHindi': _isHindiStream(titleStr),
                });
              }
            }
          }
        } catch (_) {}
      }
    }

    // 3. Render Cloud API (Streamon / Vidlink / Showbox)
    if (targetTmdbId.isNotEmpty) {
      try {
        final embedType = isTv ? 'series' : 'movie';
        final embedUrl = isTv
            ? 'https://tmdb-embed-api-4.onrender.com/api/streams/$embedType/$targetTmdbId?season=$targetSeason&episode=$targetEpisode'
            : 'https://tmdb-embed-api-4.onrender.com/api/streams/$embedType/$targetTmdbId';
        final embedRes = await http
            .get(Uri.parse(embedUrl))
            .timeout(const Duration(seconds: 6));
        if (embedRes.statusCode == 200) {
          final embedData = jsonDecode(embedRes.body);
          final streamList =
              embedData is List ? embedData : (embedData['streams'] ?? []);
          if (streamList is List) {
            for (var s in streamList) {
              final sUrl = (s['url'] ?? '').toString();
              if (sUrl.isNotEmpty) {
                final sTitle = (s['title'] ?? '$movieTitle HD').toString();
                final provName = (s['provider'] ?? 'Cloud HD').toString();
                resolved.add({
                  'server': provName,
                  'title': sTitle,
                  'url': sUrl,
                  'isHindi': _isHindiStream(sTitle),
                });
              }
            }
          }
        }
      } catch (_) {}
    }

    // Hindi servers first, then Livebox/IPTV priority
    resolved.sort((a, b) {
      final aHindi = a['isHindi'] == true ? 1 : 0;
      final bHindi = b['isHindi'] == true ? 1 : 0;
      if (aHindi != bHindi) return bHindi.compareTo(aHindi);

      final aIsXtream = (a['server'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains('livebox') ||
              (a['server'] ?? '').toString().toLowerCase().contains('iptv')
          ? 1
          : 0;
      final bIsXtream = (b['server'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains('livebox') ||
              (b['server'] ?? '').toString().toLowerCase().contains('iptv')
          ? 1
          : 0;
      return bIsXtream.compareTo(aIsXtream);
    });

    if (!mounted) return;

    if (resolved.isEmpty) {
      setState(() {
        _notFound = true;
        _statusText = 'No stream sources found for this title.';
      });
      return;
    }

    await _saveContinueWatching();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InternalPlayerScreen(
          streamUrl: resolved.first['url'].toString().trim(),
          title: movieTitle,
          sources: resolved,
          initialIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _notFound
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFE50914), size: 46),
                  const SizedBox(height: 12),
                  Text(
                    _statusText,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back'),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFE50914)),
                  const SizedBox(height: 14),
                  Text(
                    _statusText,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
      ),
    );
  }
}
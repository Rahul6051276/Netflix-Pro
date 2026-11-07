// ============================================================================
// FULL SCREEN CATEGORIES OVERLAY MODAL
// ============================================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'internal_player.dart';
import 'tmdb_config.dart';
import 'category_grid_screen.dart';

void openCategoriesModal(BuildContext context, List<dynamic> providers, VoidCallback onRefresh) {
  List allCategories = [
    {'title': 'South Action Hits (Hindi Dubbed)', 'url': '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=te|ta|ml|kn', 'isTv': false},
    {'title': 'Hollywood Blockbusters (Hindi Dubbed)', 'url': '${MobileConfig.tmdbBase}/movie/popular?api_key=${MobileConfig.tmdbKey}', 'isTv': false},
    {'title': 'Latest Netflix Blockbusters', 'url': '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=8&watch_region=IN', 'isTv': false},
    {'title': 'Amazon Prime Video Hits', 'url': '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=119&watch_region=IN', 'isTv': false},
    {'title': 'Disney+ Hotstar Specials', 'url': '${MobileConfig.tmdbBase}/movie/now_playing?api_key=${MobileConfig.tmdbKey}&language=en-US&region=IN', 'isTv': false},
    {'title': 'Trending Hindi Web Series', 'url': '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_original_language=hi&without_genres=10766&vote_count.gte=3', 'isTv': true},
    {'title': 'Action & Adventure', 'url': '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=28', 'isTv': false},
    {'title': 'Suspense & Thrillers', 'url': '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=53', 'isTv': false},
    {'title': 'Sci-Fi & Fantasy', 'url': '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=878', 'isTv': false},
    {'title': 'Horror Movies', 'url': '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=27', 'isTv': false},
    {'title': 'Comedy Specials', 'url': '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=35', 'isTv': false},
    {'title': 'Global TV Hits', 'url': '${MobileConfig.tmdbBase}/tv/popular?api_key=${MobileConfig.tmdbKey}&language=en-US', 'isTv': true},
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black.withOpacity(0.92),
    builder: (ctx) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 22),
            const Text(
              'Categories',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.builder(
                itemCount: allCategories.length,
                itemBuilder: (context, index) {
                  final cat = allCategories[index];
                  final String catTitle = (cat['title'] ?? '').toString();
                  final String catUrl = (cat['url'] ?? '').toString();
                  final bool catIsTv = cat['isTv'] == true;

                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MobileCategoryGridScreen(
                            title: catTitle,
                            baseUrl: catUrl,
                            isTv: catIsTv,
                            providers: providers,
                            onPlaySaved: onRefresh,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        catTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: index < 2 ? const Color(0xFFE50914) : Colors.white70,
                          fontSize: 17,
                          fontWeight: index < 2 ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () => Navigator.pop(ctx),
              child: const Icon(Icons.close, color: Colors.black, size: 24),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    },
  );
}

// ============================================================================
// MOBILE EPISODE SELECTOR BOTTOM SHEET
// ============================================================================
class MobileEpisodeSheet extends StatefulWidget {
  final dynamic item;
  final Function(int s, int ep) onSelected;

  const MobileEpisodeSheet({super.key, required this.item, required this.onSelected});

  @override
  State<MobileEpisodeSheet> createState() => _MobileEpisodeSheetState();
}

class _MobileEpisodeSheetState extends State<MobileEpisodeSheet> {
  int selectedSeason = 1;
  int episodeCount = 10;
  List<int> seasons = [1];

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final res = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/tv/${widget.item['tmdb_id']}?api_key=${MobileConfig.tmdbKey}')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final raw = (data['seasons'] as List<dynamic>? ?? [])
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
    return Container(
      height: 380,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Text(widget.item['title'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: seasons.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: s == selectedSeason ? const Color(0xFFE50914) : Colors.white12,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => setState(() => selectedSeason = s),
                    child: Text('Season $s'),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: episodeCount,
              itemBuilder: (ctx, i) {
                final ep = i + 1;
                return ElevatedButton(
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
    );
  }
}

// ============================================================================
// MOBILE STREAM RESOLVER BOTTOM SHEET (FAST PARALLEL + RENDER API + XTREAM + STREMIO)
// ============================================================================
class MobileStreamSheet extends StatefulWidget {
  final dynamic item;
  final int? season;
  final int? episode;
  final List<dynamic> providers;
  final VoidCallback onPlaySaved;

  const MobileStreamSheet({
    super.key,
    required this.item,
    this.season,
    this.episode,
    required this.providers,
    required this.onPlaySaved,
  });

  @override
  State<MobileStreamSheet> createState() => _MobileStreamSheetState();
}

class _MobileStreamSheetState extends State<MobileStreamSheet> {
  var streams = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDirectStreamsParallel();
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

  String _clean(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();

  // PARALLEL FAST RESOLVER WITH RENDER API, XTREAM & STREMIO
  Future<void> _fetchDirectStreamsParallel() async {
    final targetTmdbId = widget.item['tmdb_id']?.toString() ?? '';
    final isTv = widget.item['isTv'] == true;
    final movieTitle = widget.item['title'] ?? '';
    final targetSeason = widget.season ?? 1;
    final targetEpisode = widget.episode ?? 1;
    final cleanTarget = _clean(movieTitle);

    var resolved = [];

    // ========================================================================
    // 1. RENDER API EMBED SOURCES (CASTLE TV, VIDLINK, VIDSRC)
    // ========================================================================
    const renderBase = 'https://tmdb-embed-api-4.onrender.com';

    if (targetTmdbId.isNotEmpty) {
      if (isTv) {
        resolved.addAll([
          {
            'server': 'Castle TV (Render Server)',
            'title': '$movieTitle S$targetSeason:E$targetEpisode (Multi-Audio / HD)',
            'url': '$renderBase/embed/tv/$targetTmdbId/$targetSeason/$targetEpisode',
            'isHindi': false,
          },
          {
            'server': 'VidLink Pro (Render Server)',
            'title': '$movieTitle S$targetSeason:E$targetEpisode (Fast Stream)',
            'url': '$renderBase/vidlink/tv/$targetTmdbId/$targetSeason/$targetEpisode',
            'isHindi': false,
          },
          {
            'server': 'VidSrc Primary (Render Server)',
            'title': '$movieTitle S$targetSeason:E$targetEpisode (HD)',
            'url': '$renderBase/vidsrc/tv/$targetTmdbId/$targetSeason/$targetEpisode',
            'isHindi': false,
          },
        ]);
      } else {
        resolved.addAll([
          {
            'server': 'Castle TV (Render Server)',
            'title': '$movieTitle (Multi-Audio / HD)',
            'url': '$renderBase/embed/movie/$targetTmdbId',
            'isHindi': false,
          },
          {
            'server': 'VidLink Pro (Render Server)',
            'title': '$movieTitle (Fast Stream)',
            'url': '$renderBase/vidlink/movie/$targetTmdbId',
            'isHindi': false,
          },
          {
            'server': 'VidSrc Primary (Render Server)',
            'title': '$movieTitle HD (Public Stream)',
            'url': '$renderBase/vidsrc/movie/$targetTmdbId',
            'isHindi': false,
          },
        ]);
      }
    }

    String? imdbId;
    if (targetTmdbId.isNotEmpty) {
      try {
        final extType = isTv ? 'tv' : 'movie';
        final extRes = await http.get(Uri.parse(
            '${MobileConfig.tmdbBase}/$extType/$targetTmdbId/external_ids?api_key=${MobileConfig.tmdbKey}')).timeout(const Duration(seconds: 3));
        if (extRes.statusCode == 200) {
          imdbId = jsonDecode(extRes.body)['imdb_id'];
        }
      } catch (_) {}
    }

    // ========================================================================
    // 2. XTREAM & STREMIO PROVIDERS PARALLEL WORKER
    // ========================================================================
    List<Future<List<dynamic>>> tasks = widget.providers.map((prov) async {
      var providerResolved = [];
      final type = prov['type'];

      if (type == 'xtream') {
        final host = (prov['host'] ?? '').toString().replaceAll(RegExp(r'/+$'), '');
        final user = prov['username'] ?? '';
        final pass = prov['password'] ?? '';

        if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
          try {
            if (isTv) {
              final searchApi = '$host/player_api.php?username=$user&password=$pass&action=get_series';
              final xtreamRes = await http.get(Uri.parse(searchApi)).timeout(const Duration(seconds: 4));
              if (xtreamRes.statusCode == 200) {
                final seriesList = jsonDecode(xtreamRes.body) as List<dynamic>;
                var candidates = [];

                for (var s in seriesList) {
                  final sTmdb = (s['tmdb_id'] ?? s['tmdb'] ?? '').toString();
                  final rawName = (s['name'] ?? '').toString();
                  final categoryName = (s['category_name'] ?? '').toString();
                  final sClean = _clean(rawName);

                  if (sTmdb == targetTmdbId || sClean.contains(cleanTarget) || cleanTarget.contains(sClean)) {
                    s['is_hindi_detected'] = _isHindiStream(rawName, category: categoryName);
                    candidates.add(s);
                  }
                }

                candidates.sort((a, b) => (b['is_hindi_detected'] == true ? 1 : 0).compareTo(a['is_hindi_detected'] == true ? 1 : 0));

                for (var bestSeries in candidates.take(2)) {
                  final sid = bestSeries['series_id'];
                  final infoApi = '$host/player_api.php?username=$user&password=$pass&action=get_series_info&series_id=$sid';
                  final infoRes = await http.get(Uri.parse(infoApi)).timeout(const Duration(seconds: 4));
                  if (infoRes.statusCode == 200) {
                    final epMap = jsonDecode(infoRes.body)['episodes'] as Map<String, dynamic>? ?? {};
                    final epList = epMap['$targetSeason'] as List<dynamic>? ?? [];
                    final match = epList.firstWhere((e) => (e['episode_num'] ?? 0) == targetEpisode, orElse: () => null);

                    if (match != null) {
                      final isHindi = bestSeries['is_hindi_detected'] == true;
                      providerResolved.add({
                        'server': prov['name'] ?? 'LiveBox Xtream IPTV',
                        'title': isHindi
                            ? '$movieTitle (Hindi Audio) S$targetSeason:E$targetEpisode'
                            : '$movieTitle S$targetSeason:E$targetEpisode',
                        'url': '$host/series/$user/$pass/${match['id']}.${match['container_extension'] ?? "mp4"}',
                        'isHindi': isHindi,
                      });
                    }
                  }
                }
              }
            } else {
              final searchApi = '$host/player_api.php?username=$user&password=$pass&action=get_vod_streams';
              final xtreamRes = await http.get(Uri.parse(searchApi)).timeout(const Duration(seconds: 4));
              if (xtreamRes.statusCode == 200) {
                final streamList = jsonDecode(xtreamRes.body) as List<dynamic>;
                var candidates = [];

                for (var m in streamList) {
                  final mTmdb = (m['tmdb_id'] ?? m['tmdb'] ?? '').toString();
                  final rawName = (m['name'] ?? '').toString();
                  final categoryName = (m['category_name'] ?? '').toString();
                  final mClean = _clean(rawName);

                  if (mTmdb == targetTmdbId || mClean.contains(cleanTarget) || cleanTarget.contains(mClean)) {
                    candidates.add({
                      'data': m,
                      'isHindi': _isHindiStream(rawName, category: categoryName),
                    });
                  }
                }

                candidates.sort((a, b) => (b['isHindi'] == true ? 1 : 0).compareTo(a['isHindi'] == true ? 1 : 0));

                for (var cand in candidates.take(3)) {
                  final bestMovie = cand['data'];
                  final isHindi = cand['isHindi'] == true;
                  providerResolved.add({
                    'server': prov['name'] ?? 'LiveBox Xtream IPTV',
                    'title': isHindi ? '$movieTitle (Hindi Audio / Dubbed)' : '$movieTitle HD',
                    'url': '$host/movie/$user/$pass/${bestMovie['stream_id']}.${bestMovie['container_extension'] ?? "mp4"}',
                    'isHindi': isHindi,
                  });
                }
              }
            }
          } catch (_) {}
        }
      }

      if (type == 'stremio' && imdbId != null && imdbId.isNotEmpty) {
        final base = (prov['url'] ?? '').toString().replaceAll('/manifest.json', '');
        final streamPath = isTv
            ? '$base/stream/series/$imdbId:$targetSeason:$targetEpisode.json'
            : '$base/stream/movie/$imdbId.json';

        try {
          final res = await http.get(Uri.parse(streamPath)).timeout(const Duration(seconds: 3));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            for (var s in (data['streams'] ?? [])) {
              final titleStr = (s['title'] ?? s['name'] ?? '').toString();
              if (titleStr.toLowerCase().contains('donation') ||
                  titleStr.toLowerCase().contains('discord') ||
                  titleStr.toLowerCase().contains('telegram')) {
                continue;
              }

              providerResolved.add({
                'server': prov['name'] ?? 'HdHub Provider',
                'title': titleStr,
                'url': s['url'],
                'isHindi': _isHindiStream(titleStr),
              });
            }
          }
        } catch (_) {}
      }

      return providerResolved;
    }).toList();

    var results = await Future.wait(tasks);
    for (var r in results) {
      resolved.addAll(r);
    }

    // Sorting: Hindi first, then others
    resolved.sort((a, b) => (b['isHindi'] == true ? 1 : 0).compareTo(a['isHindi'] == true ? 1 : 0));

    if (mounted) {
      setState(() {
        streams = resolved;
        loading = false;
      });
    }
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
      curr.removeWhere((c) => c['tmdb_id'].toString() == widget.item['tmdb_id'].toString());
      curr.insert(0, {
        'tmdb_id': widget.item['tmdb_id'],
        'title': widget.item['title'] ?? 'Untitled',
        'backdrop': widget.item['backdrop'] ?? '',
        'year': widget.item['year'] ?? '',
        'rating': widget.item['rating'] ?? '8.0',
        'isTv': widget.item['isTv'] ?? false,
      });
      if (curr.length > 15) {
        curr = curr.sublist(0, 15);
      }
      await prefs.setString('continue_watching_mobile', jsonEncode(curr));
      widget.onPlaySaved();
    } catch (_) {}
  }

  void _playStream(String url, bool isExternal) async {
    await _saveContinueWatching();
    if (!mounted) return;
    Navigator.pop(context);

    final cleanUrl = url.trim();

    if (isExternal) {
      final intent = AndroidIntent(
        action: 'action_view',
        data: cleanUrl,
        type: 'video/*',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InternalPlayerScreen(
            streamUrl: cleanUrl,
            title: widget.item['title'],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.season != null
                ? '${widget.item['title']} - S${widget.season} E${widget.episode}'
                : widget.item['title'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))))
          else if (streams.isEmpty)
            const Expanded(child: Center(child: Text('No active streams found on server.', style: TextStyle(color: Colors.white70))))
          else
            Expanded(
              child: ListView.builder(
                itemCount: streams.length,
                itemBuilder: (ctx, i) {
                  final s = streams[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF282828),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          s['isHindi'] == true ? Icons.record_voice_over_rounded : Icons.movie_rounded,
                          color: s['isHindi'] == true ? const Color(0xFF46D369) : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s['title'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s['server'],
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: Color(0xFFE50914), size: 28),
                          onPressed: () => _playStream(s['url'], false),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 22),
                          onPressed: () => _playStream(s['url'], true),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

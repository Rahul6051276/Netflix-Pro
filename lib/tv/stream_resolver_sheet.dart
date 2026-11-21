// ============================================================================
// NETFLIX PRO TV STREAM RESOLVER (GIST XTREAM + STREMIO - NO HARDCODED SERVER)
// ============================================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_config.dart';
import 'category_grid_screen.dart';
import 'internal_player.dart';

// Helper: Fetch raw JSON data directly from user-configured TV Gist URL
Future<dynamic> _fetchTvGistPayload() async {
  final rawGist = await TvConfig.getGistUrl();
  if (rawGist.isEmpty) return null;

  final sep = rawGist.contains('?') ? '&' : '?';
  final freshUrl = '$rawGist${sep}t=${DateTime.now().millisecondsSinceEpoch}';
  final res =
      await http.get(Uri.parse(freshUrl)).timeout(const Duration(seconds: 12));
  if (res.statusCode == 200) {
    return jsonDecode(res.body);
  }
  return null;
}

// Helper: Ensure providers are loaded from saved TV Gist URL
Future<List<dynamic>> _ensureTvProvidersLoaded(List<dynamic>? passed) async {
  final rawGist = await TvConfig.getGistUrl();

  try {
    if (rawGist.isNotEmpty) {
      final decoded = await _fetchTvGistPayload();
      final list = decoded is List
          ? decoded
          : (decoded is Map
              ? (decoded['active_providers'] ?? decoded['providers'] ?? [])
              : []);
      if (list is List) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_tv_active_providers', jsonEncode(list));
        return list;
      }
    }
  } catch (_) {}

  if (passed != null && passed.isNotEmpty) return passed;

  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString('cached_tv_active_providers');
  if (cached != null && cached.isNotEmpty) {
    try {
      final list = jsonDecode(cached);
      if (list is List && list.isNotEmpty) return list;
    } catch (_) {}
  }

  return [];
}

// ============================================================================
// FULL SCREEN CATEGORIES OVERLAY MODAL (TV)
// ============================================================================
void openTvCategoriesModal(
    BuildContext context, List<dynamic> providers, VoidCallback onRefresh) {
  List allCategories = [
    {
      'title': 'South Action Hits (Hindi Dubbed)',
      'url':
          '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=te|ta|ml|kn',
      'isTv': false
    },
    {
      'title': 'Hollywood Blockbusters (Hindi Dubbed)',
      'url':
          '${TvConfig.tmdbBase}/movie/popular?api_key=${TvConfig.tmdbKey}',
      'isTv': false
    },
    {
      'title': 'Latest Netflix Blockbusters',
      'url':
          '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_watch_providers=8&watch_region=IN',
      'isTv': false
    },
    {
      'title': 'Amazon Prime Video Hits',
      'url':
          '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_watch_providers=119&watch_region=IN',
      'isTv': false
    },
    {
      'title': 'Disney+ Hotstar Specials',
      'url':
          '${TvConfig.tmdbBase}/movie/now_playing?api_key=${TvConfig.tmdbKey}&language=en-US&region=IN',
      'isTv': false
    },
    {
      'title': 'Trending Hindi Web Series',
      'url':
          '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=hi&without_genres=10766&vote_count.gte=3',
      'isTv': true
    },
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
              decoration: BoxDecoration(
                  color: Colors.white30, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 22),
            const Text(
              'Categories',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
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
                          builder: (_) => TVCategoryGridScreen(
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
                          color: index < 2
                              ? const Color(0xFFE50914)
                              : Colors.white70,
                          fontSize: 17,
                          fontWeight:
                              index < 2 ? FontWeight.w900 : FontWeight.w600,
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
// TV EPISODE SELECTOR SHEET (FROM GIST XTREAM SEASONS + TMDB FALLBACK)
// ============================================================================
class TvEpisodeSheet extends StatefulWidget {
  final dynamic item;
  final List<dynamic>? providers;
  final void Function(int season, int episode) onSelected;

  const TvEpisodeSheet({
    super.key,
    required this.item,
    this.providers,
    required this.onSelected,
  });

  @override
  State<TvEpisodeSheet> createState() => _TvEpisodeSheetState();
}

class _TvEpisodeSheetState extends State<TvEpisodeSheet> {
  int selectedSeason = 1;
  Map<int, List<dynamic>> xtreamSeasonsMap = {};
  List<int> seasons = [1];
  bool loading = true;

  String _clean(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final activeProvs = await _ensureTvProvidersLoaded(widget.providers);
    final targetTmdbId = widget.item['tmdb_id']?.toString() ?? '';
    final cleanTarget = _clean((widget.item['title'] ?? '').toString());

    for (var prov in activeProvs) {
      if (prov is Map && prov['type'] == 'xtream') {
        final host = (prov['xc_host'] ?? prov['host'] ?? '')
            .toString()
            .replaceAll(RegExp(r'/+$'), '');
        final user = (prov['xc_username'] ?? prov['username'] ?? '').toString();
        final pass = (prov['xc_password'] ?? prov['password'] ?? '').toString();

        if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
          try {
            final searchApi =
                '$host/player_api.php?username=$user&password=$pass&action=get_series';
            final xtreamRes = await http
                .get(Uri.parse(searchApi),
                    headers: {'User-Agent': 'IPTVSmartersPro'})
                .timeout(const Duration(seconds: 12));
            if (xtreamRes.statusCode == 200) {
              final seriesList = jsonDecode(xtreamRes.body);
              if (seriesList is List) {
                for (var s in seriesList) {
                  final sTmdb = (s['tmdb_id'] ?? s['tmdb'] ?? '').toString();
                  final rawName = (s['name'] ?? '').toString();
                  if ((sTmdb.isNotEmpty && sTmdb == targetTmdbId) ||
                      _clean(rawName).contains(cleanTarget)) {
                    final sid = s['series_id'];
                    final infoApi =
                        '$host/player_api.php?username=$user&password=$pass&action=get_series_info&series_id=$sid';
                    final infoRes = await http
                        .get(Uri.parse(infoApi),
                            headers: {'User-Agent': 'IPTVSmartersPro'})
                        .timeout(const Duration(seconds: 10));
                    if (infoRes.statusCode == 200) {
                      final episodesMap =
                          jsonDecode(infoRes.body)['episodes'] ?? {};
                      if (episodesMap is Map) {
                        episodesMap.forEach((sNum, eps) {
                          final sn = int.tryParse(sNum.toString()) ?? 1;
                          if (eps is List && eps.isNotEmpty) {
                            xtreamSeasonsMap[sn] = eps;
                          }
                        });
                      }
                    }
                    break;
                  }
                }
              }
            }
          } catch (_) {}
        }
      }
      if (xtreamSeasonsMap.isNotEmpty) break;
    }

    if (xtreamSeasonsMap.isNotEmpty && mounted) {
      final sortedKeys = xtreamSeasonsMap.keys.toList()..sort();
      setState(() {
        seasons = sortedKeys;
        selectedSeason = sortedKeys.first;
        loading = false;
      });
      return;
    }

    if (TvConfig.tmdbKey.isNotEmpty) {
      try {
        final res = await http
            .get(Uri.parse(
                '${TvConfig.tmdbBase}/tv/${widget.item['tmdb_id']}?api_key=${TvConfig.tmdbKey}'))
            .timeout(const Duration(seconds: 8));
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

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final realEps = xtreamSeasonsMap[selectedSeason];
    final int count =
        (realEps != null && realEps.isNotEmpty) ? realEps.length : 12;

    return Container(
      height: 390,
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
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.item['title'] ?? 'Episodes',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Expanded(
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFE50914))),
            )
          else ...[
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
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
                  crossAxisCount: 6,
                  childAspectRatio: 1.8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: count,
                itemBuilder: (ctx, i) {
                  final epNum = (realEps != null && i < realEps.length)
                      ? (int.tryParse((realEps[i]['episode_num'] ?? (i + 1))
                              .toString()) ??
                          (i + 1))
                      : (i + 1);
                  return ElevatedButton(
                    autofocus: i == 0,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSelected(selectedSeason, epNum);
                    },
                    child: Text('EP $epNum', style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// TV STREAM RESOLVER SHEET (DIRECTLY FROM USER TV GIST XTREAM + STREMIO)
// ============================================================================
class TvStreamSheet extends StatefulWidget {
  final dynamic item;
  final int? season;
  final int? episode;
  final List<dynamic> providers;
  final VoidCallback onPlaySaved;

  const TvStreamSheet({
    super.key,
    required this.item,
    this.season,
    this.episode,
    required this.providers,
    required this.onPlaySaved,
  });

  @override
  State<TvStreamSheet> createState() => _TvStreamSheetState();
}

class _TvStreamSheetState extends State<TvStreamSheet> {
  var streams = [];
  bool loading = true;
  bool missingGistUrl = false;

  @override
  void initState() {
    super.initState();
    _fetchDirectStreams();
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

  Future<void> _fetchDirectStreams() async {
    var resolved = [];
    final rawGist = await TvConfig.getGistUrl();

    if (rawGist.isEmpty) {
      if (mounted) {
        setState(() {
          missingGistUrl = true;
          streams = [];
          loading = false;
        });
      }
      return;
    }

    final activeProvs = await _ensureTvProvidersLoaded(widget.providers);
    final targetTmdbId = widget.item['tmdb_id']?.toString() ?? '';
    final isTv = widget.item['isTv'] == true;
    final movieTitle = (widget.item['title'] ?? '').toString();
    final targetSeason = widget.season ?? 1;
    final targetEpisode = widget.episode ?? 1;
    final cleanTarget = _clean(movieTitle);

    String? imdbId;
    if (targetTmdbId.isNotEmpty && TvConfig.tmdbKey.isNotEmpty) {
      try {
        final extType = isTv ? 'tv' : 'movie';
        final extRes = await http
            .get(Uri.parse(
                '${TvConfig.tmdbBase}/$extType/$targetTmdbId/external_ids?api_key=${TvConfig.tmdbKey}'))
            .timeout(const Duration(seconds: 4));
        if (extRes.statusCode == 200) {
          imdbId = jsonDecode(extRes.body)['imdb_id'];
        }
      } catch (_) {}
    }

    for (var prov in activeProvs) {
      if (prov is! Map) continue;
      final type = prov['type'];

      if (type == 'xtream') {
        final host = (prov['xc_host'] ?? prov['host'] ?? '')
            .toString()
            .replaceAll(RegExp(r'/+$'), '');
        final user = (prov['xc_username'] ?? prov['username'] ?? '').toString();
        final pass = (prov['xc_password'] ?? prov['password'] ?? '').toString();

        if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
          try {
            if (isTv) {
              final searchApi =
                  '$host/player_api.php?username=$user&password=$pass&action=get_series';
              final xtreamRes = await http
                  .get(Uri.parse(searchApi),
                      headers: {'User-Agent': 'IPTVSmartersPro'})
                  .timeout(const Duration(seconds: 15));
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
                        .get(Uri.parse(infoApi),
                            headers: {'User-Agent': 'IPTVSmartersPro'})
                        .timeout(const Duration(seconds: 10));
                    if (infoRes.statusCode == 200) {
                      final epMap = jsonDecode(infoRes.body)['episodes'] ?? {};
                      final epList =
                          (epMap is Map) ? (epMap['$targetSeason'] ?? []) : [];

                      if (epList is List && epList.isNotEmpty) {
                        final match = epList.firstWhere(
                          (e) =>
                              int.tryParse((e['episode_num'] ?? 0).toString()) ==
                              targetEpisode,
                          orElse: () => null,
                        );

                        if (match != null) {
                          final isHindi = bestSeries['is_hindi_detected'] == true;
                          resolved.add({
                            'server': prov['name'] ?? 'Xtream Series HD',
                            'title': isHindi
                                ? '$movieTitle (Hindi Audio) S$targetSeason:E$targetEpisode'
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
                  .get(Uri.parse(searchApi),
                      headers: {'User-Agent': 'IPTVSmartersPro'})
                  .timeout(const Duration(seconds: 15));
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
                        'isHindi': _isHindiStream(rawName, category: categoryName),
                      });
                    }
                  }

                  candidates.sort((a, b) => (b['isHindi'] == true ? 1 : 0)
                      .compareTo(a['isHindi'] == true ? 1 : 0));

                  for (var cand in candidates.take(3)) {
                    final bestMovie = cand['data'];
                    final isHindi = cand['isHindi'] == true;
                    resolved.add({
                      'server': prov['name'] ?? 'Xtream Movies VIP',
                      'title': isHindi
                          ? '$movieTitle (Hindi Audio / Dubbed)'
                          : '$movieTitle (Direct HD)',
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

      if (type == 'stremio' && imdbId != null && imdbId.isNotEmpty) {
        final base = (prov['url'] ?? '')
            .toString()
            .replaceAll('/manifest.json', '');
        final streamPath = isTv
            ? '$base/stream/series/$imdbId:$targetSeason:$targetEpisode.json'
            : '$base/stream/movie/$imdbId.json';

        try {
          final res = await http
              .get(Uri.parse(streamPath))
              .timeout(const Duration(seconds: 6));
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
                  'server': prov['name'] ?? 'Stremio Server',
                  'title': titleStr.isNotEmpty ? titleStr : '$movieTitle Stream',
                  'url': stremioUrl,
                  'isHindi': _isHindiStream(titleStr),
                });
              }
            }
          }
        } catch (_) {}
      }
    }

    resolved.sort((a, b) {
      final aHindi = a['isHindi'] == true ? 1 : 0;
      final bHindi = b['isHindi'] == true ? 1 : 0;
      if (aHindi != bHindi) return bHindi.compareTo(aHindi);

      final aIsXtream = (a['url'] ?? '').toString().contains('/movie/') ||
              (a['url'] ?? '').toString().contains('/series/')
          ? 1
          : 0;
      final bIsXtream = (b['url'] ?? '').toString().contains('/movie/') ||
              (b['url'] ?? '').toString().contains('/series/')
          ? 1
          : 0;
      return bIsXtream.compareTo(aIsXtream);
    });

    if (mounted) {
      setState(() {
        missingGistUrl = false;
        streams = resolved;
        loading = false;
      });
    }
  }

  Future<void> _saveContinueWatching() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('continue_watching_tv');
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
      if (curr.length > 15) {
        curr = curr.sublist(0, 15);
      }
      await prefs.setString('continue_watching_tv', jsonEncode(curr));
      widget.onPlaySaved();
    } catch (_) {}
  }

  void _playStream(String url) async {
    await _saveContinueWatching();
    if (!mounted) return;
    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InternalPlayerScreen(
          streamUrl: url.trim(),
          title: widget.item['title'],
        ),
      ),
    );
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
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.item['title'] ?? 'Streams',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : streams.isEmpty
                    ? Center(
                        child: Text(
                          missingGistUrl
                              ? 'Please add your GitHub Gist Raw URL from Sidebar'
                              : 'No streams found from Gist providers',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: streams.length,
                        itemBuilder: (ctx, i) {
                          final s = streams[i];
                          final isHindi = s['isHindi'] == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                              border: isHindi
                                  ? Border.all(color: Colors.green, width: 1)
                                  : null,
                            ),
                            child: ListTile(
                              autofocus: i == 0,
                              title: Text(
                                s['title'],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                s['server'],
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                              trailing: const Icon(Icons.play_circle_fill,
                                  color: Color(0xFFE50914), size: 32),
                              onTap: () => _playStream(s['url']),
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
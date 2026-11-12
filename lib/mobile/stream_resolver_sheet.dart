// ============================================================================
// NETFLIX PRO STREAM RESOLVER (UPGRADED WITH CINEMA HQ ENGINE)
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

// Helper: Ensure providers are always loaded (even if clicked immediately)
Future<List<dynamic>> _ensureProvidersLoaded(List<dynamic>? passed) async {
  if (passed != null && passed.isNotEmpty) return passed;

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
        await http.get(Uri.parse(freshUrl)).timeout(const Duration(seconds: 10));
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

// ============================================================================
// FULL SCREEN CATEGORIES OVERLAY MODAL
// ============================================================================
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
// MOBILE EPISODE SELECTOR BOTTOM SHEET (REAL XTREAM SEASONS + FALLBACK)
// ============================================================================
class MobileEpisodeSheet extends StatefulWidget {
  final dynamic item;
  final List<dynamic>? providers;
  final Function(int s, int ep) onSelected;

  const MobileEpisodeSheet({
    super.key,
    required this.item,
    this.providers,
    required this.onSelected,
  });

  @override
  State<MobileEpisodeSheet> createState() => _MobileEpisodeSheetState();
}

class _MobileEpisodeSheetState extends State<MobileEpisodeSheet> {
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
    final activeProvs = await _ensureProvidersLoaded(widget.providers);
    final targetTmdbId = widget.item['tmdb_id']?.toString() ?? '';
    final cleanTarget = _clean((widget.item['title'] ?? '').toString());

    // 1. Pehle Cinema HQ ki tarah Xtream se real seasons/episodes check karo
    for (var prov in activeProvs) {
      if (prov['type'] == 'xtream') {
        final host = (prov['xc_host'] ?? prov['host'] ?? '')
            .toString()
            .replaceAll(RegExp(r'/+$'), '');
        final user = prov['xc_username'] ?? prov['username'] ?? '';
        final pass = prov['xc_password'] ?? prov['password'] ?? '';

        if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
          try {
            final searchApi =
                '$host/player_api.php?username=$user&password=$pass&action=get_series';
            final xtreamRes = await http
                .get(Uri.parse(searchApi))
                .timeout(const Duration(seconds: 6));
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
                        .get(Uri.parse(infoApi))
                        .timeout(const Duration(seconds: 6));
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

    // 2. Fallback: TMDB seasons (for Stremio / Cloud API)
    try {
      final res = await http
          .get(Uri.parse(
              '${MobileConfig.tmdbBase}/tv/${widget.item['tmdb_id']}?api_key=${MobileConfig.tmdbKey}'))
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

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final realEps = xtreamSeasonsMap[selectedSeason];
    final int count = (realEps != null && realEps.isNotEmpty) ? realEps.length : 12;

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
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Text(widget.item['title'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))),
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
                itemCount: count,
                itemBuilder: (ctx, i) {
                  final epNum = (realEps != null && i < realEps.length)
                      ? (int.tryParse((realEps[i]['episode_num'] ?? (i + 1)).toString()) ?? (i + 1))
                      : (i + 1);
                  return ElevatedButton(
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
// MOBILE STREAM RESOLVER BOTTOM SHEET (CINEMA HQ UNIVERSAL ENGINE)
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

  String _clean(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();

  Future<void> _fetchDirectStreams() async {
    var resolved = [];
    final activeProvs = await _ensureProvidersLoaded(widget.providers);
    final targetTmdbId = widget.item['tmdb_id']?.toString() ?? '';
    final isTv = widget.item['isTv'] == true;
    final movieTitle = (widget.item['title'] ?? '').toString();
    final targetSeason = widget.season ?? 1;
    final targetEpisode = widget.episode ?? 1;

    String? imdbId;
    if (targetTmdbId.isNotEmpty) {
      try {
        final extType = isTv ? 'tv' : 'movie';
        final extRes = await http.get(Uri.parse(
            '${MobileConfig.tmdbBase}/$extType/$targetTmdbId/external_ids?api_key=${MobileConfig.tmdbKey}')).timeout(const Duration(seconds: 4));
        if (extRes.statusCode == 200) {
          imdbId = jsonDecode(extRes.body)['imdb_id'];
        }
      } catch (_) {}
    }

    final cleanTarget = _clean(movieTitle);

    // ==========================================
    // 1. RENDER CLOUD API (Castle, Vidlink, Showbox etc.)
    // ==========================================
    if (targetTmdbId.isNotEmpty) {
      try {
        final embedType = isTv ? 'series' : 'movie';
        final embedUrl = isTv
            ? 'https://tmdb-embed-api-4.onrender.com/api/streams/$embedType/$targetTmdbId?season=$targetSeason&episode=$targetEpisode'
            : 'https://tmdb-embed-api-4.onrender.com/api/streams/$embedType/$targetTmdbId';

        final embedRes = await http.get(Uri.parse(embedUrl)).timeout(const Duration(seconds: 8));
        if (embedRes.statusCode == 200) {
          final embedData = jsonDecode(embedRes.body);
          final streamList = embedData is List ? embedData : (embedData['streams'] ?? []);

          if (streamList is List) {
            for (var s in streamList) {
              final sUrl = (s['url'] ?? '').toString();
              if (sUrl.isNotEmpty) {
                final sTitle = (s['title'] ?? '$movieTitle HD').toString();
                final provName = (s['provider'] ?? 'Cloud API').toString();
                final isHindi = _isHindiStream(sTitle);

                resolved.add({
                  'server': 'Cloud - $provName',
                  'title': sTitle,
                  'url': sUrl,
                  'isHindi': isHindi,
                });
              }
            }
          }
        }
      } catch (_) {}
    }

    // ==========================================
    // 2. GIST ACTIVE PROVIDERS (XTREAM + STREMIO)
    // ==========================================
    for (var prov in activeProvs) {
      final type = prov['type'];

      // A. XTREAM IPTV (Livebox Pro, Abbastream IPTV etc.)
      if (type == 'xtream') {
        final host = (prov['xc_host'] ?? prov['host'] ?? '').toString().replaceAll(RegExp(r'/+$'), '');
        final user = prov['xc_username'] ?? prov['username'] ?? '';
        final pass = prov['xc_password'] ?? prov['password'] ?? '';

        if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
          try {
            if (isTv) {
              final searchApi = '$host/player_api.php?username=$user&password=$pass&action=get_series';
              final xtreamRes = await http.get(Uri.parse(searchApi)).timeout(const Duration(seconds: 8));
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
                      s['is_hindi_detected'] = _isHindiStream(rawName, category: categoryName);
                      candidates.add(s);
                    }
                  }

                  candidates.sort((a, b) => (b['is_hindi_detected'] == true ? 1 : 0)
                      .compareTo(a['is_hindi_detected'] == true ? 1 : 0));

                  for (var bestSeries in candidates.take(2)) {
                    final sid = bestSeries['series_id'];
                    final infoApi = '$host/player_api.php?username=$user&password=$pass&action=get_series_info&series_id=$sid';
                    final infoRes = await http.get(Uri.parse(infoApi)).timeout(const Duration(seconds: 8));
                    if (infoRes.statusCode == 200) {
                      final epMap = jsonDecode(infoRes.body)['episodes'] ?? {};
                      final epList = (epMap is Map) ? (epMap['$targetSeason'] ?? []) : [];

                      if (epList is List && epList.isNotEmpty) {
                        final match = epList.firstWhere(
                          (e) => int.tryParse((e['episode_num'] ?? 0).toString()) == targetEpisode,
                          orElse: () => null,
                        );

                        if (match != null) {
                          final isHindi = bestSeries['is_hindi_detected'] == true;
                          resolved.add({
                            'server': prov['name'] ?? 'Xtream Series HD',
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
                }
              }
            } else {
              final searchApi = '$host/player_api.php?username=$user&password=$pass&action=get_vod_streams';
              final xtreamRes = await http.get(Uri.parse(searchApi)).timeout(const Duration(seconds: 8));
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
                      'title': isHindi ? '$movieTitle (Hindi Audio / Dubbed)' : '$movieTitle (Direct HD)',
                      'url': '$host/movie/$user/$pass/${bestMovie['stream_id']}.${bestMovie['container_extension'] ?? "mp4"}',
                      'isHindi': isHindi,
                    });
                  }
                }
              }
            }
          } catch (_) {}
        }
      }

      // B. STREMIO ADDON (PenguPlay, HdHub etc.)
      if (type == 'stremio' && imdbId != null && imdbId.isNotEmpty) {
        final base = (prov['url'] ?? '').toString().replaceAll('/manifest.json', '');
        final streamPath = isTv
            ? '$base/stream/series/$imdbId:$targetSeason:$targetEpisode.json'
            : '$base/stream/movie/$imdbId.json';

        try {
          final res = await http.get(Uri.parse(streamPath)).timeout(const Duration(seconds: 6));
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

      final aIsXtream = (a['server'] ?? '').toString().toLowerCase().contains('iptv') ||
              (a['server'] ?? '').toString().toLowerCase().contains('livebox')
          ? 1
          : 0;
      final bIsXtream = (b['server'] ?? '').toString().toLowerCase().contains('iptv') ||
              (b['server'] ?? '').toString().toLowerCase().contains('livebox')
          ? 1
          : 0;
      return bIsXtream.compareTo(aIsXtream);
    });

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
            widget.item['title'] ?? 'Streams',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : streams.isEmpty
                    ? const Center(child: Text('No streams found', style: TextStyle(color: Colors.white54)))
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
                              border: isHindi ? Border.all(color: Colors.green, width: 1) : null,
                            ),
                            child: ListTile(
                              title: Text(
                                s['title'],
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                s['server'],
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.play_circle_fill, color: Color(0xFFE50914), size: 32),
                                    onPressed: () => _playStream(s['url'], false),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new, color: Colors.amber, size: 22),
                                    onPressed: () => _playStream(s['url'], true),
                                  ),
                                ],
                              ),
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

// ============================================================================
// 4. MORE SCREEN (ONLY REQUESTED OTT WEB SERIES HUB WITH FILTERS)
// ============================================================================
class MobileMoreScreen extends StatelessWidget {
  final List<dynamic> providers;
  const MobileMoreScreen({super.key, required this.providers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('OTT Web Series Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Netflix Web Series
          ListTile(
            leading: const Icon(Icons.video_collection, color: Color(0xFFE50914)),
            title: const Text('Netflix Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Netflix Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=213&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),

          // 2. Amazon Web Series
          ListTile(
            leading: const Icon(Icons.video_library, color: Color(0xFFE50914)),
            title: const Text('Amazon Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Amazon Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=1024&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),

          // 3. Disney+ Hotstar Web Series
          ListTile(
            leading: const Icon(Icons.live_tv, color: Color(0xFFE50914)),
            title: const Text('Disney+ Hotstar Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Disney+ Hotstar Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=2739&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),

          // 4. Zee5 Web Series
          ListTile(
            leading: const Icon(Icons.tv_rounded, color: Color(0xFFE50914)),
            title: const Text('Zee5 Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Zee5 Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=2377&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),

          // 5. SonyLIV Web Series
          ListTile(
            leading: const Icon(Icons.monitor_rounded, color: Color(0xFFE50914)),
            title: const Text('SonyLIV Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'SonyLIV Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=2334&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
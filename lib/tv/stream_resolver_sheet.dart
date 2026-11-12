import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'tmdb_config.dart';
import 'internal_player.dart';

// Helper: Ensure TV providers are always available (cached + fresh Gist)
Future<List<dynamic>> _ensureTvProvidersLoaded(List<dynamic>? passed) async {
  if (passed != null && passed.isNotEmpty) return passed;

  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString('cached_tv_providers');
  if (cached != null && cached.isNotEmpty) {
    try {
      final list = jsonDecode(cached);
      if (list is List && list.isNotEmpty) return list;
    } catch (_) {}
  }

  try {
    final freshUrl =
        '${TvConfig.gistUrl}?t=${DateTime.now().millisecondsSinceEpoch}';
    final res =
        await http.get(Uri.parse(freshUrl)).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final list = decoded is List
          ? decoded
          : (decoded['active_providers'] ?? decoded['providers'] ?? []);
      if (list is List && list.isNotEmpty) {
        await prefs.setString('cached_tv_providers', jsonEncode(list));
        return list;
      }
    }
  } catch (_) {}

  return [];
}

// ============================================================================
// TV EPISODE DIALOG (REAL XTREAM SEASONS + TMDB FALLBACK)
// ============================================================================
class TvEpisodeDialog extends StatefulWidget {
  final dynamic item;
  final List<dynamic>? providers;
  final Function(int s, int ep) onSelected;

  const TvEpisodeDialog({
    super.key,
    required this.item,
    this.providers,
    required this.onSelected,
  });

  @override
  State<TvEpisodeDialog> createState() => _TvEpisodeDialogState();
}

class _TvEpisodeDialogState extends State<TvEpisodeDialog> {
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

    // 1. Pehle Xtream se real seasons/episodes check karo
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

    // 2. Fallback: TMDB seasons
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

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final realEps = xtreamSeasonsMap[selectedSeason];
    final int count =
        (realEps != null && realEps.isNotEmpty) ? realEps.length : 12;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item['title'],
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            if (loading)
              const SizedBox(
                height: 180,
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
                height: 180,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: count,
                  itemBuilder: (ctx, i) {
                    final epNum = (realEps != null && i < realEps.length)
                        ? (int.tryParse(
                                (realEps[i]['episode_num'] ?? (i + 1))
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
                      child: Text('EP $epNum',
                          style: const TextStyle(fontSize: 12)),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TV STREAM RESOLVER DIALOG (SYNCED WITH CINEMA HQ ENGINE)
// ============================================================================
class TvStreamDialog extends StatefulWidget {
  final dynamic item;
  final int? season;
  final int? episode;
  final List<dynamic> providers;
  final VoidCallback onPlaySaved;

  const TvStreamDialog({
    super.key,
    required this.item,
    this.season,
    this.episode,
    required this.providers,
    required this.onPlaySaved,
  });

  @override
  State<TvStreamDialog> createState() => _TvStreamDialogState();
}

class _TvStreamDialogState extends State<TvStreamDialog> {
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

  String _clean(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();

  Future<void> _fetchDirectStreams() async {
    var resolved = [];
    final activeProvs = await _ensureTvProvidersLoaded(widget.providers);
    final targetTmdbId = widget.item['tmdb_id']?.toString() ?? '';
    final isTv = widget.item['isTv'] == true;
    final movieTitle = (widget.item['title'] ?? '').toString();
    final targetSeason = widget.season ?? 1;
    final targetEpisode = widget.episode ?? 1;

    String? imdbId;
    if (targetTmdbId.isNotEmpty) {
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

        final embedRes =
            await http.get(Uri.parse(embedUrl)).timeout(const Duration(seconds: 8));
        if (embedRes.statusCode == 200) {
          final embedData = jsonDecode(embedRes.body);
          final streamList =
              embedData is List ? embedData : (embedData['streams'] ?? []);

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

      if (type == 'xtream') {
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
                  .timeout(const Duration(seconds: 8));
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
                        .timeout(const Duration(seconds: 8));
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
                  .get(Uri.parse(searchApi))
                  .timeout(const Duration(seconds: 8));
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
        final base =
            (prov['url'] ?? '').toString().replaceAll('/manifest.json', '');
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
                  'title':
                      titleStr.isNotEmpty ? titleStr : '$movieTitle Stream',
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

      final aIsXtream =
          (a['server'] ?? '').toString().toLowerCase().contains('iptv') ||
                  (a['server'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains('livebox')
              ? 1
              : 0;
      final bIsXtream =
          (b['server'] ?? '').toString().toLowerCase().contains('iptv') ||
                  (b['server'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains('livebox')
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
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        height: 340,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.season != null
                  ? '${widget.item['title']} - S${widget.season} E${widget.episode}'
                  : widget.item['title'],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Expanded(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFE50914))))
            else if (streams.isEmpty)
              const Expanded(
                  child: Center(
                      child: Text('No active streams found on server.',
                          style: TextStyle(color: Colors.white54))))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: streams.length,
                  itemBuilder: (ctx, i) {
                    final s = streams[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282828),
                        borderRadius: BorderRadius.circular(8),
                        border: s['isHindi'] == true
                            ? Border.all(
                                color: const Color(0xFF46D369), width: 1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            s['isHindi'] == true
                                ? Icons.record_voice_over_rounded
                                : Icons.movie_rounded,
                            color: s['isHindi'] == true
                                ? const Color(0xFF46D369)
                                : Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  s['title'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s['server'],
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Focus(
                            autofocus: i == 0,
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent &&
                                  (event.logicalKey ==
                                          LogicalKeyboardKey.select ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.enter)) {
                                _playStream(s['url'], false);
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Builder(builder: (c) {
                              final focused = Focus.of(c).hasFocus;
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: focused
                                      ? Colors.white
                                      : const Color(0xFFE50914),
                                  foregroundColor:
                                      focused ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                ),
                                onPressed: () => _playStream(s['url'], false),
                                child: const Text('Play'),
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          Focus(
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent &&
                                  (event.logicalKey ==
                                          LogicalKeyboardKey.select ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.enter)) {
                                _playStream(s['url'], true);
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Builder(builder: (c) {
                              final focused = Focus.of(c).hasFocus;
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      focused ? Colors.white : Colors.white12,
                                  foregroundColor:
                                      focused ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                ),
                                onPressed: () => _playStream(s['url'], true),
                                child: const Text('VLC'),
                              );
                            }),
                          ),
                        ],
                      ),
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
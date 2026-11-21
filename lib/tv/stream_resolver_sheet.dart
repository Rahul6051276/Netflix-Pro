import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_config.dart';
import 'internal_player.dart';

// ============================================================================
// HELPER: FETCH PROVIDERS DIRECTLY FROM SAVED TV GIST URL
// ============================================================================
Future<List<dynamic>> _ensureTvProvidersLoaded(List<dynamic>? passed) async {
  final rawGist = await TvConfig.getGistUrl();

  try {
    if (rawGist.isNotEmpty) {
      final sep = rawGist.contains('?') ? '&' : '?';
      final freshUrl = '$rawGist${sep}t=${DateTime.now().millisecondsSinceEpoch}';
      final res = await http
          .get(Uri.parse(freshUrl))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
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
// DIRECT NATIVE PLAYER LAUNCHER FOR TV
// ============================================================================
Future<void> launchTvDirectNativePlayer({
  required dynamic item,
  int season = 1,
  int episode = 1,
  VoidCallback? onPlaySaved,
}) async {
  const MethodChannel playerChannel =
      MethodChannel('com.netflixpro.netflix_pro/player');

  String savedGistUrl = '';
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    savedGistUrl = await TvConfig.getGistUrl();

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
      'overview': item['overview'] ?? '',
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
      'tmdbKey': TvConfig.tmdbKey,
      'gistUrl': savedGistUrl,
      'isTv': isTv,
      'season': season,
      'episode': episode,
      'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) CinemaTV/1.0',
    });
  } catch (_) {}
}

// ============================================================================
// TV MOVIE & SERIES DETAIL SCREEN (STAR CAST + STORYLINE + WATCH NOW)
// ============================================================================
class TvMediaDetailScreen extends StatefulWidget {
  final dynamic item;
  final VoidCallback? onPlaySaved;

  const TvMediaDetailScreen({
    super.key,
    required this.item,
    this.onPlaySaved,
  });

  @override
  State<TvMediaDetailScreen> createState() => _TvMediaDetailScreenState();
}

class _TvMediaDetailScreenState extends State<TvMediaDetailScreen> {
  final FocusNode _watchNowFocus = FocusNode();
  final FocusNode _backFocus = FocusNode();

  String _overview = '';
  String _genres = '';
  String _runtime = '';
  List _castList = [];
  List _seasons = [1];
  int _selectedSeason = 1;
  int _episodeCount = 12;
  bool _loadingDetails = true;

  @override
  void initState() {
    super.initState();
    _overview = (widget.item['overview'] ?? '').toString();
    _fetchFullDetailsAndCast();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _watchNowFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _watchNowFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchFullDetailsAndCast() async {
    final tmdbId = (widget.item['tmdb_id'] ?? '').toString();
    final isTv = widget.item['isTv'] == true;
    if (tmdbId.isEmpty || TvConfig.tmdbKey.isEmpty) {
      if (mounted) setState(() => _loadingDetails = false);
      return;
    }

    final type = isTv ? 'tv' : 'movie';
    try {
      final res = await http
          .get(Uri.parse(
              '${TvConfig.tmdbBase}/$type/$tmdbId?api_key=${TvConfig.tmdbKey}&append_to_response=credits'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final fetchedOverview = (data['overview'] ?? '').toString();
        final genreNames = (data['genres'] as List? ?? [])
            .map((g) => (g['name'] ?? '').toString())
            .where((n) => n.isNotEmpty)
            .take(3)
            .join(' • ');

        String durationText = '';
        if (!isTv && data['runtime'] != null && (data['runtime'] as int) > 0) {
          final mins = data['runtime'] as int;
          durationText = '${mins ~/ 60}h${mins % 60}m';
        } else if (isTv && data['number_of_seasons'] != null) {
          durationText = '${data['number_of_seasons']} Seasons';
        }

        final credits = data['credits'] as Map? ?? {};
        final rawCast = (credits['cast'] as List? ?? []).take(10).toList();

        List seasonNums = [1];
        int firstEpCount = 12;
        if (isTv) {
          final rawSeasons = (data['seasons'] as List? ?? [])
              .where((s) => (s['season_number'] ?? 0) > 0)
              .toList();
          if (rawSeasons.isNotEmpty) {
            seasonNums =
                rawSeasons.map((s) => s['season_number'] as int).toList();
            firstEpCount =
                (rawSeasons.first['episode_count'] as int? ?? 12).clamp(1, 50);
          }
        }

        if (mounted) {
          setState(() {
            if (fetchedOverview.isNotEmpty) _overview = fetchedOverview;
            _genres = genreNames;
            _runtime = durationText;
            _castList = rawCast;
            _seasons = seasonNums;
            _selectedSeason = seasonNums.first;
            _episodeCount = firstEpCount;
            _loadingDetails = false;
          });
        }
      } else if (mounted) {
        setState(() => _loadingDetails = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  void _startPlayback({int season = 1, int episode = 1}) {
    launchTvDirectNativePlayer(
      item: widget.item,
      season: season,
      episode: episode,
      onPlaySaved: widget.onPlaySaved,
    );
  }

  void _openEpisodePicker() {
    showDialog(
      context: context,
      builder: (ctx) => TvEpisodeDialog(
        item: widget.item,
        initialSeasons: _seasons,
        initialSeason: _selectedSeason,
        initialEpCount: _episodeCount,
        onSelected: (season, episode) {
          _startPlayback(season: season, episode: episode);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTv = widget.item['isTv'] == true;
    final String title = (widget.item['title'] ?? 'Untitled').toString();
    final String backdrop =
        (widget.item['backdrop'] ?? widget.item['poster'] ?? '').toString();
    final String poster =
        (widget.item['poster'] ?? widget.item['backdrop'] ?? '').toString();
    final String rating = (widget.item['rating'] ?? '7.8').toString();
    final String year = (widget.item['year'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backdrop.isNotEmpty)
            Image.network(
              backdrop,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: const Color(0xFF141414)),
            ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF50B0B0B),
                  Color(0xD90B0B0B),
                  Color(0x660B0B0B),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x88000000),
                  Colors.transparent,
                  Color(0xF20B0B0B),
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(36, 22, 36, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Focus(
                    focusNode: _backFocus,
                    onKey: (node, event) {
                      if (event is RawKeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.enter)) {
                        Navigator.of(context).pop();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Builder(builder: (c) {
                      final focused = Focus.of(c).hasFocus;
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: focused ? Colors.white : Colors.white12,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: focused ? Colors.white : Colors.white24,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_rounded,
                                  size: 18,
                                  color: focused ? Colors.black : Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Back',
                                style: TextStyle(
                                  color: focused ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 195,
                            height: 285,
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: Colors.white24, width: 1.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: poster.isNotEmpty
                                ? Image.network(
                                    poster,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFF222222)),
                                  )
                                : Container(color: const Color(0xFF222222)),
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE50914),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isTv ? 'WEB SERIES' : 'MOVIE',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '$rating ★ IMDb',
                                    style: const TextStyle(
                                      color: Color(0xFF46D369),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (year.isNotEmpty) ...[
                                    const SizedBox(width: 12),
                                    Text('•  $year',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13)),
                                  ],
                                  if (_runtime.isNotEmpty) ...[
                                    const SizedBox(width: 12),
                                    Text('•  $_runtime',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                              if (_genres.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _genres,
                                  style: const TextStyle(
                                    color: Color(0xFFF5C518),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Text(
                                'STORYLINE',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _overview.isNotEmpty
                                    ? _overview
                                    : 'Storyline details available upon playback.',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Focus(
                                    focusNode: _watchNowFocus,
                                    autofocus: true,
                                    onKey: (node, event) {
                                      if (event is RawKeyDownEvent &&
                                          (event.logicalKey ==
                                                  LogicalKeyboardKey.select ||
                                              event.logicalKey ==
                                                  LogicalKeyboardKey.enter)) {
                                        if (isTv) {
                                          _openEpisodePicker();
                                        } else {
                                          _startPlayback();
                                        }
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: Builder(builder: (c) {
                                      final focused = Focus.of(c).hasFocus;
                                      return ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: focused
                                              ? Colors.white
                                              : const Color(0xFFE50914),
                                          foregroundColor: focused
                                              ? Colors.black
                                              : Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 26, vertical: 14),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          side: BorderSide(
                                            color: focused
                                                ? const Color(0xFFE50914)
                                                : Colors.transparent,
                                            width: 2.0,
                                          ),
                                        ),
                                        onPressed: () {
                                          if (isTv) {
                                            _openEpisodePicker();
                                          } else {
                                            _startPlayback();
                                          }
                                        },
                                        icon: const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 26),
                                        label: Text(
                                          isTv
                                              ? 'Select Episode & Watch'
                                              : 'Watch Now',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  if (isTv) ...[
                                    const SizedBox(width: 14),
                                    Focus(
                                      onKey: (node, event) {
                                        if (event is RawKeyDownEvent &&
                                            (event.logicalKey ==
                                                    LogicalKeyboardKey.select ||
                                                event.logicalKey ==
                                                    LogicalKeyboardKey.enter)) {
                                          _startPlayback(
                                              season: 1, episode: 1);
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: Builder(builder: (c) {
                                        final focused = Focus.of(c).hasFocus;
                                        return ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: focused
                                                ? Colors.white
                                                : Colors.white12,
                                            foregroundColor: focused
                                                ? Colors.black
                                                : Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 14),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6)),
                                          ),
                                          onPressed: () => _startPlayback(
                                              season: 1, episode: 1),
                                          icon: const Icon(
                                              Icons.fast_forward_rounded,
                                              size: 20),
                                          label: const Text(
                                            'Play S1:E1',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 18),
                              if (_castList.isNotEmpty) ...[
                                const Text(
                                  'STAR CAST',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 92,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _castList.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 14),
                                    itemBuilder: (ctx, idx) {
                                      final actor = _castList[idx];
                                      final name =
                                          (actor['name'] ?? '').toString();
                                      final character =
                                          (actor['character'] ?? '').toString();
                                      final profile = actor['profile_path'];
                                      final imgUrl = profile != null
                                          ? 'https://image.tmdb.org/t/p/w185$profile'
                                          : '';

                                      return SizedBox(
                                        width: 76,
                                        child: Column(
                                          children: [
                                            CircleAvatar(
                                              radius: 26,
                                              backgroundColor:
                                                  const Color(0xFF262626),
                                              backgroundImage: imgUrl.isNotEmpty
                                                  ? NetworkImage(imgUrl)
                                                  : null,
                                              child: imgUrl.isEmpty
                                                  ? const Icon(Icons.person,
                                                      color: Colors.white54,
                                                      size: 24)
                                                  : null,
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (character.isNotEmpty)
                                              Text(
                                                character,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 9.5,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ] else if (_loadingDetails)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xFFE50914),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
// TV EPISODE DIALOG
// ============================================================================
class TvEpisodeDialog extends StatefulWidget {
  final dynamic item;
  final List initialSeasons;
  final int initialSeason;
  final int initialEpCount;
  final Function(int s, int ep) onSelected;

  const TvEpisodeDialog({
    super.key,
    required this.item,
    this.initialSeasons = const [1],
    this.initialSeason = 1,
    this.initialEpCount = 12,
    required this.onSelected,
  });

  @override
  State<TvEpisodeDialog> createState() => _TvEpisodeDialogState();
}

class _TvEpisodeDialogState extends State<TvEpisodeDialog> {
  late int selectedSeason;
  late int episodeCount;
  late List seasons;

  @override
  void initState() {
    super.initState();
    seasons = List.from(widget.initialSeasons);
    selectedSeason = widget.initialSeason;
    episodeCount = widget.initialEpCount;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    if (TvConfig.tmdbKey.isEmpty) return;
    try {
      final res = await http
          .get(Uri.parse(
              '${TvConfig.tmdbBase}/tv/${widget.item['tmdb_id']}?api_key=${TvConfig.tmdbKey}'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawList = (data['seasons'] as List? ?? [])
            .where((s) => (s['season_number'] ?? 0) > 0)
            .toList();
        if (rawList.isNotEmpty && mounted) {
          setState(() {
            seasons = rawList.map((s) => s['season_number'] as int).toList();
            if (!seasons.contains(selectedSeason)) {
              selectedSeason = seasons.first;
            }
            final matched = rawList.firstWhere(
              (s) => s['season_number'] == selectedSeason,
              orElse: () => rawList.first,
            );
            episodeCount =
                (matched['episode_count'] as int? ?? 12).clamp(1, 50);
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
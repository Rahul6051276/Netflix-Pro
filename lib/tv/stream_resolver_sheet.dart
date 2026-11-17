import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_config.dart';

// ============================================================================
// DIRECT NATIVE PLAYER LAUNCHER FOR TV (WITH GIST URL + TV UI + ORIG LANGUAGE)
// ============================================================================
Future launchTvDirectNativePlayer({
  required dynamic item,
  int season = 1,
  int episode = 1,
  VoidCallback? onPlaySaved,
}) async {
  const MethodChannel playerChannel =
      MethodChannel('com.netflixpro.netflix_pro/player');

  String activeGistUrl = '';
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    activeGistUrl = (prefs.getString('tv_custom_gist_url') ?? '').trim();

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
      'original_language': item['original_language'] ?? '',
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
  final origLang = (item['original_language'] ?? '').toString();

  try {
    await playerChannel.invokeMethod('playVideo', {
      'url': '',
      'title': title,
      'tmdbId': tmdbId,
      'isTv': isTv,
      'season': season,
      'episode': episode,
      'gistUrl': activeGistUrl,
      'isTvDevice': true,
      'originalLanguage': origLang,
      'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0',
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
  State createState() => _TvMediaDetailScreenState();
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

  Future _fetchFullDetailsAndCast() async {
    final tmdbId = (widget.item['tmdb_id'] ?? '').toString();
    final isTv = widget.item['isTv'] == true;
    if (tmdbId.isEmpty) {
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
          durationText = '${mins ~/ 60}h ${mins % 60}m';
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
  State createState() => _TvEpisodeDialogState();
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

  Future _fetchDetails() async {
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
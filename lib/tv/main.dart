// ============================================================================
// NETFLIX PRO - OFFICIAL ANDROID TV EDITION (LEANBACK UI & DPAD CONTROLLER)
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:video_player/video_player.dart';
import './internal_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NetflixProTvApp());
}

class NetflixProTvApp extends StatelessWidget {
  const NetflixProTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netflix Pro TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
      ),
      home: const TvHomeScreen(),
    );
  }
}
class TvConfig {
  static const String gistUrl =
      'https://gist.githubusercontent.com/Rahul6051276/239654d65b2124bffd0ea21b5251dc02/raw/providers.json';
  static const String tmdbKey = 'b7cd3340a794e5a2f35e3abb820b497f';
  static const String tmdbBase = 'https://api.themoviedb.org/3';
  static const String imgBase = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBase = 'https://image.tmdb.org/t/p/w1280';
}

bool isSoapShow(String title) {
  final t = title.toLowerCase();
  const blocked = [
    'c.i.d.', 'cid', 'bhabiji', 'balika vadhu', 'kapil sharma', 'roadies',
    'pavitra rishta', 'kumkum bhagya', 'jhanak', 'kundali bhagya',
    'ye rishta', 'yrkkh', 'taarak mehta', 'tmkoc', 'kasautii', 'ishqbaaaz',
    'anupamaa', 'bigg boss', 'khatron ke khiladi', 'splitsvilla',
    'crime patrol', 'savdhaan india', 'diya aur baati', 'qubool hai',
    'jamai raja', 'tujhse hai raabta', 'radhakrishn', 'koffee with karan'
  ];
  return blocked.any((b) => t.contains(b));
}

// ----------------------------------------------------------------------------
// TV HOME SCREEN
// ----------------------------------------------------------------------------
class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  int _selectedNavIndex = 1; // Default to Home
  final List<FocusNode> _sidebarFocusNodes = List.generate(5, (_) => FocusNode());
  final FocusNode _firstContentCardFocus = FocusNode();
  final FocusNode _watchNowFocusNode = FocusNode();

  List<dynamic> activeProviders = [];
  List<dynamic> continueWatchingList = [];
  Map<String, dynamic>? activeShowcaseItem;

  // Netflix Ordered Rows
  List<dynamic> netflixSeriesList = [];
  List<dynamic> netflixMoviesList = [];
  List<dynamic> hindiWebSeriesList = [];
  List<dynamic> bollywoodMoviesList = [];
  List<dynamic> southHindiList = [];
  List<dynamic> hollywoodHindiList = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllTvData();
  }

  @override
  void dispose() {
    for (var node in _sidebarFocusNodes) {
      node.dispose();
    }
    _firstContentCardFocus.dispose();
    _watchNowFocusNode.dispose();
    super.dispose();
  }

  void _jumpFocusToSidebar() {
    final activeIndex = _selectedNavIndex.clamp(0, _sidebarFocusNodes.length - 1);
    _sidebarFocusNodes[activeIndex].requestFocus();
  }

  void _jumpFocusToContent() {
    _firstContentCardFocus.requestFocus();
  }

  Future<void> _loadAllTvData() async {
    await Future.wait([
      _fetchProviders(),
      _loadContinueWatching(),
      _fetchNetflixTvCatalogs(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _loadContinueWatching() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('continue_watching_tv');
      if (raw != null && raw.isNotEmpty && mounted) {
        setState(() {
          continueWatchingList = List<dynamic>.from(jsonDecode(raw));
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchProviders() async {
    try {
      final res = await http.get(Uri.parse(TvConfig.gistUrl));
      if (res.statusCode == 200) {
        activeProviders = jsonDecode(res.body)['active_providers'] ?? [];
      }
    } catch (_) {}
  }

  Future<void> _fetchNetflixTvCatalogs() async {
    try {
      // 1. Only on Netflix Originals (Series)
      final netflixTvRes = await http.get(Uri.parse(
          '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_networks=213&sort_by=popularity.desc&vote_count.gte=20'));
      if (netflixTvRes.statusCode == 200) {
        netflixSeriesList = _parseTvList(jsonDecode(netflixTvRes.body)['results'], isTv: true);
        if (netflixSeriesList.isNotEmpty) {
          activeShowcaseItem = netflixSeriesList.first;
        }
      }

      // 2. Netflix Blockbuster Movies (Provider 8)
      final netflixMovieRes = await http.get(Uri.parse(
          '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&sort_by=popularity.desc&vote_count.gte=10'));
      if (netflixMovieRes.statusCode == 200) {
        netflixMoviesList = _parseTvList(jsonDecode(netflixMovieRes.body)['results']);
      }

      // 3. Trending Indian Web Series
      final hindiTvRes = await http.get(Uri.parse(
          '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=vote_count.desc&vote_count.gte=10'));
      if (hindiTvRes.statusCode == 200) {
        hindiWebSeriesList = _parseTvList(jsonDecode(hindiTvRes.body)['results'], isTv: true)
            .where((item) => !isSoapShow(item['title'] ?? ''))
            .toList();
      }

      // 4. Bollywood Movies
      final bollyRes = await http.get(Uri.parse(
          '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=hi&sort_by=popularity.desc&vote_count.gte=10'));
      if (bollyRes.statusCode == 200) {
        bollywoodMoviesList = _parseTvList(jsonDecode(bollyRes.body)['results']);
      }

      // 5. South Indian Hindi Dubbed
      final southRes = await http.get(Uri.parse(
          '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn&sort_by=popularity.desc&vote_count.gte=20'));
      if (southRes.statusCode == 200) {
        southHindiList = _parseTvList(jsonDecode(southRes.body)['results']);
      }

      // 6. Hollywood Hindi Dubbed
      final hollyRes = await http.get(Uri.parse(
          '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=en&sort_by=popularity.desc&vote_count.gte=80'));
      if (hollyRes.statusCode == 200) {
        hollywoodHindiList = _parseTvList(jsonDecode(hollyRes.body)['results']);
      }
    } catch (_) {}
  }

  List<dynamic> _parseTvList(dynamic list, {bool isTv = false}) {
    List<dynamic> res = [];
    final currentYear = DateTime.now().year.toString();
    for (var m in (list ?? [])) {
      if (m['backdrop_path'] == null && m['poster_path'] == null) continue;
      res.add({
        'tmdb_id': m['id'],
        'title': m['title'] ?? m['name'] ?? 'Untitled',
        'year': (m['release_date'] ?? m['first_air_date'] ?? currentYear).toString().split('-')[0],
        'rating': m['vote_average']?.toString() ?? '8.0',
        'backdrop': m['backdrop_path'] != null
            ? '${TvConfig.backdropBase}${m['backdrop_path']}'
            : '${TvConfig.imgBase}${m['poster_path']}',
        'poster': m['poster_path'] != null
            ? '${TvConfig.imgBase}${m['poster_path']}'
            : '${TvConfig.backdropBase}${m['backdrop_path']}',
        'overview': m['overview'] ?? '',
        'isTv': isTv,
      });
    }
    return res;
  }

  void _onTvItemSelect(Map<String, dynamic> item) {
    if (item['isTv'] == true) {
      showDialog(
        context: context,
        builder: (ctx) => TvEpisodeDialog(
          item: item,
          onSelected: (season, episode) {
            _showTvStreamDialog(item, season: season, episode: episode);
          },
        ),
      );
    } else {
      _showTvStreamDialog(item);
    }
  }

  void _showTvStreamDialog(Map<String, dynamic> item, {int? season, int? episode}) {
    showDialog(
      context: context,
      builder: (ctx) => TvStreamDialog(
        item: item,
        season: season,
        episode: episode,
        providers: activeProviders,
        onPlaySaved: () => _loadContinueWatching(),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // NETFLIX LEANBACK SIDEBAR
  // --------------------------------------------------------------------------
  Widget _buildNetflixSidebar() {
    final icons = [
      Icons.search_rounded,
      Icons.home_filled,
      Icons.movie_creation_outlined,
      Icons.tv_rounded,
      Icons.history_rounded,
    ];

    return Container(
      width: 64,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // Netflix Red Brand Mark
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'N',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 36),
          Expanded(
            child: ListView.separated(
              itemCount: icons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemBuilder: (ctx, i) {
                return NetflixSidebarIcon(
                  focusNode: _sidebarFocusNodes[i],
                  icon: icons[i],
                  isSelected: _selectedNavIndex == i,
                  onRightArrow: _jumpFocusToContent,
                  onTap: () {
                    setState(() => _selectedNavIndex = i);
                    _jumpFocusToContent();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TOP DYNAMIC CINEMATIC BILLBOARD
  // --------------------------------------------------------------------------
  Widget _buildNetflixBillboard(Map<String, dynamic> item) {
    return SizedBox(
      height: 340,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Colors.black],
                  stops: [0.0, 0.40],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: Image.network(
                item['backdrop'],
                fit: BoxFit.cover,
                alignment: Alignment.topRight,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF141414)),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x66141414), Color(0xFF141414)],
                  stops: [0.15, 0.65, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 24,
            right: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('N', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item['isTv'] == true ? 'SERIES' : 'FILM',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item['title'].toString().toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('98% Match', style: TextStyle(color: Color(0xFF46D369), fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 10),
                    Text(item['year'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(2)),
                      child: const Text('U/A 16+', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ),
                    const SizedBox(width: 10),
                    const Text('Ultra HD 4K', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  (item['overview'] ?? '').toString().isNotEmpty
                      ? item['overview']
                      : 'Watch high-speed HD streams without commitments directly on your Android TV.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Focus(
                      focusNode: _watchNowFocusNode,
                      onKey: (node, event) {
                        if (event is RawKeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.select ||
                                event.logicalKey == LogicalKeyboardKey.enter)) {
                          _onTvItemSelect(item);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Builder(builder: (c) {
                        final focused = Focus.of(c).hasFocus;
                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: focused ? Colors.white : Colors.white24,
                            foregroundColor: focused ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            side: BorderSide(
                              color: focused ? Colors.white : Colors.transparent,
                              width: 1.8,
                            ),
                          ),
                          onPressed: () => _onTvItemSelect(item),
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: const Text('Play', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

    // --------------------------------------------------------------------------
  // NETFLIX LANDSCAPE ROW (16:9 RATIO)
  // --------------------------------------------------------------------------
  Widget _buildNetflixRow(String title, List<dynamic> items, {bool isFirstRow = false}) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 155,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (ctx, idx) {
              return NetflixTvCard(
                focusNode: (isFirstRow && idx == 0) ? _firstContentCardFocus : null,
                item: items[idx],
                isFirstInRow: idx == 0,
                onLeftBoundaryHit: _jumpFocusToSidebar,
                onFocusGained: () {
                  setState(() => activeShowcaseItem = items[idx]);
                },
                onTap: () => _onTvItemSelect(items[idx]),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Row(
        children: [
          _buildNetflixSidebar(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (activeShowcaseItem != null) _buildNetflixBillboard(activeShowcaseItem!),

                        if (continueWatchingList.isNotEmpty)
                          _buildNetflixRow('Continue Watching for You', continueWatchingList, isFirstRow: true),

                        // 1. NETFLIX ORIGINAL SERIES
                        _buildNetflixRow(
                          'Only on Netflix (Original Series)',
                          netflixSeriesList,
                          isFirstRow: continueWatchingList.isEmpty,
                        ),

                        // 2. NETFLIX BLOCKBUSTER MOVIES
                        _buildNetflixRow('Netflix Blockbuster Movies', netflixMoviesList),

                        // 3. TRENDING INDIAN WEB SERIES
                        _buildNetflixRow('Trending Indian Web Series', hindiWebSeriesList),

                        // 4. BOLLYWOOD BLOCKBUSTERS
                        _buildNetflixRow('Bollywood Blockbusters', bollywoodMoviesList),

                        // 5. SOUTH ACTION HINDI DUBBED
                        _buildNetflixRow('South Action Hits (Hindi Dubbed)', southHindiList),

                        // 6. HOLLYWOOD HITS
                        _buildNetflixRow('Hollywood Hits (Hindi Dubbed)', hollywoodHindiList),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// SIDEBAR ICON WIDGET
// ----------------------------------------------------------------------------
class NetflixSidebarIcon extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onRightArrow;
  final VoidCallback onTap;

  const NetflixSidebarIcon({
    super.key,
    required this.focusNode,
    required this.icon,
    required this.isSelected,
    required this.onRightArrow,
    required this.onTap,
  });

  @override
  State<NetflixSidebarIcon> createState() => _NetflixSidebarIconState();
}

class _NetflixSidebarIconState extends State<NetflixSidebarIcon> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _isFocused = f),
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            widget.onRightArrow();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isFocused ? const Color(0xFFE50914) : Colors.transparent,
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Icon(
            widget.icon,
            color: _isFocused
                ? Colors.white
                : widget.isSelected
                    ? Colors.white
                    : Colors.white38,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// NETFLIX TV CARD WITH DPAD HIGHLIGHT
// ----------------------------------------------------------------------------
class NetflixTvCard extends StatefulWidget {
  final FocusNode? focusNode;
  final Map<String, dynamic> item;
  final bool isFirstInRow;
  final VoidCallback onLeftBoundaryHit;
  final VoidCallback onFocusGained;
  final VoidCallback onTap;

  const NetflixTvCard({
    super.key,
    this.focusNode,
    required this.item,
    this.isFirstInRow = false,
    required this.onLeftBoundaryHit,
    required this.onFocusGained,
    required this.onTap,
  });

  @override
  State<NetflixTvCard> createState() => _NetflixTvCardState();
}

class _NetflixTvCardState extends State<NetflixTvCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) {
        setState(() => _isFocused = f);
        if (f) widget.onFocusGained();
      },
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft && widget.isFirstInRow) {
            widget.onLeftBoundaryHit();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: 180,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isFocused ? Colors.white : Colors.transparent,
                width: 2.2,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.4),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.item['backdrop'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1E1E)),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      color: Colors.black87,
                      child: Text(
                        widget.item['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// TV EPISODE SELECTOR DIALOG
// ----------------------------------------------------------------------------
class TvEpisodeDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(int s, int ep) onSelected;

  const TvEpisodeDialog({super.key, required this.item, required this.onSelected});

  @override
  State<TvEpisodeDialog> createState() => _TvEpisodeDialogState();
}

class _TvEpisodeDialogState extends State<TvEpisodeDialog> {
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
          '${TvConfig.tmdbBase}/tv/${widget.item['tmdb_id']}?api_key=${TvConfig.tmdbKey}'));
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
    return Dialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item['title'],
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
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
      ),
    );
  }
}

// // ----------------------------------------------------------------------------
// // TV STREAM RESOLVER DIALOG
// // ----------------------------------------------------------------------------
class TvStreamDialog extends StatefulWidget {
  final Map<String, dynamic> item;
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
  List<dynamic> streams = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStreams();
  }

  String _clean(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _fetchStreams() async {
    List<dynamic> resolved = [];

    try {
      final isTvShow = widget.item['media_type'] == 'tv' || widget.item['is_tv'] == true;
      final movieTitle = widget.item['title'] ?? widget.item['name'] ?? '';
      final targetSeason = widget.season ?? widget.item['season'] ?? 1;
      final targetEpisode = widget.episode ?? widget.item['episode'] ?? 1;

      for (var prov in widget.providers) {
        final host = prov['host']?.toString().replaceAll(RegExp(r'/+$'), '');
        final user = prov['username'];
        final pass = prov['password'];

        if (host == null || user == null || pass == null) continue;

        if (isTvShow) {
          final searchApi = '$host/player_api.php?username=$user&password=$pass&action=get_series';
          final xtreamRes = await http.get(Uri.parse(searchApi)).timeout(const Duration(seconds: 8));

          if (xtreamRes.statusCode == 200) {
            final List<dynamic> seriesList = jsonDecode(xtreamRes.body);
            List<dynamic> candidates = [];

            for (var s in seriesList) {
              final sTmdb = (s['tmdb_id'] ?? s['tmdb'] ?? '').toString();
              final rawName = (s['name'] ?? '').toString();
              final categoryName = (s['category_name'] ?? '').toString();
              final sClean = _clean(rawName);
              final queryClean = _clean(movieTitle);

              bool isHindi = rawName.toLowerCase().contains('hindi') || categoryName.toLowerCase().contains('hindi');

              if (sTmdb.isNotEmpty && sTmdb == widget.item['tmdb_id'].toString()) {
                candidates.add({'series_id': s['series_id'], 'is_hindi_detected': isHindi});
              } else if (sClean.contains(queryClean) || queryClean.contains(sClean)) {
                candidates.add({'series_id': s['series_id'], 'is_hindi_detected': isHindi});
              }
            }

            for (var bestSeries in candidates.take(2)) {
              final sid = bestSeries['series_id'];
              final infoApi = '$host/player_api.php?username=$user&password=$pass&action=get_series_info&series_id=$sid';
              final infoRes = await http.get(Uri.parse(infoApi)).timeout(const Duration(seconds: 8));

              if (infoRes.statusCode == 200) {
                final epMap = jsonDecode(infoRes.body)['episodes'] as Map<String, dynamic>? ?? {};
                final epList = epMap['$targetSeason'] as List<dynamic>? ?? [];
                final match = epList.firstWhere(
                  (e) => (e['episode_num'] ?? 0) == targetEpisode,
                  orElse: () => null,
                );

                if (match != null) {
                  final isHindi = bestSeries['is_hindi_detected'] == true;
                  resolved.add({
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
          final xtreamRes = await http.get(Uri.parse(searchApi)).timeout(const Duration(seconds: 8));

          if (xtreamRes.statusCode == 200) {
            final List<dynamic> streamList = jsonDecode(xtreamRes.body);
            List<dynamic> candidates = [];

            for (var m in streamList) {
              final mTmdb = (m['tmdb_id'] ?? m['tmdb'] ?? '').toString();
              final rawName = (m['name'] ?? '').toString();
              final categoryName = (m['category_name'] ?? '').toString();
              final mClean = _clean(rawName);
              final queryClean = _clean(movieTitle);

              bool isHindi = rawName.toLowerCase().contains('hindi') || categoryName.toLowerCase().contains('hindi');

              if (mTmdb.isNotEmpty && mTmdb == widget.item['tmdb_id'].toString()) {
                candidates.add({
                  'stream_id': m['stream_id'],
                  'ext': m['container_extension'] ?? 'mp4',
                  'is_hindi_detected': isHindi,
                });
              } else if (mClean.contains(queryClean) || queryClean.contains(mClean)) {
                candidates.add({
                  'stream_id': m['stream_id'],
                  'ext': m['container_extension'] ?? 'mp4',
                  'is_hindi_detected': isHindi,
                });
              }
            }

            for (var c in candidates.take(3)) {
              final isHindi = c['is_hindi_detected'] == true;
              resolved.add({
                'server': prov['name'] ?? 'LiveBox Xtream IPTV',
                'title': isHindi ? '$movieTitle (Hindi Audio)' : movieTitle,
                'url': '$host/movie/$user/$pass/${c['stream_id']}.${c['ext']}',
                'isHindi': isHindi,
              });
            }
          }
        }
      }

      resolved.sort((a, b) {
        if (a['isHindi'] == true && b['isHindi'] != true) return -1;
        if (a['isHindi'] != true && b['isHindi'] == true) return 1;
        return 0;
      });

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('continue_watching_tv');
      List<dynamic> curr = [];
      if (raw != null) {
        curr = List<dynamic>.from(jsonDecode(raw));
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

      if (curr.length > 15) curr = curr.sublist(0, 15);
      await prefs.setString('continue_watching_tv', jsonEncode(curr));
      widget.onPlaySaved();
    } catch (_) {}

    if (mounted) {
      setState(() {
        streams = resolved;
        loading = false;
      });
    }
  }

  void _playStream(String url, bool isExternal) {
    if (!mounted) return;
    Navigator.pop(context);

    final cleanUrl = url.trim();
    final playTitle = widget.item['title'] ?? widget.item['name'] ?? 'Playing Video';

    if (isExternal) {
      final intent = AndroidIntent(
        action: 'action_view',
        data: cleanUrl,
        type: 'video/*',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      intent.launch();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InternalPlayerScreen(
            streamUrl: cleanUrl,
            title: playTitle,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF181818),
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
                  ? '${widget.item['title'] ?? widget.item['name']} - S${widget.season} E${widget.episode}'
                  : (widget.item['title'] ?? widget.item['name'] ?? 'Select Stream'),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))))
            else if (streams.isEmpty)
              const Expanded(child: Center(child: Text('No active streams found on server.', style: TextStyle(color: Colors.white54))))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: streams.length,
                  itemBuilder: (ctx, i) {
                    final s = streams[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242424),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            s['isHindi'] == true ? Icons.translate : Icons.play_circle_fill,
                            color: const Color(0xFFE50914),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['title'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  s['server'] ?? '',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
                            onPressed: () => _playStream(s['url'] ?? '', false),
                            child: const Text('Play', style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                            onPressed: () => _playStream(s['url'] ?? '', true),
                            child: const Text('External', style: TextStyle(color: Colors.white70)),
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

// ============================================================================
// TV INTERNAL VIDEO PLAYER (FULL EMBEDDED DPAD CONTROLLER)
// ============================================================================
class InternalPlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;

  InternalPlayerScreen({
    super.key,
    String? videoUrl,
    String? streamUrl,
    required this.title,
  }) : streamUrl = (streamUrl != null && streamUrl.isNotEmpty)
            ? streamUrl
            : (videoUrl ?? '');

  @override
  State<InternalPlayerScreen> createState() => _InternalPlayerScreenState();
}

class _InternalPlayerScreenState extends State<InternalPlayerScreen>
    with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInit = false;
  bool _hasError = false;
  String _errorMsg = '';

  bool _showOverlay = false;
  Timer? _hideTimer;

  int _scaleMode = 0; // 0: FIT, 1: FILL, 2: CROP
  String _ratioToast = '';
  Timer? _ratioToastTimer;

  Timer? _holdSeekTimer;
  int _seekOffsetSec = 0;
  bool _isHoldingSeek = false;
  int _seekMultiplier = 10;
  Duration _targetSeekPos = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _cleanExitToHome();
    }
  }

  void _cleanExitToHome() {
    _hideTimer?.cancel();
    _holdSeekTimer?.cancel();
    _ratioToastTimer?.cancel();
    if (_isInit) {
      _controller.pause();
      _controller.dispose();
      _isInit = false;
    }
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.streamUrl),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      );

      await _controller.initialize();
      _controller.play();

      if (mounted) setState(() => _isInit = true);

      _controller.addListener(() {
        if (mounted && !_isHoldingSeek) setState(() {});
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = e.toString();
        });
      }
    }
  }

  void _triggerOverlay() {
    setState(() => _showOverlay = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _controller.value.isPlaying && !_isHoldingSeek) {
        setState(() => _showOverlay = false);
      }
    });
  }

  void _cycleScaleMode() {
    final names = ['FIT (16:9)', 'FILL (STRETCH)', 'CROP (ZOOM)'];
    setState(() {
      _scaleMode = (_scaleMode + 1) % 3;
      _ratioToast = names[_scaleMode];
    });

    _ratioToastTimer?.cancel();
    _ratioToastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _ratioToast = '');
    });
  }

  void _commitSeek() {
    if (!_isInit) return;
    _controller.seekTo(_targetSeekPos).then((_) {
      if (mounted) {
        setState(() {
          _isHoldingSeek = false;
          _seekOffsetSec = 0;
          _seekMultiplier = 10;
        });
        _controller.play();
        _triggerOverlay();
      }
    });
  }

  void _onDpadKeyDown(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.backspace) {
      _cleanExitToHome();
      return;
    }

    _triggerOverlay();

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      if (_isHoldingSeek) {
        _holdSeekTimer?.cancel();
        _commitSeek();
      } else if (_isInit) {
        if (_controller.value.isPlaying) {
          _controller.pause();
        } else {
          _controller.play();
        }
      }
      return;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      _cycleScaleMode();
      return;
    }

    if (key == LogicalKeyboardKey.arrowRight && _holdSeekTimer == null) {
      if (!_isHoldingSeek && _isInit) {
        _targetSeekPos = _controller.value.position;
      }
      _isHoldingSeek = true;
      _seekMultiplier = 10;
      int count = 0;

      _holdSeekTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        count++;
        if (count > 16) {
          _seekMultiplier = 60;
        } else if (count > 6) {
          _seekMultiplier = 30;
        } else {
          _seekMultiplier = 10;
        }

        final dur = _controller.value.duration;
        _targetSeekPos = (_targetSeekPos + Duration(seconds: _seekMultiplier)) > dur
            ? dur
            : _targetSeekPos + Duration(seconds: _seekMultiplier);

        setState(() {
          _seekOffsetSec += _seekMultiplier;
        });
      });
      return;
    }

    if (key == LogicalKeyboardKey.arrowLeft && _holdSeekTimer == null) {
      if (!_isHoldingSeek && _isInit) {
        _targetSeekPos = _controller.value.position;
      }
      _isHoldingSeek = true;
      _seekMultiplier = 10;
      int count = 0;

      _holdSeekTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        count++;
        if (count > 16) {
          _seekMultiplier = 60;
        } else if (count > 6) {
          _seekMultiplier = 30;
        } else {
          _seekMultiplier = 10;
        }

        _targetSeekPos = (_targetSeekPos - Duration(seconds: _seekMultiplier)) < Duration.zero
            ? Duration.zero
            : _targetSeekPos - Duration(seconds: _seekMultiplier);

        setState(() {
          _seekOffsetSec -= _seekMultiplier;
        });
      });
      return;
    }
  }

  void _onDpadKeyUp(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowLeft) {
      _holdSeekTimer?.cancel();
      _holdSeekTimer = null;

      Future.delayed(const Duration(milliseconds: 900), () {
        if (_isHoldingSeek && _holdSeekTimer == null) {
          _commitSeek();
        }
      });
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _holdSeekTimer?.cancel();
    _ratioToastTimer?.cancel();
    if (_isInit) {
      _controller.dispose();
    }
    super.dispose();
  }

  Widget _buildVideoOutput() {
    if (!_isInit) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
    }

    if (_scaleMode == 1) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      );
    } else if (_scaleMode == 2) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Duration currentPos = _isInit ? _controller.value.position : Duration.zero;
    final Duration totalDur = _isInit ? _controller.value.duration : Duration.zero;
    final Duration activeDisplayPos = _isHoldingSeek ? _targetSeekPos : currentPos;

    final double progressRatio = totalDur.inMilliseconds > 0
        ? (activeDisplayPos.inMilliseconds / totalDur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _cleanExitToHome();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKey: (node, event) {
            if (event is RawKeyDownEvent) {
              _onDpadKeyDown(event.logicalKey);
            } else if (event is RawKeyUpEvent) {
              _onDpadKeyUp(event.logicalKey);
            }
            return KeyEventResult.handled;
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildVideoOutput(),

              if (_ratioToast.isNotEmpty)
                Positioned(
                  top: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30, width: 1.2),
                    ),
                    child: Text(
                      _ratioToast,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),

              if (_isHoldingSeek)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE50914), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _seekOffsetSec > 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDuration(_targetSeekPos),
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_seekOffsetSec > 0 ? "+" : ""}${_seekOffsetSec}s (Press OK to Play)',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              if ((_showOverlay || _isHoldingSeek) && _isInit)
                Positioned(
                  bottom: 24,
                  left: 40,
                  right: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (ctx, constraints) {
                            final barWidth = constraints.maxWidth;
                            final thumbLeft = (barWidth * progressRatio).clamp(0.0, barWidth - 14.0);

                            return SizedBox(
                              height: 16,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Container(
                                    height: _isHoldingSeek ? 8 : 5,
                                    width: barWidth,
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  Container(
                                    height: _isHoldingSeek ? 8 : 5,
                                    width: barWidth * progressRatio,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE50914),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: _isHoldingSeek
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFE50914).withOpacity(0.8),
                                                blurRadius: 8,
                                              ),
                                            ]
                                          : [],
                                    ),
                                  ),
                                  if (_isHoldingSeek)
                                    Positioned(
                                      left: thumbLeft,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(0.8),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(activeDisplayPos),
                              style: TextStyle(
                                color: _isHoldingSeek ? Colors.white : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatDuration(totalDur),
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

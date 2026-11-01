// ============================================================================
// NETFLIX PRO TV - CINEMA HQ RE-ENGINEERED EDITION (200+ CATALOG & RESOLVER)
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'internal_player.dart';

// Android TV SSL Handshake Override
class TVHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = TVHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const NetflixTvApp());
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

class NetflixTvApp extends StatelessWidget {
  const NetflixTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netflix Pro TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        fontFamily: 'sans-serif',
      ),
      home: const TvHomeScreen(),
    );
  }
}

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  int _selectedNavIndex = 2; // Default Home
  final List<FocusNode> _sidebarFocusNodes = List.generate(6, (_) => FocusNode());
  final FocusNode _firstContentCardFocus = FocusNode();
  final FocusNode _watchNowFocusNode = FocusNode();

  List<dynamic> activeProviders = [];
  List> continueWatchingList = [];
  Map<String, dynamic>? activeShowcaseItem;

  // Home Fast Lists
  List> homeBollywoodList = [];
  List> homeSouthList = [];
  List> homeHollywoodList = [];
  List> homeHindiSeriesList = [];
  List> homeEnglishSeriesList = [];

  // Dedicated Movies Section (200+ Items Each)
  List> allBollywoodMovies = [];
  List> allSouthMovies = [];
  List> allHollywoodMovies = [];

  // Dedicated Web Series Section (200+ Items Each)
  List> allHindiSeries = [];
  List> allEnglishSeries = [];
  List> allSouthSeries = [];

  bool isLoading = true;
  String _catalogSortType = 'latest';

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
      _fetchHomeCatalogContent(),
    ]);
    if (mounted) setState(() => isLoading = false);
    _fetchDeepCatalogs();
  }

  Future<void> _loadContinueWatching() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('continue_watching_tv');
      if (raw != null && raw.isNotEmpty && mounted) {
        setState(() {
          continueWatchingList = List>.from(jsonDecode(raw));
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchProviders() async {
    try {
      final res = await http.get(Uri.parse(TvConfig.gistUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        activeProviders = jsonDecode(res.body)['active_providers'] ?? [];
      }
    } catch (_) {}
  }

  // Fast Instant Render for Home Screen
  Future<void> _fetchHomeCatalogContent() async {
    try {
      // 1. Bollywood Latest Cinema
      final bollyRes = await http.get(Uri.parse(
          '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=hi&sort_by=primary_release_date.desc&vote_count.gte=5')).timeout(const Duration(seconds: 8));
      if (bollyRes.statusCode == 200) {
        homeBollywoodList = _parseTvList(jsonDecode(bollyRes.body)['results']);
        if (homeBollywoodList.isNotEmpty) activeShowcaseItem = homeBollywoodList.first;
      }

      // 2. South Indian Blockbusters
      final southRes = await http.get(Uri.parse(
          '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn&sort_by=popularity.desc&vote_count.gte=10')).timeout(const Duration(seconds: 8));
      if (southRes.statusCode == 200) {
        homeSouthList = _parseTvList(jsonDecode(southRes.body)['results']);
      }

      // 3. Hollywood Latest Releases (Global & Hindi Dubbed)
      final hollyRes = await http.get(Uri.parse(
          '${TvConfig.tmdbBase}/movie/now_playing?api_key=${TvConfig.tmdbKey}&language=en-US&region=IN')).timeout(const Duration(seconds: 8));
      if (hollyRes.statusCode == 200) {
        homeHollywoodList = _parseTvList(jsonDecode(hollyRes.body)['results']);
      }

      // 4. Hindi Web Series
      final hindiTvRes = await http.get(Uri.parse(
          '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=first_air_date.desc&vote_count.gte=2')).timeout(const Duration(seconds: 8));
      if (hindiTvRes.statusCode == 200) {
        homeHindiSeriesList = _parseTvList(jsonDecode(hindiTvRes.body)['results'], isTv: true)
            .where((item) => !isSoapShow(item['title'] ?? ''))
            .toList();
      }

      // 5. Global & English Web Series (Latest on air)
      final engTvRes = await http.get(Uri.parse(
          '${TvConfig.tmdbBase}/tv/on_the_air?api_key=${TvConfig.tmdbKey}&language=en-US')).timeout(const Duration(seconds: 8));
      if (engTvRes.statusCode == 200) {
        homeEnglishSeriesList = _parseTvList(jsonDecode(engTvRes.body)['results'], isTv: true);
      }
    } catch (_) {}
  }

  // Deep Fetch 200+ Titles Multi-page Pagination (10 pages x 20 = 200 items)
  Future<void> _fetchDeepCatalogs() async {
    final sortQuery = _catalogSortType == 'latest'
        ? 'primary_release_date.desc'
        : 'popularity.desc';
    final sortTvQuery = _catalogSortType == 'latest'
        ? 'first_air_date.desc'
        : 'popularity.desc';

    // 1. Bollywood Movies (200+)
    _fetchPages(
      baseUrl: '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=hi&sort_by=$sortQuery&vote_count.gte=5',
      isTv: false,
      onDone: (list) {
        if (mounted) setState(() => allBollywoodMovies = list);
      },
    );

    // 2. South Movies (200+)
    _fetchPages(
      baseUrl: '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn&sort_by=$sortQuery&vote_count.gte=10',
      isTv: false,
      onDone: (list) {
        if (mounted) setState(() => allSouthMovies = list);
      },
    );

    // 3. Hollywood Movies (200+)
    _fetchPages(
      baseUrl: '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&sort_by=$sortQuery&vote_count.gte=20',
      isTv: false,
      onDone: (list) {
        if (mounted) setState(() => allHollywoodMovies = list);
      },
    );

    // 4. Hindi Web Series (200+)
    _fetchPages(
      baseUrl: '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=$sortTvQuery&vote_count.gte=2',
      isTv: true,
      onDone: (list) {
        if (mounted) {
          setState(() => allHindiSeries = list.where((i) => !isSoapShow(i['title'] ?? '')).toList());
        }
      },
    );

    // 5. English & Global Web Series (200+)
    _fetchPages(
      baseUrl: '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&sort_by=$sortTvQuery&vote_count.gte=15',
      isTv: true,
      onDone: (list) {
        if (mounted) setState(() => allEnglishSeries = list);
      },
    );

    // 6. South Web Series (200+)
    _fetchPages(
      baseUrl: '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=te%7Cta%7Cml&sort_by=$sortTvQuery&vote_count.gte=2',
      isTv: true,
      onDone: (list) {
        if (mounted) setState(() => allSouthSeries = list);
      },
    );
  }

  Future<void> _fetchPages({
    required String baseUrl,
    required bool isTv,
    required Function(List>) onDone,
  }) async {
    List> accumulated = [];
    for (int p = 1; p <= 10; p++) {
      try {
        final res = await http.get(Uri.parse('$baseUrl&page=$p')).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body)['results'];
          accumulated.addAll(_parseTvList(data, isTv: isTv));
        }
      } catch (_) {}
    }
    onDone(accumulated);
  }

  void _toggleSortType() {
    setState(() {
      _catalogSortType = _catalogSortType == 'latest' ? 'popular' : 'latest';
      isLoading = true;
    });
    _fetchDeepCatalogs().then((_) {
      if (mounted) setState(() => isLoading = false);
    });
  }

  List> _parseTvList(dynamic list, {bool isTv = false}) {
    List> res = [];
    final currentYear = DateTime.now().year.toString();
    for (var m in (list ?? [])) {
      if (m['backdrop_path'] == null && m['poster_path'] == null) continue;
      res.add({
        'tmdb_id': m['id'],
        'title': m['title'] ?? m['name'] ?? 'Untitled',
        'year': (m['release_date'] ?? m['first_air_date'] ?? currentYear).toString().split('-')[0],
        'rating': m['vote_average']?.toString() ?? '7.5',
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

  // ============================================================================
  // NETFLIX RED MINIMAL SLIM SIDEBAR
  // ============================================================================
  Widget _buildNetflixNavRail() {
    final icons = [
      Icons.person_outline_rounded,
      Icons.search_rounded,
      Icons.home_filled,
      Icons.movie_creation_outlined, // 3: Movies Tab
      Icons.tv_rounded,              // 4: Web Series Tab
      Icons.grid_view_rounded,
    ];

    return Container(
      width: 58,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFE50914), // Netflix Red Accent Dot
              shape: BoxShape.circle,
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

  // ============================================================================
  // NETFLIX BILLBOARD SHOWCASE
  // ============================================================================
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
                  stops: [0.0, 0.45],
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
                  stops: [0.2, 0.65, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 24,
            right: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('NETFLIX PRO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['isTv'] == true ? 'S E R I E S' : 'M O V I E',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item['title'].toString().toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${item['rating']} ★ Match', style: const TextStyle(color: Color(0xFF46D369), fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Text('${item['year']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(3)),
                      child: const Text('Ultra HD 4K', style: TextStyle(color: Colors.white70, fontSize: 9)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  (item['overview'] ?? '').toString().isNotEmpty
                      ? item['overview']
                      : 'Stream latest releases in high quality with high-speed playback.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
                  ),
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
                            backgroundColor: focused ? Colors.white : const Color(0xFFE50914),
                            foregroundColor: focused ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            side: BorderSide(
                              color: focused ? Colors.white : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          onPressed: () => _onTvItemSelect(item),
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: const Text('Watch Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        );
                      }),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.add, color: Colors.white70, size: 20),
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

  // ============================================================================
  // NETFLIX LANDSCAPE ROW (16:9 RATIO)
  // ============================================================================
  Widget _buildNetflixRow(String title, List> items, {bool isFirstRow = false}) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${items.length} Titles',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (ctx, idx) {
              return NetflixCard(
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
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Focus(
            onKey: (node, event) {
              if (event is RawKeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter)) {
                _toggleSortType();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Builder(builder: (c) {
              final focused = Focus.of(c).hasFocus;
              return InkWell(
                onTap: _toggleSortType,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: focused ? Colors.white : const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _catalogSortType == 'latest' ? Icons.fiber_new_rounded : Icons.whatshot_rounded,
                        size: 15,
                        color: focused ? Colors.black : const Color(0xFFE50914),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _catalogSortType == 'latest' ? 'Filter: Latest Releases' : 'Filter: Most Popular',
                        style: TextStyle(
                          color: focused ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Row(
        children: [
          _buildNetflixNavRail(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TAB 2: MAIN HOME
                        if (_selectedNavIndex == 2 || _selectedNavIndex <= 1) ...[
                          if (activeShowcaseItem != null) _buildNetflixBillboard(activeShowcaseItem!),
                          if (continueWatchingList.isNotEmpty)
                            _buildNetflixRow('Continue Watching', continueWatchingList, isFirstRow: true),
                          if (homeBollywoodList.isNotEmpty)
                            _buildNetflixRow('Latest Bollywood Releases', homeBollywoodList,
                                isFirstRow: continueWatchingList.isEmpty),
                          if (homeSouthList.isNotEmpty)
                            _buildNetflixRow('South Blockbusters (Hindi Dubbed)', homeSouthList),
                          if (homeHollywoodList.isNotEmpty)
                            _buildNetflixRow('Latest Hollywood Cinema (Dubbed & Global)', homeHollywoodList),
                          if (homeHindiSeriesList.isNotEmpty)
                            _buildNetflixRow('Latest Hindi Web Series', homeHindiSeriesList),
                          if (homeEnglishSeriesList.isNotEmpty)
                            _buildNetflixRow('Global Hits On The Air', homeEnglishSeriesList),
                        ],

                        // TAB 3: DEDICATED MOVIES SECTION (200+ CATALOG)
                        if (_selectedNavIndex == 3) ...[
                          _buildCategoryHeader('All Movies (200+ Titles Per Hub)'),
                          if (activeShowcaseItem != null) _buildNetflixBillboard(activeShowcaseItem!),
                          _buildNetflixRow(
                            'Bollywood Hit Movies',
                            allBollywoodMovies.isNotEmpty ? allBollywoodMovies : homeBollywoodList,
                            isFirstRow: true,
                          ),
                          _buildNetflixRow(
                            'South Indian Blockbusters (Hindi Dubbed)',
                            allSouthMovies.isNotEmpty ? allSouthMovies : homeSouthList,
                          ),
                          _buildNetflixRow(
                            'Hollywood Blockbusters (Hindi Dubbed & Global)',
                            allHollywoodMovies.isNotEmpty ? allHollywoodMovies : homeHollywoodList,
                          ),
                        ],

                        // TAB 4: DEDICATED WEB SERIES SECTION (200+ CATALOG)
                        if (_selectedNavIndex == 4) ...[
                          _buildCategoryHeader('All Web Series (Hindi Dubbed & Originals)'),
                          if (activeShowcaseItem != null) _buildNetflixBillboard(activeShowcaseItem!),
                          _buildNetflixRow(
                            'Hindi OTT Web Series',
                            allHindiSeries.isNotEmpty ? allHindiSeries : homeHindiSeriesList,
                            isFirstRow: true,
                          ),
                          _buildNetflixRow(
                            'Global Web Series (Hindi Dubbed & English)',
                            allEnglishSeries.isNotEmpty ? allEnglishSeries : homeEnglishSeriesList,
                          ),
                          _buildNetflixRow(
                            'South Indian Web Series (Hindi Dubbed)',
                            allSouthSeries,
                          ),
                        ],

                        // TAB 5: EXPLORE ALL
                        if (_selectedNavIndex == 5) ...[
                          _buildCategoryHeader('Explore All Collections'),
                          _buildNetflixRow('Bollywood Top Rated', homeBollywoodList, isFirstRow: true),
                          _buildNetflixRow('South Indian Hits', homeSouthList),
                          _buildNetflixRow('Hollywood Dubbed Hits', homeHollywoodList),
                          _buildNetflixRow('Hindi Originals', homeHindiSeriesList),
                          _buildNetflixRow('Global Shows', homeEnglishSeriesList),
                        ],
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
// NETFLIX MINIMAL SIDEBAR ICON
// ============================================================================
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isFocused ? Colors.white24 : Colors.transparent,
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Icon(
            widget.icon,
            color: _isFocused
                ? Colors.white
                : widget.isSelected
                    ? const Color(0xFFE50914)
                    : Colors.white38,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// NETFLIX POSTER CARD (NETFLIX RED/WHITE BORDER & HOVER SCALE)
// ============================================================================
class NetflixCard extends StatefulWidget {
  final FocusNode? focusNode;
  final Map<String, dynamic> item;
  final bool isFirstInRow;
  final VoidCallback onLeftBoundaryHit;
  final VoidCallback onFocusGained;
  final VoidCallback onTap;

  const NetflixCard({
    super.key,
    this.focusNode,
    required this.item,
    this.isFirstInRow = false,
    required this.onLeftBoundaryHit,
    required this.onFocusGained,
    required this.onTap,
  });

  @override
  State<NetflixCard> createState() => _NetflixCardState();
}

class _NetflixCardState extends State<NetflixCard> {
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
            width: 175,
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
                        color: const Color(0xFFE50914).withOpacity(0.55),
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
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF222222)),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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

// ============================================================================
// TV EPISODE DIALOG
// ============================================================================
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

// ============================================================================
// TV STREAM RESOLVER DIALOG
// ============================================================================
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
  List> streams = [];
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
    List> resolved = [];
    final targetTmdbId = widget.item['tmdb_id']?.toString() ?? '';
    final isTv = widget.item['isTv'] == true;
    final movieTitle = widget.item['title'] ?? '';
    final targetSeason = widget.season ?? 1;
    final targetEpisode = widget.episode ?? 1;

    String? imdbId;
    if (targetTmdbId.isNotEmpty) {
      try {
        final extType = isTv ? 'tv' : 'movie';
        final extRes = await http.get(Uri.parse(
            '${TvConfig.tmdbBase}/$extType/$targetTmdbId/external_ids?api_key=${TvConfig.tmdbKey}')).timeout(const Duration(seconds: 4));
        if (extRes.statusCode == 200) {
          imdbId = jsonDecode(extRes.body)['imdb_id'];
        }
      } catch (_) {}
    }

    final cleanTarget = _clean(movieTitle);

    for (var prov in widget.providers) {
      final type = prov['type'];

      if (type == 'xtream') {
        final host = (prov['host'] ?? '').toString().replaceAll(RegExp(r'/+$'), '');
        final user = prov['username'] ?? '';
        final pass = prov['password'] ?? '';

        if (host.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
          try {
            if (isTv) {
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

                  if (sTmdb == targetTmdbId || sClean.contains(cleanTarget) || cleanTarget.contains(sClean)) {
                    s['is_hindi_detected'] = _isHindiStream(rawName, category: categoryName);
                    candidates.add(s);
                  }
                }

                candidates.sort((a, b) => (b['is_hindi_detected'] == true ? 1 : 0).compareTo(a['is_hindi_detected'] == true ? 1 : 0));

                for (var bestSeries in candidates.take(2)) {
                  final sid = bestSeries['series_id'];
                  final infoApi = '$host/player_api.php?username=$user&password=$pass&action=get_series_info&series_id=$sid';
                  final infoRes = await http.get(Uri.parse(infoApi)).timeout(const Duration(seconds: 8));
                  if (infoRes.statusCode == 200) {
                    final epMap = jsonDecode(infoRes.body)['episodes'] as Map<String, dynamic>? ?? {};
                    final epList = epMap['$targetSeason'] as List<dynamic>? ?? [];
                    final match = epList.firstWhere((e) => (e['episode_num'] ?? 0) == targetEpisode, orElse: () => null);

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
                  resolved.add({
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
          final res = await http.get(Uri.parse(streamPath)).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            for (var s in (data['streams'] ?? [])) {
              final titleStr = (s['title'] ?? s['name'] ?? '').toString();
              if (titleStr.toLowerCase().contains('donation') ||
                  titleStr.toLowerCase().contains('discord') ||
                  titleStr.toLowerCase().contains('telegram')) {
                continue;
              }

              resolved.add({
                'server': prov['name'] ?? 'HdHub Provider',
                'title': titleStr,
                'url': s['url'],
                'isHindi': _isHindiStream(titleStr),
              });
            }
          }
        } catch (_) {}
      }
    }

    resolved.sort((a, b) {
      final aHindi = a['isHindi'] == true ? 1 : 0;
      final bHindi = b['isHindi'] == true ? 1 : 0;
      if (aHindi != bHindi) return bHindi.compareTo(aHindi);

      final aIsXtream = (a['server'] ?? '').toString().contains('Xtream') ? 1 : 0;
      final bIsXtream = (b['server'] ?? '').toString().contains('Xtream') ? 1 : 0;
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
      List<dynamic> curr = [];
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
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))))
            else if (streams.isEmpty)
              const Expanded(child: Center(child: Text('No active streams found on server.')))
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
                        color: const Color(0xFF282828),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            s['isHindi'] == true ? Icons.record_voice_over_rounded : Icons.movie_rounded,
                            color: s['isHindi'] == true ? const Color(0xFF46D369) : Colors.white,
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
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s['server'],
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Focus(
                            autofocus: i == 0,
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent &&
                                  (event.logicalKey == LogicalKeyboardKey.select ||
                                      event.logicalKey == LogicalKeyboardKey.enter)) {
                                _playStream(s['url'], false);
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Builder(builder: (c) {
                              final focused = Focus.of(c).hasFocus;
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: focused ? Colors.white : const Color(0xFFE50914),
                                  foregroundColor: focused ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                  (event.logicalKey == LogicalKeyboardKey.select ||
                                      event.logicalKey == LogicalKeyboardKey.enter)) {
                                _playStream(s['url'], true);
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Builder(builder: (c) {
                              final focused = Focus.of(c).hasFocus;
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: focused ? Colors.white : Colors.white12,
                                  foregroundColor: focused ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

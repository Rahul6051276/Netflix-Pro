// ============================================================================
// 1. APP ENTRY POINT & SYSTEM CONFIGURATION
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'internal_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const MobileCinemaTvApp());
}

// ============================================================================
// 2. THEME & TMDB CONFIGURATION
// ============================================================================

class NetflixColors {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF121212);
  static const Color primaryRed = Color(0xFFE50914);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFB3B3B3);
  static const Color buttonDark = Color(0xFF262626);
}

class AppConfig {
  static const String gistUrl =
      'https://gist.githubusercontent.com/Rahul6051276/239654d65b2124bffd0ea21b5251dc02/raw/providers.json';
  static const String tmdbKey = 'b7cd3340a794e5a2f35e3abb820b497f';
  static const String tmdbBase = 'https://api.themoviedb.org/3';
  static const String imgBase = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBase = 'https://image.tmdb.org/t/p/w780';
}

bool isDailySoapTitle(String title) {
  final t = title.toLowerCase();
  const blockList = [
    'c.i.d.', 'cid', 'bhabiji', 'balika vadhu', 'kapil sharma', 'roadies',
    'pavitra rishta', 'kumkum bhagya', 'jhanak', 'kundali bhagya',
    'ye rishta', 'yrkkh', 'taarak mehta', 'tmkoc', 'kasautii', 'ishqbaaaz',
    'anupamaa', 'bigg boss', 'khatron ke khiladi', 'splitsvilla',
    'crime patrol', 'savdhaan india', 'diya aur baati', 'qubool hai',
    'jamai raja', 'tujhse hai raabta', 'radhakrishn', 'koffee with karan',
    'india\'s got', 'mangal lakshmi', 'pushpa impossible', 'may i come in'
  ];
  return blockList.any((b) => t.contains(b));
}

class MobileCinemaTvApp extends StatelessWidget {
  const MobileCinemaTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netflix Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: NetflixColors.background,
        primaryColor: NetflixColors.primaryRed,
        fontFamily: 'sans-serif',
      ),
      home: const MobileSplashScreen(),
    );
  }
}

// ============================================================================
// 3. SPLASH SCREEN (NETFLIX PRO)
// ============================================================================

class MobileSplashScreen extends StatefulWidget {
  const MobileSplashScreen({super.key});

  @override
  State<MobileSplashScreen> createState() => _MobileSplashScreenState();
}

class _MobileSplashScreenState extends State<MobileSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scale = Tween<double>(begin: 0.8, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MobileHomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NetflixColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'NETFLIX',
                      style: TextStyle(
                        color: NetflixColors.primaryRed,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: NetflixColors.primaryRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// 4. MAIN HOME SCREEN
// ============================================================================

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  var activeProviders = [];
  var continueWatchingList = [];

  var heroBanners = [];
  var hindiWebSeries = [];
  var bollywoodLatest = [];
  var hollywoodHindiDubbed = [];
  var southHindiDubbed = [];
  var netflixSeries = [];
  var amazonSeries = [];
  var hollywoodHindiSeries = [];

  bool isLoading = true;
  int _currentHeroIndex = 0;
  final PageController _heroPageController = PageController();
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroPageController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _fetchProviders(),
      _loadContinueWatching(),
      _fetchTmdbContent(),
    ]);
    if (mounted) {
      setState(() => isLoading = false);
      _startHeroTimer();
    }
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    if (heroBanners.isNotEmpty) {
      _heroTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_heroPageController.hasClients) {
          int nextPage = (_currentHeroIndex + 1) % heroBanners.length;
          _heroPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _loadContinueWatching() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('continue_watching_mobile');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List && mounted) {
          setState(() {
            continueWatchingList = List.from(decoded);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchProviders() async {
    try {
      final res = await http.get(Uri.parse(AppConfig.gistUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        activeProviders = data['active_providers'] ?? [];
      }
    } catch (_) {}
  }

  Future<void> _fetchTmdbContent() async {
    try {
      final netflixRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_networks=213&sort_by=popularity.desc&vote_count.gte=20'));
      if (netflixRes.statusCode == 200) {
        netflixSeries = _parseResults(jsonDecode(netflixRes.body)['results'], isTv: true);
        if (netflixSeries.isNotEmpty) heroBanners = netflixSeries.take(6).toList();
      }

      final bollyRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=hi&sort_by=popularity.desc&vote_count.gte=10'));
      if (bollyRes.statusCode == 200) {
        bollywoodLatest = _parseResults(jsonDecode(bollyRes.body)['results']);
        if (heroBanners.isEmpty && bollywoodLatest.isNotEmpty) {
          heroBanners = bollywoodLatest.take(5).toList();
        }
      }

      final hindiTvRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=vote_count.desc&vote_count.gte=10'));
      if (hindiTvRes.statusCode == 200) {
        final rawList = jsonDecode(hindiTvRes.body)['results'] ?? [];
        hindiWebSeries = _parseResults(rawList, isTv: true)
            .where((item) => !isDailySoapTitle(item['title'] ?? ''))
            .toList();
      }

      final hollyRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=en&sort_by=popularity.desc&vote_count.gte=100'));
      if (hollyRes.statusCode == 200) {
        hollywoodHindiDubbed = _parseResults(jsonDecode(hollyRes.body)['results']);
      }

      final southRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn&sort_by=popularity.desc&vote_count.gte=20'));
      if (southRes.statusCode == 200) {
        southHindiDubbed = _parseResults(jsonDecode(southRes.body)['results']);
      }

      final amazonRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_networks=1024&sort_by=popularity.desc&vote_count.gte=20'));
      if (amazonRes.statusCode == 200) {
        amazonSeries = _parseResults(jsonDecode(amazonRes.body)['results'], isTv: true);
      }

      final hollySeriesRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_original_language=en&sort_by=popularity.desc&vote_count.gte=30'));
      if (hollySeriesRes.statusCode == 200) {
        hollywoodHindiSeries = _parseResults(jsonDecode(hollySeriesRes.body)['results'], isTv: true);
      }
    } catch (_) {}
  }

  dynamic _parseResults(dynamic list, {bool isTv = false}) {
    var res = [];
    final currentYear = DateTime.now().year.toString();
    for (var m in (list ?? [])) {
      if (m['poster_path'] == null && m['backdrop_path'] == null) continue;
      res.add({
        'tmdb_id': m['id'],
        'title': m['title'] ?? m['name'] ?? 'Untitled',
        'year': (m['release_date'] ?? m['first_air_date'] ?? currentYear)
            .toString()
            .split('-')[0],
        'rating': m['vote_average']?.toString() ?? '7.8',
        'backdrop': m['backdrop_path'] != null
            ? '${AppConfig.backdropBase}${m['backdrop_path']}'
            : '${AppConfig.imgBase}${m['poster_path']}',
        'poster': m['poster_path'] != null
            ? '${AppConfig.imgBase}${m['poster_path']}'
            : '${AppConfig.backdropBase}${m['backdrop_path']}',
        'isTv': isTv,
      });
    }
    return res;
  }

  void _onItemTapped(dynamic item) {
    if (item['isTv'] == true) {
      showDialog(
        context: context,
        builder: (ctx) => MobileEpisodeSelectorDialog(
          item: item,
          onSelected: (season, episode) {
            _showQualitySheet(item, season: season, episode: episode);
          },
        ),
      );
    } else {
      _showQualitySheet(item);
    }
  }

  void _showQualitySheet(dynamic item, {int? season, int? episode}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NetflixColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return MobileQualitySelectorSheet(
          item: item,
          season: season,
          episode: episode,
          providers: activeProviders,
          onPlaySaved: () => _loadContinueWatching(),
        );
      },
    );
  }

  Widget _buildAppDrawer() {
    return Drawer(
      backgroundColor: NetflixColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: NetflixColors.surface),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'NETFLIX',
                      style: TextStyle(
                        color: NetflixColors.primaryRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: NetflixColors.primaryRed,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Explore Categories',
                  style: TextStyle(color: NetflixColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          _drawerItem('Netflix Originals', Icons.movie_outlined, 'netflix_series'),
          _drawerItem('Bollywood Movies', Icons.movie_filter_rounded, 'bollywood'),
          _drawerItem('South Indian (Hindi)', Icons.local_movies_rounded, 'south'),
          _drawerItem('Hollywood Movies', Icons.theaters_rounded, 'hollywood_movies'),
          _drawerItem('Hindi Web Series', Icons.live_tv_rounded, 'hindi_series'),
          _drawerItem('English Web Series', Icons.connected_tv_rounded, 'english_series'),
        ],
      ),
    );
  }

  Widget _drawerItem(String title, IconData icon, String type) {
    return ListTile(
      leading: Icon(icon, color: NetflixColors.primaryRed, size: 22),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MobileCatalogGridView(
              categoryType: type,
              title: title,
              providers: activeProviders,
              onItemTapped: _onItemTapped,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHorizontalRow(String title, dynamic items) {
    var list = items is List ? items : [];
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: NetflixColors.textWhite,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SizedBox(
          height: 165,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              return GestureDetector(
                onTap: () => _onItemTapped(item),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      item['poster'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: NetflixColors.surface,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBanner() {
    if (heroBanners.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        SizedBox(
          height: 480,
          child: PageView.builder(
            controller: _heroPageController,
            itemCount: heroBanners.length,
            onPageChanged: (i) => setState(() => _currentHeroIndex = i),
            itemBuilder: (ctx, idx) {
              final item = heroBanners[idx];
              return Image.network(
                item['poster'],
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => Container(color: NetflixColors.surface),
              );
            },
          ),
        ),
        Container(
          height: 480,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black87,
                Colors.transparent,
                Colors.transparent,
                NetflixColors.background,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.25, 0.65, 1.0],
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Builder(
            builder: (context) {
              final currentItem = heroBanners[_currentHeroIndex];
              return Column(
                children: [
                  Text(
                    currentItem['title'] ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 24),
                          SizedBox(height: 4),
                          Text('My List', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _onItemTapped(currentItem),
                        icon: const Icon(Icons.play_arrow, color: Colors.black, size: 26),
                        label: const Text(
                          'Play',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _onItemTapped(currentItem),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, color: Colors.white, size: 24),
                            SizedBox(height: 4),
                            Text('Info', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildAppDrawer(),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white, size: 26),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'NETFLIX',
              style: TextStyle(
                color: NetflixColors.primaryRed,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: NetflixColors.primaryRed,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 26),
            onPressed: () {
              showSearch(
                context: context,
                delegate: TmdbSearchDelegate(onItemTapped: _onItemTapped),
              );
            },
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: NetflixColors.primaryRed),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroBanner(),
                  const SizedBox(height: 10),
                  if (continueWatchingList.isNotEmpty)
                    _buildHorizontalRow('Continue Watching', continueWatchingList),
                  _buildHorizontalRow('Only on Netflix', netflixSeries),
                  _buildHorizontalRow('Trending Bollywood', bollywoodLatest),
                  _buildHorizontalRow('Popular Hindi Series', hindiWebSeries),
                  _buildHorizontalRow('Hollywood Hindi Dubbed', hollywoodHindiDubbed),
                  _buildHorizontalRow('South Indian Hindi Dubbed', southHindiDubbed),
                  _buildHorizontalRow('Amazon Prime Series', amazonSeries),
                  _buildHorizontalRow('Top English Series', hollywoodHindiSeries),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

// ============================================================================
// 5. TMDB LIVE SEARCH ENGINE
// ============================================================================

class TmdbSearchDelegate extends SearchDelegate {
  final Function(dynamic) onItemTapped;
  TmdbSearchDelegate({required this.onItemTapped});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NetflixColors.background,
      appBarTheme: const AppBarTheme(backgroundColor: NetflixColors.surface),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: NetflixColors.textMuted),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _searchView();

  @override
  Widget buildSuggestions(BuildContext context) => _searchView();

  Widget _searchView() {
    if (query.trim().isEmpty) {
      return const Center(
        child: Text('Search for movies, shows, genres...', style: TextStyle(color: NetflixColors.textMuted)),
      );
    }
    return FutureBuilder(
      future: _performSearch(query.trim()),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: NetflixColors.primaryRed));
        }
        var list = snapshot.data is List ? snapshot.data as List : [];
        if (list.isEmpty) {
          return const Center(child: Text('No results found.', style: TextStyle(color: NetflixColors.textMuted)));
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(color: Color(0xFF202020), height: 1),
          itemBuilder: (ctx, idx) {
            final item = list[idx];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.network(
                  item['poster'],
                  width: 50,
                  height: 75,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 50, height: 75, color: NetflixColors.surface),
                ),
              ),
              title: Text(item['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(
                '${item['year']} • ${item['isTv'] ? "Series" : "Movie"}',
                style: const TextStyle(color: NetflixColors.textMuted, fontSize: 12),
              ),
              trailing: const Icon(Icons.play_circle_outline, color: Colors.white70, size: 28),
              onTap: () {
                close(ctx, null);
                onItemTapped(item);
              },
            );
          },
        );
      },
    );
  }

  Future<dynamic> _performSearch(String q) async {
    try {
      final url = '${AppConfig.tmdbBase}/search/multi?api_key=${AppConfig.tmdbKey}&query=${Uri.encodeComponent(q)}';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        var parsed = [];
        for (var m in results) {
          final type = m['media_type'];
          if (type != 'movie' && type != 'tv') continue;
          if (m['poster_path'] == null && m['backdrop_path'] == null) continue;
          parsed.add({
            'tmdb_id': m['id'],
            'title': m['title'] ?? m['name'] ?? 'Untitled',
            'year': (m['release_date'] ?? m['first_air_date'] ?? '').toString().split('-')[0],
            'rating': m['vote_average']?.toString() ?? '7.0',
            'poster': m['poster_path'] != null ? '${AppConfig.imgBase}${m['poster_path']}' : '${AppConfig.backdropBase}${m['backdrop_path']}',
            'backdrop': m['backdrop_path'] != null ? '${AppConfig.backdropBase}${m['backdrop_path']}' : '${AppConfig.imgBase}${m['poster_path']}',
            'isTv': type == 'tv',
          });
        }
        return parsed;
      }
    } catch (_) {}
    return [];
  }
}

// ============================================================================
// 6. CATALOG GRID VIEW
// ============================================================================

class MobileCatalogGridView extends StatefulWidget {
  final String categoryType;
  final String title;
  final List providers;
  final Function(dynamic) onItemTapped;

  const MobileCatalogGridView({
    super.key,
    required this.categoryType,
    required this.title,
    required this.providers,
    required this.onItemTapped,
  });

  @override
  State<MobileCatalogGridView> createState() => _MobileCatalogGridViewState();
}

class _MobileCatalogGridViewState extends State<MobileCatalogGridView> {
  var itemsList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch100Titles();
  }

  Future<void> _fetch100Titles() async {
    final bool isTv = widget.categoryType == 'hindi_series' || 
                      widget.categoryType == 'english_series' ||
                      widget.categoryType == 'netflix_series';
    var fetched = [];

    for (int page = 1; page <= 5; page++) {
      String url = '';

      if (widget.categoryType == 'netflix_series') {
        url = '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_networks=213&sort_by=popularity.desc&vote_count.gte=20&page=$page';
      } else if (widget.categoryType == 'bollywood') {
        url = '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=hi&sort_by=primary_release_date.desc&vote_count.gte=10&page=$page';
      } else if (widget.categoryType == 'south') {
        url = '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn&sort_by=primary_release_date.desc&vote_count.gte=15&page=$page';
      } else if (widget.categoryType == 'hollywood_movies') {
        url = '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=en&sort_by=primary_release_date.desc&vote_count.gte=50&page=$page';
      } else if (widget.categoryType == 'hindi_series') {
        url = '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=first_air_date.desc&vote_count.gte=10&page=$page';
      } else if (widget.categoryType == 'english_series') {
        url = '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_original_language=en&sort_by=first_air_date.desc&vote_count.gte=40&page=$page';
      }

      try {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final rawResults = data['results'] ?? [];
          for (var m in rawResults) {
            if (m['poster_path'] == null && m['backdrop_path'] == null) continue;
            final t = (m['title'] ?? m['name'] ?? 'Untitled').toString();

            if (widget.categoryType == 'hindi_series' && isDailySoapTitle(t)) {
              continue;
            }

            fetched.add({
              'tmdb_id': m['id'],
              'title': t,
              'year': (m['release_date'] ?? m['first_air_date'] ?? DateTime.now().year.toString()).toString().split('-')[0],
              'rating': m['vote_average']?.toString() ?? '7.5',
              'poster': m['poster_path'] != null
                  ? '${AppConfig.imgBase}${m['poster_path']}'
                  : '${AppConfig.backdropBase}${m['backdrop_path']}',
              'backdrop': m['backdrop_path'] != null
                  ? '${AppConfig.backdropBase}${m['backdrop_path']}'
                  : '${AppConfig.imgBase}${m['poster_path']}',
              'isTv': isTv,
            });
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        itemsList = fetched;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NetflixColors.background,
      appBar: AppBar(
        backgroundColor: NetflixColors.surface,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: NetflixColors.primaryRed))
          : itemsList.isEmpty
              ? const Center(child: Text('No titles available', style: TextStyle(color: NetflixColors.textMuted)))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: itemsList.length,
                  itemBuilder: (ctx, idx) {
                    final item = itemsList[idx];
                    return GestureDetector(
                      onTap: () => widget.onItemTapped(item),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          item['poster'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: NetflixColors.surface),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ============================================================================
// 7. WEB SERIES SEASON & EPISODE SELECTOR POPUP
// ============================================================================

class MobileEpisodeSelectorDialog extends StatefulWidget {
  final dynamic item;
  final Function(int season, int episode) onSelected;

  const MobileEpisodeSelectorDialog({
    super.key,
    required this.item,
    required this.onSelected,
  });

  @override
  State<MobileEpisodeSelectorDialog> createState() => _MobileEpisodeSelectorDialogState();
}

class _MobileEpisodeSelectorDialogState extends State<MobileEpisodeSelectorDialog> {
  int selectedSeason = 1;
  int selectedEpisode = 1;
  int totalSeasons = 1;
  int episodesInCurrentSeason = 10;
  bool loadingDetails = true;

  @override
  void initState() {
    super.initState();
    _fetchTvDetails();
  }

  Future<void> _fetchTvDetails() async {
    try {
      final url = '${AppConfig.tmdbBase}/tv/${widget.item['tmdb_id']}?api_key=${AppConfig.tmdbKey}';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final seasons = data['seasons'] as List? ?? [];
        final validSeasons = seasons.where((s) => (s['season_number'] ?? 0) > 0).toList();
        if (validSeasons.isNotEmpty && mounted) {
          setState(() {
            totalSeasons = validSeasons.length;
            episodesInCurrentSeason = validSeasons.first['episode_count'] ?? 10;
            loadingDetails = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => loadingDetails = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NetflixColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        widget.item['title'] ?? 'Select Episode',
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: loadingDetails
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator(color: NetflixColors.primaryRed)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<int>(
                  value: selectedSeason,
                  dropdownColor: NetflixColors.buttonDark,
                  isExpanded: true,
                  items: List.generate(totalSeasons, (i) => i + 1).map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text('Season $s', style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedSeason = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Episode', style: TextStyle(color: NetflixColors.textMuted, fontSize: 13)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 150,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: episodesInCurrentSeason,
                    itemBuilder: (ctx, i) {
                      final epNum = i + 1;
                      final isSelected = selectedEpisode == epNum;
                      return GestureDetector(
                        onTap: () => setState(() => selectedEpisode = epNum),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? NetflixColors.primaryRed : NetflixColors.buttonDark,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$epNum',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: NetflixColors.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: NetflixColors.primaryRed,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          onPressed: () {
            Navigator.pop(context);
            widget.onSelected(selectedSeason, selectedEpisode);
          },
          child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ============================================================================
// 8. QUALITY SELECTOR BOTTOM SHEET
// ============================================================================

class MobileQualitySelectorSheet extends StatelessWidget {
  final dynamic item;
  final int? season;
  final int? episode;
  final List providers;
  final VoidCallback onPlaySaved;

  const MobileQualitySelectorSheet({
    super.key,
    required this.item,
    this.season,
    this.episode,
    required this.providers,
    required this.onPlaySaved,
  });

  void _playStream(BuildContext context, String streamUrl) async {
    Navigator.pop(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('continue_watching_mobile');
      List history = raw != null ? jsonDecode(raw) : [];
      history.removeWhere((e) => e['tmdb_id'] == item['tmdb_id']);
      history.insert(0, item);
      if (history.length > 20) history = history.sublist(0, 20);
      await prefs.setString('continue_watching_mobile', jsonEncode(history));
      onPlaySaved();
    } catch (_) {}

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InternalPlayer(
            streamUrl: streamUrl,
            title: item['title'] ?? '',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  item['poster'],
                  width: 50,
                  height: 75,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 50, height: 75, color: NetflixColors.buttonDark),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['isTv'] == true ? 'Season $season • Episode $episode' : '${item['year']} • Movie',
                      style: const TextStyle(color: NetflixColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Select Streaming Server',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          ...providers.map((p) {
            final name = p['name'] ?? 'Server';
            final template = p['url_template'] ?? '';
            String finalUrl = template
                .replaceAll('{id}', item['tmdb_id'].toString())
                .replaceAll('{s}', (season ?? 1).toString())
                .replaceAll('{e}', (episode ?? 1).toString());

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: NetflixColors.buttonDark,
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListTile(
                leading: const Icon(Icons.play_circle_fill, color: NetflixColors.primaryRed),
                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                onTap: () => _playStream(context, finalUrl),
              ),
            );
          }),
        ],
      ),
    );
  }
}

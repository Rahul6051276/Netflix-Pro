// ============================================================================
// NETFLIX PRO - AUTHENTIC MOBILE APP EXPERIENCE
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const NetflixProApp());
}

// ============================================================================
// 1. CONFIGURATION & TMDB API CREDENTIALS
// ============================================================================

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

class NetflixProApp extends StatelessWidget {
  const NetflixProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netflix Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          surface: Color(0xFF181818),
        ),
        fontFamily: 'sans-serif',
      ),
      home: const NetflixAnimatedSplash(),
    );
  }
}

// ============================================================================
// 2. AUTHENTIC ANIMATED NETFLIX "N" SPLASH SCREEN
// ============================================================================

class NetflixAnimatedSplash extends StatefulWidget {
  const NetflixAnimatedSplash({super.key});

  @override
  State<NetflixAnimatedSplash> createState() => _NetflixAnimatedSplashState();
}

class _NetflixAnimatedSplashState extends State<NetflixAnimatedSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.65, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.25)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_animCtrl);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_animCtrl);

    _glowAnimation = Tween<double>(begin: 0.0, end: 32.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _animCtrl.forward();

    Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const NetflixHomeScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _animCtrl,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: SizedBox(
                  width: 140,
                  height: 240,
                  child: CustomPaint(
                    painter: NetflixLogoPainter(glowRadius: _glowAnimation.value),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class NetflixLogoPainter extends CustomPainter {
  final double glowRadius;
  NetflixLogoPainter({required this.glowRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final double colWidth = size.width * 0.28;

    final leftRect = Rect.fromLTWH(0, 0, colWidth, size.height);
    final leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE50914), Color(0xFF8B0000)],
      ).createShader(leftRect);

    final rightRect = Rect.fromLTWH(size.width - colWidth, 0, colWidth, size.height);
    final rightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF8B0000), Color(0xFFE50914)],
      ).createShader(rightRect);

    if (glowRadius > 0) {
      final glowPaint = Paint()
        ..color = const Color(0xFFE50914).withOpacity(0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
      canvas.drawRect(leftRect, glowPaint);
      canvas.drawRect(rightRect, glowPaint);
    }

    canvas.drawRect(leftRect, leftPaint);
    canvas.drawRect(rightRect, rightPaint);

    final diagPath = Path()
      ..moveTo(0, 0)
      ..lineTo(colWidth, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - colWidth, size.height)
      ..close();

    canvas.drawShadow(diagPath, Colors.black, 10.0, true);

    final diagRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final diagPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF1E27), Color(0xFFB81D24)],
      ).createShader(diagRect);

    canvas.drawPath(diagPath, diagPaint);
  }

  @override
  bool shouldRepaint(covariant NetflixLogoPainter oldDelegate) =>
      oldDelegate.glowRadius != glowRadius;
}

// ============================================================================
// 3. NETFLIX HOMEPAGE (100% NETFLIX CONTENT FEED & BILLBOARD)
// ============================================================================

class NetflixHomeScreen extends StatefulWidget {
  const NetflixHomeScreen({super.key});

  @override
  State<NetflixHomeScreen> createState() => _NetflixHomeScreenState();
}

class _NetflixHomeScreenState extends State<NetflixHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  var activeProviders = [];
  var continueWatchingList = [];

  var heroItems = [];
  int currentHeroIndex = 0;
  final PageController _heroController = PageController();
  Timer? _heroTimer;

  var top10India = [];
  var netflixHindiSeries = [];
  var netflixSouthHits = [];
  var netflixTrendingMovies = [];
  var netflixInternationalHindi = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllNetflixData();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    if (heroItems.isNotEmpty) {
      _heroTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_heroController.hasClients) {
          int nextPage = (currentHeroIndex + 1) % heroItems.length;
          _heroController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _loadAllNetflixData() async {
    await Future.wait([
      _fetchProviders(),
      _loadContinueWatching(),
      _fetchHeroBillboard(),
      _fetchTop10India(),
      _fetchNetflixCategory('hindi_series', (list) => netflixHindiSeries = list),
      _fetchNetflixCategory('south_hits', (list) => netflixSouthHits = list),
      _fetchNetflixCategory('trending_movies', (list) => netflixTrendingMovies = list),
      _fetchNetflixCategory('international_hindi', (list) => netflixInternationalHindi = list),
    ]);

    if (mounted) {
      setState(() => isLoading = false);
      _startHeroTimer();
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

  Future<void> _fetchHeroBillboard() async {
    try {
      final url =
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_networks=213&sort_by=popularity.desc';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        var list = [];
        for (var m in results.take(6)) {
          if (m['poster_path'] == null && m['backdrop_path'] == null) continue;
          list.add({
            'tmdb_id': m['id'],
            'title': m['name'] ?? m['title'] ?? 'Netflix Original',
            'year': (m['first_air_date'] ?? m['release_date'] ?? '2025').toString().split('-')[0],
            'rating': m['vote_average']?.toString() ?? '8.4',
            'poster': m['poster_path'] != null
                ? '${AppConfig.imgBase}${m['poster_path']}'
                : '${AppConfig.backdropBase}${m['backdrop_path']}',
            'backdrop': m['backdrop_path'] != null
                ? '${AppConfig.backdropBase}${m['backdrop_path']}'
                : '${AppConfig.imgBase}${m['poster_path']}',
            'isTv': true,
          });
        }
        heroItems = list;
      }
    } catch (_) {}
  }

  Future<void> _fetchTop10India() async {
    try {
      final url =
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&sort_by=popularity.desc';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        var list = [];
        for (var m in results.take(10)) {
          if (m['poster_path'] == null) continue;
          list.add({
            'tmdb_id': m['id'],
            'title': m['title'] ?? m['name'] ?? 'Top 10 Movie',
            'year': (m['release_date'] ?? m['first_air_date'] ?? '2025').toString().split('-')[0],
            'rating': m['vote_average']?.toString() ?? '8.0',
            'poster': '${AppConfig.imgBase}${m['poster_path']}',
            'backdrop': m['backdrop_path'] != null
                ? '${AppConfig.backdropBase}${m['backdrop_path']}'
                : '${AppConfig.imgBase}${m['poster_path']}',
            'isTv': false,
          });
        }
        top10India = list;
      }
    } catch (_) {}
  }

  Future<void> _fetchNetflixCategory(String cat, Function(List) onDone) async {
    String url = '';
    bool isTv = false;

    if (cat == 'hindi_series') {
      url =
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_networks=213&with_original_language=hi&sort_by=popularity.desc';
      isTv = true;
    } else if (cat == 'south_hits') {
      url =
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&with_original_language=te%7Cta%7Cml%7Ckn&sort_by=popularity.desc';
      isTv = false;
    } else if (cat == 'trending_movies') {
      url =
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&sort_by=popularity.desc';
      isTv = false;
    } else if (cat == 'international_hindi') {
      url =
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_networks=213&sort_by=popularity.desc';
      isTv = true;
    }

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        var list = [];
        for (var m in results.take(15)) {
          if (m['poster_path'] == null) continue;
          final title = (m['title'] ?? m['name'] ?? 'Untitled').toString();
          if (isTv && isDailySoapTitle(title)) continue;

          list.add({
            'tmdb_id': m['id'],
            'title': title,
            'year': (m['release_date'] ?? m['first_air_date'] ?? '2025').toString().split('-')[0],
            'rating': m['vote_average']?.toString() ?? '7.8',
            'poster': '${AppConfig.imgBase}${m['poster_path']}',
            'backdrop': m['backdrop_path'] != null
                ? '${AppConfig.backdropBase}${m['backdrop_path']}'
                : '${AppConfig.imgBase}${m['poster_path']}',
            'isTv': isTv,
          });
        }
        onDone(list);
      }
    } catch (_) {}
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
      backgroundColor: const Color(0xFF181818),
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

  void _openCatalog(String title, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MobileCatalogGridView(
          title: title,
          categoryType: type,
          providers: activeProviders,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildNetflixAppDrawer(),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            )
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(child: _buildNetflixHeroBillboard()),
                if (continueWatchingList.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildContinueWatchingRow(continueWatchingList),
                  ),
                if (top10India.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildTop10Row(top10India),
                  ),
                SliverToBoxAdapter(
                  child: _buildNetflixRow('Netflix Hindi Web Series', netflixHindiSeries),
                ),
                SliverToBoxAdapter(
                  child: _buildNetflixRow('Netflix South Hits (Hindi Dubbed)', netflixSouthHits),
                ),
                SliverToBoxAdapter(
                  child: _buildNetflixRow('Trending Netflix Originals', netflixTrendingMovies),
                ),
                SliverToBoxAdapter(
                  child: _buildNetflixRow('Netflix International Hits (Hindi Dubbed)', netflixInternationalHindi),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 35)),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: const Color(0xFF141414).withOpacity(0.95),
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        children: [
          const Text(
            'N',
            style: TextStyle(
              color: Color(0xFFE50914),
              fontWeight: FontWeight.w900,
              fontSize: 26,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'NETFLIX',
            style: TextStyle(
              color: Color(0xFFE50914),
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
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
      ],
    );
  }

  Widget _buildNetflixHeroBillboard() {
    if (heroItems.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 480,
          child: PageView.builder(
            controller: _heroController,
            itemCount: heroItems.length,
            onPageChanged: (i) => setState(() => currentHeroIndex = i),
            itemBuilder: (ctx, idx) {
              final item = heroItems[idx];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item['poster'],
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) =>
                        Container(color: const Color(0xFF181818)),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xCC141414),
                          Color(0xFF141414),
                        ],
                        stops: [0.0, 0.45, 0.8, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    left: 20,
                    right: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const Text(
                                'TOP 10',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '#1 in Series Today',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['title'],
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 10),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item['year']} • Netflix Original • ⭐ ${item['rating']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => _onItemTapped(item),
                          icon: const Icon(Icons.play_arrow, color: Colors.black, size: 28),
                          label: const Text(
                            'Play',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 36, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTop10Row(List items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Top 10 in India Today',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: items.length,
            itemBuilder: (ctx, idx) {
              final item = items[idx];
              final rank = idx + 1;
              return GestureDetector(
                onTap: () => _onItemTapped(item),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        bottom: -15,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 105,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2E2E2E),
                            shadows: [
                              Shadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 2,
                                offset: const Offset(-1, -1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 0,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            item['poster'],
                            width: 105,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(width: 105, color: const Color(0xFF1E1E1E)),
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
      ],
    );
  }

  Widget _buildContinueWatchingRow(List items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Continue Watching for Rahul',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (ctx, idx) {
              final item = items[idx];
              return GestureDetector(
                onTap: () => _onItemTapped(item),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: const Color(0xFF1E1E1E),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                item['poster'] ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: const Color(0xFF1E1E1E)),
                              ),
                              const Center(
                                child: Icon(Icons.play_circle_outline,
                                    color: Colors.white70, size: 36),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        height: 3,
                        color: const Color(0xFFE50914),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNetflixRow(String title, List items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SizedBox(
          height: 165,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (ctx, idx) {
              final item = items[idx];
              return GestureDetector(
                onTap: () => _onItemTapped(item),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: const Color(0xFF1E1E1E),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      item['poster'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFF1E1E1E)),
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

  Widget _buildNetflixAppDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF141414),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF181818)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'NETFLIX PRO',
                  style: TextStyle(
                    color: Color(0xFFE50914),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Stream Resolvers Connected: ${activeProviders.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          _drawerTile('Bollywood Movies', Icons.movie_filter,
              () => _openCatalog('Bollywood Movies', 'bollywood')),
          _drawerTile('South Indian (Hindi Dubbed)', Icons.local_fire_department,
              () => _openCatalog('South Indian Movies', 'south')),
          _drawerTile('Hollywood Movies (Hindi Dubbed)', Icons.theaters,
              () => _openCatalog('Hollywood Movies', 'hollywood_movies')),
          _drawerTile('Hindi Web Series', Icons.live_tv,
              () => _openCatalog('Hindi Web Series', 'hindi_series')),
          _drawerTile('English Web Series', Icons.connected_tv,
              () => _openCatalog('English Web Series', 'english_series')),
        ],
      ),
    );
  }

  Widget _drawerTile(String t, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFE50914)),
      title: Text(t,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      trailing:
          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

// ============================================================================
// 4. TMDB LIVE SEARCH ENGINE
// ============================================================================

class TmdbSearchDelegate extends SearchDelegate {
  final Function(dynamic) onItemTapped;
  TmdbSearchDelegate({required this.onItemTapped});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF141414),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF181818)),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white54),
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
        child: Text('Search Netflix movies, series, originals...',
            style: TextStyle(color: Colors.white54)),
      );
    }
    return FutureBuilder(
      future: _performSearch(query.trim()),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)));
        }
        var list = snapshot.data is List ? snapshot.data as List : [];
        if (list.isEmpty) {
          return const Center(
              child: Text('No results found.',
                  style: TextStyle(color: Colors.white54)));
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(color: Color(0xFF262626)),
          itemBuilder: (ctx, idx) {
            final item = list[idx];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  item['poster'],
                  width: 45,
                  height: 65,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(width: 45, height: 65, color: const Color(0xFF1E1E1E)),
                ),
              ),
              title: Text(item['title'],
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${item['year']} • ${item['isTv'] ? "Series" : "Movie"}',
                  style: const TextStyle(color: Colors.white54)),
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
      final url =
          '${AppConfig.tmdbBase}/search/multi?api_key=${AppConfig.tmdbKey}&query=${Uri.encodeComponent(q)}';
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
            'year': (m['release_date'] ?? m['first_air_date'] ?? '2025').toString().split('-')[0],
            'rating': m['vote_average']?.toString() ?? '7.0',
            'poster': m['poster_path'] != null
                ? '${AppConfig.imgBase}${m['poster_path']}'
                : '${AppConfig.backdropBase}${m['backdrop_path']}',
            'backdrop': m['backdrop_path'] != null
                ? '${AppConfig.backdropBase}${m['backdrop_path']}'
                : '${AppConfig.imgBase}${m['poster_path']}',
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
// 5. 100+ TITLES CATALOG (DRAWER GRID VIEW - WITH GUARANTEED LOAD FIX)
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
        widget.categoryType == 'english_series';
    var fetched = [];

    for (int page = 1; page <= 5; page++) {
      String url = '';

      if (widget.categoryType == 'bollywood') {
        url =
            '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=hi&sort_by=popularity.desc&page=$page';
      } else if (widget.categoryType == 'south') {
        url =
            '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn&sort_by=popularity.desc&page=$page';
      } else if (widget.categoryType == 'hollywood_movies') {
        url =
            '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=en&sort_by=popularity.desc&page=$page';
      } else if (widget.categoryType == 'hindi_series') {
        url =
            '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=popularity.desc&page=$page';
      } else if (widget.categoryType == 'english_series') {
        url =
            '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_original_language=en&sort_by=popularity.desc&page=$page';
      }

      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
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
              'year': (m['release_date'] ??
                      m['first_air_date'] ??
                      '2025')
                  .toString()
                  .split('-')[0],
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
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        title: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : itemsList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 48),
                      const SizedBox(height: 12),
                      const Text('Titles load nahi ho sake',
                          style: TextStyle(color: Colors.white60, fontSize: 15)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE50914),
                        ),
                        onPressed: () {
                          setState(() => isLoading = true);
                          _fetch100Titles();
                        },
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: itemsList.length,
                  itemBuilder: (ctx, idx) {
                    final item = itemsList[idx];
                    return GestureDetector(
                      onTap: () => widget.onItemTapped(item),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              item['poster'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: const Color(0xFF1E1E1E)),
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black87],
                                  stops: [0.65, 1.0],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 6,
                              left: 6,
                              right: 6,
                              child: Text(
                                item['title'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ============================================================================
// 6. NETFLIX WEB SERIES EPISODE SELECTOR POPUP
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
  State<MobileEpisodeSelectorDialog> createState() =>
      _MobileEpisodeSelectorDialogState();
}

class _MobileEpisodeSelectorDialogState
    extends State<MobileEpisodeSelectorDialog> {
  int totalSeasons = 1;
  int selectedSeason = 1;
  int episodeCount = 10;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSeriesDetails();
  }

  Future<void> _fetchSeriesDetails() async {
    try {
      final url =
          '${AppConfig.tmdbBase}/tv/${widget.item['tmdb_id']}?api_key=${AppConfig.tmdbKey}';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final seasons = data['number_of_seasons'] ?? 1;
        if (mounted) {
          setState(() {
            totalSeasons = seasons > 0 ? seasons : 1;
          });
        }
        await _fetchSeasonEpisodes(1);
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchSeasonEpisodes(int s) async {
    setState(() => isLoading = true);
    try {
      final url =
          '${AppConfig.tmdbBase}/tv/${widget.item['tmdb_id']}/season/$s?api_key=${AppConfig.tmdbKey}';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final epList = data['episodes'] as List? ?? [];
        if (mounted) {
          setState(() {
            selectedSeason = s;
            episodeCount = epList.isNotEmpty ? epList.length : 10;
            isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        selectedSeason = s;
        episodeCount = 10;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: totalSeasons,
                itemBuilder: (ctx, idx) {
                  final s = idx + 1;
                  final isSel = s == selectedSeason;
                  return GestureDetector(
                    onTap: () => _fetchSeasonEpisodes(s),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            isSel ? const Color(0xFFE50914) : const Color(0xFF262626),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Season $s',
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Select Episode',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFE50914)))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: episodeCount,
                      itemBuilder: (ctx, idx) {
                        final ep = idx + 1;
                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            widget.onSelected(selectedSeason, ep);
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF262626),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              'EP $ep',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
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
// 7. XTREAM IPTV & STREMIO STREAM RESOLVER ENGINE
// ============================================================================

class MobileQualitySelectorSheet extends StatefulWidget {
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

  @override
  State<MobileQualitySelectorSheet> createState() =>
      _MobileQualitySelectorSheetState();
}

class _MobileQualitySelectorSheetState extends State<MobileQualitySelectorSheet> {
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

  String _cleanString(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  Future<void> _fetchDirectStreams() async {
    var resolved = [];
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
            '${AppConfig.tmdbBase}/$extType/$targetTmdbId/external_ids?api_key=${AppConfig.tmdbKey}')).timeout(const Duration(seconds: 4));
        if (extRes.statusCode == 200) {
          imdbId = jsonDecode(extRes.body)['imdb_id'];
        }
      } catch (_) {}
    }

    final cleanTarget = _cleanString(movieTitle);

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
                var seriesList = jsonDecode(xtreamRes.body) as List;
                var candidates = [];

                for (var s in seriesList) {
                  final sTmdb = (s['tmdb_id'] ?? s['tmdb'] ?? '').toString();
                  final rawName = (s['name'] ?? '').toString();
                  final categoryName = (s['category_name'] ?? '').toString();
                  final sClean = _cleanString(rawName);

                  bool isMatch = false;
                  if (sTmdb.isNotEmpty && sTmdb == targetTmdbId) {
                    isMatch = true;
                  } else if (sClean.contains(cleanTarget) || cleanTarget.contains(sClean)) {
                    isMatch = true;
                  }

                  if (isMatch) {
                    s['is_hindi_detected'] = _isHindiStream(rawName, category: categoryName);
                    candidates.add(s);
                  }
                }

                candidates.sort((a, b) {
                  final aH = a['is_hindi_detected'] == true ? 1 : 0;
                  final bH = b['is_hindi_detected'] == true ? 1 : 0;
                  return bH.compareTo(aH);
                });

                for (var bestSeries in candidates.take(2)) {
                  final seriesId = bestSeries['series_id'];
                  final infoApi = '$host/player_api.php?username=$user&password=$pass&action=get_series_info&series_id=$seriesId';
                  final infoRes = await http.get(Uri.parse(infoApi)).timeout(const Duration(seconds: 8));
                  if (infoRes.statusCode == 200) {
                    final infoData = jsonDecode(infoRes.body);
                    final episodesMap = infoData['episodes'] as Map? ?? {};
                    var epList = episodesMap['$targetSeason'] as List? ?? [];

                    dynamic matchedEp;
                    if (epList.isNotEmpty) {
                      matchedEp = epList.firstWhere(
                        (e) => (e['episode_num'] ?? 0) == targetEpisode,
                        orElse: () => null,
                      );
                    }

                    if (matchedEp != null) {
                      final epStreamId = matchedEp['id'];
                      final ext = matchedEp['container_extension'] ?? 'mp4';
                      final isHindi = bestSeries['is_hindi_detected'] == true;
                      resolved.add({
                        'server': prov['name'] ?? 'Xtream Series HD',
                        'title': isHindi
                            ? '$movieTitle (Hindi Audio) S$targetSeason:E$targetEpisode'
                            : '$movieTitle S$targetSeason:E$targetEpisode',
                        'url': '$host/series/$user/$pass/$epStreamId.$ext',
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
                var streamList = jsonDecode(xtreamRes.body) as List;
                var candidates = [];

                for (var m in streamList) {
                  final mTmdb = (m['tmdb_id'] ?? m['tmdb'] ?? '').toString();
                  final rawName = (m['name'] ?? '').toString();
                  final categoryName = (m['category_name'] ?? '').toString();
                  final mClean = _cleanString(rawName);

                  bool isMatch = false;
                  if (mTmdb.isNotEmpty && mTmdb == targetTmdbId) {
                    isMatch = true;
                  } else if (mClean.contains(cleanTarget) || cleanTarget.contains(mClean)) {
                    isMatch = true;
                  }

                  if (isMatch) {
                    final isHindi = _isHindiStream(rawName, category: categoryName);
                    candidates.add({
                      'data': m,
                      'isHindi': isHindi,
                      'name': rawName,
                    });
                  }
                }

                candidates.sort((a, b) {
                  final aH = a['isHindi'] == true ? 1 : 0;
                  final bH = b['isHindi'] == true ? 1 : 0;
                  return bH.compareTo(aH);
                });

                for (var cand in candidates.take(3)) {
                  final bestMovie = cand['data'];
                  final streamId = bestMovie['stream_id'];
                  final ext = bestMovie['container_extension'] ?? 'mp4';
                  final isHindi = cand['isHindi'] == true;

                  resolved.add({
                    'server': prov['name'] ?? 'Xtream Movies VIP',
                    'title': isHindi
                        ? '$movieTitle (Hindi Audio / Dubbed)'
                        : '$movieTitle (Direct HD)',
                    'url': '$host/movie/$user/$pass/$streamId.$ext',
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

              final isHindi = _isHindiStream(titleStr);

              resolved.add({
                'server': prov['name'] ?? 'HdHub Server',
                'title': titleStr,
                'url': s['url'],
                'isHindi': isHindi,
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
      final raw = prefs.getString('continue_watching_mobile');
      var current = [];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          current = List.from(decoded);
        }
      }

      current.removeWhere((c) => c['tmdb_id'].toString() == widget.item['tmdb_id'].toString());

      current.insert(0, {
        'tmdb_id': widget.item['tmdb_id'],
        'title': widget.item['title'] ?? 'Untitled',
        'poster': widget.item['poster'] ?? '',
        'backdrop': widget.item['backdrop'] ?? widget.item['poster'] ?? '',
        'year': widget.item['year'] ?? '2025',
        'rating': widget.item['rating'] ?? '8.0',
        'isTv': widget.item['isTv'] ?? false,
      });

      if (current.length > 15) current = current.sublist(0, 15);
      await prefs.setString('continue_watching_mobile', jsonEncode(current));
      widget.onPlaySaved();
    } catch (_) {}
  }

  void _playStream(String url, bool isVlc) async {
    await _saveContinueWatching();
    if (!mounted) return;
    Navigator.of(context).pop();

    final cleanUrl = url.trim();

    if (isVlc) {
      final intent = AndroidIntent(
        action: 'action_view',
        data: cleanUrl,
        type: 'video/*',
      );
      await intent.launch();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InternalPlayerScreen(
            videoUrl: cleanUrl,
            streamUrl: cleanUrl,
            title: widget.season != null
                ? '${widget.item['title']} (S${widget.season} E${widget.episode})'
                : widget.item['title'],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.season != null
                ? '${widget.item['title']} - S${widget.season} E${widget.episode}'
                : widget.item['title'],
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Expanded(
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFE50914))))
          else if (streams.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No active streams found on servers.',
                    style: TextStyle(color: Colors.white54)),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: streams.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final s = streams[i];
                  final isHindi = s['isHindi'] == true;
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isHindi ? const Color(0xFF10B981) : Colors.white12,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isHindi)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'HINDI',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      s['title'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(s['server'],
                                  style: const TextStyle(
                                      color: Color(0xFFE50914), fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill,
                              color: Color(0xFFE50914), size: 30),
                          onPressed: () => _playStream(s['url'], false),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new,
                              color: Colors.amber, size: 24),
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

// ============================================================================
// 8. CINEMA HQ ENGINE INTERNAL VIDEO PLAYER (CROP/ZOOM + VOL/BRIGHTNESS)
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

class _InternalPlayerScreenState extends State<InternalPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInit = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _controlsTimer;

  bool _isLocked = false;
  bool _showUnlockButton = false;
  Timer? _unlockTimer;

  double _volume = 1.0;
  double _brightness = 0.5;
  String _overlayText = '';
  IconData _overlayIcon = Icons.volume_up_rounded;
  bool _showOverlayIndicator = false;
  Timer? _overlayTimer;

  int _scaleMode = 2; // CROP (Zoom default)

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final cleanUrl = widget.streamUrl.trim();

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(cleanUrl),
      );

      await _controller.initialize();
      _controller.setVolume(_volume);
      _controller.play();
      _startHideTimer();

      if (mounted) {
        setState(() => _isInit = true);
      }

      _controller.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _startHideTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (_isLocked) {
      setState(() => _showUnlockButton = !_showUnlockButton);
      if (_showUnlockButton) {
        _unlockTimer?.cancel();
        _unlockTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showUnlockButton = false);
        });
      }
      return;
    }

    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _togglePlayPause() {
    if (!_isInit || _isLocked) return;
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
      _showControls = true;
    });
    _startHideTimer();
  }

  void _seekRelative(int seconds) {
    if (!_isInit || _isLocked) return;
    final currentPos = _controller.value.position;
    final totalDur = _controller.value.duration;

    var newPos = currentPos + Duration(seconds: seconds);
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > totalDur) newPos = totalDur;

    _controller.seekTo(newPos);
    _startHideTimer();
  }

  void _cycleScaleMode() {
    if (_isLocked) return;
    setState(() {
      _scaleMode = (_scaleMode + 1) % 3;
      _showControls = true;
    });
    _startHideTimer();
  }

  void _onVerticalDragUpdate(
      DragUpdateDetails details, double screenWidth, double screenHeight) {
    if (_isLocked) return;

    final delta = -details.primaryDelta! / (screenHeight * 0.75);

    if (details.localPosition.dx < screenWidth / 2) {
      setState(() {
        _brightness = (_brightness + delta).clamp(0.0, 1.0);
        _overlayText = '${(_brightness * 100).toInt()}%';
        _overlayIcon = Icons.brightness_6_rounded;
        _showOverlayIndicator = true;
      });
    } else {
      setState(() {
        _volume = (_volume + delta).clamp(0.0, 1.0);
        _controller.setVolume(_volume);
        _overlayText = '${(_volume * 100).toInt()}%';
        _overlayIcon =
            _volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded;
        _showOverlayIndicator = true;
      });
    }

    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showOverlayIndicator = false);
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _overlayTimer?.cancel();
    _unlockTimer?.cancel();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Widget _buildVideoOutput() {
    if (!_isInit) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      );
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
    final scaleNames = ['FIT (16:9)', 'FILL (STRETCH)', 'CROP (ZOOM)'];
    final size = MediaQuery.of(context).size;

    final Duration activeDisplayPos =
        _isInit ? _controller.value.position : Duration.zero;
    final Duration totalDur =
        _isInit ? _controller.value.duration : Duration.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          _buildVideoOutput(),
          if (_isInit && _controller.value.isBuffering)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            ),
          IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity((1.0 - _brightness) * 0.75),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onVerticalDragUpdate: (details) =>
                _onVerticalDragUpdate(details, size.width, size.height),
            child: Container(color: Colors.transparent),
          ),
          if (_showOverlayIndicator && !_isLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF181818).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFE50914).withOpacity(0.5), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_overlayIcon, color: const Color(0xFFE50914), size: 28),
                  const SizedBox(width: 10),
                  Text(
                    _overlayText,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          if (_hasError)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.6), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent, size: 48),
                    const SizedBox(height: 10),
                    const Text(
                      'Stream load nahi ho saki',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLocked && _showUnlockButton)
            Positioned(
              left: 24,
              top: 24,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isLocked = false;
                    _showUnlockButton = false;
                    _showControls = true;
                  });
                  _startHideTimer();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(25),
                    border:
                        Border.all(color: const Color(0xFFE50914), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_open_rounded,
                          color: Color(0xFFE50914), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Unlock Screen',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_showControls && _isInit && !_isLocked)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  stops: [0.0, 0.22, 0.72, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 18,
                    left: 24,
                    right: 24,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isLocked = true;
                              _showControls = false;
                              _showUnlockButton = true;
                            });
                            _unlockTimer?.cancel();
                            _unlockTimer =
                                Timer(const Duration(seconds: 3), () {
                              if (mounted) {
                                setState(() => _showUnlockButton = false);
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF181818).withOpacity(0.9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white24, width: 1.2),
                            ),
                            child: const Icon(Icons.lock_outline_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        GestureDetector(
                          onTap: _cycleScaleMode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF181818).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFFE50914), width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.aspect_ratio_rounded,
                                    color: Color(0xFFE50914), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  scaleNames[_scaleMode],
                                  style: const TextStyle(
                                    color: Color(0xFFE50914),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _seekRelative(-30),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black45,
                              border: Border.all(
                                  color: Colors.white24, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.replay_30_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            width: 65,
                            height: 65,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  const Color(0xFFE50914).withOpacity(0.85),
                              border: Border.all(
                                  color: Colors.white24, width: 2),
                            ),
                            child: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                        GestureDetector(
                          onTap: () => _seekRelative(30),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black45,
                              border: Border.all(
                                  color: Colors.white24, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.forward_30_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 24,
                    right: 24,
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(activeDisplayPos),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFE50914),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: const Color(0xFFE50914),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: activeDisplayPos.inMilliseconds
                                  .clamp(0, totalDur.inMilliseconds)
                                  .toDouble(),
                              min: 0.0,
                              max: totalDur.inMilliseconds.toDouble() > 0
                                  ? totalDur.inMilliseconds.toDouble()
                                  : 1.0,
                              onChanged: (val) {
                                _controller.seekTo(
                                    Duration(milliseconds: val.toInt()));
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(totalDur),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

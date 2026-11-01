import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'internal_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const MobileCinemaTvApp());
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
      title: 'Netflix',
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
      home: const MobileSplashScreen(),
    );
  }
}

// ----------------- NETFLIX ANIMATED SPLASH -----------------
class MobileSplashScreen extends StatefulWidget {
  const MobileSplashScreen({super.key});

  @override
  State<MobileSplashScreen> createState() => _MobileSplashScreenState();
}

class _MobileSplashScreenState extends State<MobileSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation _scale;
  late Animation _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _scale = Tween(begin: 0.75, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacity = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    _controller.forward();

    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (_, __, ___) => const MobileHomeScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
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
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: SizedBox(
                  width: 105,
                  height: 185,
                  child: CustomPaint(
                    painter: NetflixLogoPainter(),
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ----------------- NETFLIX HOMESCREEN -----------------
class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _bottomNavIndex = 0;
  var activeProviders = [];
  var continueWatchingList = [];

  var heroBanners = [];
  int currentHeroIndex = 0;
  final PageController _heroController = PageController(viewportFraction: 0.88);
  Timer? _heroTimer;

  // Categories Data Lists
  var netflixSeries = [];
  var netflixMovies = [];
  var hindiWebSeries = [];
  var bollywoodLatest = [];
  var hollywoodHindiDubbed = [];
  var southHindiDubbed = [];
  var amazonSeries = [];
  var hollywoodHindiSeries = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    if (heroBanners.isNotEmpty) {
      _heroTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_heroController.hasClients) {
          int nextPage = (currentHeroIndex + 1) % heroBanners.length;
          _heroController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      });
    }
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

  Future<void> _loadContinueWatching() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('continue_watching_mobile');
      if (raw != null && raw.isNotEmpty) {
        if (mounted) {
          setState(() {
            continueWatchingList = jsonDecode(raw) as List;
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
      // 1. NETFLIX ORIGINAL SERIES
      final netflixTvRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_networks=213&sort_by=popularity.desc&vote_count.gte=20'));
      if (netflixTvRes.statusCode == 200) {
        netflixSeries = _parseResults(jsonDecode(netflixTvRes.body)['results'], isTv: true);
        if (netflixSeries.isNotEmpty) {
          heroBanners = netflixSeries.take(6).toList();
        }
      }

      // 2. NETFLIX BLOCKBUSTER MOVIES (with_watch_providers=8&watch_region=IN)
      final netflixMovieRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&sort_by=popularity.desc&vote_count.gte=10'));
      if (netflixMovieRes.statusCode == 200) {
        netflixMovies = _parseResults(jsonDecode(netflixMovieRes.body)['results']);
      }

      // 3. HINDI WEB SERIES
      final hindiTvRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=vote_count.desc&vote_count.gte=10'));
      if (hindiTvRes.statusCode == 200) {
        final rawList = jsonDecode(hindiTvRes.body)['results'] ?? [];
        hindiWebSeries = _parseResults(rawList, isTv: true)
            .where((item) => !isDailySoapTitle(item['title'] ?? ''))
            .toList();
      }

      // 4. BOLLYWOOD MOVIES
      final bollyRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=hi&sort_by=popularity.desc&vote_count.gte=10'));
      if (bollyRes.statusCode == 200) {
        bollywoodLatest = _parseResults(jsonDecode(bollyRes.body)['results']);
      }

      // 5. HOLLYWOOD HINDI DUBBED
      final hollyRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=en&sort_by=popularity.desc&vote_count.gte=100'));
      if (hollyRes.statusCode == 200) {
        hollywoodHindiDubbed = _parseResults(jsonDecode(hollyRes.body)['results']);
      }

      // 6. SOUTH INDIAN DUBBED
      final southRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn&sort_by=popularity.desc&vote_count.gte=20'));
      if (southRes.statusCode == 200) {
        southHindiDubbed = _parseResults(jsonDecode(southRes.body)['results']);
      }

      // 7. AMAZON ORIGINALS
      final amazonRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_networks=1024&sort_by=popularity.desc&vote_count.gte=20'));
      if (amazonRes.statusCode == 200) {
        amazonSeries = _parseResults(jsonDecode(amazonRes.body)['results'], isTv: true);
      }

      // 8. HOLLYWOOD SERIES
      final hollySeriesRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_original_language=en&sort_by=popularity.desc&vote_count.gte=30'));
      if (hollySeriesRes.statusCode == 200) {
        hollywoodHindiSeries = _parseResults(jsonDecode(hollySeriesRes.body)['results'], isTv: true);
      }
    } catch (_) {}
  }

  List _parseResults(dynamic list, {bool isTv = false}) {
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
          categoryType: type,
          title: title,
          providers: activeProviders,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }

  void _showCategoriesMenuSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'CATEGORIES',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              _categorySheetItem('Netflix Originals (Series)', () => _openCatalog('Netflix Originals', 'netflix_originals')),
              _categorySheetItem('Netflix Movies', () => _openCatalog('Netflix Movies', 'netflix_movies')),
              _categorySheetItem('Hindi Web Series', () => _openCatalog('Hindi Web Series', 'hindi_series')),
              _categorySheetItem('Bollywood Movies', () => _openCatalog('Bollywood Movies', 'bollywood')),
              _categorySheetItem('South Indian (Hindi Dubbed)', () => _openCatalog('South Indian Movies', 'south')),
              _categorySheetItem('Hollywood Movies (Hindi Dubbed)', () => _openCatalog('Hollywood Movies', 'hollywood_movies')),
              _categorySheetItem('English Web Series', () => _openCatalog('English Web Series', 'english_series')),
            ],
          ),
        );
      },
    );
  }

  Widget _categorySheetItem(String title, VoidCallback onTap) {
    return ListTile(
      title: Center(
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.4),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 35,
            child: CustomPaint(painter: NetflixLogoPainter()),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () => _openCatalog('TV Shows', 'hindi_series'),
            child: const Text('TV Shows', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 24),
          GestureDetector(
            onTap: () => _openCatalog('Movies', 'bollywood'),
            child: const Text('Movies', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 24),
          GestureDetector(
            onTap: _showCategoriesMenuSheet,
            child: const Row(
              children: [
                Text('Categories', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------- HERO CAROUSEL -----------------
  Widget _buildHeroCarousel() {
    if (heroBanners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _heroController,
            itemCount: heroBanners.length,
            onPageChanged: (i) => setState(() => currentHeroIndex = i),
            itemBuilder: (ctx, idx) {
              final item = heroBanners[idx];
              final isCurrent = idx == currentHeroIndex;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(horizontal: 6, vertical: isCurrent ? 0 : 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.7),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onTap: () => _onItemTapped(item),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          item['backdrop'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1E1E)),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.transparent, Colors.black87],
                              stops: [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'NETFLIX SPOTLIGHT',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item['title'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item['year']} • ⭐ ${item['rating']}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                onPressed: () => _onItemTapped(item),
                                icon: const Icon(Icons.play_arrow, color: Colors.black, size: 20),
                                label: const Text('Play', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            heroBanners.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == currentHeroIndex ? 7 : 5,
              height: index == currentHeroIndex ? 7 : 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == currentHeroIndex ? const Color(0xFFE50914) : Colors.white24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueWatchingRow(dynamic items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            'Continue Watching for You',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                  width: 115,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFF1E1E1E),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                item['poster'] ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1E1E)),
                              ),
                              const Center(
                                child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 36),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(height: 3, color: const Color(0xFFE50914)),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          item['title'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
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

  Widget _buildNetflixRow(String title, dynamic items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFF1E1E1E),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      item['poster'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1E1E)),
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

  Widget _buildAuthenticBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(top: BorderSide(color: Color(0xFF262626), width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          if (index == 1) {
            showSearch(context: context, delegate: TmdbSearchDelegate(onItemTapped: _onItemTapped));
          } else if (index == 2) {
            _showCategoriesMenuSheet();
          } else {
            setState(() => _bottomNavIndex = index);
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white38,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_rounded), label: 'Categories'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'My Netflix'),
        ],
      ),
    );
  }

  // ----------------- NETFLIX PRIORITY LAYOUT -----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    SliverToBoxAdapter(child: _buildHeroCarousel()), // TOP NETFLIX SPOTLIGHT
                    if (continueWatchingList.isNotEmpty)
                      SliverToBoxAdapter(child: _buildContinueWatchingRow(continueWatchingList)),
                    
                    // 1. NETFLIX ORIGINAL SERIES
                    SliverToBoxAdapter(child: _buildNetflixRow('Only on Netflix (Original Series)', netflixSeries)),
                    
                    // 2. NETFLIX BLOCKBUSTER MOVIES (LIVE WITH WATCH PROVIDER 8)
                    SliverToBoxAdapter(child: _buildNetflixRow('Netflix Blockbuster Movies', netflixMovies)),
                    
                    // 3. REMAINING ORIGINAL CATEGORIES (ALL PRESERVED)
                    SliverToBoxAdapter(child: _buildNetflixRow('Trending Indian Web Series', hindiWebSeries)),
                    SliverToBoxAdapter(child: _buildNetflixRow('Bollywood Blockbusters', bollywoodLatest)),
                    SliverToBoxAdapter(child: _buildNetflixRow('Hollywood Hits (Hindi Dubbed)', hollywoodHindiDubbed)),
                    SliverToBoxAdapter(child: _buildNetflixRow('South Action Hits (Hindi Dubbed)', southHindiDubbed)),
                    SliverToBoxAdapter(child: _buildNetflixRow('Amazon Prime Specials', amazonSeries)),
                    SliverToBoxAdapter(child: _buildNetflixRow('Global Web Series', hollywoodHindiSeries)),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildTopNavBar(),
                ),
              ],
            ),
      bottomNavigationBar: _buildAuthenticBottomNav(),
    );
  }
}

// ----------------- TMDB SEARCH DELEGATE -----------------
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
      return const Center(child: Text('Search movies & series...', style: TextStyle(color: Colors.white54)));
    }
    return FutureBuilder(
      future: _performSearch(query.trim()),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
        }
        final list = (snapshot.data as List?) ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('No results found.', style: TextStyle(color: Colors.white54)));
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
                  errorBuilder: (_, __, ___) => Container(width: 45, height: 65, color: const Color(0xFF1E1E1E)),
                ),
              ),
              title: Text(item['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('${item['year']} • ${item['isTv'] ? "Series" : "Movie"}', style: const TextStyle(color: Colors.white54)),
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

  Future<List> _performSearch(String q) async {
    try {
      final url = '${AppConfig.tmdbBase}/search/multi?api_key=${AppConfig.tmdbKey}&query=${Uri.encodeComponent(q)}';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = (data['results'] as List?) ?? [];
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

// ----------------- CATALOG GRID VIEW -----------------
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
    final bool isTv = widget.categoryType == 'hindi_series' || widget.categoryType == 'english_series' || widget.categoryType == 'netflix_originals';
    var fetched = [];

    for (int page = 1; page <= 5; page++) {
      String url = '';

      if (widget.categoryType == 'netflix_originals') {
        url = '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_networks=213&sort_by=popularity.desc&vote_count.gte=20&page=$page';
      } else if (widget.categoryType == 'netflix_movies') {
        url = '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&sort_by=popularity.desc&vote_count.gte=10&page=$page';
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
          final rawResults = (data['results'] as List?) ?? [];
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

    fetched.sort((a, b) {
      final yA = int.tryParse(a['year']?.toString() ?? '0') ?? 0;
      final yB = int.tryParse(b['year']?.toString() ?? '0') ?? 0;
      return yB.compareTo(yA);
    });

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
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : itemsList.isEmpty
              ? const Center(child: Text('Titles load nahi ho sake', style: TextStyle(color: Colors.white60)))
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
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              item['poster'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1E1E)),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item['title'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    item['year'],
                                    style: const TextStyle(color: Colors.white54, fontSize: 9),
                                  ),
                                ],
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

// ----------------- EPISODE SELECTOR DIALOG -----------------
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
  int episodeCount = 10;
  var availableSeasons = [1, 2, 3];
  bool loadingSeasons = true;

  @override
  void initState() {
    super.initState();
    _fetchTvDetails();
  }

  Future<void> _fetchTvDetails() async {
    try {
      final res = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/tv/${widget.item['tmdb_id']}?api_key=${AppConfig.tmdbKey}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final seasons = (data['seasons'] as List?);
        if (seasons != null && seasons.isNotEmpty) {
          final valid = seasons
              .where((s) => (s['season_number'] ?? 0) > 0)
              .map((s) => s['season_number'] as int)
              .toList();
          if (valid.isNotEmpty) {
            setState(() {
              availableSeasons = valid;
              selectedSeason = valid.first;
              final cur = seasons.firstWhere((s) => s['season_number'] == selectedSeason, orElse: () => null);
              episodeCount = cur != null ? (cur['episode_count'] ?? 10) : 10;
              loadingSeasons = false;
            });
            return;
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => loadingSeasons = false);
  }

  void _onSeasonChanged(int s) {
    setState(() {
      selectedSeason = s;
      episodeCount = 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item['title'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableSeasons.map((s) {
                  final isSel = s == selectedSeason;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSel ? const Color(0xFFE50914) : const Color(0xFF262626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _onSeasonChanged(s as int),
                      child: Text('Season $s', style: const TextStyle(fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: episodeCount,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.5,
                ),
                itemBuilder: (ctx, idx) {
                  final ep = idx + 1;
                  return OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white12),
                      backgroundColor: const Color(0xFF262626),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSelected(selectedSeason, ep);
                    },
                    child: Text('EP $ep', style: const TextStyle(color: Colors.white, fontSize: 12)),
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

// ----------------- QUALITY SELECTOR SHEET -----------------
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
  State<MobileQualitySelectorSheet> createState() => _MobileQualitySelectorSheetState();
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
                final seriesList = (jsonDecode(xtreamRes.body) as List?) ?? [];
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
                    final episodesMap = infoData['episodes'] as Map<String, dynamic>? ?? {};
                    final epList = (episodesMap['$targetSeason'] as List?) ?? [];

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
                final streamList = (jsonDecode(xtreamRes.body) as List?) ?? [];
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
            final sList = (data['streams'] as List?) ?? [];
            for (var s in sList) {
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
        current = jsonDecode(raw) as List;
      }

      current.removeWhere((c) => c['tmdb_id'].toString() == widget.item['tmdb_id'].toString());

      current.insert(0, {
        'tmdb_id': widget.item['tmdb_id'],
        'title': widget.item['title'] ?? 'Untitled',
        'poster': widget.item['poster'] ?? '',
        'backdrop': widget.item['backdrop'] ?? widget.item['poster'] ?? '',
        'year': widget.item['year'] ?? DateTime.now().year.toString(),
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
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))))
          else if (streams.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No active streams found on servers.', style: TextStyle(color: Colors.white54)),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                              Text(s['server'], style: const TextStyle(color: Color(0xFFE50914), fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: Color(0xFFE50914), size: 30),
                          onPressed: () => _playStream(s['url'], false),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new, color: Colors.amber, size: 24),
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

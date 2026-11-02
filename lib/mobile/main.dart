// ============================================================================
// NETFLIX PRO MOBILE - COMPLETE STANDALONE EDITION (CATALOG, GRID & RESOLVER)
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

// SSL Handshake Override
class MobileHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MobileHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const NetflixMobileApp());
}

class MobileConfig {
  static const String gistUrl =
      'https://gist.githubusercontent.com/Rahul6051276/239654d65b2124bffd0ea21b5251dc02/raw/providers.json';
  static const String tmdbKey = 'b7cd3340a794e5a2f35e3abb820b497f';
  static const String tmdbBase = 'https://api.themoviedb.org/3';
  static const String imgBase = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBase = 'https://image.tmdb.org/t/p/w1280';
}

// Strict Daily Soap & TV Serial Filter
bool isSoapShow(String title) {
  final t = title.toLowerCase();
  const blocked = [
    'c.i.d.', 'cid', 'bhabiji', 'balika vadhu', 'kapil sharma', 'roadies',
    'pavitra rishta', 'kumkum bhagya', 'jhanak', 'kundali bhagya',
    'ye rishta', 'yrkkh', 'taarak mehta', 'tmkoc', 'kasautii', 'ishqbaaaz',
    'anupamaa', 'bigg boss', 'khatron ke khiladi', 'splitsvilla',
    'crime patrol', 'savdhaan india', 'diya aur baati', 'qubool hai',
    'jamai raja', 'tujhse hai raabta', 'radhakrishn', 'koffee with karan',
    'chudail', 'sasural', 'fitoor', 'bhojpuri', 'nagin', 'naagin', 'parineetii',
    'udaariyaan', 'imlie', 'ghukk', 'shravani', 'suhaagan', 'dharampatnii',
    'lo chudail', 'chali sasural'
  ];
  return blocked.any((b) => t.contains(b));
}

class NetflixMobileApp extends StatelessWidget {
  const NetflixMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netflix Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        fontFamily: 'sans-serif',
      ),
              home: const NetflixSplashScreen(),
    );
  }
}
// ============================================================================
// NETFLIX INTRO / SPLASH SCREEN
// ============================================================================
class NetflixSplashScreen extends StatefulWidget {
  const NetflixSplashScreen({super.key});

  @override
  State<NetflixSplashScreen> createState() => _NetflixSplashScreenState();
}

class _NetflixSplashScreenState extends State<NetflixSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );

    _controller.forward();

    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const MobileHomeScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
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
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'N',
                      style: TextStyle(
                        color: Color(0xFFE50914),
                        fontSize: 90,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.0,
                        fontFamily: 'Helvetica Neue',
                        shadows: [
                          Shadow(
                            blurRadius: 25.0,
                            color: Color(0x99E50914),
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'NETFLIX PRO',
                      style: TextStyle(
                        color: Color(0xFFE50914),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4.0,
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
class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  List<dynamic> activeProviders = [];
  List<dynamic> continueWatchingList = [];
  dynamic billboardItem;

  // Home Categories
  List<dynamic> homeNetflixList = [];
  List<dynamic> homePrimeList = [];
  List<dynamic> homeHotstarList = [];
  List<dynamic> homeHindiSeriesList = [];
  List<dynamic> homeEnglishSeriesList = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllMobileData();
  }

  Future<void> _loadAllMobileData() async {
    await Future.wait([
      _fetchProviders(),
      _loadContinueWatching(),
      _fetchHomeCatalogContent(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _loadContinueWatching() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('continue_watching_mobile');
      if (raw != null && raw.isNotEmpty && mounted) {
        setState(() {
          continueWatchingList = jsonDecode(raw) as List<dynamic>;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchProviders() async {
    try {
      final res = await http.get(Uri.parse(MobileConfig.gistUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        activeProviders = jsonDecode(res.body)['active_providers'] ?? [];
      }
    } catch (_) {}
  }

  Future<void> _fetchHomeCatalogContent() async {
    try {
      // 1. Netflix Blockbusters (Hindi + Global)
      final netflixRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&sort_by=primary_release_date.desc')).timeout(const Duration(seconds: 8));
      if (netflixRes.statusCode == 200) {
        homeNetflixList = _parseList(jsonDecode(netflixRes.body)['results']);
        if (homeNetflixList.isNotEmpty) billboardItem = homeNetflixList.first;
      }

      // 2. Prime Video Hits
      final primeRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=119&watch_region=IN&sort_by=primary_release_date.desc')).timeout(const Duration(seconds: 8));
      if (primeRes.statusCode == 200) {
        homePrimeList = _parseList(jsonDecode(primeRes.body)['results']);
      }

      // 3. Disney+ Hotstar & Cinema Specials
      final hotstarRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/movie/now_playing?api_key=${MobileConfig.tmdbKey}&language=en-US&region=IN')).timeout(const Duration(seconds: 8));
      if (hotstarRes.statusCode == 200) {
        homeHotstarList = _parseList(jsonDecode(hotstarRes.body)['results']);
      }

      // 4. Latest Hindi Web Series (Filtered OTT - Daily Soaps Excluded)
      final hindiTvRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=popularity.desc&vote_count.gte=5')).timeout(const Duration(seconds: 8));
      if (hindiTvRes.statusCode == 200) {
        homeHindiSeriesList = _parseList(jsonDecode(hindiTvRes.body)['results'], isTv: true)
            .where((item) => !isSoapShow(item['title'] ?? ''))
            .toList();
      }

      // 5. Global Web Series On The Air
      final engTvRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/tv/on_the_air?api_key=${MobileConfig.tmdbKey}&language=en-US')).timeout(const Duration(seconds: 8));
      if (engTvRes.statusCode == 200) {
        homeEnglishSeriesList = _parseList(jsonDecode(engTvRes.body)['results'], isTv: true);
      }
    } catch (_) {}
  }

  List<dynamic> _parseList(dynamic list, {bool isTv = false}) {
    var res = [];
    final currentYear = DateTime.now().year.toString();
    for (var m in (list ?? [])) {
      if (m['backdrop_path'] == null && m['poster_path'] == null) continue;
      final t = (m['title'] ?? m['name'] ?? 'Untitled').toString();
      if (isTv && isSoapShow(t)) continue;

      res.add({
        'tmdb_id': m['id'],
        'title': t,
        'year': (m['release_date'] ?? m['first_air_date'] ?? currentYear).toString().split('-')[0],
        'rating': m['vote_average']?.toString() ?? '7.5',
        'backdrop': m['backdrop_path'] != null
            ? '${MobileConfig.backdropBase}${m['backdrop_path']}'
            : '${MobileConfig.imgBase}${m['poster_path']}',
        'poster': m['poster_path'] != null
            ? '${MobileConfig.imgBase}${m['poster_path']}'
            : '${MobileConfig.backdropBase}${m['backdrop_path']}',
        'overview': m['overview'] ?? '',
        'isTv': isTv,
      });
    }
    return res;
  }

  void _onItemSelect(dynamic item) {
    if (item['isTv'] == true) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => MobileEpisodeSheet(
          item: item,
          onSelected: (season, episode) {
            _showMobileStreamSheet(item, season: season, episode: episode);
          },
        ),
      );
    } else {
      _showMobileStreamSheet(item);
    }
  }

  void _showMobileStreamSheet(dynamic item, {int? season, int? episode}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MobileStreamSheet(
        item: item,
        season: season,
        episode: episode,
        providers: activeProviders,
        onPlaySaved: () => _loadContinueWatching(),
      ),
    );
  }

    // ============================================================================
  // TOP SPOTLIGHT BILLBOARD
  // ============================================================================
  Widget _buildMobileBillboard(dynamic item) {
    if (item == null) return const SizedBox.shrink();

    final String imgUrl = (item['backdrop'] != null && item['backdrop'].toString().isNotEmpty)
        ? item['backdrop'].toString()
        : (item['poster'] != null ? item['poster'].toString() : '');

    return SizedBox(
      height: 460,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imgUrl.isNotEmpty)
            Image.network(
              imgUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1F1F1F)),
            )
          else
            Container(color: const Color(0xFF1F1F1F)),
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
                stops: [0.0, 0.45, 0.75, 1.0],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['title'] ?? item['name'] ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow, size: 22),
                      label: const Text('Play', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.info_outline, size: 20),
                      label: const Text('Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
  // MOBILE HORIZONTAL ROW (WITH SEE ALL)
  // ============================================================================
  Widget _buildMobileRow(
    String title,
    List<dynamic> items,
    String baseUrl, {
    bool isTv = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    void openSeeAll() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MobileCategoryGridScreen(
            title: title,
            baseUrl: baseUrl,
            isTv: isTv,
            providers: activeProviders,
            onPlaySaved: () => _loadContinueWatching(),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: openSeeAll,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'See All →',
                    style: TextStyle(color: Color(0xFFE50914), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 175,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: items.length + 1,
            itemBuilder: (ctx, idx) {
              if (idx == items.length) {
                return InkWell(
                  onTap: openSeeAll,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 105,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202020),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.grid_view_rounded, color: Color(0xFFE50914), size: 28),
                        SizedBox(height: 6),
                        Text('See All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Explore More', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }

              final item = items[idx];
              return InkWell(
                onTap: () => _onItemSelect(item),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 115,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        item['poster'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF222222)),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black, Colors.transparent],
                            ),
                          ),
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
                      ),
                    ],
                  ),
                ),
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
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE50914),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('N', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            const Text('NETFLIX PRO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 1.1)),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : RefreshIndicator(
              color: const Color(0xFFE50914),
              backgroundColor: const Color(0xFF202020),
              onRefresh: _loadAllMobileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (billboardItem != null) _buildMobileBillboard(billboardItem),
                    const SizedBox(height: 8),

                    // Netflix Blockbusters
                    if (homeNetflixList.isNotEmpty)
                      _buildMobileRow(
                        'Latest Netflix Blockbusters (Hindi + Global)',
                        homeNetflixList,
                        '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=8&watch_region=IN',
                      ),

                    // Prime Video
                    if (homePrimeList.isNotEmpty)
                      _buildMobileRow(
                        'Amazon Prime Video Hits',
                        homePrimeList,
                        '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=119&watch_region=IN',
                      ),

                    // Disney+ Hotstar
                    if (homeHotstarList.isNotEmpty)
                      _buildMobileRow(
                        'Disney+ Hotstar & Cinema Specials',
                        homeHotstarList,
                        '${MobileConfig.tmdbBase}/movie/now_playing?api_key=${MobileConfig.tmdbKey}&language=en-US&region=IN',
                      ),

                    // Hindi Web Series
                    if (homeHindiSeriesList.isNotEmpty)
                      _buildMobileRow(
                        'Latest Hindi Web Series',
                        homeHindiSeriesList,
                        '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_original_language=hi&without_genres=10766&vote_count.gte=5',
                        isTv: true,
                      ),

                    // Global Shows
                    if (homeEnglishSeriesList.isNotEmpty)
                      _buildMobileRow(
                        'Global Hits On The Air',
                        homeEnglishSeriesList,
                        '${MobileConfig.tmdbBase}/tv/on_the_air?api_key=${MobileConfig.tmdbKey}&language=en-US',
                        isTv: true,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ============================================================================
// MOBILE 3-COLUMN VERTICAL GRID SCREEN (SEE ALL WITH LATEST / POPULAR)
// ============================================================================
class MobileCategoryGridScreen extends StatefulWidget {
  final String title;
  final String baseUrl;
  final bool isTv;
  final List<dynamic> providers;
  final VoidCallback onPlaySaved;

  const MobileCategoryGridScreen({
    super.key,
    required this.title,
    required this.baseUrl,
    required this.isTv,
    required this.providers,
    required this.onPlaySaved,
  });

  @override
  State<MobileCategoryGridScreen> createState() => _MobileCategoryGridScreenState();
}

class _MobileCategoryGridScreenState extends State<MobileCategoryGridScreen> {
  var items = [];
  bool isLoading = true;
  String sortType = 'latest';

  @override
  void initState() {
    super.initState();
    _fetchGridData();
  }

  void _toggleSort() {
    setState(() {
      sortType = sortType == 'latest' ? 'popular' : 'latest';
      isLoading = true;
      items.clear();
    });
    _fetchGridData();
  }

  Future<void> _fetchGridData() async {
    final sortQuery = sortType == 'latest'
        ? (widget.isTv ? 'first_air_date.desc' : 'primary_release_date.desc')
        : 'popularity.desc';

    var cleanUrl = widget.baseUrl;
    cleanUrl = cleanUrl.replaceAll(RegExp(r'sort_by=[^&]+'), '');
    final sep = cleanUrl.contains('?') ? '&' : '?';

    var accumulated = [];
    for (int p = 1; p <= 10; p++) {
      try {
        final url = '$cleanUrl${sep}sort_by=$sortQuery&page=$p';
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body)['results'];
          final currentYear = DateTime.now().year.toString();
          for (var m in (data ?? [])) {
            if (m['backdrop_path'] == null && m['poster_path'] == null) continue;
            final t = (m['title'] ?? m['name'] ?? 'Untitled').toString();
            if (isSoapShow(t)) continue;

            accumulated.add({
              'tmdb_id': m['id'],
              'title': t,
              'year': (m['release_date'] ?? m['first_air_date'] ?? currentYear).toString().split('-')[0],
              'rating': m['vote_average']?.toString() ?? '7.5',
              'backdrop': m['backdrop_path'] != null
                  ? '${MobileConfig.backdropBase}${m['backdrop_path']}'
                  : '${MobileConfig.imgBase}${m['poster_path']}',
              'poster': m['poster_path'] != null
                  ? '${MobileConfig.imgBase}${m['poster_path']}'
                  : '${MobileConfig.backdropBase}${m['backdrop_path']}',
              'overview': m['overview'] ?? '',
              'isTv': widget.isTv,
            });
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        items = accumulated;
        isLoading = false;
      });
    }
  }

  void _onGridItemClick(dynamic item) {
    if (item['isTv'] == true) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => MobileEpisodeSheet(
          item: item,
          onSelected: (season, episode) {
            _showDirectStreamSheet(item, season: season, episode: episode);
          },
        ),
      );
    } else {
      _showDirectStreamSheet(item);
    }
  }

  void _showDirectStreamSheet(dynamic item, {int? season, int? episode}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MobileStreamSheet(
        item: item,
        season: season,
        episode: episode,
        providers: widget.providers,
        onPlaySaved: widget.onPlaySaved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.9),
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _toggleSort,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE50914), width: 1.2),
                ),
                child: Row(
                  children: [
                    Icon(
                      sortType == 'latest' ? Icons.fiber_new_rounded : Icons.whatshot_rounded,
                      size: 16,
                      color: const Color(0xFFE50914),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sortType == 'latest' ? 'Latest' : 'Popular',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 10,
                childAspectRatio: 0.64,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, idx) {
                final item = items[idx];
                return InkWell(
                  onTap: () => _onGridItemClick(item),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          item['poster'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF222222)),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black, Colors.transparent],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item['title'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${item['rating']} ★', style: const TextStyle(color: Color(0xFF46D369), fontSize: 9)),
                                    Text('${item['year']}', style: const TextStyle(color: Colors.white60, fontSize: 9)),
                                  ],
                                ),
                              ],
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
// MOBILE EPISODE BOTTOM SHEET
// ============================================================================
class MobileEpisodeSheet extends StatefulWidget {
  final dynamic item;
  final Function(int s, int ep) onSelected;

  const MobileEpisodeSheet({super.key, required this.item, required this.onSelected});

  @override
  State<MobileEpisodeSheet> createState() => _MobileEpisodeSheetState();
}

class _MobileEpisodeSheetState extends State<MobileEpisodeSheet> {
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
          '${MobileConfig.tmdbBase}/tv/${widget.item['tmdb_id']}?api_key=${MobileConfig.tmdbKey}')).timeout(const Duration(seconds: 8));
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
    return Container(
      height: 380,
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
    );
  }
}

// ============================================================================
// MOBILE STREAM RESOLVER BOTTOM SHEET
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
            '${MobileConfig.tmdbBase}/$extType/$targetTmdbId/external_ids?api_key=${MobileConfig.tmdbKey}')).timeout(const Duration(seconds: 4));
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
                final seriesList = jsonDecode(xtreamRes.body) as List<dynamic>;
                var candidates = [];

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
                final streamList = jsonDecode(xtreamRes.body) as List<dynamic>;
                var candidates = [];

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
            widget.season != null
                ? '${widget.item['title']} - S${widget.season} E${widget.episode}'
                : widget.item['title'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))))
          else if (streams.isEmpty)
            const Expanded(child: Center(child: Text('No active streams found on server.', style: TextStyle(color: Colors.white70))))
          else
            Expanded(
              child: ListView.builder(
                itemCount: streams.length,
                itemBuilder: (ctx, i) {
                  final s = streams[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF282828),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          s['isHindi'] == true ? Icons.record_voice_over_rounded : Icons.movie_rounded,
                          color: s['isHindi'] == true ? const Color(0xFF46D369) : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s['title'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s['server'],
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: Color(0xFFE50914), size: 28),
                          onPressed: () => _playStream(s['url'], false),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 22),
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

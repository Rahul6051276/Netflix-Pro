// ============================================================================
// 1. APP ENTRY POINT & SYSTEM CONFIGURATION
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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const MobileCinemaTvApp());
}

// ============================================================================
// 2. CONFIGURATION & TMDB API CREDENTIALS
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

class MobileCinemaTvApp extends StatelessWidget {
  const MobileCinemaTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cinema TV HQ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1014),
        fontFamily: 'sans-serif',
      ),
      home: const MobileSplashScreen(),
    );
  }
}

// ============================================================================
// 3. SPLASH SCREEN
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
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
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
      backgroundColor: const Color(0xFF0F1014),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0072D2), Color(0xFF001B44)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0072D2).withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(color: const Color(0xFF38BDF8), width: 2.5),
                      ),
                      child: const Center(
                        child: Icon(Icons.play_arrow_rounded, size: 55, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'CINEMA ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0072D2), Color(0xFF00458E)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'TV HQ',
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
      _heroTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (_heroPageController.hasClients) {
          int nextPage = (_currentHeroIndex + 1) % heroBanners.length;
          _heroPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
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
      final bollyRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=hi&sort_by=popularity.desc&vote_count.gte=10'));
      if (bollyRes.statusCode == 200) {
        bollywoodLatest = _parseResults(jsonDecode(bollyRes.body)['results']);
        if (bollywoodLatest.isNotEmpty) heroBanners = bollywoodLatest.take(5).toList();
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

      final netflixRes = await http.get(Uri.parse(
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_networks=213&sort_by=popularity.desc&vote_count.gte=20'));
      if (netflixRes.statusCode == 200) {
        netflixSeries = _parseResults(jsonDecode(netflixRes.body)['results'], isTv: true);
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
      backgroundColor: const Color(0xFF16181F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      backgroundColor: const Color(0xFF07080B),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0F1014)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0072D2), Color(0xFF001B44)],
                    ),
                    border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 12),
                const Text(
                  'CINEMA TV HQ',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.movie_filter_rounded, color: Color(0xFF38BDF8)),
            title: const Text('Bollywood Movies', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCatalogGridView(
                    categoryType: 'bollywood',
                    title: 'Bollywood Movies',
                    providers: activeProviders,
                    onItemTapped: _onItemTapped,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_movies_rounded, color: Color(0xFF38BDF8)),
            title: const Text('South Indian (Hindi Dubbed)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCatalogGridView(
                    categoryType: 'south',
                    title: 'South Indian Movies',
                    providers: activeProviders,
                    onItemTapped: _onItemTapped,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.theaters_rounded, color: Color(0xFF38BDF8)),
            title: const Text('Hollywood Movies (Hindi Dubbed)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCatalogGridView(
                    categoryType: 'hollywood_movies',
                    title: 'Hollywood Movies',
                    providers: activeProviders,
                    onItemTapped: _onItemTapped,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.live_tv_rounded, color: Color(0xFF38BDF8)),
            title: const Text('Hindi Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCatalogGridView(
                    categoryType: 'hindi_series',
                    title: 'Hindi Web Series',
                    providers: activeProviders,
                    onItemTapped: _onItemTapped,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.connected_tv_rounded, color: Color(0xFF38BDF8)),
            title: const Text('English Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCatalogGridView(
                    categoryType: 'english_series',
                    title: 'English Web Series',
                    providers: activeProviders,
                    onItemTapped: _onItemTapped,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHorizontalRow(dynamic items) {
    var list = items is List ? items : [];
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: list.length,
        itemBuilder: (ctx, i) {
          final item = list[i];
          return GestureDetector(
            onTap: () => _onItemTapped(item),
            child: Container(
              width: 175,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF1E2029),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      item['backdrop'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFF1E2029)),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: Colors.black87,
                        child: Text(
                          item['title'],
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
          );
        },
      ),
    );
  }

  Widget _buildHeroSlider() {
    if (heroBanners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _heroPageController,
            itemCount: heroBanners.length,
            onPageChanged: (index) {
              setState(() => _currentHeroIndex = index);
            },
            itemBuilder: (context, index) {
              final item = heroBanners[index];
              return GestureDetector(
                onTap: () => _onItemTapped(item),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      item['backdrop'] ?? item['poster'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFF1E2029)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF0F1014).withOpacity(0.3),
                            const Color(0xFF0F1014),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 14,
                      right: 14,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item['title'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                                          const SizedBox(width: 2),
                                          Text(
                                            item['rating'] ?? '7.5',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item['year'] ?? '',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _onItemTapped(item),
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                            label: const Text(
                              'Watch',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0072D2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            heroBanners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentHeroIndex == index ? 16 : 5,
              height: 4,
              decoration: BoxDecoration(
                color: _currentHeroIndex == index
                    ? const Color(0xFF0072D2)
                    : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0F1014),
      drawer: _buildAppDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: const Color(0xFF0F1014).withOpacity(0.95),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Row(
            children: [
              const Text(
                'CINEMA ',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0072D2), Color(0xFF00458E)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HQ',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white, size: 26),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: TmdbSearchDelegate(
                    onItemTapped: _onItemTapped,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroSlider(),
                  const SizedBox(height: 12),
                  if (continueWatchingList.isNotEmpty) ...[
                    _buildHeader('Continue Watching'),
                    _buildHorizontalRow(continueWatchingList),
                  ],
                  if (bollywoodLatest.isNotEmpty) ...[
                    _buildHeader('Bollywood Latest Movies'),
                    _buildHorizontalRow(bollywoodLatest),
                  ],
                  if (hollywoodHindiDubbed.isNotEmpty) ...[
                    _buildHeader('Hollywood Movies (Hindi Dubbed)'),
                    _buildHorizontalRow(hollywoodHindiDubbed),
                  ],
                  if (southHindiDubbed.isNotEmpty) ...[
                    _buildHeader('South Indian Movies (Hindi Dubbed)'),
                    _buildHorizontalRow(southHindiDubbed),
                  ],
                  if (hindiWebSeries.isNotEmpty) ...[
                    _buildHeader('Hindi Web Series (Indian Originals)'),
                    _buildHorizontalRow(hindiWebSeries),
                  ],
                  if (netflixSeries.isNotEmpty) ...[
                    _buildHeader('Netflix Specials & Series (Hindi/Eng)'),
                    _buildHorizontalRow(netflixSeries),
                  ],
                  if (amazonSeries.isNotEmpty) ...[
                    _buildHeader('Amazon Prime Originals'),
                    _buildHorizontalRow(amazonSeries),
                  ],
                  const SizedBox(height: 25),
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
      scaffoldBackgroundColor: const Color(0xFF0F1014),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF16181F)),
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
      return const Center(child: Text('Type to search movies & series...', style: TextStyle(color: Colors.white54)));
    }
    return FutureBuilder(
      future: _performSearch(query.trim()),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
        }
        var list = snapshot.data is List ? snapshot.data as List : [];
        if (list.isEmpty) {
          return const Center(child: Text('No results found.', style: TextStyle(color: Colors.white54)));
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(color: Color(0xFF232631)),
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
                  errorBuilder: (_, __, ___) => Container(width: 45, height: 65, color: const Color(0xFF1E2029)),
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
// 6. 100+ TITLES CATALOG (DRAWER CATEGORIES GRID VIEW)
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
  int _currentHeroIndex = 0;
  final PageController _heroPageController = PageController();
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    _fetch100Titles();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroPageController.dispose();
    super.dispose();
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    if (itemsList.isNotEmpty) {
      _heroTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (_heroPageController.hasClients) {
          int count = itemsList.length > 5 ? 5 : itemsList.length;
          int nextPage = (_currentHeroIndex + 1) % count;
          _heroPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Widget _buildHeroSlider() {
    final heroItems = itemsList.take(5).toList();
    if (heroItems.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _heroPageController,
            itemCount: heroItems.length,
            onPageChanged: (index) {
              setState(() => _currentHeroIndex = index);
            },
            itemBuilder: (context, index) {
              final item = heroItems[index];
              return GestureDetector(
                onTap: () => widget.onItemTapped(item),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      item['backdrop'] ?? item['poster'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFF1E2029)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF0F1014).withOpacity(0.4),
                            const Color(0xFF0F1014),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 14,
                      right: 14,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item['title'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                                          const SizedBox(width: 2),
                                          Text(
                                            item['rating'] ?? '7.5',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item['year'] ?? '',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => widget.onItemTapped(item),
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                            label: const Text(
                              'Watch',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0072D2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            heroItems.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentHeroIndex == index ? 16 : 5,
              height: 4,
              decoration: BoxDecoration(
                color: _currentHeroIndex == index
                    ? const Color(0xFF0072D2)
                    : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _fetch100Titles() async {
    final bool isTv = widget.categoryType == 'hindi_series' || widget.categoryType == 'english_series';
    var fetched = [];

    for (int page = 1; page <= 5; page++) {
      String url = '';

      if (widget.categoryType == 'bollywood') {
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
      _startHeroTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16181F),
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : itemsList.isEmpty
              ? const Center(child: Text('Titles load nahi ho sake', style: TextStyle(color: Colors.white60)))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeroSlider(),
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: itemsList.length,
                        itemBuilder: (ctx, idx) {
                          final item = itemsList[idx];
                          return GestureDetector(
                            onTap: () => widget.onItemTapped(item),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    item['poster'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E2029)),
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
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                    ],
                  ),
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
  int episodeCount = 10;
  List availableSeasons = [1, 2, 3];
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
        final seasons = data['seasons'] as List?;
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
      backgroundColor: const Color(0xFF1E2029),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item['title'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
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
                        backgroundColor: isSel ? const Color(0xFF0072D2) : const Color(0xFF282B37),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _onSeasonChanged(s),
                      child: Text('Season $s'),
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
                      side: const BorderSide(color: Color(0xFF3A3F50)),
                      backgroundColor: const Color(0xFF232631),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

// ============================================================================
// 8. XTREAM IPTV & STREMIO STREAM RESOLVER ENGINE
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
      height: MediaQuery.of(context).size.height * 0.5,
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
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF0072D2))))
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
                      color: const Color(0xFF1E2029),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHindi ? const Color(0xFF10B981) : Colors.white10,
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
                              Text(s['server'], style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: Color(0xFF0072D2), size: 28),
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

// ============================================================================
// 9. INTERNAL VIDEO PLAYER (FULL SCREEN CROP + 30s + VOL/BRIGHTNESS + LOCK)
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

  // 0: FIT (16:9), 1: FILL (Stretch), 2: CROP (Zoom / Notch-fill default)
  int _scaleMode = 2;

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

      // Cinema HQ standard initialization: custom headers se IPTV servers block karte hain
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
        child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
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
              child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
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
                color: const Color(0xFF0C111B).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF1E88E5).withOpacity(0.5), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_overlayIcon, color: const Color(0xFF1E88E5), size: 28),
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
                  color: const Color(0xFF0C111B).withOpacity(0.95),
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
                        Border.all(color: const Color(0xFF1E88E5), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_open_rounded,
                          color: Color(0xFF1E88E5), size: 20),
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
                              color: const Color(0xFF161922).withOpacity(0.9),
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
                              color: const Color(0xFF161922).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF1E88E5), width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.aspect_ratio_rounded,
                                    color: Color(0xFF1E88E5), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  scaleNames[_scaleMode],
                                  style: const TextStyle(
                                    color: Color(0xFF1E88E5),
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
                                  const Color(0xFF1E88E5).withOpacity(0.85),
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
                              activeTrackColor: const Color(0xFF1E88E5),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: const Color(0xFF1E88E5),
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

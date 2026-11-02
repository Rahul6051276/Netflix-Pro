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
    DeviceOrientation.portraitDown,
  ]);
  runApp(const NetflixProApp());
}

class NetflixProApp extends StatelessWidget {
  const NetflixProApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netflix Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: const Color(0xFFE50914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          surface: Color(0xFF121212),
        ),
      ),
      home: const NetflixSplashScreen(),
    );
  }
}

// ==================== NETFLIX 'N' INTRO ANIMATION ====================
class NetflixSplashScreen extends StatefulWidget {
  const NetflixSplashScreen({Key? key}) : super(key: key);

  @override
  State<NetflixSplashScreen> createState() => _NetflixSplashScreenState();
}

class _NetflixSplashScreenState extends State<NetflixSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.25).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _animController.forward();

    Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const NetflixMobileMainScreen(),
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
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Text(
                  'N',
                  style: TextStyle(
                    fontSize: 140,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Helvetica Neue',
                    color: const Color(0xFFE50914),
                    shadows: [
                      BoxShadow(
                        color: const Color(0xFFE50914).withOpacity(0.6),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
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

// ==================== MAIN NETFLIX PRO SCREEN ====================
class NetflixMobileMainScreen extends StatefulWidget {
  const NetflixMobileMainScreen({Key? key}) : super(key: key);

  @override
  State<NetflixMobileMainScreen> createState() => _NetflixMobileMainScreenState();
}

class _NetflixMobileMainScreenState extends State<NetflixMobileMainScreen> {
  int _currentTab = 0;
  bool _isLoading = true;
  Map<String, dynamic> _config = {};

  List trendingMovies = [];
  List continueWatching = [];
  List netflixBlockbusters = [];
  List bollywoodHits = [];
  List southSpecials = [];
  List myWatchlist = [];

  final String tmdbApiKey = 'e69ec06ce3bc891f9b3662d558a5e3df';
  final String gistConfigUrl =
      'https://gist.githubusercontent.com/Rahul6051276/5d1dbbe072236fa7c61bf64c9ca4e8df/raw/providers.json';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await _loadWatchlist();
    await _fetchGistConfig();
    await _fetchTMDBData();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('netflix_watchlist');
    if (saved != null) {
      try {
        myWatchlist = jsonDecode(saved);
      } catch (_) {}
    }
  }

  Future<void> _toggleWatchlist(Map movie) async {
    final prefs = await SharedPreferences.getInstance();
    final id = movie['id'];
    final exists = myWatchlist.any((item) => item['id'] == id);

    setState(() {
      if (exists) {
        myWatchlist.removeWhere((item) => item['id'] == id);
      } else {
        myWatchlist.add(movie);
      }
    });

    await prefs.setString('netflix_watchlist', jsonEncode(myWatchlist));
  }

  Future<void> _fetchGistConfig() async {
    try {
      final res = await http.get(Uri.parse(gistConfigUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        _config = jsonDecode(res.body);
      }
    } catch (_) {}
  }

  Future<void> _fetchTMDBData() async {
    try {
      final tRes = await http.get(Uri.parse(
        'https://api.themoviedb.org/3/trending/all/week?api_key=$tmdbApiKey',
      ));
      if (tRes.statusCode == 200) {
        final d = jsonDecode(tRes.body);
        trendingMovies = d['results'] ?? [];
        if (trendingMovies.length > 5) {
          continueWatching = trendingMovies.sublist(1, 5);
        }
      }

      final nRes = await http.get(Uri.parse(
        'https://api.themoviedb.org/3/discover/movie?api_key=$tmdbApiKey&with_networks=213&sort_by=popularity.desc',
      ));
      if (nRes.statusCode == 200) {
        final d = jsonDecode(nRes.body);
        netflixBlockbusters = d['results'] ?? [];
      }

      final bRes = await http.get(Uri.parse(
        'https://api.themoviedb.org/3/discover/movie?api_key=$tmdbApiKey&with_original_language=hi&sort_by=popularity.desc',
      ));
      if (bRes.statusCode == 200) {
        final d = jsonDecode(bRes.body);
        bollywoodHits = d['results'] ?? [];
      }

      final sRes = await http.get(Uri.parse(
        'https://api.themoviedb.org/3/discover/movie?api_key=$tmdbApiKey&with_original_language=te|ta|ml|kn&sort_by=popularity.desc',
      ));
      if (sRes.statusCode == 200) {
        final d = jsonDecode(sRes.body);
        southSpecials = d['results'] ?? [];
      }
    } catch (_) {}
  }

  void _openStreamSheet(Map item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileStreamSheet(
        item: item,
        config: _config,
      ),
    );
  }

  Widget _buildHomeView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      );
    }

    final heroItem = trendingMovies.isNotEmpty ? trendingMovies[0] : null;

    final List allCategories = [
      {
        'title': 'Latest Netflix Blockbusters (Hindi + Glo...',
        'items': netflixBlockbusters.isNotEmpty ? netflixBlockbusters : trendingMovies,
      },
      {
        'title': 'Bollywood Blockbusters',
        'items': bollywoodHits,
      },
      {
        'title': 'South Indian Action Blockbusters',
        'items': southSpecials,
      },
    ];

    return RefreshIndicator(
      color: const Color(0xFFE50914),
      backgroundColor: Colors.black,
      onRefresh: _fetchInitialData,
      child: CustomScrollView(
        slivers: [
          // Header: For Rahul, Download, Search (Chromecast removed)
          SliverAppBar(
            backgroundColor: Colors.black.withOpacity(0.92),
            pinned: true,
            automaticallyImplyLeading: false,
            elevation: 0,
            title: const Text(
              'For Rahul',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 0.2,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_downward, color: Colors.white, size: 22),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 24),
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: MovieSearchDelegate(
                      apiKey: tmdbApiKey,
                      onMovieSelected: _openStreamSheet,
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Row(
                  children: [
                    _categoryPill('TV Shows'),
                    const SizedBox(width: 8),
                    _categoryPill('Movies'),
                    const SizedBox(width: 8),
                    _categoryDropdownPill('Categories'),
                  ],
                ),
              ),
            ),
          ),

          // Billboard Hero Poster Section
          if (heroItem != null)
            SliverToBoxAdapter(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    height: 440,
                    width: double.infinity,
                    foregroundDecoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0x99000000),
                          Color(0xFF000000),
                        ],
                        stops: [0.0, 0.4, 0.75, 1.0],
                      ),
                    ),
                    child: Image.network(
                      'https://image.tmdb.org/t/p/w780${heroItem['poster_path'] ?? heroItem['backdrop_path']}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF181818)),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: Column(
                      children: [
                        Text(
                          heroItem['title'] ?? heroItem['name'] ?? 'Collision Course',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Action • Suspense • Blockbuster • HD',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow, color: Colors.black, size: 24),
                                label: const Text(
                                  'Play',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                onPressed: () => _openStreamSheet(heroItem),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2B2B2B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                icon: Icon(
                                  myWatchlist.any((e) => e['id'] == heroItem['id'])
                                      ? Icons.check
                                      : Icons.add,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                label: const Text(
                                  'My List',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                onPressed: () => _toggleWatchlist(heroItem),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Continue Watching for Rahul
          if (continueWatching.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Continue Watching for Rahul',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'See All →',
                          style: TextStyle(color: Color(0xFFE50914), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 190,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: continueWatching.length + 1,
                      itemBuilder: (context, i) {
                        if (i == continueWatching.length) {
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.grid_view_rounded, color: Color(0xFFE50914), size: 30),
                                SizedBox(height: 8),
                                Text('See All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Explore More', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                          );
                        }

                        final item = continueWatching[i];
                        return GestureDetector(
                          onTap: () => _openStreamSheet(item),
                          child: Container(
                            width: 120,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: const Color(0xFF181818),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    'https://image.tmdb.org/t/p/w342${item['poster_path'] ?? item['backdrop_path']}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1E1E)),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      color: Colors.black87,
                                      child: Text(
                                        item['title'] ?? item['name'] ?? '',
                                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                  ),
                ],
              ),
            ),

          // Categories Rows
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cat = allCategories[index];
                final List items = cat['items'] ?? [];
                if (items.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              cat['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(
                            'See All →',
                            style: TextStyle(color: Color(0xFFE50914), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 165,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final poster = item['poster_path'];
                          return GestureDetector(
                            onTap: () => _openStreamSheet(item),
                            child: Container(
                              width: 110,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: const Color(0xFF181818),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: poster != null
                                    ? Image.network(
                                        'https://image.tmdb.org/t/p/w342$poster',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Center(child: Icon(Icons.movie, color: Colors.white24)),
                                      )
                                    : const Center(child: Icon(Icons.movie, color: Colors.white24)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              childCount: allCategories.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _categoryPill(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white38),
      ),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _categoryDropdownPill(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white38),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
        ],
      ),
    );
  }

  Widget _buildLiveView() {
    final banner = _config['live_sports_banner'] ?? {};
    final List sportsChannels = _config['sports_channels'] ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live Sports & TV Channels'),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (banner['is_live'] == true)
            GestureDetector(
              onTap: () {
                _openStreamSheet({
                  'title': banner['title'] ?? 'Live Match',
                  'keywords': banner['search_keywords'] ?? [],
                  'is_live': true,
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF181818),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      if (banner['backdrop'] != null)
                        Image.network(
                          banner['backdrop'],
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(height: 180, color: Colors.black45),
                        ),
                      Container(
                        height: 180,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xCC000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE NOW',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              banner['title'] ?? 'LIVE SPORTS EVENT',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              banner['subtitle'] ?? '',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Text(
            'Channels',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics),
            itemCount: sportsChannels.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemBuilder: (context, idx) {
              final ch = sportsChannels[idx];
              return InkWell(
                onTap: () {
                  _openStreamSheet({
                    'title': ch['title'] ?? 'Live Channel',
                    'keywords': ch['search_keywords'] ?? [ch['title']],
                    'is_live': true,
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (ch['poster'] != null && ch['poster'].toString().isNotEmpty)
                        Image.network(
                          ch['poster'],
                          height: 48,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.tv, size: 36, color: Colors.white54),
                        )
                      else
                        const Icon(Icons.tv, size: 36, color: Colors.white54),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          ch['title'] ?? '',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildWatchlistView() {
    if (myWatchlist.isEmpty) {
      return const Center(
        child: Text(
          'Your watchlist is empty.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('My List'),
        backgroundColor: Colors.black,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: myWatchlist.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.68,
        ),
        itemBuilder: (context, i) {
          final item = myWatchlist[i];
          final poster = item['poster_path'];
          return GestureDetector(
            onTap: () => _openStreamSheet(item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: poster != null
                  ? Image.network(
                      'https://image.tmdb.org/t/p/w342$poster',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF181818)),
                    )
                  : Container(color: const Color(0xFF181818)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildHomeView(),
          _buildLiveView(),
          _buildWatchlistView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: const Color(0xFFE50914),
        unselectedItemColor: Colors.white54,
        onTap: (index) => setState(() => _currentTab = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.live_tv),
            label: 'Live',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmarks),
            label: 'My List',
          ),
        ],
      ),
    );
  }
}

// ==================== STREAM RESOLVER SHEET ====================
class MobileStreamSheet extends StatefulWidget {
  final Map item;
  final Map config;

  const MobileStreamSheet({
    Key? key,
    required this.item,
    required this.config,
  }) : super(key: key);

  @override
  State<MobileStreamSheet> createState() => _MobileStreamSheetState();
}

class _MobileStreamSheetState extends State<MobileStreamSheet> {
  bool _searching = true;
  List streams = [];

  @override
  void initState() {
    super.initState();
    _fetchDirectStreams();
  }

  Future<void> _fetchDirectStreams() async {
    setState(() => _searching = true);
    final List found = [];
    final activeProviders = widget.config['active_providers'] ?? [];

    if (widget.item['is_live'] == true) {
      final List keywords = widget.item['keywords'] ?? [];
      for (var prov in activeProviders) {
        if (prov['type'] == 'xtream') {
          final host = (prov['host'] ?? '').toString().replaceAll(RegExp(r'/+$'), '');
          final user = prov['username'] ?? '';
          final pass = prov['password'] ?? '';

          try {
            final api = '$host/player_api.php?username=$user&password=$pass&action=get_live_streams';
            final res = await http.get(Uri.parse(api)).timeout(const Duration(seconds: 12));
            if (res.statusCode == 200) {
              final liveList = jsonDecode(res.body);
              for (var ch in (liveList is List ? liveList : [])) {
                final chName = (ch['name'] ?? '').toString().toLowerCase();

                if (chName.contains('plus') || chName.contains('gold') || chName.contains('bharat') || chName.contains('utsav')) {
                  continue;
                }

                bool matches = false;
                for (var kw in keywords) {
                  final cleanKw = kw.toString().toLowerCase();
                  if (cleanKw.isNotEmpty && chName.contains(cleanKw)) {
                    matches = true;
                    break;
                  }
                }

                if (matches) {
                  found.add({
                    'server': prov['name'] ?? 'Xtream Live IPTV',
                    'title': ch['name'] ?? widget.item['title'],
                    'url': '$host/live/$user/$pass/${ch['stream_id']}.m3u8',
                  });
                }
              }
            }
          } catch (_) {}
        }
      }
    } else {
      for (var prov in activeProviders) {
        if (prov['type'] == 'stremio') {
          var manifestUrl = prov['url'] ?? '';
          var baseUrl = manifestUrl.replaceAll('/manifest.json', '');
          var imdbId = widget.item['imdb_id'];

          if (imdbId == null && widget.item['id'] != null) {
            try {
              final tmdbRes = await http.get(Uri.parse(
                'https://api.themoviedb.org/3/movie/${widget.item['id']}/external_ids?api_key=e69ec06ce3bc891f9b3662d558a5e3df',
              )).timeout(const Duration(seconds: 4));
              if (tmdbRes.statusCode == 200) {
                final ids = jsonDecode(tmdbRes.body);
                imdbId = ids['imdb_id'];
              }
            } catch (_) {}
          }

          if (imdbId != null && imdbId.toString().startsWith('tt')) {
            try {
              final streamUrl = '$baseUrl/stream/movie/$imdbId.json';
              final res = await http.get(Uri.parse(streamUrl)).timeout(const Duration(seconds: 8));
              if (res.statusCode == 200) {
                final data = jsonDecode(res.body);
                for (var s in (data['streams'] is List ? data['streams'] : [])) {
                  found.add({
                    'server': prov['name'] ?? 'HD Streams',
                    'title': s['title'] ?? s['name'] ?? widget.item['title'],
                    'url': s['url'] ?? (s['infoHash'] != null ? 'magnet:?xt=urn:btih:${s['infoHash']}' : ''),
                  });
                }
              }
            } catch (_) {}
          }
        } else if (prov['type'] == 'xtream') {
          final host = (prov['host'] ?? '').toString().replaceAll(RegExp(r'/+$'), '');
          final user = prov['username'] ?? '';
          final pass = prov['password'] ?? '';

          try {
            final searchApi = '$host/player_api.php?username=$user&password=$pass&action=get_vod_streams';
            final xtreamRes = await http.get(Uri.parse(searchApi)).timeout(const Duration(seconds: 15));
            if (xtreamRes.statusCode == 200) {
              final vodList = jsonDecode(xtreamRes.body);
              final queryTitle = (widget.item['title'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

              for (var movie in (vodList is List ? vodList : [])) {
                final movieName = (movie['name'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                if (queryTitle.isNotEmpty && movieName.contains(queryTitle)) {
                  final ext = movie['container_extension'] ?? 'mp4';
                  found.add({
                    'server': prov['name'] ?? 'Xtream VOD Server',
                    'title': movie['name'] ?? widget.item['title'],
                    'url': '$host/movie/$user/$pass/${movie['stream_id']}.$ext',
                  });
                }
              }
            }
          } catch (_) {}
        }
      }
    }

    if (mounted) {
      setState(() {
        streams = found;
        _searching = false;
      });
    }
  }

  void _playInternal(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InternalPlayerScreen(
          streamUrl: url,
          title: title,
        ),
      ),
    );
  }

  Future<void> _playExternalVlc(String streamUrl) async {
    try {
      final intent = AndroidIntent(
        action: 'action_view',
        data: streamUrl,
        type: 'video/*',
        package: 'org.videolan.vlc',
      );
      await intent.launch();
    } catch (_) {
      try {
        final genericIntent = AndroidIntent(
          action: 'action_view',
          data: streamUrl,
          type: 'video/*',
        );
        await genericIntent.launch();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot launch video player: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.item['title'] ?? widget.item['name'] ?? 'Select Stream',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_searching)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: Color(0xFFE50914)),
              ),
            )
          else if (streams.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No active streams found on server.',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: streams.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                itemBuilder: (context, idx) {
                  final s = streams[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      s['title'] ?? 'Stream Source',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 2,
                    ),
                    subtitle: Text(
                      s['server'] ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text('Play'),
                          onPressed: () => _playInternal(s['url'], s['title']),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text('VLC'),
                          onPressed: () => _playExternalVlc(s['url']),
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

// ==================== SEARCH DELEGATE ====================
class MovieSearchDelegate extends SearchDelegate {
  final String apiKey;
  final Function(Map) onMovieSelected;

  MovieSearchDelegate({required this.apiKey, required this.onMovieSelected});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF000000),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121212)),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _search();

  @override
  Widget buildSuggestions(BuildContext context) => _search();

  Widget _search() {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Type a movie or show name...', style: TextStyle(color: Colors.white54)));
    }

    return FutureBuilder<http.Response>(
      future: http.get(Uri.parse('https://api.themoviedb.org/3/search/multi?api_key=$apiKey&query=$query')),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
        }

        final data = jsonDecode(snapshot.data!.body);
        final List list = data['results'] ?? [];

        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final movie = list[i];
            return ListTile(
              leading: movie['poster_path'] != null
                  ? Image.network(
                      'https://image.tmdb.org/t/p/w92${movie['poster_path']}',
                      width: 40,
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.movie),
              title: Text(movie['title'] ?? movie['name'] ?? ''),
              subtitle: Text(movie['release_date'] ?? movie['first_air_date'] ?? ''),
              onTap: () {
                close(context, null);
                onMovieSelected(movie);
              },
            );
          },
        );
      },
    );
  }
}

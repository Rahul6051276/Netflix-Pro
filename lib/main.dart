import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'internal_player.dart'; // Yahan alag file se player screen import ki gayi hai

// ============================================================================
// 1. APP CONFIGURATION & CONSTANTS
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
  final lower = title.toLowerCase();
  final blockedKeywords = [
    'anupamaa',
    'yeh rishta',
    'taarak mehta',
    'kumkum bhagya',
    'kundali bhagya',
    'ghum hai kisikey',
    'imlie',
    'bhagya lakshmi',
    'radha mohan',
    'parineetii',
    'udaariyaan',
  ];
  return blockedKeywords.any((kw) => lower.contains(kw));
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const NetflixProApp());
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
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141414),
          elevation: 0,
        ),
      ),
      home: const NetflixHomeScreen(),
    );
  }
}

// ============================================================================
// 2. MAIN NETFLIX HOME SCREEN
// ============================================================================

class NetflixHomeScreen extends StatefulWidget {
  const NetflixHomeScreen({super.key});

  @override
  State<NetflixHomeScreen> createState() => _NetflixHomeScreenState();
}

class _NetflixHomeScreenState extends State<NetflixHomeScreen> {
  List providers = [];
  bool isLoading = true;

  var heroItems = [];
  int currentHeroIndex = 0;
  final PageController _heroController = PageController();
  Timer? _heroTimer;

  var onlyOnNetflix = [];
  var trendingBollywood = [];
  var popularHindiSeries = [];
  var hollywoodHits = [];
  var southSpecial = [];

  @override
  void initState() {
    super.initState();
    _loadAllContent();
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
          int count = heroItems.length;
          int nextPage = (currentHeroIndex + 1) % count;
          _heroController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _loadAllContent() async {
    await _fetchProviders();
    await Future.wait([
      _fetchHeroTitles(),
      _fetchRowCategory('only_netflix', (list) => onlyOnNetflix = list),
      _fetchRowCategory('bollywood', (list) => trendingBollywood = list),
      _fetchRowCategory('hindi_series', (list) => popularHindiSeries = list),
      _fetchRowCategory('hollywood', (list) => hollywoodHits = list),
      _fetchRowCategory('south', (list) => southSpecial = list),
    ]);

    if (mounted) {
      setState(() => isLoading = false);
      _startHeroTimer();
    }
  }

  Future<void> _fetchProviders() async {
    try {
      final res = await http.get(Uri.parse(AppConfig.gistUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        providers = data['active_providers'] ?? [];
      }
    } catch (_) {}
  }

  Future<void> _fetchHeroTitles() async {
    try {
      final url =
          '${AppConfig.tmdbBase}/trending/all/week?api_key=${AppConfig.tmdbKey}';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        var list = [];
        for (var m in results.take(6)) {
          if (m['backdrop_path'] == null && m['poster_path'] == null) continue;
          list.add({
            'tmdb_id': m['id'],
            'title': m['title'] ?? m['name'] ?? 'Netflix Original',
            'year': (m['release_date'] ?? m['first_air_date'] ?? '')
                .toString()
                .split('-')[0],
            'rating': m['vote_average']?.toString() ?? '8.2',
            'poster': m['poster_path'] != null
                ? '${AppConfig.imgBase}${m['poster_path']}'
                : '${AppConfig.backdropBase}${m['backdrop_path']}',
            'backdrop': m['backdrop_path'] != null
                ? '${AppConfig.backdropBase}${m['backdrop_path']}'
                : '${AppConfig.imgBase}${m['poster_path']}',
            'isTv': m['media_type'] == 'tv',
          });
        }
        heroItems = list;
      }
    } catch (_) {}
  }

  Future<void> _fetchRowCategory(String cat, Function(List) onDone) async {
    String url = '';
    bool isTv = false;

    if (cat == 'only_netflix') {
      url =
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_networks=213&sort_by=popularity.desc';
      isTv = true;
    } else if (cat == 'bollywood') {
      url =
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=hi&sort_by=primary_release_date.desc&vote_count.gte=10';
    } else if (cat == 'hindi_series') {
      url =
          '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=first_air_date.desc&vote_count.gte=10';
      isTv = true;
    } else if (cat == 'hollywood') {
      url =
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=en&sort_by=popularity.desc';
    } else if (cat == 'south') {
      url =
          '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn&sort_by=popularity.desc&vote_count.gte=20';
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
            'year': (m['release_date'] ?? m['first_air_date'] ?? '')
                .toString()
                .split('-')[0],
            'rating': m['vote_average']?.toString() ?? '7.5',
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

  void _handleItemClick(dynamic item) {
    if (item['isTv'] == true) {
      showDialog(
        context: context,
        builder: (ctx) => MobileEpisodeSelectorDialog(
          item: item,
          onSelected: (season, ep) {
            ServerLauncherHelper.showServerSelector(
              context: context,
              item: item,
              providers: providers,
              season: season,
              episode: ep,
            );
          },
        ),
      );
    } else {
      ServerLauncherHelper.showServerSelector(
        context: context,
        item: item,
        providers: providers,
      );
    }
  }

  void _openCatalog(String title, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MobileCatalogGridView(
          title: title,
          categoryType: type,
          providers: providers,
          onItemTapped: _handleItemClick,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildNetflixDrawer(),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            )
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(child: _buildNetflixHeroBillboard()),
                SliverToBoxAdapter(
                  child: _buildNetflixRow('Only on Netflix', onlyOnNetflix),
                ),
                SliverToBoxAdapter(
                  child: _buildNetflixRow(
                      'Trending Bollywood', trendingBollywood),
                ),
                SliverToBoxAdapter(
                  child: _buildNetflixRow(
                      'Popular Hindi Series', popularHindiSeries),
                ),
                SliverToBoxAdapter(
                  child: _buildNetflixRow('Hollywood Hits', hollywoodHits),
                ),
                SliverToBoxAdapter(
                  child: _buildNetflixRow(
                      'South Action Blockbusters', southSpecial),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: const Color(0xFF141414).withOpacity(0.95),
      title: Row(
        children: [
          const Text(
            'NETFLIX',
            style: TextStyle(
              color: Color(0xFFE50914),
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: 2.0,
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
                fontSize: 10,
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
              delegate: TmdbSearchDelegate(onItemTapped: _handleItemClick),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.account_box, color: Colors.white, size: 28),
          onPressed: () {},
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
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                          '${item['year']} • ${item['isTv'] ? "Series" : "Movie"} • ⭐ ${item['rating']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add,
                                      color: Colors.white, size: 26),
                                  onPressed: () {},
                                ),
                                const Text('My List',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(width: 24),
                            ElevatedButton.icon(
                              onPressed: () => _handleItemClick(item),
                              icon: const Icon(Icons.play_arrow,
                                  color: Colors.black, size: 28),
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
                                    horizontal: 24, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.info_outline,
                                      color: Colors.white, size: 26),
                                  onPressed: () => _handleItemClick(item),
                                ),
                                const Text('Info',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ],
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
                onTap: () => _handleItemClick(item),
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

  Widget _buildNetflixDrawer() {
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
                const SizedBox(height: 4),
                Text(
                  'Active Providers: ${providers.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          _drawerTile('Bollywood Movies', Icons.movie_filter,
              () => _openCatalog('Bollywood Movies', 'bollywood')),
          _drawerTile('Hindi Web Series', Icons.tv,
              () => _openCatalog('Hindi Series', 'hindi_series')),
          _drawerTile('South Blockbusters', Icons.local_fire_department,
              () => _openCatalog('South Movies', 'south')),
          _drawerTile('Hollywood Movies', Icons.movie,
              () => _openCatalog('Hollywood Movies', 'hollywood_movies')),
          _drawerTile('English Web Series', Icons.live_tv,
              () => _openCatalog('English Series', 'english_series')),
        ],
      ),
    );
  }

  Widget _drawerTile(String t, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(t, style: const TextStyle(color: Colors.white, fontSize: 14)),
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
// 3. TMDB LIVE SEARCH ENGINE
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
        child: Text('Type to search movies & series...',
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
            'year': (m['release_date'] ?? m['first_air_date'] ?? '')
                .toString()
                .split('-')[0],
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
// 4. 100+ TITLES CATALOG (DRAWER CATEGORIES GRID VIEW)
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
            '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=hi&sort_by=primary_release_date.desc&vote_count.gte=10&page=$page';
      } else if (widget.categoryType == 'south') {
        url =
            '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn&sort_by=primary_release_date.desc&vote_count.gte=15&page=$page';
      } else if (widget.categoryType == 'hollywood_movies') {
        url =
            '${AppConfig.tmdbBase}/discover/movie?api_key=${AppConfig.tmdbKey}&with_original_language=en&sort_by=primary_release_date.desc&vote_count.gte=50&page=$page';
      } else if (widget.categoryType == 'hindi_series') {
        url =
            '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=first_air_date.desc&vote_count.gte=10&page=$page';
      } else if (widget.categoryType == 'english_series') {
        url =
            '${AppConfig.tmdbBase}/discover/tv?api_key=${AppConfig.tmdbKey}&with_original_language=en&sort_by=first_air_date.desc&vote_count.gte=40&page=$page';
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
              'year': (m['release_date'] ??
                      m['first_air_date'] ??
                      DateTime.now().year.toString())
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
        title: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : itemsList.isEmpty
              ? const Center(
                  child: Text('Titles load nahi ho sake',
                      style: TextStyle(color: Colors.white60)))
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
// 5. WEB SERIES SEASON & EPISODE SELECTOR POPUP (NETFLIX STYLE)
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
// 6. SERVER SELECTOR (DUAL BUTTON: INTERNAL PLAYER + EXTERNAL INTENT)
// ============================================================================

class ServerLauncherHelper {
  static Future<void> launchExternalIntent({
    required BuildContext context,
    required String streamUrl,
    required String title,
  }) async {
    try {
      final intent = AndroidIntent(
        action: 'action_view',
        data: streamUrl,
        type: 'video/*',
        arguments: <String, dynamic>{
          'title': title,
        },
      );
      await intent.launch();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('External video player launch nahi hua: $e'),
          backgroundColor: const Color(0xFFE50914),
        ),
      );
    }
  }

  static void launchInternalPlayer({
    required BuildContext context,
    required String streamUrl,
    required String title,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InternalPlayerScreen(
          streamUrl: streamUrl,
          title: title,
        ),
      ),
    );
  }

  static void showServerSelector({
    required BuildContext context,
    required dynamic item,
    required List providers,
    int season = 1,
    int episode = 1,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final tmdbId = item['tmdb_id'].toString();
        final isTv = item['isTv'] == true;
        final title = item['title'] ?? 'Playing Video';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      item['poster'] ?? '',
                      width: 48,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(width: 48, height: 68, color: Colors.white10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isTv
                              ? 'Season $season • Episode $episode'
                              : '${item['year']} • Movie',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Select Streaming Server',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              if (providers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No active providers found.',
                        style: TextStyle(color: Colors.white54)),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: providers.length,
                  itemBuilder: (context, idx) {
                    final p = providers[idx];
                    final pName = p['name'] ?? 'Server ${idx + 1}';
                    String urlTemplate = p['url_template'] ?? '';

                    String finalUrl = urlTemplate
                        .replaceAll('{id}', tmdbId)
                        .replaceAll('{s}', season.toString())
                        .replaceAll('{e}', episode.toString())
                        .trim();

                    final streamTitle =
                        isTv ? '$title - S$season:E$episode' : title;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262626),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Provider: ${p['name'] ?? 'Custom'}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Blue Play Button -> In-App Internal Player (internal_player.dart)
                          IconButton(
                            icon: const Icon(Icons.play_circle_fill,
                                color: Color(0xFF1E88E5), size: 34),
                            onPressed: () {
                              Navigator.pop(ctx);
                              launchInternalPlayer(
                                context: context,
                                streamUrl: finalUrl,
                                title: streamTitle,
                              );
                            },
                          ),
                          // Yellow Intent Button -> External Player
                          IconButton(
                            icon: const Icon(Icons.open_in_new,
                                color: Colors.amber, size: 24),
                            onPressed: () {
                              Navigator.pop(ctx);
                              launchExternalIntent(
                                context: context,
                                streamUrl: finalUrl,
                                title: streamTitle,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

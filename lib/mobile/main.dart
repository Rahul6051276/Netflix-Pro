import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// CONFIGURATION & TMDB KEYS
// ============================================================================
class MobileConfig {
  static const String tmdbBase = 'https://api.themoviedb.org/3';
  static const String tmdbKey = 'f8983e20e36098ffb4e87ff0ac64ebf9';
  static const String imgBase = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBase = 'https://image.tmdb.org/t/p/original';
}

// ============================================================================
// SOAP & DAILY SERIAL FILTER LOGIC
// ============================================================================
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

// ============================================================================
// MAIN ENTRY & APP THEME
// ============================================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NetflixMobileApp());
}

class NetflixMobileApp extends StatelessWidget {
  const NetflixMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netflix Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          surface: Color(0xFF141414),
        ),
      ),
      home: const MobileHomeScreen(),
    );
  }
}

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int _currentBottomNavIndex = 0;
  List<dynamic> activeProviders = [];
  List<dynamic> continueWatchingList = [];
  Map<String, dynamic>? activeBillboardItem;

  // 5 CORE OTT CATEGORY LISTS (HINDI + ENGLISH)
  List<dynamic> homeNetflixList = [];
  List<dynamic> homePrimeList = [];
  List<dynamic> homeHotstarList = [];
  List<dynamic> homeSonyLivList = [];
  List<dynamic> homeZee5List = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllMobileData();
  }

  Future<void> _loadAllMobileData() async {
    setState(() => isLoading = true);
    await Future.wait([
      _fetchProviders(),
      _loadContinueWatching(),
      _fetchCatalogs(),
    ]);
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchProviders() async {
    try {
      final res = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/watch/providers/movie?api_key=${MobileConfig.tmdbKey}&watch_region=IN')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        activeProviders = data['results'] ?? [];
      }
    } catch (_) {}
  }

  Future<void> _loadContinueWatching() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('continue_watching_mobile');
      if (raw != null && raw.isNotEmpty && mounted) {
        setState(() {
          continueWatchingList = List<dynamic>.from(jsonDecode(raw));
        });
      }
    } catch (_) {}
  }

  // ============================================================================
  // PARSER METHOD
  // ============================================================================
  List<dynamic> _parseCatalog(dynamic list, {bool isTv = false}) {
    if (list == null) return [];
    var res = [];
    final currentYear = DateTime.now().year.toString();
    for (var m in list) {
      if (m['backdrop_path'] == null && m['poster_path'] == null) continue;
      final t = (m['title'] ?? m['name'] ?? 'Untitled').toString();

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

  // ============================================================================
  // 5 CORE OTT CATALOG DATA FETCH (HINDI + ENGLISH)
  // ============================================================================
  Future<void> _fetchCatalogs() async {
    // 1. Netflix Blockbusters (Hindi + English)
    try {
      final res = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=hi|en&with_watch_providers=8&watch_region=IN&sort_by=popularity.desc')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        homeNetflixList = _parseCatalog(jsonDecode(res.body)['results']);
      }
    } catch (_) {}

    // 2. Amazon Prime Video Hits (Hindi + English)
    try {
      final res = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=hi|en&with_watch_providers=119&watch_region=IN&sort_by=popularity.desc')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        homePrimeList = _parseCatalog(jsonDecode(res.body)['results']);
      }
    } catch (_) {}

    // 3. Disney+ Hotstar Specials (Hindi + English)
    try {
      final res = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=hi|en&with_watch_providers=122&watch_region=IN&sort_by=popularity.desc')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        homeHotstarList = _parseCatalog(jsonDecode(res.body)['results']);
      }
    } catch (_) {}

    // 4. SonyLIV Originals & Series (Hindi + English OTT Series)
    try {
      final res = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_original_language=hi|en&with_watch_providers=237&watch_region=IN&without_genres=10766&vote_count.gte=1&sort_by=popularity.desc')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        homeSonyLivList = _parseCatalog(jsonDecode(res.body)['results'], isTv: true)
            .where((item) => !isSoapShow(item['title'] ?? ''))
            .toList();
      }
    } catch (_) {}

    // 5. ZEE5 Premium Specials (Hindi + English OTT Series)
    try {
      final res = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_original_language=hi|en&with_watch_providers=232&watch_region=IN&without_genres=10766&vote_count.gte=1&sort_by=popularity.desc')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        homeZee5List = _parseCatalog(jsonDecode(res.body)['results'], isTv: true)
            .where((item) => !isSoapShow(item['title'] ?? ''))
            .toList();
      }
    } catch (_) {}

    // Set Welcome Billboard
    if (homeNetflixList.isNotEmpty) {
      activeBillboardItem = homeNetflixList.first;
    } else if (homePrimeList.isNotEmpty) {
      activeBillboardItem = homePrimeList.first;
    } else if (homeHotstarList.isNotEmpty) {
      activeBillboardItem = homeHotstarList.first;
    }

    if (mounted) setState(() {});
  }

  // ============================================================================
  // UI WIDGET BUILDERS
  // ============================================================================
  Widget _buildBillboard(Map<String, dynamic> item) {
    return Stack(
      children: [
        Container(
          height: 440,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(item['poster'] ?? item['backdrop'] ?? ''),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          height: 440,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black45,
                Color(0xFF141414),
              ],
              stops: [0.3, 0.7, 1.0],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  item['title'] ?? '',
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
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow, size: 24),
                    label: const Text('Play', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () {},
                    icon: const Icon(Icons.info_outline, size: 22),
                    label: const Text('Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMovieRow(String title, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 165,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final movie = items[index];
                return Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.grey[900],
                    image: DecorationImage(
                      image: NetworkImage(movie['poster'] ?? movie['backdrop'] ?? ''),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // MAIN SCAFFOLD & BOTTOM NAV
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (activeBillboardItem != null) _buildBillboard(activeBillboardItem!),
                  if (continueWatchingList.isNotEmpty)
                    _buildMovieRow('Continue Watching for You', continueWatchingList),
                  if (homeNetflixList.isNotEmpty)
                    _buildMovieRow('Latest Netflix Blockbusters', homeNetflixList),
                  if (homePrimeList.isNotEmpty)
                    _buildMovieRow('Amazon Prime Video Hits', homePrimeList),
                  if (homeHotstarList.isNotEmpty)
                    _buildMovieRow('Disney+ Hotstar Specials', homeHotstarList),
                  if (homeSonyLivList.isNotEmpty)
                    _buildMovieRow('SonyLIV Originals & Series', homeSonyLivList),
                  if (homeZee5List.isNotEmpty)
                    _buildMovieRow('ZEE5 Premium Specials', homeZee5List),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentBottomNavIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categories'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'My Netflix'),
        ],
      ),
    );
  }
}

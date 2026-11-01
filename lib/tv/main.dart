import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

// TV ka SSL Certificate bypass karne ke liye
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
  runApp(const NetflixProTVApp());
}

// ============================================================================
// CONFIGURATION & API KEYS
// ============================================================================
class TVConfig {
  static const String gistUrl =
      'https://gist.githubusercontent.com/Rahul6051276/f5240bc75ad4aa0499d21799a9cf5c66/raw/netflix_providers.json';
  static const String tmdbKey = '81a303644f1e5828271032db9a35e4d5';
  static const String tmdbBase = 'https://api.themoviedb.org/3';
  static const String imgBase = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBase = 'https://image.tmdb.org/t/p/original';

  static const List<String> stremioAddons = [
    'https://v3-cinemeta.strem.io',
    'https://torrentio.strem.fun',
  ];
}

class NetflixProTVApp extends StatelessWidget {
  const NetflixProTVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netflix Pro TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        fontFamily: 'Helvetica',
      ),
      home: const TVSplashScreen(),
    );
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================
class MediaItem {
  final dynamic tmdbId;
  final String title;
  final String year;
  final String rating;
  final String backdrop;
  final String poster;
  final String overview;
  final bool isTv;
  final String endpoint;
  dynamic xtreamStreamId;

  MediaItem({
    required this.tmdbId,
    required this.title,
    required this.year,
    required this.rating,
    required this.backdrop,
    required this.poster,
    required this.overview,
    required this.isTv,
    required this.endpoint,
    this.xtreamStreamId,
  });

  factory MediaItem.fromTmdb(Map<String, dynamic> json, {bool isTv = false, String endpoint = ''}) {
    String parsedYear = '2026';
    final dateStr = (json['release_date'] ?? json['first_air_date'])?.toString();
    if (dateStr != null && dateStr.contains('-')) {
      parsedYear = dateStr.split('-')[0];
    }

    String ratingStr = '7.5';
    if (json['vote_average'] != null) {
      final num? val = json['vote_average'] is num
          ? json['vote_average']
          : num.tryParse(json['vote_average'].toString());
      if (val != null) {
        ratingStr = val.toStringAsFixed(1);
      }
    }

    final backdropPath = json['backdrop_path']?.toString();
    final posterPath = json['poster_path']?.toString();

    return MediaItem(
      tmdbId: json['id'] ?? 0,
      title: (json['title'] ?? json['name'] ?? 'Untitled').toString(),
      year: parsedYear,
      rating: ratingStr,
      backdrop: backdropPath != null
          ? '${TVConfig.backdropBase}$backdropPath'
          : (posterPath != null ? '${TVConfig.imgBase}$posterPath' : ''),
      poster: posterPath != null
          ? '${TVConfig.imgBase}$posterPath'
          : (backdropPath != null ? '${TVConfig.backdropBase}$backdropPath' : ''),
      overview: (json['overview'] ?? 'No description available for this title.').toString(),
      isTv: isTv,
      endpoint: endpoint,
    );
  }
}

class XtreamServerInfo {
  final String serverUrl;
  final String username;
  final String password;

  XtreamServerInfo({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  factory XtreamServerInfo.fromJson(Map<String, dynamic> json) {
    var s = (json['server'] ?? json['url'] ?? '').toString().trim();
    if (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return XtreamServerInfo(
      serverUrl: s,
      username: (json['username'] ?? json['user'] ?? '').toString().trim(),
      password: (json['password'] ?? json['pass'] ?? '').toString().trim(),
    );
  }

  String buildVodStreamUrl(dynamic streamId) {
    return '$serverUrl/movie/$username/$password/$streamId.mp4';
  }

  String buildSeriesStreamUrl(dynamic streamId, int season, int episode) {
    return '$serverUrl/series/$username/$password/$streamId/$season/$episode.mp4';
  }
}

// ============================================================================
// XTREAM STREAM ENGINE
// ============================================================================
class XtreamStremioEngine {
  static List<XtreamServerInfo> servers = [];
  static bool isInitialized = false;

  static Future<void> initEngine() async {
    if (isInitialized) return;
    try {
      final res = await http.get(Uri.parse(TVConfig.gistUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        servers.clear();

        List<dynamic> list = [];
        if (decoded is Map<String, dynamic> && decoded.containsKey('active_providers')) {
          list = decoded['active_providers'] as List<dynamic>;
        } else if (decoded is List) {
          list = decoded;
        }

        for (var item in list) {
          if (item is Map<String, dynamic>) {
            final s = XtreamServerInfo.fromJson(item);
            if (s.serverUrl.isNotEmpty && s.username.isNotEmpty) {
              servers.add(s);
            }
          }
        }
        isInitialized = true;
      }
    } catch (_) {}
  }

  static Future<String?> resolveStreamUrl(MediaItem item, {int season = 1, int episode = 1}) async {
    if (servers.isEmpty) await initEngine();
    if (servers.isEmpty) return null;

    final primaryServer = servers.first;
    final id = item.xtreamStreamId ?? item.tmdbId;

    if (item.isTv) {
      return primaryServer.buildSeriesStreamUrl(id, season, episode);
    } else {
      return primaryServer.buildVodStreamUrl(id);
    }
  }
}

// ============================================================================
// 1. SPLASH SCREEN
// ============================================================================
class TVSplashScreen extends StatefulWidget {
  const TVSplashScreen({super.key});

  @override
  State<TVSplashScreen> createState() => _TVSplashScreenState();
}

class _TVSplashScreenState extends State<TVSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeIn),
      ),
    );

    _animController.forward();

    Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const TVHomeScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 110,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE50914).withOpacity(0.55),
                            blurRadius: 45,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'N',
                          style: TextStyle(
                            color: Color(0xFFE50914),
                            fontSize: 130,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'NETFLIX PRO',
                      style: TextStyle(
                        color: Colors.white,
                        letterSpacing: 8,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
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
// 2. MAIN TV HOME SCREEN (6 TOP HINDI OTT HUBS)
// ============================================================================
class TVHomeScreen extends StatefulWidget {
  const TVHomeScreen({super.key});

  @override
  State<TVHomeScreen> createState() => _TVHomeScreenState();
}

class _TVHomeScreenState extends State<TVHomeScreen> {
  int _selectedSidebarIndex = 1;
  MediaItem? activeBillboardItem;

  List<MediaItem> netflixHubList = [];
  List<MediaItem> primeHubList = [];
  List<MediaItem> hotstarHubList = [];
  List<MediaItem> sonyLivHubList = [];
  List<MediaItem> zee5HubList = [];
  List<MediaItem> bollywoodHubList = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialContent();
  }

  Future<void> _loadInitialContent() async {
    try {
      final quickResults = await Future.wait([
        _fetchCategory('/discover/movie?with_watch_providers=8&watch_region=IN&with_original_language=hi&sort_by=popularity.desc'),
        _fetchCategory('/discover/movie?with_watch_providers=119&watch_region=IN&with_original_language=hi&sort_by=popularity.desc'),
      ]);

      if (mounted) {
        setState(() {
          netflixHubList = quickResults[0];
          primeHubList = quickResults[1];

          if (netflixHubList.isNotEmpty) {
            activeBillboardItem = netflixHubList.first;
          }
          isLoading = false;
        });
      }

      _fetchRemainingHubs();
      XtreamStremioEngine.initEngine();
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchRemainingHubs() async {
    try {
      final hotstar = await _fetchCategory('/discover/movie?with_watch_providers=122&watch_region=IN&sort_by=popularity.desc');
      final sony = await _fetchCategory('/discover/tv?with_watch_providers=237&watch_region=IN&with_original_language=hi&sort_by=popularity.desc', isTv: true);
      final zee = await _fetchCategory('/discover/movie?with_watch_providers=232&watch_region=IN&with_original_language=hi&sort_by=popularity.desc');
      final bolly = await _fetchCategory('/discover/movie?with_original_language=hi&sort_by=primary_release_date.desc&vote_count.gte=10');

      if (mounted) {
        setState(() {
          hotstarHubList = hotstar;
          sonyLivHubList = sony;
          zee5HubList = zee;
          bollywoodHubList = bolly;
        });
      }
    } catch (_) {}
  }

  Future<List<MediaItem>> _fetchCategory(String endpoint, {bool isTv = false}) async {
    try {
      final sep = endpoint.contains('?') ? '&' : '?';
      final url = '${TVConfig.tmdbBase}$endpoint${sep}api_key=${TVConfig.tmdbKey}&page=1';
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Android TV; Mobile)',
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List<dynamic>? ?? [];
        return results
            .where((m) => m['backdrop_path'] != null || m['poster_path'] != null)
            .map((m) => MediaItem.fromTmdb(m, isTv: isTv, endpoint: endpoint))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _playMedia(MediaItem item) async {
    final streamUrl = await XtreamStremioEngine.resolveStreamUrl(item);

    if (streamUrl == null || streamUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stream link resolving failed.')),
      );
      return;
    }

    try {
      final intent = AndroidIntent(
        action: 'action_view',
        data: streamUrl,
        type: 'video/*',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Launch intent failed: $streamUrl')),
      );
    }
  }

  void _openFullGridView(String categoryTitle, List<MediaItem> initialItems, String endpoint, bool isTv) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TVCategoryGridScreen(
          title: categoryTitle,
          initialItems: initialItems,
          endpoint: endpoint,
          isTv: isTv,
        ),
      ),
    );
  }

  Widget _buildTVBillboard() {
    final item = activeBillboardItem;
    if (item == null) return const SizedBox.shrink();

    return Stack(
      children: [
        SizedBox(
          height: 380,
          width: double.infinity,
          child: Image.network(
            item.backdrop,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1B1B1B)),
          ),
        ),
        Container(
          height: 380,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Color(0x33141414),
                Color(0xCC141414),
                Color(0xFF141414),
              ],
            ),
          ),
        ),
        Container(
          height: 380,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF141414),
                Color(0xB3141414),
                Colors.transparent,
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Positioned(
          top: 65,
          left: 45,
          width: 580,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('N', style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold, fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    item.isTv ? 'S E R I E S' : 'H I N D I   B L O C K B U S T E R',
                    style: const TextStyle(color: Colors.white70, letterSpacing: 4, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${item.rating} ★ Match', style: const TextStyle(color: Color(0xFF46D369), fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 14),
                  Text(item.year, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(3)),
                    child: const Text('Ultra HD 4K', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(border: Border.all(color: Colors.white30), borderRadius: BorderRadius.circular(3)),
                    child: const Text('Hindi Audio', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.overview,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Focus(
                child: Builder(
                  builder: (context) {
                    final isFocused = Focus.of(context).hasFocus;
                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        side: isFocused ? const BorderSide(color: Color(0xFFE50914), width: 3) : BorderSide.none,
                      ),
                      icon: const Icon(Icons.play_arrow, size: 26),
                      label: const Text('Play Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      onPressed: () => _playMedia(item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTVRow(String title, List<MediaItem> items, String endpoint, bool isTv) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: const [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE50914)),
                  ),
                  SizedBox(width: 14),
                  Text(
                    'Connecting to TMDb Catalog...',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Text(
                'Explore 200+ Titles →',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            itemCount: items.length + 1,
            itemBuilder: (ctx, idx) {
              if (idx == items.length) {
                return Container(
                  width: 190,
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Focus(
                    child: Builder(
                      builder: (context) {
                        final isFocused = Focus.of(context).hasFocus;
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _openFullGridView(title, items, endpoint, isTv),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222222),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isFocused ? Colors.white : Colors.white24,
                                width: isFocused ? 3.0 : 1.0,
                              ),
                              boxShadow: isFocused
                                  ? [BoxShadow(color: Colors.white.withOpacity(0.55), blurRadius: 10, spreadRadius: 2)]
                                  : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.grid_view_rounded, color: Color(0xFFE50914), size: 34),
                                const SizedBox(height: 6),
                                const Text('See All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                const Text('(200+ Titles)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }

              final item = items[idx];
              return Container(
                width: 230,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Focus(
                  onFocusChange: (focused) {
                    if (focused && mounted) {
                      setState(() => activeBillboardItem = item);
                    }
                  },
                  child: Builder(
                    builder: (context) {
                      final isFocused = Focus.of(context).hasFocus;
                      return InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _playMedia(item),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isFocused ? Colors.white : Colors.transparent,
                              width: isFocused ? 3.0 : 0.0,
                            ),
                            boxShadow: isFocused
                                ? [BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)]
                                : [],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                item.backdrop,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [Colors.black87, Colors.transparent],
                                    ),
                                  ),
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
            },
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildTVSidebar() {
    return Container(
      width: 58,
      color: Colors.transparent,
      child: Column(
        children: [
          const SizedBox(height: 24),
          _sidebarItem(0, Icons.search, 'Search', onTap: () {}),
          const SizedBox(height: 20),
          _sidebarItem(1, Icons.home_filled, 'Home'),
          _sidebarItem(2, Icons.tv, 'Hotstar & SonyLIV', onTap: () {
            _openFullGridView('Hotstar & SonyLIV Hindi Hub', hotstarHubList, '/discover/movie?with_watch_providers=122&watch_region=IN', false);
          }),
          _sidebarItem(3, Icons.movie_creation_outlined, 'Netflix & Prime', onTap: () {
            _openFullGridView('Netflix & Prime Hindi Hub', netflixHubList, '/discover/movie?with_watch_providers=8&watch_region=IN&with_original_language=hi', false);
          }),
          _sidebarItem(4, Icons.video_library_outlined, 'Zee5 & Cinema', onTap: () {
            _openFullGridView('Zee5 Cinema Hub', zee5HubList, '/discover/movie?with_watch_providers=232&watch_region=IN&with_original_language=hi', false);
          }),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label, {VoidCallback? onTap}) {
    return Focus(
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          final isSelected = _selectedSidebarIndex == index;

          return InkWell(
            onTap: () {
              setState(() => _selectedSidebarIndex = index);
              if (onTap != null) onTap();
            },
            child: Container(
              height: 48,
              width: 48,
              margin: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isSelected || isFocused)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(isFocused ? 0.25 : 0.12),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Icon(
                    icon,
                    color: isFocused
                        ? Colors.white
                        : (isSelected ? const Color(0xFFE50914) : Colors.white60),
                    size: 22,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Row(
        children: [
          _buildTVSidebar(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTVBillboard(),
                        _buildTVRow('Netflix Originals & Hindi Hits', netflixHubList, '/discover/movie?with_watch_providers=8&watch_region=IN&with_original_language=hi&sort_by=popularity.desc', false),
                        _buildTVRow('Amazon Prime Video Hindi Hub', primeHubList, '/discover/movie?with_watch_providers=119&watch_region=IN&with_original_language=hi&sort_by=popularity.desc', false),
                        _buildTVRow('Disney+ Hotstar Hindi Specials & Blockbusters', hotstarHubList, '/discover/movie?with_watch_providers=122&watch_region=IN&sort_by=popularity.desc', false),
                        _buildTVRow('SonyLIV Pure Desi Hindi Drama', sonyLivHubList, '/discover/tv?with_watch_providers=237&watch_region=IN&with_original_language=hi&sort_by=popularity.desc', true),
                        _buildTVRow('Zee5 Hindi Cinema & Originals', zee5HubList, '/discover/movie?with_watch_providers=232&watch_region=IN&with_original_language=hi&sort_by=popularity.desc', false),
                        _buildTVRow('Bollywood Latest Blockbusters', bollywoodHubList, '/discover/movie?with_original_language=hi&sort_by=primary_release_date.desc&vote_count.gte=10', false),
                        const SizedBox(height: 40),
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
// 3. FULL SCREEN VERTICAL GRID SCREEN (SEE ALL - 200+ TITLES DEEP PAGINATION)
// ============================================================================
class TVCategoryGridScreen extends StatefulWidget {
  final String title;
  final List<MediaItem> initialItems;
  final String endpoint;
  final bool isTv;

  const TVCategoryGridScreen({
    super.key,
    required this.title,
    required this.initialItems,
    required this.endpoint,
    required this.isTv,
  });

  @override
  State<TVCategoryGridScreen> createState() => _TVCategoryGridScreenState();
}

class _TVCategoryGridScreenState extends State<TVCategoryGridScreen> {
  late List<MediaItem> allItems;
  bool isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    allItems = List.from(widget.initialItems);
    _loadDeepPages();
  }

  Future<void> _loadDeepPages() async {
    setState(() => isLoadingMore = true);
    for (int p = 2; p <= 10; p++) {
      try {
        final sep = widget.endpoint.contains('?') ? '&' : '?';
        final url = '${TVConfig.tmdbBase}${widget.endpoint}${sep}api_key=${TVConfig.tmdbKey}&page=$p';
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final results = data['results'] as List<dynamic>? ?? [];
          final newItems = results
              .where((m) => m['poster_path'] != null)
              .map((m) => MediaItem.fromTmdb(m, isTv: widget.isTv, endpoint: widget.endpoint))
              .toList();

          if (mounted) {
            setState(() {
              allItems.addAll(newItems);
            });
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() => isLoadingMore = false);
  }

  Future<void> _playMedia(MediaItem item) async {
    final streamUrl = await XtreamStremioEngine.resolveStreamUrl(item);
    if (streamUrl == null) return;

    try {
      final intent = AndroidIntent(
        action: 'action_view',
        data: streamUrl,
        type: 'video/*',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        title: Row(
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(4)),
              child: Text('${allItems.length} Titles', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            childAspectRatio: 0.68,
          ),
          itemCount: allItems.length,
          itemBuilder: (ctx, idx) {
            final item = allItems[idx];
            return Focus(
              child: Builder(
                builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _playMedia(item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isFocused ? Colors.white : Colors.transparent,
                          width: isFocused ? 3.0 : 0.0,
                        ),
                        boxShadow: isFocused
                            ? [BoxShadow(color: Colors.white.withOpacity(0.55), blurRadius: 12, spreadRadius: 2)]
                            : [],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            item.poster,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${item.rating} ★', style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                      Text(item.year, style: const TextStyle(color: Colors.white60, fontSize: 11)),
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
          },
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

void main() {
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
  List<dynamic>? genres;

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
    this.genres,
  });

  factory MediaItem.fromTmdb(Map<String, dynamic> json, {bool isTv = false, String endpoint = ''}) {
    final currentYear = DateTime.now().year.toString();
    final releaseDate = json['release_date'] ?? json['first_air_date'] ?? currentYear;
    final yearParsed = releaseDate.toString().split('-')[0];

    return MediaItem(
      tmdbId: json['id'],
      title: json['title'] ?? json['name'] ?? 'Untitled',
      year: yearParsed.isNotEmpty ? yearParsed : currentYear,
      rating: json['vote_average'] != null ? (json['vote_average'] as num).toStringAsFixed(1) : '7.5',
      backdrop: json['backdrop_path'] != null
          ? '${TVConfig.backdropBase}${json['backdrop_path']}'
          : (json['poster_path'] != null ? '${TVConfig.imgBase}${json['poster_path']}' : ''),
      poster: json['poster_path'] != null
          ? '${TVConfig.imgBase}${json['poster_path']}'
          : (json['backdrop_path'] != null ? '${TVConfig.backdropBase}${json['backdrop_path']}' : ''),
      overview: json['overview'] ?? 'No overview available for this title.',
      isTv: isTv,
      endpoint: endpoint,
      genres: json['genre_ids'] as List<dynamic>?,
    );
  }
}

class XtreamServerInfo {
  final String serverUrl;
  final String username;
  final String password;
  final String status;

  XtreamServerInfo({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.status = 'Active',
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
      status: (json['status'] ?? 'Active').toString(),
    );
  }

  String buildVodStreamUrl(dynamic streamId, {String extension = 'mp4'}) {
    return '$serverUrl/movie/$username/$password/$streamId.$extension';
  }

  String buildSeriesStreamUrl(dynamic streamId, int season, int episode, {String extension = 'mp4'}) {
    return '$serverUrl/series/$username/$password/$streamId/$season/$episode.$extension';
  }

  String buildVodActionUrl() {
    return '$serverUrl/player_api.php?username=$username&password=$password&action=get_vod_streams';
  }

  String buildSeriesActionUrl() {
    return '$serverUrl/player_api.php?username=$username&password=$password&action=get_series';
  }
}

class StremioStreamResult {
  final String title;
  final String url;
  final String? quality;
  final String source;

  StremioStreamResult({
    required this.title,
    required this.url,
    this.quality,
    required this.source,
  });
}

// ============================================================================
// XTREAM & STREMIO STREAM ENGINE
// ============================================================================
class XtreamStremioEngine {
  static List<XtreamServerInfo> servers = [];
  static Map<String, dynamic> xtreamVodCache = {};
  static Map<String, dynamic> xtreamSeriesCache = {};
  static bool isXtreamSyncing = false;

  static Future<void> initEngine() async {
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
      }
    } catch (_) {}

    if (servers.isNotEmpty) {
      syncXtreamIndexes();
    }
  }

  static Future<void> syncXtreamIndexes() async {
    if (servers.isEmpty || isXtreamSyncing) return;
    isXtreamSyncing = true;

    for (var srv in servers) {
      try {
        final vodRes = await http.get(Uri.parse(srv.buildVodActionUrl())).timeout(const Duration(seconds: 10));
        if (vodRes.statusCode == 200) {
          final vodList = jsonDecode(vodRes.body);
          if (vodList is List) {
            for (var item in vodList) {
              if (item is Map<String, dynamic>) {
                final streamId = item['stream_id'];
                final name = (item['name'] ?? '').toString().toLowerCase();
                final tmdb = item['tmdb_id'] ?? item['custom_sid'];
                if (tmdb != null) {
                  xtreamVodCache['tmdb_$tmdb'] = streamId;
                }
                if (name.isNotEmpty) {
                  xtreamVodCache['name_$name'] = streamId;
                }
              }
            }
          }
        }

        final serRes = await http.get(Uri.parse(srv.buildSeriesActionUrl())).timeout(const Duration(seconds: 10));
        if (serRes.statusCode == 200) {
          final serList = jsonDecode(serRes.body);
          if (serList is List) {
            for (var item in serList) {
              if (item is Map<String, dynamic>) {
                final seriesId = item['series_id'];
                final name = (item['name'] ?? '').toString().toLowerCase();
                final tmdb = item['tmdb_id'];
                if (tmdb != null) {
                  xtreamSeriesCache['tmdb_$tmdb'] = seriesId;
                }
                if (name.isNotEmpty) {
                  xtreamSeriesCache['name_$name'] = seriesId;
                }
              }
            }
          }
        }
        break;
      } catch (_) {}
    }
    isXtreamSyncing = false;
  }

  static Future<String?> resolveStreamUrl(MediaItem item, {int season = 1, int episode = 1}) async {
    if (servers.isEmpty) await initEngine();
    if (servers.isEmpty) return null;

    final primaryServer = servers.first;
    dynamic resolvedId = item.xtreamStreamId;

    if (item.isTv) {
      resolvedId ??= xtreamSeriesCache['tmdb_${item.tmdbId}'];
      resolvedId ??= xtreamSeriesCache['name_${item.title.toLowerCase()}'];
      resolvedId ??= item.tmdbId;

      return primaryServer.buildSeriesStreamUrl(resolvedId, season, episode);
    } else {
      resolvedId ??= xtreamVodCache['tmdb_${item.tmdbId}'];
      resolvedId ??= xtreamVodCache['name_${item.title.toLowerCase()}'];
      resolvedId ??= item.tmdbId;

      return primaryServer.buildVodStreamUrl(resolvedId);
    }
  }

  static Future<List<StremioStreamResult>> fetchStremioStreams(MediaItem item, {int season = 1, int episode = 1}) async {
    List<StremioStreamResult> results = [];
    final idParam = item.isTv ? 'tt_${item.tmdbId}:$season:$episode' : 'tt_${item.tmdbId}';

    for (var addon in TVConfig.stremioAddons) {
      try {
        final type = item.isTv ? 'series' : 'movie';
        final url = '$addon/stream/$type/$idParam.json';
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final streams = data['streams'] as List<dynamic>? ?? [];
          for (var st in streams) {
            if (st['url'] != null) {
              results.add(
                StremioStreamResult(
                  title: st['title'] ?? st['name'] ?? 'Stream Server',
                  url: st['url'],
                  quality: st['name'],
                  source: 'Stremio Engine',
                ),
              );
            }
          }
        }
      } catch (_) {}
    }
    return results;
  }
}

// ============================================================================
// 1. AUTHENTIC NETFLIX "TA-DUM" INTRO SPLASH SCREEN
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
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeIn),
      ),
    );

    _glowAnimation = Tween<double>(begin: 20.0, end: 60.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animController.forward();

    Timer(const Duration(milliseconds: 2500), () {
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
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE50914).withOpacity(0.6),
                            blurRadius: _glowAnimation.value,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'N',
                          style: TextStyle(
                            color: Color(0xFFE50914),
                            fontSize: 140,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Helvetica',
                            letterSpacing: -5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'NETFLIX PRO',
                      style: TextStyle(
                        color: Colors.white,
                        letterSpacing: 8,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
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
// 2. MAIN TV HOME SCREEN
// ============================================================================
class TVHomeScreen extends StatefulWidget {
  const TVHomeScreen({super.key});

  @override
  State<TVHomeScreen> createState() => _TVHomeScreenState();
}

class _TVHomeScreenState extends State<TVHomeScreen> {
  int _selectedSidebarIndex = 1;
  MediaItem? activeBillboardItem;

  List<MediaItem> netflixSeriesList = [];
  List<MediaItem> netflixMoviesList = [];
  List<MediaItem> primeSeriesList = [];
  List<MediaItem> primeMoviesList = [];
  List<MediaItem> sonyLivSeriesList = [];
  List<MediaItem> zee5List = [];
  List<MediaItem> bollywoodMoviesList = [];
  List<MediaItem> southHindiList = [];
  List<MediaItem> hollywoodHindiList = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialContent();
  }

  Future<void> _loadInitialContent() async {
    try {
      final quickResults = await Future.wait([
        _fetchCategory('/discover/tv?with_networks=213&sort_by=popularity.desc', isTv: true),
        _fetchCategory('/discover/movie?with_watch_providers=8&watch_region=IN&sort_by=popularity.desc'),
      ]);

      if (mounted) {
        setState(() {
          netflixSeriesList = quickResults[0];
          netflixMoviesList = quickResults[1];
          if (netflixSeriesList.isNotEmpty) {
            activeBillboardItem = netflixSeriesList.first;
          }
          isLoading = false;
        });
      }

      _fetchRemainingRows();
      XtreamStremioEngine.initEngine();
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchRemainingRows() async {
    try {
      final pSeries = await _fetchCategory('/discover/tv?with_watch_providers=119&watch_region=IN&sort_by=popularity.desc', isTv: true);
      final pMovies = await _fetchCategory('/discover/movie?with_watch_providers=119&watch_region=IN&sort_by=popularity.desc');
      final sLiv = await _fetchCategory('/discover/tv?with_original_language=hi&with_watch_providers=237&watch_region=IN', isTv: true);
      final z5 = await _fetchCategory('/discover/movie?with_original_language=hi&with_watch_providers=232&watch_region=IN');
      final bWood = await _fetchCategory('/discover/movie?with_original_language=hi&sort_by=popularity.desc');
      final south = await _fetchCategory('/discover/movie?with_original_language=te%7Cta%7Cml%7Ckn&sort_by=popularity.desc');
      final hWood = await _fetchCategory('/discover/movie?with_original_language=en&sort_by=popularity.desc');

      if (mounted) {
        setState(() {
          primeSeriesList = pSeries;
          primeMoviesList = pMovies;
          sonyLivSeriesList = sLiv;
          zee5List = z5;
          bollywoodMoviesList = bWood;
          southHindiList = south;
          hollywoodHindiList = hWood;
        });
      }
    } catch (_) {}
  }

  Future<List<MediaItem>> _fetchCategory(String endpoint, {bool isTv = false}) async {
    try {
      final sep = endpoint.contains('?') ? '&' : '?';
      final url = '${TVConfig.tmdbBase}$endpoint${sep}api_key=${TVConfig.tmdbKey}&page=1';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

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
        const SnackBar(content: Text('No active Xtream stream link resolved.')),
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
                    item.isTv ? 'S E R I E S' : 'F I L M',
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
                    child: const Text('5.1 Audio', style: TextStyle(color: Colors.white70, fontSize: 10)),
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
              Row(
                children: [
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
                          label: const Text('Play', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          onPressed: () => _playMedia(item),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Focus(
                    child: Builder(
                      builder: (context) {
                        final isFocused = Focus.of(context).hasFocus;
                        return OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.12),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            side: isFocused ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          icon: const Icon(Icons.info_outline, size: 22),
                          label: const Text('Episodes & Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          onPressed: () => _showMediaDetailsModal(item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTVRow(String title, List<MediaItem> items, String endpoint, bool isTv) {
    if (items.isEmpty) return const SizedBox.shrink();

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
          _sidebarItem(2, Icons.tv, 'TV Series', onTap: () {
            _openFullGridView('All TV Series', netflixSeriesList, '/discover/tv?with_networks=213&sort_by=first_air_date.desc', true);
          }),
          _sidebarItem(3, Icons.movie_creation_outlined, 'Movies', onTap: () {
            _openFullGridView('All Movies', bollywoodMoviesList, '/discover/movie?with_original_language=hi&sort_by=primary_release_date.desc', false);
          }),
          _sidebarItem(4, Icons.video_library_outlined, 'OTT Hub', onTap: () {
            _openFullGridView('SonyLIV & Zee5 Hub', sonyLivSeriesList, '/discover/tv?with_watch_providers=237&watch_region=IN', true);
          }),
          _sidebarItem(5, Icons.history, 'History', onTap: () {}),
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

  void _showMediaDetailsModal(MediaItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      isScrollControlled: true,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.75,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(item.poster, width: 100, height: 145, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('${item.year}  •  ${item.rating} ★ Match  •  ${item.isTv ? "TV Series" : "Movie"}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 10),
                          Text(item.overview, style: const TextStyle(color: Colors.white60, fontSize: 13), maxLines: 4),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const Text('Available Stream Engines & Mirrors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Expanded(
                  child: FutureBuilder<List<StremioStreamResult>>(
                    future: XtreamStremioEngine.fetchStremioStreams(item),
                    builder: (context, snapshot) {
                      final stremioStreams = snapshot.data ?? [];
                      return ListView(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.flash_on, color: Color(0xFFE50914)),
                            title: const Text('Xtream Fast Direct Stream (Primary Server)'),
                            subtitle: const Text('Ultra HD 4K / 1080p Direct Engine'),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _playMedia(item);
                              },
                              child: const Text('Play'),
                            ),
                          ),
                          ...stremioStreams.map((st) {
                            return ListTile(
                              leading: const Icon(Icons.cloud_download, color: Colors.blueAccent),
                              title: Text(st.title),
                              subtitle: Text('${st.source} • ${st.quality ?? "HD"}'),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  AndroidIntent(
                                    action: 'action_view',
                                    data: st.url,
                                    type: 'video/*',
                                    flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
                                  ).launch();
                                },
                                child: const Text('Stream'),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                        _buildTVRow('Only on Netflix (Original Series)', netflixSeriesList, '/discover/tv?with_networks=213&sort_by=first_air_date.desc', true),
                        _buildTVRow('Netflix Blockbuster Movies', netflixMoviesList, '/discover/movie?with_watch_providers=8&watch_region=IN&sort_by=primary_release_date.desc', false),
                        _buildTVRow('Amazon Prime Video Originals', primeSeriesList, '/discover/tv?with_watch_providers=119&watch_region=IN&sort_by=first_air_date.desc', true),
                        _buildTVRow('Amazon Prime Blockbuster Movies', primeMoviesList, '/discover/movie?with_watch_providers=119&watch_region=IN&sort_by=primary_release_date.desc', false),
                        _buildTVRow('SonyLIV Originals & Drama Series', sonyLivSeriesList, '/discover/tv?with_original_language=hi&with_watch_providers=237&watch_region=IN', true),
                        _buildTVRow('Zee5 Originals & Cinema', zee5List, '/discover/movie?with_original_language=hi&with_watch_providers=232&watch_region=IN', false),
                        _buildTVRow('Bollywood Blockbusters', bollywoodMoviesList, '/discover/movie?with_original_language=hi&sort_by=primary_release_date.desc', false),
                        _buildTVRow('South Action Hits (Hindi Dubbed)', southHindiList, '/discover/movie?with_original_language=te%7Cta%7Cml%7Ckn&sort_by=popularity.desc', false),
                        _buildTVRow('Hollywood Hits (Hindi Dubbed)', hollywoodHindiList, '/discover/movie?with_original_language=en&sort_by=popularity.desc', false),
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

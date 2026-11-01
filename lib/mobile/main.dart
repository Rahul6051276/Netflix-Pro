import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'internal_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const NetflixProMobileApp());
}

class MobileConfig {
  static const String gistUrl =
      'https://gist.githubusercontent.com/Rahul6051276/f5240bc75ad4aa0499d21799a9cf5c66/raw/netflix_providers.json';
  static const String tmdbKey = '81a303644f1e5828271032db9a35e4d5';
  static const String tmdbBase = 'https://api.themoviedb.org/3';
  static const String imgBase = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBase = 'https://image.tmdb.org/t/p/original';
}

class NetflixProMobileApp extends StatelessWidget {
  const NetflixProMobileApp({super.key});

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
          surface: Color(0xFF141414),
        ),
      ),
      home: const MobileHomeScreen(),
    );
  }
}
// ============================================================================
// SOAP FILTER LOGIC
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
      final res = await http.get(Uri.parse(MobileConfig.gistUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        activeProviders = data['active_providers'] ?? [];
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
  // 5 CORE OTT CATALOG FETCH (NETFLIX, PRIME, HOTSTAR, SONYLIV, ZEE5)
  // ============================================================================
    Future<void> _fetchCatalogs() async {
    // 1. Netflix
    try {
      final res = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&sort_by=primary_release_date.desc')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        homeNetflixList = _parseCatalog(jsonDecode(res.body)['results']);
      }
    } catch (_) {}

    // 2. Prime Video
    try {
      final res = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=119&watch_region=IN&sort_by=primary_release_date.desc')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        homePrimeList = _parseCatalog(jsonDecode(res.body)['results']);
      }
    } catch (_) {}

    // 3. Hotstar
    try {
      final res = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/movie/now_playing?api_key=${MobileConfig.tmdbKey}&language=en-US&region=IN')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        homeHotstarList = _parseCatalog(jsonDecode(res.body)['results']);
      }
    } catch (_) {}

    // 4. SonyLIV
    try {
      final res = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_watch_providers=237&watch_region=IN&without_genres=10766&vote_count.gte=3&sort_by=popularity.desc')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        homeSonyLivList = _parseCatalog(jsonDecode(res.body)['results'], isTv: true)
            .where((item) => !isSoapShow(item['title'] ?? ''))
            .toList();
      }
    } catch (_) {}

    // 5. ZEE5
    try {
      final res = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_watch_providers=232&watch_region=IN&without_genres=10766&vote_count.gte=3&sort_by=popularity.desc')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        homeZee5List = _parseCatalog(jsonDecode(res.body)['results'], isTv: true)
            .where((item) => !isSoapShow(item['title'] ?? ''))
            .toList();
      }
    } catch (_) {}

    // Set Welcome Billboard from first available list
    if (homeNetflixList.isNotEmpty) {
      activeBillboardItem = homeNetflixList.first;
    } else if (homePrimeList.isNotEmpty) {
      activeBillboardItem = homePrimeList.first;
    } else if (homeHotstarList.isNotEmpty) {
      activeBillboardItem = homeHotstarList.first;
    }

    if (mounted) setState(() {});
  }

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

  // --------------------------------------------------------------------------
  // STREAM MODAL & PLAYER SELECTION DIALOG
  // --------------------------------------------------------------------------
  void _onItemTapped(Map<String, dynamic> item) {
    if (item['isTv'] == true) {
      _showSeriesSeasonEpisodeSelector(item);
    } else {
      _showStreamProviderSelection(item);
    }
  }

  void _showSeriesSeasonEpisodeSelector(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        int selectedSeason = 1;
        int selectedEpisode = 1;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? 'Select Episode',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      DropdownButton<int>(
                        value: selectedSeason,
                        dropdownColor: const Color(0xFF2A2A2A),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        items: List.generate(10, (i) => i + 1)
                            .map((s) => DropdownMenuItem(value: s, child: Text('Season $s')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedSeason = val);
                        },
                      ),
                      DropdownButton<int>(
                        value: selectedEpisode,
                        dropdownColor: const Color(0xFF2A2A2A),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        items: List.generate(30, (i) => i + 1)
                            .map((e) => DropdownMenuItem(value: e, child: Text('Episode $e')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedEpisode = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showStreamProviderSelection(
                          item,
                          season: selectedSeason,
                          episode: selectedEpisode,
                        );
                      },
                      child: const Text('Find Streams', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showStreamProviderSelection(Map<String, dynamic> item, {int? season, int? episode}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        if (activeProviders.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('No active streaming providers available.', style: TextStyle(color: Colors.white70)),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Select Server - ${item['title']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(color: Colors.white12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: activeProviders.length,
                  itemBuilder: (context, idx) {
                    final provider = activeProviders[idx];
                    final pName = provider['name'] ?? 'Server ${idx + 1}';
                    return ListTile(
                      leading: const Icon(Icons.cloud_queue, color: Color(0xFFE50914)),
                      title: Text(pName, style: const TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.play_arrow, color: Colors.white54),
                      onTap: () {
                        Navigator.pop(ctx);
                        _constructAndPromptPlayer(provider, item, season: season, episode: episode);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _constructAndPromptPlayer(Map<String, dynamic> provider, Map<String, dynamic> item, {int? season, int? episode}) {
    final server = provider['server'] ?? '';
    final username = provider['username'] ?? '';
    final password = provider['password'] ?? '';
    final tmdbId = item['tmdb_id'];

    String streamUrl = '';
    if (item['isTv'] == true && season != null && episode != null) {
      streamUrl = '$server/series/$username/$password/$tmdbId/$season/$episode.mp4';
    } else {
      streamUrl = '$server/movie/$username/$password/$tmdbId.mp4';
    }

    _showPlayerChoiceDialog(streamUrl, item['title'] ?? 'Video');
  }

  void _showPlayerChoiceDialog(String streamUrl, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              const Text('Play mode choose karein:', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.play_circle_fill, color: Color(0xFFE50914), size: 36),
                title: const Text('Internal Player', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Fast in-app player with ±30s seek', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InternalPlayerScreen(
                        streamUrl: streamUrl,
                        title: title,
                      ),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.blueAccent, size: 36),
                title: const Text('External Player', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('VLC, Just Player ya MX Player me open karein', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  try {
                    final intent = AndroidIntent(
                      action: 'action_view',
                      data: streamUrl,
                      type: 'video/*',
                      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
                    );
                    intent.launch();
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('External video player launch failed.')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // UI WIDGETS
  // --------------------------------------------------------------------------
  Widget _buildBillboard(Map<String, dynamic> item) {
    return Stack(
      children: [
        SizedBox(
          height: 440,
          width: double.infinity,
          child: Image.network(
            item['poster'] ?? '',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
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
                Colors.transparent,
                Color(0x99141414),
                Color(0xFF141414),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                item['title'] ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${item['rating']} ★', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Text(item['year'] ?? '', style: const TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 24),
                    label: const Text('Play', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    onPressed: () => _onItemTapped(item),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    icon: const Icon(Icons.info_outline, size: 20),
                    label: const Text('Info', style: TextStyle(fontSize: 15)),
                    onPressed: () {},
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (ctx, idx) {
              final m = items[idx];
              return GestureDetector(
                onTap: () => _onItemTapped(m),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.grey[900],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    m['poster'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white24),
                    ),
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
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
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        onTap: (idx) => setState(() => _currentBottomNavIndex = idx),
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

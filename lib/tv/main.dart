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

class TVConfig {
  static const String gistUrl =
      'https://gist.githubusercontent.com/Rahul6051276/f5240bc75ad4aa0499d21799a9cf5c66/raw/netflix_providers.json';
  static const String tmdbKey = '81a303644f1e5828271032db9a35e4d5';
  static const String tmdbBase = 'https://api.themoviedb.org/3';
  static const String imgBase = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBase = 'https://image.tmdb.org/t/p/original';
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
      ),
      home: const TVSplashScreen(),
    );
  }
}

// ============================================================================
// 1. NETFLIX "TA-DUM" INTRO SPLASH SCREEN
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
      duration: const Duration(milliseconds: 2200),
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

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const TVHomeScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 700),
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
                            fontFamily: 'Helvetica',
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
// 2. MAIN TV HOME SCREEN (HERO BILLBOARD + HORIZONTAL ROWS)
// ============================================================================
class TVHomeScreen extends StatefulWidget {
  const TVHomeScreen({super.key});

  @override
  State<TVHomeScreen> createState() => _TVHomeScreenState();
}

class _TVHomeScreenState extends State<TVHomeScreen> {
  int _selectedSidebarIndex = 1; // 1 = Home
  bool _sidebarExpanded = false;

  List<dynamic> activeProviders = [];
  Map<String, dynamic>? activeBillboardItem;

  // Catalogs (Har category me 200+ deep fetch)
  List<dynamic> netflixSeriesList = [];
  List<dynamic> netflixMoviesList = [];
  List<dynamic> primeSeriesList = [];
  List<dynamic> primeMoviesList = [];
  List<dynamic> sonyLivSeriesList = [];
  List<dynamic> zee5List = [];
  List<dynamic> bollywoodMoviesList = [];
  List<dynamic> southHindiList = [];
  List<dynamic> hollywoodHindiList = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllTVData();
  }

  Future<void> _loadAllTVData() async {
    await Future.wait([
      _fetchProviders(),
      _fetchDeepCatalogs(),
    ]);
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchProviders() async {
    try {
      final res = await http.get(Uri.parse(TVConfig.gistUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        activeProviders = data['active_providers'] ?? [];
      }
    } catch (_) {}
  }

  // Deep Pagination Helper (Pages 1 to 10 fetch karega = 200+ items)
  Future<List<dynamic>> _fetchDeepCategory(String endpoint, {bool isTv = false, int pages = 8}) async {
    List<dynamic> aggregated = [];
    final currentYear = DateTime.now().year.toString();

    for (int page = 1; page <= pages; page++) {
      try {
        final separator = endpoint.contains('?') ? '&' : '?';
        final url = '${TVConfig.tmdbBase}$endpoint${separator}api_key=${TVConfig.tmdbKey}&page=$page';
        final res = await http.get(Uri.parse(url));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final results = data['results'] as List<dynamic>? ?? [];

          for (var m in results) {
            if (m['backdrop_path'] == null && m['poster_path'] == null) continue;
            aggregated.add({
              'tmdb_id': m['id'],
              'title': m['title'] ?? m['name'] ?? 'Untitled',
              'year': (m['release_date'] ?? m['first_air_date'] ?? currentYear).toString().split('-')[0],
              'rating': m['vote_average']?.toStringAsFixed(1) ?? '7.8',
              'backdrop': m['backdrop_path'] != null
                  ? '${TVConfig.backdropBase}${m['backdrop_path']}'
                  : '${TVConfig.imgBase}${m['poster_path']}',
              'poster': m['poster_path'] != null
                  ? '${TVConfig.imgBase}${m['poster_path']}'
                  : '${TVConfig.backdropBase}${m['backdrop_path']}',
              'overview': m['overview'] ?? 'No synopsis available.',
              'isTv': isTv,
            });
          }
        }
      } catch (_) {
        break;
      }
    }
    return aggregated;
  }

  Future<void> _fetchDeepCatalogs() async {
    try {
      final results = await Future.wait([
        // 1. Netflix Series (Provider: 213)
        _fetchDeepCategory('/discover/tv?with_networks=213&sort_by=first_air_date.desc&vote_count.gte=10', isTv: true),
        // 2. Netflix Movies (Provider ID 8)
        _fetchDeepCategory('/discover/movie?with_watch_providers=8&watch_region=IN&sort_by=primary_release_date.desc&vote_count.gte=8'),
        // 3. Amazon Prime Series (Provider ID 119/9)
        _fetchDeepCategory('/discover/tv?with_watch_providers=119&watch_region=IN&sort_by=first_air_date.desc&vote_count.gte=8', isTv: true),
        // 4. Amazon Prime Movies
        _fetchDeepCategory('/discover/movie?with_watch_providers=119&watch_region=IN&sort_by=primary_release_date.desc&vote_count.gte=8'),
        // 5. SonyLIV Originals & Indian Drama Series
        _fetchDeepCategory('/discover/tv?with_original_language=hi&with_watch_providers=237&watch_region=IN&sort_by=first_air_date.desc&vote_count.gte=5', isTv: true),
        // 6. Zee5 Originals & Regional Movies
        _fetchDeepCategory('/discover/movie?with_original_language=hi&with_watch_providers=232&watch_region=IN&sort_by=primary_release_date.desc&vote_count.gte=5'),
        // 7. Bollywood Blockbusters (Latest first)
        _fetchDeepCategory('/discover/movie?with_original_language=hi&sort_by=primary_release_date.desc&vote_count.gte=15'),
        // 8. South Action Hits (Hindi Dubbed)
        _fetchDeepCategory('/discover/movie?with_original_language=te%7Cta%7Cml%7Ckn&sort_by=popularity.desc&vote_count.gte=15'),
        // 9. Hollywood Hits
        _fetchDeepCategory('/discover/movie?with_original_language=en&sort_by=popularity.desc&vote_count.gte=100'),
      ]);

      if (mounted) {
        setState(() {
          netflixSeriesList = results[0];
          netflixMoviesList = results[1];
          primeSeriesList = results[2];
          primeMoviesList = results[3];
          sonyLivSeriesList = results[4];
          zee5List = results[5];
          bollywoodMoviesList = results[6];
          southHindiList = results[7];
          hollywoodHindiList = results[8];

          if (netflixSeriesList.isNotEmpty) {
            activeBillboardItem = netflixSeriesList.first;
          }
        });
      }
    } catch (_) {}
  }

  void _openFullGridView(String categoryTitle, List<dynamic> fullCatalog) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TVCategoryGridScreen(
          title: categoryTitle,
          items: fullCatalog,
          activeProviders: activeProviders,
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // STREAM INTENT & PLAYER LAUNCH
  // --------------------------------------------------------------------------
  void _playStreamDirectly(Map<String, dynamic> item) {
    if (activeProviders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active servers available.')),
      );
      return;
    }

    final provider = activeProviders.first;
    final server = provider['server'] ?? '';
    final username = provider['username'] ?? '';
    final password = provider['password'] ?? '';
    final tmdbId = item['tmdb_id'];

    String streamUrl = item['isTv'] == true
        ? '$server/series/$username/$password/$tmdbId/1/1.mp4'
        : '$server/movie/$username/$password/$tmdbId.mp4';

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
        const SnackBar(content: Text('Could not launch video player.')),
      );
    }
  }

  // --------------------------------------------------------------------------
  // TV BILLBOARD HERO BANNER
  // --------------------------------------------------------------------------
  Widget _buildTVBillboard() {
    final item = activeBillboardItem;
    if (item == null) return const SizedBox.shrink();

    return Stack(
      children: [
        // Backdrop Image
        SizedBox(
          height: 380,
          width: double.infinity,
          child: Image.network(
            item['backdrop'] ?? '',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1B1B1B)),
          ),
        ),
        // Vignette Gradients
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
        // Meta Text & Direct Play
        Positioned(
          top: 70,
          left: 45,
          width: 580,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('N', style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    item['isTv'] == true ? 'S E R I E S' : 'F I L M',
                    style: const TextStyle(color: Colors.white70, letterSpacing: 4, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item['title'] ?? '',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('${item['rating']} ★ Match', style: const TextStyle(color: Color(0xFF46D369), fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 14),
                  Text(item['year'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(3)),
                    child: const Text('Ultra HD 4K', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item['overview'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.play_arrow, size: 26),
                label: const Text('Play', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () => _playStreamDirectly(item),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // TV HORIZONTAL ROW WITH "SEE ALL" BUTTON
  // --------------------------------------------------------------------------
  Widget _buildTVRow(String title, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Home screen par shuruat ke 15 latest items dikhayenge
    final previewItems = items.take(15).toList();

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
              Text(
                'Total ${items.length}+ Titles',
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            itemCount: previewItems.length + 1, // +1 for See All card
            itemBuilder: (ctx, idx) {
              if (idx == previewItems.length) {
                // Last Card: SEE ALL
                return Container(
                  width: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _openFullGridView(title, items),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.grid_view_rounded, color: Color(0xFFE50914), size: 36),
                          const SizedBox(height: 8),
                          const Text('See All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('(${items.length}+ Titles)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final item = previewItems[idx];
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
                        onTap: () => _playStreamDirectly(item),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isFocused ? Colors.white : Colors.transparent,
                              width: isFocused ? 3.0 : 0.0,
                            ),
                            boxShadow: isFocused
                                ? [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]
                                : [],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                item['backdrop'] ?? '',
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
                                    item['title'] ?? '',
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
        const SizedBox(height: 18),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // TV LEFT SLIM RAIL
  // --------------------------------------------------------------------------
  Widget _buildTVSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _sidebarExpanded ? 180 : 56,
      color: Colors.black.withOpacity(0.92),
      child: Column(
        children: [
          const SizedBox(height: 25),
          const Icon(Icons.search, color: Colors.white, size: 24),
          const SizedBox(height: 35),
          _sidebarItem(1, Icons.home_filled, 'Home'),
          _sidebarItem(2, Icons.tv, 'TV Series', onTap: () => _openFullGridView('All TV Series', [...netflixSeriesList, ...primeSeriesList, ...sonyLivSeriesList])),
          _sidebarItem(3, Icons.movie, 'Movies', onTap: () => _openFullGridView('All Blockbuster Movies', [...netflixMoviesList, ...primeMoviesList, ...bollywoodMoviesList])),
          _sidebarItem(4, Icons.category, 'OTT Hub', onTap: () => _openFullGridView('SonyLIV & Zee5 Hub', [...sonyLivSeriesList, ...zee5List])),
          const Spacer(),
          IconButton(
            icon: Icon(_sidebarExpanded ? Icons.arrow_back_ios : Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onPressed: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label, {VoidCallback? onTap}) {
    final isSelected = _selectedSidebarIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedSidebarIndex = index);
        if (onTap != null) onTap();
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFE50914) : Colors.white60, size: 24),
            if (_sidebarExpanded) ...[
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
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
                        _buildTVRow('Only on Netflix (Original Series)', netflixSeriesList),
                        _buildTVRow('Netflix Blockbuster Movies', netflixMoviesList),
                        _buildTVRow('Amazon Prime Video Originals', primeSeriesList),
                        _buildTVRow('Amazon Prime Blockbuster Movies', primeMoviesList),
                        _buildTVRow('SonyLIV Originals & Drama Series', sonyLivSeriesList),
                        _buildTVRow('Zee5 Originals & Cinema', zee5List),
                        _buildTVRow('Bollywood Blockbusters', bollywoodMoviesList),
                        _buildTVRow('South Action Hits (Hindi Dubbed)', southHindiList),
                        _buildTVRow('Hollywood Hits (Hindi Dubbed)', hollywoodHindiList),
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
// 3. DEDICATED TV VERTICAL GRID SCREEN (SEE ALL VIEW - 200+ TITLES)
// ============================================================================
class TVCategoryGridScreen extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final List<dynamic> activeProviders;

  const TVCategoryGridScreen({
    super.key,
    required this.title,
    required this.items,
    required this.activeProviders,
  });

  void _playStreamDirectly(BuildContext context, Map<String, dynamic> item) {
    if (activeProviders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active servers available.')),
      );
      return;
    }

    final provider = activeProviders.first;
    final server = provider['server'] ?? '';
    final username = provider['username'] ?? '';
    final password = provider['password'] ?? '';
    final tmdbId = item['tmdb_id'];

    String streamUrl = item['isTv'] == true
        ? '$server/series/$username/$password/$tmdbId/1/1.mp4'
        : '$server/movie/$username/$password/$tmdbId.mp4';

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
        const SnackBar(content: Text('Could not launch video player.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(4)),
              child: Text('${items.length}+ Titles', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, // TV par 5 columns ka balanced poster layout
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            childAspectRatio: 0.68,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, idx) {
            final item = items[idx];
            return Focus(
              child: Builder(
                builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _playStreamDirectly(context, item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isFocused ? Colors.white : Colors.transparent,
                          width: isFocused ? 3.0 : 0.0,
                        ),
                        boxShadow: isFocused
                            ? [BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 12, spreadRadius: 2)]
                            : [],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            item['poster'] ?? '',
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
                                    item['title'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${item['rating']} ★', style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                      Text(item['year'] ?? '', style: const TextStyle(color: Colors.white60, fontSize: 11)),
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

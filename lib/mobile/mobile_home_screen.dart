// ============================================================================
// NETFLIX PRO MOBILE HOME & NAVIGATION SUITE (BOLLYWOOD + SOUTH + ENGLISH LATEST)
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_config.dart';
import 'category_grid_screen.dart';
import 'stream_resolver_sheet.dart';
import 'media_detail_sheet.dart';

class MobileRootScreen extends StatefulWidget {
  const MobileRootScreen({super.key});

  @override
  State<MobileRootScreen> createState() => _MobileRootScreenState();
}

class _MobileRootScreenState extends State<MobileRootScreen> {
  int _currentIndex = 0;
  List<dynamic> activeProviders = [];
  bool _hasGistUrl = false;

  @override
  void initState() {
    super.initState();
    _fetchGlobalProviders();
  }

  String _formatConnectedProviders() {
    if (activeProviders.isEmpty) {
      return 'Connected: Gist Source Active';
    }
    final names = activeProviders
        .map((p) => p is Map ? (p['name'] ?? p['title'] ?? p['id'] ?? '').toString() : p.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      return 'Connected: ${activeProviders.length} Active Sources';
    }
    return 'Connected: ${names.join(' + ')}';
  }

  void _showGistConfigDialog() {
    final controller = TextEditingController();
    MobileConfig.getGistUrl().then((existing) {
      controller.text = existing;
      if (!mounted) return;
      bool isSyncing = false;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) {
            final bool isConnected = controller.text.trim().isNotEmpty;

            return Dialog(
              backgroundColor: const Color(0xFF1A2234),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Colors.white12, width: 1),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.link_rounded, color: Color(0xFFEAB308), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GitHub Gist Raw Source',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Supports Xtream IPTV, Stremio Addons & JSON',
                                style: TextStyle(
                                  color: Color(0xFFEAB308),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Input Label & Multi-line Box
                    const Text(
                      'GitHub Gist Raw Link (or IPTV / Stremio link)',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      minLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'https://gist.githubusercontent.com/.../raw/providers.json',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF131926),
                        contentPadding: const EdgeInsets.all(14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Green Connected Status Box
                    if (isConnected) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF123528),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.45)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _formatConnectedProviders(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Connect & Sync + Clear Buttons Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: isSyncing
                                ? null
                                : () async {
                                    final val = controller.text.trim();
                                    if (val.isEmpty) return;
                                    setModalState(() => isSyncing = true);
                                    await MobileConfig.saveGistUrl(val);
                                    await _fetchGlobalProviders();
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Gist Source Connected & Synced!'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                            icon: isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text(
                              'Connect & Sync',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.55)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: isSyncing
                                ? null
                                : () async {
                                    controller.clear();
                                    await MobileConfig.saveGistUrl('');
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.remove('cached_active_providers');
                                    if (mounted) {
                                      setState(() {
                                        activeProviders = [];
                                        _hasGistUrl = false;
                                      });
                                    }
                                    setModalState(() {});
                                  },
                            child: const Text(
                              'Clear',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Bottom Helper Links Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            controller.text =
                                'https://gist.githubusercontent.com/username/gist_id/raw/providers.json';
                            setModalState(() {});
                          },
                          child: const Text(
                            'Fill Sample URL',
                            style: TextStyle(
                              color: Color(0xFFEAB308),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Supported format: {"active_providers": [...]}'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text(
                            'View Gist Templates',
                            style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
      ).then((_) => controller.dispose());
    });
  }

  Future<void> _fetchGlobalProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final rawGist = await MobileConfig.getGistUrl();

    if (mounted) {
      setState(() => _hasGistUrl = rawGist.isNotEmpty);
    }

    if (rawGist.isEmpty) return;

    final cached = prefs.getString('cached_active_providers');
    if (cached != null && cached.isNotEmpty && mounted) {
      try {
        setState(() {
          activeProviders = jsonDecode(cached) as List<dynamic>;
        });
      } catch (_) {}
    }

    try {
      final sep = rawGist.contains('?') ? '&' : '?';
      final freshUrl =
          '$rawGist${sep}t=${DateTime.now().millisecondsSinceEpoch}';
      final res =
          await http.get(Uri.parse(freshUrl)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['active_providers'] ?? decoded['providers'] ?? []);
        if (list is List && list.isNotEmpty) {
          await prefs.setString('cached_active_providers', jsonEncode(list));
          if (mounted) {
            setState(() {
              activeProviders = list;
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      MobileHomeScreen(
        providers: activeProviders,
        hasGistUrl: _hasGistUrl,
        onOpenGistDialog: _showGistConfigDialog,
      ),
      MobileSearchScreen(providers: activeProviders),
      MobileMyListScreen(providers: activeProviders),
      MobileMoreScreen(
        providers: activeProviders,
        onOpenGistSettings: _showGistConfigDialog,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled, size: 22), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search, size: 22), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline, size: 22), label: 'My List'),
          BottomNavigationBarItem(icon: Icon(Icons.menu, size: 22), label: 'More'),
        ],
      ),
    );
  }
}

// ============================================================================
// 1. HOME SCREEN (BOLLYWOOD + SOUTH + ENGLISH LATEST MIXED GENRES - UNCHANGED)
// ============================================================================
class MobileHomeScreen extends StatefulWidget {
  final List<dynamic> providers;
  final bool hasGistUrl;
  final VoidCallback? onOpenGistDialog;

  const MobileHomeScreen({
    super.key,
    required this.providers,
    this.hasGistUrl = false,
    this.onOpenGistDialog,
  });

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  List<dynamic> continueWatchingList = [];
  List<dynamic> homeBannerList = [];
  List<dynamic> homeActionList = [];
  List<dynamic> homeThrillerSuspenseList = [];
  List<dynamic> homeCrimeMysteryList = [];
  List<dynamic> homeBollywoodLatestList = [];
  List<dynamic> homeSouthLatestList = [];
  List<dynamic> homeEnglishLatestList = [];
  List<dynamic> homeNetflixList = [];
  List<dynamic> homePrimeList = [];
  List<dynamic> homeHindiSeriesList = [];

  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  Timer? _autoSlideTimer;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllMobileData();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startAutoSlide(int itemCount) {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (itemCount > 0 && mounted && _bannerController.hasClients) {
        _currentBannerIndex = (_currentBannerIndex + 1) % itemCount;
        _bannerController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadAllMobileData() async {
    await _loadContinueWatching();
    await _fetchHomeCatalogContent();
    if (mounted) {
      setState(() => isLoading = false);
      if (homeBannerList.isNotEmpty) {
        _startAutoSlide(homeBannerList.take(6).length);
      }
    }
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

  Future<List<dynamic>> _fetchSingleCategory(String url, {bool isTv = false}) async {
    if (MobileConfig.tmdbKey.isEmpty) return [];
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final parsed = _parseList(jsonDecode(res.body)['results'], isTv: isTv);
        if (isTv) {
          return parsed.where((item) => !isSoapShow(item['title'] ?? '')).toList();
        }
        return parsed;
      }
    } catch (_) {}
    return [];
  }

  Future<void> _fetchHomeCatalogContent() async {
    if (MobileConfig.tmdbKey.isEmpty) return;
    final now = DateTime.now();
    final todayIso =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    const mixedLangs = 'hi|en|te|ta|ml|kn';

    final results = await Future.wait([
      _fetchSingleCategory(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&sort_by=popularity.desc&vote_count.gte=25'),
      _fetchSingleCategory(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=28&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&sort_by=primary_release_date.desc&vote_count.gte=20'),
      _fetchSingleCategory(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=53&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&sort_by=primary_release_date.desc&vote_count.gte=15'),
      _fetchSingleCategory(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=9648,80&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&sort_by=primary_release_date.desc&vote_count.gte=15'),
      _fetchSingleCategory(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=hi&primary_release_date.lte=$todayIso&sort_by=primary_release_date.desc&vote_count.gte=8'),
      _fetchSingleCategory(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=te|ta|ml|kn&primary_release_date.lte=$todayIso&sort_by=primary_release_date.desc&vote_count.gte=10'),
      _fetchSingleCategory(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=en&primary_release_date.lte=$todayIso&sort_by=primary_release_date.desc&vote_count.gte=50'),
      _fetchSingleCategory(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&sort_by=popularity.desc'),
      _fetchSingleCategory(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=119&watch_region=IN&sort_by=popularity.desc'),
      _fetchSingleCategory(
          '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=popularity.desc&vote_count.gte=3',
          isTv: true),
    ]);

    homeBannerList = results[0];
    homeActionList = results[1];
    homeThrillerSuspenseList = results[2];
    homeCrimeMysteryList = results[3];
    homeBollywoodLatestList = results[4];
    homeSouthLatestList = results[5];
    homeEnglishLatestList = results[6];
    homeNetflixList = results[7];
    homePrimeList = results[8];
    homeHindiSeriesList = results[9];
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MediaDetailSheet(
        item: item,
        providers: widget.providers,
        onPlaySaved: () => _loadContinueWatching(),
      ),
    );
  }

  Future<void> _toggleMyList(dynamic item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('my_watchlist') ?? '[]';
    List list = jsonDecode(raw);

    final id = item['tmdb_id'];
    final exists = list.any((x) => x['tmdb_id'] == id);

    if (exists) {
      list.removeWhere((x) => x['tmdb_id'] == id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from My List'), duration: Duration(seconds: 1)),
        );
      }
    } else {
      list.add(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to My List successfully!'), duration: Duration(seconds: 1)),
        );
      }
    }
    await prefs.setString('my_watchlist', jsonEncode(list));
  }

  Widget _buildSlidingBanner(List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final bannerItems = items.take(6).toList();

    return SizedBox(
      height: 440,
      width: double.infinity,
      child: PageView.builder(
        controller: _bannerController,
        itemCount: bannerItems.length,
        onPageChanged: (idx) => _currentBannerIndex = idx,
        itemBuilder: (context, index) {
          final item = bannerItems[index];
          final String imgUrl = item['backdrop'] ?? item['poster'] ?? '';

          return GestureDetector(
            onTap: () => _onItemSelect(item),
            onLongPress: () => _toggleMyList(item),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imgUrl.isNotEmpty
                    ? Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1F1F1F)))
                    : Container(color: const Color(0xFF1F1F1F)),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent, Color(0xFF141414)],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      Text(
                        item['title'] ?? '',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 10, color: Colors.black, offset: Offset(0, 2))],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Bollywood • South • Hollywood Latest',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircularPreviewsRow(List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final previewItems = items.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            'Previews',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 105,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: previewItems.length,
            itemBuilder: (ctx, idx) {
              final item = previewItems[idx];
              final img = item['poster'] ?? item['backdrop'] ?? '';
              return GestureDetector(
                onTap: () => _onItemSelect(item),
                onLongPress: () => _toggleMyList(item),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE50914), width: 2.2),
                        ),
                        child: ClipOval(
                          child: img.isNotEmpty
                              ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey))
                              : Container(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 74,
                        child: Text(
                          item['title'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
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

  Widget _buildMobileRow(String title, List<dynamic> items, String baseUrl, {bool isTv = false}) {
    if (items.isEmpty) return const SizedBox.shrink();

    void openSeeAll() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MobileCategoryGridScreen(
            title: title,
            baseUrl: baseUrl,
            isTv: isTv,
            providers: widget.providers,
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
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              if (baseUrl.isNotEmpty)
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
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: items.length + (baseUrl.isNotEmpty ? 1 : 0),
            itemBuilder: (ctx, idx) {
              if (baseUrl.isNotEmpty && idx == items.length) {
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
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
              final String cardImg = item['poster'] ?? item['backdrop'] ?? '';

              return InkWell(
                onTap: () => _onItemSelect(item),
                onLongPress: () => _toggleMyList(item),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 112,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(6)),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      cardImg.isNotEmpty
                          ? Image.network(cardImg, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF222222)))
                          : Container(color: const Color(0xFF222222)),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black, Colors.transparent]),
                          ),
                          child: Text(
                            item['title'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayIso =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    const mixedLangs = 'hi|en|te|ta|ml|kn';

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : Stack(
              children: [
                RefreshIndicator(
                  color: const Color(0xFFE50914),
                  backgroundColor: const Color(0xFF202020),
                  onRefresh: _loadAllMobileData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSlidingBanner(homeBannerList),
                        const SizedBox(height: 6),
                        _buildCircularPreviewsRow(homeBannerList),
                        const SizedBox(height: 10),

                        if (continueWatchingList.isNotEmpty)
                          _buildMobileRow('Continue Watching', continueWatchingList, ''),

                        _buildMobileRow(
                          'Action & Adventure (Bollywood • South • English)',
                          homeActionList,
                          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=28&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&vote_count.gte=20',
                        ),
                        _buildMobileRow(
                          'Thriller & Suspense (Bollywood • South • English)',
                          homeThrillerSuspenseList,
                          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=53&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&vote_count.gte=15',
                        ),
                        _buildMobileRow(
                          'Crime & Mystery Suspense (Latest Mix)',
                          homeCrimeMysteryList,
                          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=9648,80&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&vote_count.gte=15',
                        ),
                        _buildMobileRow(
                          'Bollywood Latest Movies',
                          homeBollywoodLatestList,
                          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=hi&primary_release_date.lte=$todayIso&vote_count.gte=8',
                        ),
                        _buildMobileRow(
                          'South Latest Movies (Hindi Dubbed)',
                          homeSouthLatestList,
                          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=te|ta|ml|kn&primary_release_date.lte=$todayIso&vote_count.gte=10',
                        ),
                        _buildMobileRow(
                          'English / Hollywood Latest Movies',
                          homeEnglishLatestList,
                          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=en&primary_release_date.lte=$todayIso&vote_count.gte=50',
                        ),
                        _buildMobileRow(
                          'Latest Netflix Blockbusters',
                          homeNetflixList,
                          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=8&watch_region=IN',
                        ),
                        _buildMobileRow(
                          'Amazon Prime Video Hits',
                          homePrimeList,
                          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=119&watch_region=IN',
                        ),
                        _buildMobileRow(
                          'Trending Hindi Web Series',
                          homeHindiSeriesList,
                          '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_original_language=hi&without_genres=10766&vote_count.gte=3',
                          isTv: true,
                        ),
                      ],
                    ),
                  ),
                ),

                // Top Header Bar (Clean alignment: Left Brand + Right Gist Active Pill + Circular Search)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.only(top: 38, left: 16, right: 14, bottom: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.95),
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'NETFLIX',
                          style: TextStyle(
                            color: Color(0xFFE50914),
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (widget.onOpenGistDialog != null)
                          InkWell(
                            onTap: widget.onOpenGistDialog,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: widget.hasGistUrl
                                    ? const Color(0xFF123528).withOpacity(0.92)
                                    : Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: widget.hasGistUrl
                                      ? const Color(0xFF22C55E).withOpacity(0.65)
                                      : Colors.white24,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.link_rounded,
                                    size: 14,
                                    color: widget.hasGistUrl
                                        ? const Color(0xFF22C55E)
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    widget.hasGistUrl ? 'Gist Active' : 'Gist Link',
                                    style: TextStyle(
                                      color: widget.hasGistUrl
                                          ? const Color(0xFF22C55E)
                                          : Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (widget.hasGistUrl) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF22C55E),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MobileSearchScreen(
                                  providers: widget.providers,
                                  onPlaySaved: _loadContinueWatching,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                          ),
                        ),
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
// 2. SEARCH SCREEN (UNCHANGED)
// ============================================================================
class MobileSearchScreen extends StatefulWidget {
  final List<dynamic> providers;
  final VoidCallback? onPlaySaved;

  const MobileSearchScreen({super.key, required this.providers, this.onPlaySaved});

  @override
  State<MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<MobileSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  var searchResults = [];
  bool isSearching = false;
  Timer? _debounce;

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        searchResults.clear();
        isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _executeSearch(query.trim());
    });
  }

  Future<void> _executeSearch(String q) async {
    if (MobileConfig.tmdbKey.isEmpty) return;
    setState(() => isSearching = true);
    final encoded = Uri.encodeComponent(q);
    final url = '${MobileConfig.tmdbBase}/search/multi?api_key=${MobileConfig.tmdbKey}&query=$encoded&language=en-US';

    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['results'];
        var filtered = [];
        final currentYear = DateTime.now().year.toString();

        for (var m in (data ?? [])) {
          final type = m['media_type'];
          if (type != 'movie' && type != 'tv') continue;
          if (m['poster_path'] == null && m['backdrop_path'] == null) continue;
          final title = (m['title'] ?? m['name'] ?? 'Untitled').toString();
          if (isSoapShow(title)) continue;

          filtered.add({
            'tmdb_id': m['id'],
            'title': title,
            'year': (m['release_date'] ?? m['first_air_date'] ?? currentYear).toString().split('-')[0],
            'rating': m['vote_average']?.toString() ?? '7.5',
            'poster': m['poster_path'] != null ? '${MobileConfig.imgBase}${m['poster_path']}' : '${MobileConfig.backdropBase}${m['backdrop_path']}',
            'backdrop': m['backdrop_path'] != null ? '${MobileConfig.backdropBase}${m['backdrop_path']}' : '${MobileConfig.imgBase}${m['poster_path']}',
            'isTv': type == 'tv',
          });
        }

        if (mounted) {
          setState(() {
            searchResults = filtered;
            isSearching = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => isSearching = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search movies, web series...',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white70),
              onPressed: () {
                _searchCtrl.clear();
                _onQueryChanged('');
              },
            ),
        ],
      ),
      body: isSearching
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : searchResults.isEmpty
              ? Center(
                  child: Text(
                    _searchCtrl.text.isEmpty ? 'Search for your favorite content' : 'No results found',
                    style: const TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.64,
                  ),
                  itemCount: searchResults.length,
                  itemBuilder: (ctx, idx) {
                    final item = searchResults[idx];
                    return InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => MediaDetailSheet(
                            item: item,
                            providers: widget.providers,
                            onPlaySaved: widget.onPlaySaved ?? () {},
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          item['poster'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF222222)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ============================================================================
// 3. MY LIST SCREEN (UNCHANGED)
// ============================================================================
class MobileMyListScreen extends StatefulWidget {
  final List<dynamic> providers;
  const MobileMyListScreen({super.key, required this.providers});

  @override
  State<MobileMyListScreen> createState() => _MobileMyListScreenState();
}

class _MobileMyListScreenState extends State<MobileMyListScreen> {
  List watchlist = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('my_watchlist') ?? '[]';
      if (mounted) {
        setState(() {
          watchlist = jsonDecode(raw);
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _onItemSelect(dynamic item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MediaDetailSheet(
        item: item,
        providers: widget.providers,
        onPlaySaved: () => _loadWatchlist(),
      ),
    );
  }

  Future<void> _removeFromList(dynamic item) async {
    final prefs = await SharedPreferences.getInstance();
    watchlist.removeWhere((x) => x['tmdb_id'] == item['tmdb_id']);
    await prefs.setString('my_watchlist', jsonEncode(watchlist));
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from My List'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('My Watchlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadWatchlist,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : watchlist.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      'Your list is empty.\nLong press any movie poster on Home screen to add it here!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.64,
                  ),
                  itemCount: watchlist.length,
                  itemBuilder: (ctx, idx) {
                    final item = watchlist[idx];
                    return GestureDetector(
                      onTap: () => _onItemSelect(item),
                      onLongPress: () => _removeFromList(item),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          item['poster'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF222222)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ============================================================================
// 4. MORE SCREEN (WITH GIST URL SETTING OPTION)
// ============================================================================
class MobileMoreScreen extends StatelessWidget {
  final List<dynamic> providers;
  final VoidCallback onOpenGistSettings;

  const MobileMoreScreen({
    super.key,
    required this.providers,
    required this.onOpenGistSettings,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayIso =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    const mixedLangs = 'hi|en|te|ta|ml|kn';

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Latest Genres & OTT Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.link_rounded, color: Color(0xFFE50914)),
            title: const Text('GitHub Gist Raw Source', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: onOpenGistSettings,
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFE50914)),
            title: const Text('Action & Adventure (Bolly + South + Eng)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Action & Adventure Latest',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=28&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&vote_count.gte=20',
                    isTv: false,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.psychology_rounded, color: Color(0xFFE50914)),
            title: const Text('Thriller & Suspense (Bolly + South + Eng)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Thriller & Suspense Latest',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=53&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&vote_count.gte=15',
                    isTv: false,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.search_rounded, color: Color(0xFFE50914)),
            title: const Text('Crime & Mystery Suspense (Latest Mix)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Crime & Mystery Suspense',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=9648,80&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&vote_count.gte=15',
                    isTv: false,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.movie_filter_rounded, color: Color(0xFFE50914)),
            title: const Text('Bollywood Latest Movies', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Bollywood Latest Movies',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=hi&primary_release_date.lte=$todayIso&vote_count.gte=8',
                    isTv: false,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.local_movies_rounded, color: Color(0xFFE50914)),
            title: const Text('South Latest Movies (Hindi Dubbed)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'South Latest Movies',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=te|ta|ml|kn&primary_release_date.lte=$todayIso&vote_count.gte=10',
                    isTv: false,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.theaters_rounded, color: Color(0xFFE50914)),
            title: const Text('English / Hollywood Latest Movies', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'English / Hollywood Latest',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=en&primary_release_date.lte=$todayIso&vote_count.gte=50',
                    isTv: false,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.video_collection, color: Color(0xFFE50914)),
            title: const Text('Netflix Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Netflix Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=213&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.video_library, color: Color(0xFFE50914)),
            title: const Text('Amazon Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Amazon Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=1024&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
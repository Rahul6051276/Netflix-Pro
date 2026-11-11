// ============================================================================
// NETFLIX PRO MOBILE HOME & NAVIGATION SUITE (AUTO-SLIDE & WORKING MY LIST)
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_config.dart';
import 'category_grid_screen.dart';
import 'stream_resolver_sheet.dart';

class MobileRootScreen extends StatefulWidget {
  const MobileRootScreen({super.key});

  @override
  State<MobileRootScreen> createState() => _MobileRootScreenState();
}

class _MobileRootScreenState extends State<MobileRootScreen> {
  int _currentIndex = 0;
  List<dynamic> activeProviders = [];

  @override
  void initState() {
    super.initState();
    _fetchGlobalProviders();
  }

  Future<void> _fetchGlobalProviders() async {
    try {
      final res = await http.get(Uri.parse(MobileConfig.gistUrl)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            activeProviders = jsonDecode(res.body)['active_providers'] ?? [];
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      MobileHomeScreen(providers: activeProviders),
      MobileSearchScreen(providers: activeProviders),
      const MobileMyListScreen(),
      MobileMoreScreen(providers: activeProviders),
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
// 1. HOME SCREEN (AUTO-SLIDING BANNER & CENTER NETFLIX PRO)
// ============================================================================
class MobileHomeScreen extends StatefulWidget {
  final List<dynamic> providers;
  const MobileHomeScreen({super.key, required this.providers});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  List<dynamic> continueWatchingList = [];
  List<dynamic> homeNetflixList = [];
  List<dynamic> homePrimeList = [];
  List<dynamic> homeHotstarList = [];
  List<dynamic> homeSouthHindiList = [];
  List<dynamic> homeHollywoodHindiList = [];
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
      if (homeNetflixList.isNotEmpty) {
        _startAutoSlide(homeNetflixList.take(5).length);
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

  Future<void> _fetchHomeCatalogContent() async {
    try {
      final netflixRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&sort_by=popularity.desc')).timeout(const Duration(seconds: 4));
      if (netflixRes.statusCode == 200) {
        homeNetflixList = _parseList(jsonDecode(netflixRes.body)['results']);
      }
    } catch (_) {}

    try {
      final primeRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=119&watch_region=IN&sort_by=popularity.desc')).timeout(const Duration(seconds: 4));
      if (primeRes.statusCode == 200) {
        homePrimeList = _parseList(jsonDecode(primeRes.body)['results']);
      }
    } catch (_) {}

    try {
      final hotstarRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/movie/now_playing?api_key=${MobileConfig.tmdbKey}&language=en-US&region=IN')).timeout(const Duration(seconds: 4));
      if (hotstarRes.statusCode == 200) {
        homeHotstarList = _parseList(jsonDecode(hotstarRes.body)['results']);
      }
    } catch (_) {}

    try {
      final southRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=te|ta|ml|kn&sort_by=popularity.desc')).timeout(const Duration(seconds: 4));
      if (southRes.statusCode == 200) {
        homeSouthHindiList = _parseList(jsonDecode(southRes.body)['results']);
      }
    } catch (_) {}

    try {
      final hollywoodRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/movie/popular?api_key=${MobileConfig.tmdbKey}&page=1')).timeout(const Duration(seconds: 4));
      if (hollywoodRes.statusCode == 200) {
        homeHollywoodHindiList = _parseList(jsonDecode(hollywoodRes.body)['results']);
      }
    } catch (_) {}

    try {
      final hindiTvRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=popularity.desc&vote_count.gte=3')).timeout(const Duration(seconds: 4));
      if (hindiTvRes.statusCode == 200) {
        homeHindiSeriesList = _parseList(jsonDecode(hindiTvRes.body)['results'], isTv: true)
            .where((item) => !isSoapShow(item['title'] ?? ''))
            .toList();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from My List'), duration: Duration(seconds: 1)),
      );
    } else {
      list.add(item);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to My List successfully!'), duration: Duration(seconds: 1)),
      );
    }
    await prefs.setString('my_watchlist', jsonEncode(list));
  }

  // AUTO-SLIDING BANNER
  Widget _buildSlidingBanner(List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final bannerItems = items.take(5).toList();

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
            onTap: () => _onItemSelect(item), // Click to play / open stream server
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
                        'Trending • Top Rated • HD',
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

  // CIRCULAR PREVIEWS ROW
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
                        _buildSlidingBanner(homeNetflixList),
                        const SizedBox(height: 6),
                        _buildCircularPreviewsRow(homeNetflixList),
                        const SizedBox(height: 10),

                        if (continueWatchingList.isNotEmpty)
                          _buildMobileRow('Continue Watching', continueWatchingList, ''),

                        _buildMobileRow(
                          'Latest Netflix Blockbusters',
                          homeNetflixList,
                          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=8&watch_region=IN',
                        ),
                        _buildMobileRow(
                          'South Action Hits (Hindi Dubbed)',
                          homeSouthHindiList,
                          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=te|ta|ml|kn',
                        ),
                        _buildMobileRow(
                          'Hollywood Blockbusters (Hindi Dubbed)',
                          homeHollywoodHindiList,
                          '${MobileConfig.tmdbBase}/movie/popular?api_key=${MobileConfig.tmdbKey}',
                        ),
                        _buildMobileRow(
                          'Amazon Prime Video Hits',
                          homePrimeList,
                          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=119&watch_region=IN',
                        ),
                        _buildMobileRow(
                          'Disney+ Hotstar & Cinema Specials',
                          homeHotstarList,
                          '${MobileConfig.tmdbBase}/movie/now_playing?api_key=${MobileConfig.tmdbKey}&language=en-US&region=IN',
                        ),
                      ],
                    ),
                  ),
                ),

                // NETFLIX PRO CENTERED HEADER BAR
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Text(
                          'NETFLIX PRO',
                          style: TextStyle(
                            color: Color(0xFFE50914),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.search, color: Colors.white, size: 26),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => MobileSearchScreen(providers: widget.providers, onPlaySaved: _loadContinueWatching)),
                                );
                              },
                            ),
                          ],
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
// 2. SEARCH SCREEN
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
                        if (item['isTv'] == true) {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => MobileEpisodeSheet(
                              item: item,
                              onSelected: (season, ep) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => MobileStreamSheet(
                                    item: item,
                                    season: season,
                                    episode: ep,
                                    providers: widget.providers,
                                    onPlaySaved: widget.onPlaySaved ?? () {},
                                  ),
                                );
                              },
                            ),
                          );
                        } else {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => MobileStreamSheet(
                              item: item,
                              providers: widget.providers,
                              onPlaySaved: widget.onPlaySaved ?? () {},
                            ),
                          );
                        }
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
// 3. MY LIST SCREEN (WORKING PLAY & AUTO-SYNC)
// ============================================================================
class MobileMyListScreen extends StatefulWidget {
  const MobileMyListScreen({super.key});

  @override
  State<MobileMyListScreen> createState() => _MobileMyListScreenState();
}

class _MobileMyListScreenState extends State<MobileMyListScreen> {
  List watchlist = [];
  bool isLoading = true;
  List<dynamic> activeProviders = [];

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
    _fetchProviders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadWatchlist();
  }

  Future<void> _fetchProviders() async {
    try {
      final res = await http.get(Uri.parse(MobileConfig.gistUrl)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            activeProviders = jsonDecode(res.body)['active_providers'] ?? [];
          });
        }
      }
    } catch (_) {}
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
        onPlaySaved: () => _loadWatchlist(),
      ),
    );
  }

  Future<void> _removeFromList(dynamic item) async {
    final prefs = await SharedPreferences.getInstance();
    watchlist.removeWhere((x) => x['tmdb_id'] == item['tmdb_id']);
    await prefs.setString('my_watchlist', jsonEncode(watchlist));
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Removed from My List'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _loadWatchlist();

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('My Watchlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      onTap: () => _onItemSelect(item), // Click to open stream/server sheet and play!
                      onLongPress: () => _removeFromList(item), // Long press to remove
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
// 4. MORE SCREEN (ONLY REQUESTED OTT WEB SERIES HUB WITH FILTERS)
// ============================================================================
class MobileMoreScreen extends StatelessWidget {
  final List<dynamic> providers;
  const MobileMoreScreen({super.key, required this.providers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('OTT Web Series Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Netflix Web Series
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

          // 2. Amazon Web Series
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
          const Divider(color: Colors.white24),

          // 3. Disney+ Hotstar Web Series
          ListTile(
            leading: const Icon(Icons.live_tv, color: Color(0xFFE50914)),
            title: const Text('Disney+ Hotstar Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Disney+ Hotstar Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=2739&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),

          // 4. Zee5 Web Series
          ListTile(
            leading: const Icon(Icons.tv_rounded, color: Color(0xFFE50914)),
            title: const Text('Zee5 Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'Zee5 Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=2377&without_genres=10766',
                    isTv: true,
                    providers: providers,
                    onPlaySaved: () {},
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),

          // 5. SonyLIV Web Series
          ListTile(
            leading: const Icon(Icons.monitor_rounded, color: Color(0xFFE50914)),
            title: const Text('SonyLIV Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileCategoryGridScreen(
                    title: 'SonyLIV Web Series',
                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=2334&without_genres=10766',
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
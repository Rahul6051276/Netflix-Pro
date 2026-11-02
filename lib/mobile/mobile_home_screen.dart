import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_config.dart';
import 'category_grid_screen.dart';
import 'stream_resolver_sheet.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  List<dynamic> activeProviders = [];
  List<dynamic> continueWatchingList = [];
  dynamic billboardItem;

  List<dynamic> homeNetflixList = [];
  List<dynamic> homePrimeList = [];
  List<dynamic> homeHotstarList = [];
  List<dynamic> homeSouthHindiList = [];
  List<dynamic> homeHollywoodHindiList = [];
  List<dynamic> homeHindiSeriesList = [];
  List<dynamic> homeEnglishSeriesList = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllMobileData();
  }

  Future<void> _loadAllMobileData() async {
    _loadContinueWatching();
    _fetchProviders();
    await _fetchHomeCatalogContent();
    if (mounted) setState(() => isLoading = false);
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

  Future<void> _fetchProviders() async {
    try {
      final res = await http.get(Uri.parse(MobileConfig.gistUrl)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        activeProviders = jsonDecode(res.body)['active_providers'] ?? [];
      }
    } catch (_) {}
  }

  Future<void> _fetchHomeCatalogContent() async {
    try {
      final netflixRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&sort_by=popularity.desc')).timeout(const Duration(seconds: 4));
      if (netflixRes.statusCode == 200) {
        homeNetflixList = _parseList(jsonDecode(netflixRes.body)['results']);
        if (homeNetflixList.isNotEmpty) billboardItem = homeNetflixList.first;
      }
    } catch (_) {}

    try {
      final primeRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_watch_providers=119&watch_region=IN&sort_by=popularity.desc')).timeout(const Duration(seconds: 4));
      if (primeRes.statusCode == 200) {
        homePrimeList = _parseList(jsonDecode(primeRes.body)['results']);
        billboardItem ??= homePrimeList.isNotEmpty ? homePrimeList.first : null;
      }
    } catch (_) {}

    try {
      final hotstarRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/movie/now_playing?api_key=${MobileConfig.tmdbKey}&language=en-US&region=IN')).timeout(const Duration(seconds: 4));
      if (hotstarRes.statusCode == 200) {
        homeHotstarList = _parseList(jsonDecode(hotstarRes.body)['results']);
        billboardItem ??= homeHotstarList.isNotEmpty ? homeHotstarList.first : null;
      }
    } catch (_) {}

    try {
      final southRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=te|ta|ml|kn&sort_by=popularity.desc')).timeout(const Duration(seconds: 4));
      if (southRes.statusCode == 200) {
        homeSouthHindiList = _parseList(jsonDecode(southRes.body)['results']);
        billboardItem ??= homeSouthHindiList.isNotEmpty ? homeSouthHindiList.first : null;
      }
    } catch (_) {}

    try {
      final hollywoodRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/movie/popular?api_key=${MobileConfig.tmdbKey}&page=1')).timeout(const Duration(seconds: 4));
      if (hollywoodRes.statusCode == 200) {
        homeHollywoodHindiList = _parseList(jsonDecode(hollywoodRes.body)['results']);
        billboardItem ??= homeHollywoodHindiList.isNotEmpty ? homeHollywoodHindiList.first : null;
      }
    } catch (_) {}

    try {
      final hindiTvRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=popularity.desc&vote_count.gte=3')).timeout(const Duration(seconds: 4));
      if (hindiTvRes.statusCode == 200) {
        homeHindiSeriesList = _parseList(jsonDecode(hindiTvRes.body)['results'], isTv: true)
            .where((item) => !isSoapShow(item['title'] ?? ''))
            .toList();
        billboardItem ??= homeHindiSeriesList.isNotEmpty ? homeHindiSeriesList.first : null;
      }
    } catch (_) {}

    try {
      final engTvRes = await http.get(Uri.parse(
          '${MobileConfig.tmdbBase}/tv/on_the_air?api_key=${MobileConfig.tmdbKey}&language=en-US')).timeout(const Duration(seconds: 4));
      if (engTvRes.statusCode == 200) {
        homeEnglishSeriesList = _parseList(jsonDecode(engTvRes.body)['results'], isTv: true);
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
        providers: activeProviders,
        onPlaySaved: () => _loadContinueWatching(),
      ),
    );
  }

  Widget _buildTopPill(String title, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white30, width: 1.0),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBillboard(dynamic item) {
    if (item == null) return const SizedBox.shrink();

    final String imgUrl = (item['backdrop'] != null && item['backdrop'].toString().isNotEmpty)
        ? item['backdrop'].toString()
        : (item['poster'] != null ? item['poster'].toString() : '');

    return SizedBox(
      height: 490,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imgUrl.isNotEmpty)
            Image.network(
              imgUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1F1F1F)),
            )
          else
            Container(color: const Color(0xFF1F1F1F)),

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
                stops: [0.0, 0.42, 0.78, 1.0],
              ),
            ),
          ),

          Positioned(
            bottom: 14,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (item['title'] ?? item['name'] ?? '').toString(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(blurRadius: 10, color: Colors.black, offset: Offset(0, 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Action • Suspense • Blockbuster • HD',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        onPressed: () => _onItemSelect(item),
                        icon: const Icon(Icons.play_arrow, size: 26, color: Colors.black),
                        label: const Text('Play', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B2B2B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        onPressed: () => _onItemSelect(item),
                        icon: const Icon(Icons.add, size: 24, color: Colors.white),
                        label: const Text('My List', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRow(
    String title,
    List<dynamic> items,
    String baseUrl, {
    bool isTv = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    void openSeeAll() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MobileCategoryGridScreen(
            title: title,
            baseUrl: baseUrl,
            isTv: isTv,
            providers: activeProviders,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
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
          height: 175,
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
              final String cardImg = (item['poster'] != null && item['poster'].toString().isNotEmpty)
                  ? item['poster'].toString()
                  : (item['backdrop'] != null ? item['backdrop'].toString() : '');

              return InkWell(
                onTap: () => _onItemSelect(item),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 115,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cardImg.isNotEmpty)
                        Image.network(
                          cardImg,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF222222),
                            child: const Center(child: Icon(Icons.movie, color: Colors.white24)),
                          ),
                        )
                      else
                        Container(
                          color: const Color(0xFF222222),
                          child: const Center(child: Icon(Icons.movie, color: Colors.white24)),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black, Colors.transparent],
                            ),
                          ),
                          child: Text(
                            item['title'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
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
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeItem = billboardItem ??
        (homeNetflixList.isNotEmpty
            ? homeNetflixList.first
            : (homePrimeList.isNotEmpty
                ? homePrimeList.first
                : (homeSouthHindiList.isNotEmpty
                    ? homeSouthHindiList.first
                    : {
                        'title': 'The Dark Knight',
                        'backdrop': 'https://image.tmdb.org/t/p/w1280/nMKdUUepR0i5zn0y1T4CsSB5chy.jpg',
                        'poster': 'https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haRef0WH.jpg',
                        'tmdb_id': 155,
                        'isTv': false,
                      })));

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : Stack(
              children: [
                // Scrollable Content
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
                        _buildMobileBillboard(activeItem),
                        const SizedBox(height: 10),

                        if (continueWatchingList.isNotEmpty)
                          _buildMobileRow(
                            'Continue Watching for Rahul',
                            continueWatchingList,
                            '',
                          ),

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

                        _buildMobileRow(
                          'Latest Hindi Web Series',
                          homeHindiSeriesList,
                          '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_original_language=hi&without_genres=10766&vote_count.gte=3',
                          isTv: true,
                        ),

                        _buildMobileRow(
                          'Global Hits On The Air',
                          homeEnglishSeriesList,
                          '${MobileConfig.tmdbBase}/tv/on_the_air?api_key=${MobileConfig.tmdbKey}&language=en-US',
                          isTv: true,
                        ),
                      ],
                    ),
                  ),
                ),

                // Top Sticky Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'For Rahul',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white, size: 24),
                                  onPressed: () {},
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 18),
                                IconButton(
                                  icon: const Icon(Icons.search, color: Colors.white, size: 24),
                                  onPressed: () {},
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildTopPill('TV Shows', onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MobileCategoryGridScreen(
                                    title: 'TV Shows',
                                    baseUrl: '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}',
                                    isTv: true,
                                    providers: activeProviders,
                                    onPlaySaved: () => _loadContinueWatching(),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(width: 8),
                            _buildTopPill('Movies', onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MobileCategoryGridScreen(
                                    title: 'Movies',
                                    baseUrl: '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}',
                                    isTv: false,
                                    providers: activeProviders,
                                    onPlaySaved: () => _loadContinueWatching(),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(width: 8),
                            _buildTopPill('Categories ⌵', onTap: () => openCategoriesModal(context, activeProviders, () => _loadContinueWatching())),
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

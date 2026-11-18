import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_config.dart';
import 'category_grid_screen.dart';
import 'stream_resolver_sheet.dart';
import 'tv_search_screen.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  int _selectedNavIndex = 2; // Default Home
  final List<FocusNode> _sidebarFocusNodes = List.generate(7, (_) => FocusNode());
  final FocusNode _firstContentCardFocus = FocusNode();
  final FocusNode _watchNowFocusNode = FocusNode();

  List activeProviders = [];
  String currentGistUrl = '';
  bool isGistConnected = false;

  List continueWatchingList = [];
  dynamic activeShowcaseItem;

  // Home Fast Lists
  List homeBollywoodLatestList = [];
  List homeNetflixList = [];
  List homePrimeList = [];
  List homeHotstarList = [];
  List homeHindiSeriesList = [];
  List homeEnglishSeriesList = [];

  // Dedicated Movies Section (200+ Items Each)
  List allBollywoodMovies = [];
  List allSouthMovies = [];
  List allHollywoodMovies = [];

  // Dedicated Web Series Section (200+ Items Each)
  List allHindiSeries = [];
  List allNetflixSeries = [];
  List allAmazonSeries = [];
  List allSouthSeries = [];

  bool isLoading = true;
  String _catalogSortType = 'latest';

  @override
  void initState() {
    super.initState();
    _loadAllTvData();
  }

  @override
  void dispose() {
    for (var node in _sidebarFocusNodes) {
      node.dispose();
    }
    _firstContentCardFocus.dispose();
    _watchNowFocusNode.dispose();
    super.dispose();
  }

  void _jumpFocusToSidebar() {
    final activeIndex = _selectedNavIndex.clamp(0, _sidebarFocusNodes.length - 1);
    _sidebarFocusNodes[activeIndex].requestFocus();
  }

  void _jumpFocusToContent() {
    _firstContentCardFocus.requestFocus();
  }

  Future _loadAllTvData() async {
    await Future.wait([
      _fetchProviders(),
      _loadContinueWatching(),
      _fetchHomeCatalogContent(),
    ]);
    if (mounted) setState(() => isLoading = false);
    _fetchDeepCatalogs();
  }

  Future _loadContinueWatching() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('continue_watching_tv');
      if (raw != null && raw.isNotEmpty && mounted) {
        setState(() {
          continueWatchingList = jsonDecode(raw) as List;
        });
      }
    } catch (_) {}
  }

  Future _fetchProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGist = (prefs.getString('tv_custom_gist_url') ?? '').trim();

    if (savedGist.isEmpty) {
      await prefs.remove('tv_cached_active_providers');
      if (mounted) {
        setState(() {
          currentGistUrl = '';
          activeProviders = [];
          isGistConnected = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && currentGistUrl.isEmpty) {
            _openTvGistDialog();
          }
        });
      }
      return;
    }

    currentGistUrl = savedGist;
    final cached = prefs.getString('tv_cached_active_providers');
    if (cached != null && cached.isNotEmpty && mounted) {
      try {
        final list = jsonDecode(cached) as List;
        setState(() {
          activeProviders = list;
          isGistConnected = list.isNotEmpty;
        });
      } catch (_) {}
    }

    try {
      final sep = currentGistUrl.contains('?') ? '&' : '?';
      final url = '$currentGistUrl${sep}t=${DateTime.now().millisecondsSinceEpoch}';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['active_providers'] ?? decoded['providers'] ?? []);
        if (list is List && list.isNotEmpty) {
          await prefs.setString('tv_cached_active_providers', jsonEncode(list));
          if (mounted) {
            setState(() {
              activeProviders = list;
              isGistConnected = true;
            });
          }
        }
      }
    } catch (_) {}
  }

  void _openTvGistDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _TvGistManagerDialog(
        initialUrl: currentGistUrl,
        currentProviders: activeProviders,
        onSynced: (newUrl, newProviders) {
          if (mounted) {
            setState(() {
              currentGistUrl = newUrl;
              activeProviders = newProviders;
              isGistConnected = newUrl.isNotEmpty && newProviders.isNotEmpty;
            });
          }
        },
      ),
    );
  }

  // Fast Parallel Instant Render for Home Screen
  Future _fetchHomeCatalogContent() async {
    await Future.wait([
      // 0. Latest Bollywood Movies
      () async {
        try {
          final bollyRes = await http.get(Uri.parse(
              '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=hi&region=IN&sort_by=primary_release_date.desc&vote_count.gte=2')).timeout(const Duration(seconds: 6));
          if (bollyRes.statusCode == 200) {
            homeBollywoodLatestList = _parseTvList(jsonDecode(bollyRes.body)['results']);
            if (homeBollywoodLatestList.isNotEmpty) {
              activeShowcaseItem = homeBollywoodLatestList.first;
            }
          }
        } catch (_) {}
      }(),

      // 1. Netflix Latest
      () async {
        try {
          final netflixRes = await http.get(Uri.parse(
              '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&sort_by=primary_release_date.desc')).timeout(const Duration(seconds: 6));
          if (netflixRes.statusCode == 200) {
            homeNetflixList = _parseTvList(jsonDecode(netflixRes.body)['results']);
            if (activeShowcaseItem == null && homeNetflixList.isNotEmpty) {
              activeShowcaseItem = homeNetflixList.first;
            }
          }
        } catch (_) {}
      }(),

      // 2. Prime Video Latest
      () async {
        try {
          final primeRes = await http.get(Uri.parse(
              '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_watch_providers=119&watch_region=IN&sort_by=primary_release_date.desc')).timeout(const Duration(seconds: 6));
          if (primeRes.statusCode == 200) {
            homePrimeList = _parseTvList(jsonDecode(primeRes.body)['results']);
            if (activeShowcaseItem == null && homePrimeList.isNotEmpty) {
              activeShowcaseItem = homePrimeList.first;
            }
          }
        } catch (_) {}
      }(),

      // 3. Hotstar & Disney Specials
      () async {
        try {
          final hotstarRes = await http.get(Uri.parse(
              '${TvConfig.tmdbBase}/movie/now_playing?api_key=${TvConfig.tmdbKey}&language=en-US&region=IN')).timeout(const Duration(seconds: 6));
          if (hotstarRes.statusCode == 200) {
            homeHotstarList = _parseTvList(jsonDecode(hotstarRes.body)['results']);
          }
        } catch (_) {}
      }(),

      // 4. Hindi Web Series
      () async {
        try {
          final hindiTvRes = await http.get(Uri.parse(
              '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=popularity.desc&vote_count.gte=5')).timeout(const Duration(seconds: 6));
          if (hindiTvRes.statusCode == 200) {
            homeHindiSeriesList = _parseTvList(jsonDecode(hindiTvRes.body)['results'], isTv: true)
                .where((item) => !isSoapShow(item['title'] ?? ''))
                .toList();
          }
        } catch (_) {}
      }(),

      // 5. Global Web Series
      () async {
        try {
          final engTvRes = await http.get(Uri.parse(
              '${TvConfig.tmdbBase}/tv/on_the_air?api_key=${TvConfig.tmdbKey}&language=en-US')).timeout(const Duration(seconds: 6));
          if (engTvRes.statusCode == 200) {
            homeEnglishSeriesList = _parseTvList(jsonDecode(engTvRes.body)['results'], isTv: true);
          }
        } catch (_) {}
      }(),
    ]);
  }

  // Deep Fetch 200+ Titles via Parallel Multi-page Pagination
  Future _fetchDeepCatalogs() async {
    final sortQuery = _catalogSortType == 'latest'
        ? 'primary_release_date.desc'
        : 'popularity.desc';
    final sortTvQuery = _catalogSortType == 'latest'
        ? 'first_air_date.desc'
        : 'popularity.desc';

    await Future.wait([
      _fetchPages(
        baseUrl: '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=hi&sort_by=$sortQuery',
        isTv: false,
        onDone: (list) {
          if (mounted) setState(() => allBollywoodMovies = list);
        },
      ),
      _fetchPages(
        baseUrl: '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn&sort_by=$sortQuery',
        isTv: false,
        onDone: (list) {
          if (mounted) setState(() => allSouthMovies = list);
        },
      ),
      _fetchPages(
        baseUrl: '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&sort_by=$sortQuery',
        isTv: false,
        onDone: (list) {
          if (mounted) setState(() => allHollywoodMovies = list);
        },
      ),
      _fetchPages(
        baseUrl: '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=hi&without_genres=10766&vote_count.gte=5&sort_by=$sortTvQuery',
        isTv: true,
        onDone: (list) {
          if (mounted) {
            setState(() => allHindiSeries = list.where((i) => !isSoapShow(i['title'] ?? '')).toList());
          }
        },
      ),
      _fetchPages(
        baseUrl: '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_networks=213&without_genres=10766&sort_by=$sortTvQuery',
        isTv: true,
        onDone: (list) {
          if (mounted) {
            setState(() => allNetflixSeries = list.where((i) => !isSoapShow(i['title'] ?? '')).toList());
          }
        },
      ),
      _fetchPages(
        baseUrl: '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_networks=1024&without_genres=10766&sort_by=$sortTvQuery',
        isTv: true,
        onDone: (list) {
          if (mounted) {
            setState(() => allAmazonSeries = list.where((i) => !isSoapShow(i['title'] ?? '')).toList());
          }
        },
      ),
      _fetchPages(
        baseUrl: '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=te%7Cta%7Cml&sort_by=$sortTvQuery',
        isTv: true,
        onDone: (list) {
          if (mounted) setState(() => allSouthSeries = list);
        },
      ),
    ]);
  }

  Future _fetchPages({
    required String baseUrl,
    required bool isTv,
    required Function(List) onDone,
  }) async {
    final pageFutures = List.generate(8, (index) async {
      final p = index + 1;
      try {
        final res = await http.get(Uri.parse('$baseUrl&page=$p')).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body)['results'];
          return _parseTvList(data, isTv: isTv);
        }
      } catch (_) {}
      return [];
    });

    final results = await Future.wait(pageFutures);
    final accumulated = results.expand((e) => e).toList();
    onDone(accumulated);
  }

  void _toggleSortType() {
    setState(() {
      _catalogSortType = _catalogSortType == 'latest' ? 'popular' : 'latest';
      isLoading = true;
    });
    _fetchDeepCatalogs().then((_) {
      if (mounted) setState(() => isLoading = false);
    });
  }

  List _parseTvList(dynamic list, {bool isTv = false}) {
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
            ? '${TvConfig.backdropBase}${m['backdrop_path']}'
            : '${TvConfig.imgBase}${m['poster_path']}',
        'poster': m['poster_path'] != null
            ? '${TvConfig.imgBase}${m['poster_path']}'
            : '${TvConfig.backdropBase}${m['backdrop_path']}',
        'overview': m['overview'] ?? '',
        'original_language': m['original_language'] ?? '',
        'isTv': isTv,
      });
    }
    return res;
  }

  void _onTvItemSelect(dynamic item) {
    if (!isGistConnected || activeProviders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFE50914),
          content: Text('Please add your GitHub Gist link in the Left Sidebar first!'),
          duration: Duration(seconds: 2),
        ),
      );
      _openTvGistDialog();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TvMediaDetailScreen(
          item: item,
          onPlaySaved: () => _loadContinueWatching(),
        ),
      ),
    );
  }

  // ============================================================================
  // NETFLIX RED MINIMAL SLIM SIDEBAR (WITH GIST LINK MANAGER)
  // ============================================================================
  Widget _buildNetflixNavRail() {
    final icons = [
      Icons.person_outline_rounded, // 0
      Icons.search_rounded,         // 1: Search
      Icons.home_filled,            // 2: Home
      Icons.movie_creation_outlined,// 3: Movies
      Icons.tv_rounded,             // 4: Web Series
      Icons.grid_view_rounded,      // 5: Explore
      Icons.link_rounded,           // 6: Gist Link Manager
    ];

    return Container(
      width: 60,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFE50914),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 26),
          Expanded(
            child: ListView.separated(
              itemCount: icons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (ctx, i) {
                final bool isGistItem = (i == 6);
                return NetflixSidebarIcon(
                  focusNode: _sidebarFocusNodes[i],
                  icon: icons[i],
                  isSelected: _selectedNavIndex == i,
                  customColor: isGistItem
                      ? (isGistConnected ? const Color(0xFF22C55E) : const Color(0xFFEF4444))
                      : null,
                  onRightArrow: _jumpFocusToContent,
                  onTap: () {
                    if (isGistItem) {
                      _openTvGistDialog();
                    } else {
                      setState(() => _selectedNavIndex = i);
                      _jumpFocusToContent();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // NETFLIX BILLBOARD SHOWCASE
  // ============================================================================
  Widget _buildNetflixBillboard(dynamic item) {
    return SizedBox(
      height: 340,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Colors.black],
                  stops: [0.0, 0.45],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: Image.network(
                item['backdrop'],
                fit: BoxFit.cover,
                alignment: Alignment.topRight,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF141414)),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x66141414), Color(0xFF141414)],
                  stops: [0.2, 0.65, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 24,
            right: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('NETFLIX PRO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['isTv'] == true ? 'S E R I E S' : 'M O V I E',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _openTvGistDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isGistConnected ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isGistConnected ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          ),
                        ),
                        child: Text(
                          isGistConnected ? '● Gist Active' : '● Add Gist in Sidebar',
                          style: TextStyle(
                            color: isGistConnected ? const Color(0xFF4ADE80) : Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item['title'].toString().toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${item['rating']} ★ Match', style: const TextStyle(color: Color(0xFF46D369), fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Text('${item['year']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(3)),
                      child: const Text('Ultra HD 4K', style: TextStyle(color: Colors.white70, fontSize: 9)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  (item['overview'] ?? '').toString().isNotEmpty
                      ? item['overview']
                      : 'Stream latest releases in high quality with high-speed playback.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Focus(
                      focusNode: _watchNowFocusNode,
                      onKey: (node, event) {
                        if (event is RawKeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.select ||
                                event.logicalKey == LogicalKeyboardKey.enter)) {
                          _onTvItemSelect(item);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Builder(builder: (c) {
                        final focused = Focus.of(c).hasFocus;
                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: focused ? Colors.white : const Color(0xFFE50914),
                            foregroundColor: focused ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            side: BorderSide(
                              color: focused ? Colors.white : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          onPressed: () => _onTvItemSelect(item),
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: const Text('Watch Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        );
                      }),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _openTvGistDialog,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.link_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text('Gist URL', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
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

  // ============================================================================
  // NETFLIX LANDSCAPE ROW WITH DIRECT SEE-ALL INTEGRATION
  // ============================================================================
  Widget _buildNetflixRow(
    String title,
    List items,
    String baseUrl, {
    bool isFirstRow = false,
    bool isTv = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    void openSeeAll() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TVCategoryGridScreen(
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              InkWell(
                onTap: openSeeAll,
                child: Text(
                  '${items.length} Titles  •  See All →',
                  style: const TextStyle(color: Color(0xFFE50914), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length + 1,
            itemBuilder: (ctx, idx) {
              if (idx == items.length) {
                return Container(
                  width: 160,
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Focus(
                    child: Builder(
                      builder: (context) {
                        final isFocused = Focus.of(context).hasFocus;
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: openSeeAll,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222222),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isFocused ? Colors.white : Colors.white24,
                                width: isFocused ? 2.5 : 1.0,
                              ),
                              boxShadow: isFocused
                                  ? [BoxShadow(color: const Color(0xFFE50914).withOpacity(0.55), blurRadius: 10, spreadRadius: 2)]
                                  : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.grid_view_rounded, color: Color(0xFFE50914), size: 32),
                                SizedBox(height: 6),
                                Text('See All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Explore Catalog', style: TextStyle(color: Colors.white60, fontSize: 11)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }

              final currentItem = items[idx];
              return NetflixCard(
                focusNode: (isFirstRow && idx == 0) ? _firstContentCardFocus : null,
                item: currentItem,
                isFirstInRow: idx == 0,
                onLeftBoundaryHit: _jumpFocusToSidebar,
                onFocusGained: () {
                  setState(() => activeShowcaseItem = currentItem);
                },
                onTap: () => _onTvItemSelect(currentItem),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Focus(
            onKey: (node, event) {
              if (event is RawKeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter)) {
                _toggleSortType();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Builder(builder: (c) {
              final focused = Focus.of(c).hasFocus;
              return InkWell(
                onTap: _toggleSortType,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: focused ? Colors.white : const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _catalogSortType == 'latest' ? Icons.fiber_new_rounded : Icons.whatshot_rounded,
                        size: 15,
                        color: focused ? Colors.black : const Color(0xFFE50914),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _catalogSortType == 'latest' ? 'Filter: Latest Releases' : 'Filter: Most Popular',
                        style: TextStyle(
                          color: focused ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Row(
        children: [
          _buildNetflixNavRail(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : _selectedNavIndex == 1
                    ? TvSearchScreen(
                        searchBoxFocusNode: _firstContentCardFocus,
                        onLeftBoundaryHit: _jumpFocusToSidebar,
                        onItemSelected: _onTvItemSelect,
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TAB 2: MAIN HOME (LATEST MIX)
                            if (_selectedNavIndex == 2 || _selectedNavIndex == 0) ...[
                              if (activeShowcaseItem != null) _buildNetflixBillboard(activeShowcaseItem!),
                              if (continueWatchingList.isNotEmpty)
                                _buildNetflixRow(
                                  'Continue Watching',
                                  continueWatchingList,
                                  '',
                                  isFirstRow: true,
                                ),
                              if (homeBollywoodLatestList.isNotEmpty)
                                _buildNetflixRow(
                                  'Latest Bollywood Movies',
                                  homeBollywoodLatestList,
                                  '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=hi',
                                  isFirstRow: continueWatchingList.isEmpty,
                                ),
                              if (homeNetflixList.isNotEmpty)
                                _buildNetflixRow(
                                  'Latest Netflix Blockbusters (Hindi + Global)',
                                  homeNetflixList,
                                  '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_watch_providers=8&watch_region=IN',
                                  isFirstRow: continueWatchingList.isEmpty && homeBollywoodLatestList.isEmpty,
                                ),
                              if (homePrimeList.isNotEmpty)
                                _buildNetflixRow(
                                  'Amazon Prime Video Hits',
                                  homePrimeList,
                                  '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_watch_providers=119&watch_region=IN',
                                ),
                              if (homeHotstarList.isNotEmpty)
                                _buildNetflixRow(
                                  'Disney+ Hotstar & Cinema Specials',
                                  homeHotstarList,
                                  '${TvConfig.tmdbBase}/movie/now_playing?api_key=${TvConfig.tmdbKey}&language=en-US&region=IN',
                                ),
                              if (homeHindiSeriesList.isNotEmpty)
                                _buildNetflixRow(
                                  'Latest Hindi Web Series',
                                  homeHindiSeriesList,
                                  '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=hi&without_genres=10766&vote_count.gte=5',
                                  isTv: true,
                                ),
                              if (homeEnglishSeriesList.isNotEmpty)
                                _buildNetflixRow(
                                  'Global Hits On The Air',
                                  homeEnglishSeriesList,
                                  '${TvConfig.tmdbBase}/tv/on_the_air?api_key=${TvConfig.tmdbKey}&language=en-US',
                                  isTv: true,
                                ),
                            ],

                            // TAB 3: DEDICATED MOVIES SECTION (200+ CATALOG)
                            if (_selectedNavIndex == 3) ...[
                              _buildCategoryHeader('All Movies (200+ Titles Per Hub)'),
                              if (activeShowcaseItem != null) _buildNetflixBillboard(activeShowcaseItem!),
                              _buildNetflixRow(
                                'Bollywood Hit Movies',
                                allBollywoodMovies.isNotEmpty ? allBollywoodMovies : homeBollywoodLatestList,
                                '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=hi',
                                isFirstRow: true,
                              ),
                              _buildNetflixRow(
                                'South Indian Blockbusters (Hindi Dubbed)',
                                allSouthMovies.isNotEmpty ? allSouthMovies : homePrimeList,
                                '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn',
                              ),
                              _buildNetflixRow(
                                'Hollywood Blockbusters (Hindi Dubbed & Global)',
                                allHollywoodMovies.isNotEmpty ? allHollywoodMovies : homeHotstarList,
                                '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}',
                              ),
                            ],

                            // TAB 4: DEDICATED WEB SERIES SECTION (200+ CATALOG)
                            if (_selectedNavIndex == 4) ...[
                              _buildCategoryHeader('All Web Series (Hindi, Netflix, Amazon & South)'),
                              if (activeShowcaseItem != null) _buildNetflixBillboard(activeShowcaseItem!),
                              _buildNetflixRow(
                                'All Hindi Web Series',
                                allHindiSeries.isNotEmpty ? allHindiSeries : homeHindiSeriesList,
                                '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=hi&without_genres=10766&vote_count.gte=5',
                                isFirstRow: true,
                                isTv: true,
                              ),
                              _buildNetflixRow(
                                'All Netflix Series',
                                allNetflixSeries.isNotEmpty ? allNetflixSeries : homeEnglishSeriesList,
                                '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_networks=213&without_genres=10766',
                                isTv: true,
                              ),
                              _buildNetflixRow(
                                'All Amazon Series',
                                allAmazonSeries.isNotEmpty ? allAmazonSeries : homeHindiSeriesList,
                                '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_networks=1024&without_genres=10766',
                                isTv: true,
                              ),
                              _buildNetflixRow(
                                'All South Indian Web Series',
                                allSouthSeries,
                                '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=te%7Cta%7Cml',
                                isTv: true,
                              ),
                            ],

                            // TAB 5: EXPLORE ALL
                            if (_selectedNavIndex == 5) ...[
                              _buildCategoryHeader('Explore All Collections'),
                              _buildNetflixRow(
                                'Bollywood Top Rated',
                                homeBollywoodLatestList.isNotEmpty ? homeBollywoodLatestList : homeNetflixList,
                                '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=hi',
                                isFirstRow: true,
                              ),
                              _buildNetflixRow(
                                'South Indian Hits',
                                homePrimeList,
                                '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn',
                              ),
                              _buildNetflixRow(
                                'Hollywood Dubbed Hits',
                                homeHotstarList,
                                '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}',
                              ),
                              _buildNetflixRow(
                                'Hindi Originals',
                                homeHindiSeriesList,
                                '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=hi&without_genres=10766&vote_count.gte=5',
                                isTv: true,
                              ),
                              _buildNetflixRow(
                                'Netflix Originals',
                                allNetflixSeries.isNotEmpty ? allNetflixSeries : homeEnglishSeriesList,
                                '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_networks=213&without_genres=10766',
                                isTv: true,
                              ),
                              _buildNetflixRow(
                                'Amazon Prime Originals',
                                allAmazonSeries.isNotEmpty ? allAmazonSeries : homeHindiSeriesList,
                                '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_networks=1024&without_genres=10766',
                                isTv: true,
                              ),
                            ],
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
// TV GITHUB GIST URL MANAGER DIALOG
// ============================================================================
class _TvGistManagerDialog extends StatefulWidget {
  final String initialUrl;
  final List currentProviders;
  final Function(String newUrl, List newProviders) onSynced;

  const _TvGistManagerDialog({
    required this.initialUrl,
    required this.currentProviders,
    required this.onSynced,
  });

  @override
  State<_TvGistManagerDialog> createState() => _TvGistManagerDialogState();
}

class _TvGistManagerDialogState extends State<_TvGistManagerDialog> {
  late TextEditingController _urlController;
  bool _isSyncing = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    if (widget.initialUrl.isNotEmpty && widget.currentProviders.isNotEmpty) {
      _statusMessage = 'Connected (${widget.currentProviders.length} active sources)';
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveAndSyncGist() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _statusMessage = 'Please paste a valid GitHub Gist Raw URL';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isSyncing = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      final sep = rawUrl.contains('?') ? '&' : '?';
      final testUrl = '$rawUrl${sep}t=${DateTime.now().millisecondsSinceEpoch}';
      final res = await http.get(Uri.parse(testUrl)).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['active_providers'] ?? decoded['providers'] ?? []);

        if (list is List && list.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('tv_custom_gist_url', rawUrl);
          await prefs.setString('tv_cached_active_providers', jsonEncode(list));

          widget.onSynced(rawUrl, list);
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF16A34A),
                content: Text('Gist Connected! ${list.length} providers synced.'),
              ),
            );
          }
        } else {
          setState(() {
            _statusMessage = 'No active providers found in this Gist JSON.';
            _isError = true;
          });
        }
      } else {
        setState(() {
          _statusMessage = 'Failed to load URL (HTTP ${res.statusCode})';
          _isError = true;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection error: Invalid URL or no internet.';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _clearGist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tv_custom_gist_url');
    await prefs.remove('tv_cached_active_providers');
    _urlController.clear();
    widget.onSynced('', []);
    if (mounted) {
      setState(() {
        _statusMessage = 'Gist URL cleared.';
        _isError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white24),
      ),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.link_rounded, color: Color(0xFFE50914), size: 24),
                    SizedBox(width: 10),
                    Text(
                      'GitHub Gist Source Manager',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste your GitHub Gist Raw JSON link below to unlock streaming providers:',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://gist.githubusercontent.com/.../raw/providers.json',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF262626),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.8),
                ),
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _isError ? const Color(0xFFEF4444) : const Color(0xFF4ADE80),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.initialUrl.isNotEmpty)
                  TextButton(
                    onPressed: _isSyncing ? null : _clearGist,
                    child: const Text(
                      'Remove Link',
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _isSyncing ? null : _saveAndSyncGist,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(
                    _isSyncing ? 'Syncing...' : 'Save & Sync Gist',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// NETFLIX MINIMAL SIDEBAR ICON
// ============================================================================
class NetflixSidebarIcon extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final bool isSelected;
  final Color? customColor;
  final VoidCallback onRightArrow;
  final VoidCallback onTap;

  const NetflixSidebarIcon({
    super.key,
    required this.focusNode,
    required this.icon,
    required this.isSelected,
    this.customColor,
    required this.onRightArrow,
    required this.onTap,
  });

  @override
  State createState() => _NetflixSidebarIconState();
}

class _NetflixSidebarIconState extends State<NetflixSidebarIcon> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final activeIconColor = widget.customColor ??
        (widget.isSelected ? const Color(0xFFE50914) : Colors.white38);

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _isFocused = f),
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            widget.onRightArrow();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isFocused ? Colors.white24 : Colors.transparent,
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Icon(
            widget.icon,
            color: _isFocused ? Colors.white : activeIconColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// NETFLIX POSTER CARD (NETFLIX RED/WHITE BORDER & HOVER SCALE)
// ============================================================================
class NetflixCard extends StatefulWidget {
  final FocusNode? focusNode;
  final dynamic item;
  final bool isFirstInRow;
  final VoidCallback onLeftBoundaryHit;
  final VoidCallback onFocusGained;
  final VoidCallback onTap;

  const NetflixCard({
    super.key,
    this.focusNode,
    required this.item,
    this.isFirstInRow = false,
    required this.onLeftBoundaryHit,
    required this.onFocusGained,
    required this.onTap,
  });

  @override
  State createState() => _NetflixCardState();
}

class _NetflixCardState extends State<NetflixCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) {
        setState(() => _isFocused = f);
        if (f) widget.onFocusGained();
      },
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft && widget.isFirstInRow) {
            widget.onLeftBoundaryHit();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: 175,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isFocused ? Colors.white : Colors.transparent,
                width: 2.2,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE50914).withOpacity(0.55),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.item['backdrop'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF222222)),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      color: Colors.black87,
                      child: Text(
                        widget.item['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
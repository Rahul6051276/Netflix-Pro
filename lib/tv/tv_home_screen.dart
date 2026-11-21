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
  final List<FocusNode> _sidebarFocusNodes = List.generate(6, (_) => FocusNode());
  final FocusNode _gistSidebarFocusNode = FocusNode();
  final FocusNode _firstContentCardFocus = FocusNode();
  final FocusNode _watchNowFocusNode = FocusNode();

  bool _hasGistUrl = false;

  List activeProviders = [];
  List continueWatchingList = [];
  dynamic activeShowcaseItem;

  // Home Fast Lists
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
    _gistSidebarFocusNode.dispose();
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

  String _formatTvConnectedProviders() {
    if (activeProviders.isEmpty) {
      return 'Connected: Gist Source Active';
    }
    final names = activeProviders
        .map((p) => p is Map
            ? (p['name'] ?? p['title'] ?? p['id'] ?? '').toString()
            : p.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      return 'Connected: ${activeProviders.length} Active Sources';
    }
    return 'Connected: ${names.join(' + ')}';
  }

  bool _isRemoteOkKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  void _showGistConfigDialog() {
    final controller = TextEditingController();
    final FocusNode inputFocus = FocusNode(debugLabel: 'tv_gist_input');
    final FocusNode syncFocus = FocusNode(debugLabel: 'tv_gist_sync');
    final FocusNode clearFocus = FocusNode(debugLabel: 'tv_gist_clear');
    final FocusNode closeFocus = FocusNode(debugLabel: 'tv_gist_close');

    TvConfig.getGistUrl().then((existing) {
      controller.text = existing;
      if (!mounted) return;
      bool isSyncing = false;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) {
            final bool isConnected = controller.text.trim().isNotEmpty;

            Future<void> handleConnectAndSync() async {
              if (isSyncing) return;
              final val = controller.text.trim();
              if (val.isEmpty) return;
              setModalState(() => isSyncing = true);
              try {
                await TvConfig.saveGistUrl(val);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  setState(() {
                    _hasGistUrl = true;
                    isLoading = true;
                  });
                }
                await _loadAllTvData();
              } finally {
                if (mounted) {
                  setModalState(() => isSyncing = false);
                }
              }
            }

            Future<void> handleClear() async {
              if (isSyncing) return;
              controller.clear();
              await TvConfig.saveGistUrl('');
              if (mounted) {
                setState(() {
                  activeProviders = [];
                  _hasGistUrl = false;
                });
              }
              setModalState(() {});
            }

            return Dialog(
              backgroundColor: const Color(0xFF1A2234),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Colors.white12, width: 1),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Icon(Icons.link_rounded,
                                  color: Color(0xFFEAB308), size: 22),
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
                                    ),
                                  ),
                                  SizedBox(height: 4),
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
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(4),
                              child: Focus(
                                focusNode: closeFocus,
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent &&
                                      _isRemoteOkKey(event.logicalKey)) {
                                    Navigator.of(ctx).pop();
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: Builder(builder: (c) {
                                  final focused = Focus.of(c).hasFocus;
                                  return IconButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: focused ? Colors.white : Colors.white70,
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'GitHub Gist Raw Link (or IPTV / Stremio link)',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(1),
                          child: TextField(
                            controller: controller,
                            focusNode: inputFocus,
                            autofocus: true,
                            maxLines: 2,
                            minLines: 1,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5),
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => setModalState(() {}),
                            onSubmitted: (_) => handleConnectAndSync(),
                            decoration: InputDecoration(
                              hintText:
                                  'https://gist.githubusercontent.com/.../raw/providers.json',
                              hintStyle: const TextStyle(
                                  color: Colors.white38, fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFF131926),
                              contentPadding: const EdgeInsets.all(14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF3B82F6), width: 2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (isConnected) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF123528),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF22C55E).withOpacity(0.45)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF22C55E), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _formatTvConnectedProviders(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: FocusTraversalOrder(
                                order: const NumericFocusOrder(2),
                                child: Focus(
                                  focusNode: syncFocus,
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        _isRemoteOkKey(event.logicalKey)) {
                                      handleConnectAndSync();
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: Builder(builder: (c) {
                                    final focused = Focus.of(c).hasFocus;
                                    return SizedBox(
                                      height: 46,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          side: BorderSide(
                                            color: focused
                                                ? Colors.white
                                                : Colors.transparent,
                                            width: 2.2,
                                          ),
                                        ),
                                        onPressed:
                                            isSyncing ? null : handleConnectAndSync,
                                        icon: const Icon(Icons.refresh_rounded,
                                            size: 18),
                                        label: const Text(
                                          'Connect & Sync',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FocusTraversalOrder(
                                order: const NumericFocusOrder(3),
                                child: Focus(
                                  focusNode: clearFocus,
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        _isRemoteOkKey(event.logicalKey)) {
                                      handleClear();
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: Builder(builder: (c) {
                                    final focused = Focus.of(c).hasFocus;
                                    return SizedBox(
                                      height: 46,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFEF4444),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          side: BorderSide(
                                            color: focused
                                                ? Colors.white
                                                : const Color(0xFFEF4444)
                                                    .withOpacity(0.55),
                                            width: focused ? 2.2 : 1,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: isSyncing ? null : handleClear,
                                        child: const Text(
                                          'Clear',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ).then((_) {
        inputFocus.dispose();
        syncFocus.dispose();
        clearFocus.dispose();
        closeFocus.dispose();
        controller.dispose();
      });
    });
  }

  Future _fetchProviders() async {
    try {
      final rawGist = await TvConfig.getGistUrl();
      if (mounted) {
        setState(() => _hasGistUrl = rawGist.isNotEmpty);
      }
      if (rawGist.isEmpty) return;

      final sep = rawGist.contains('?') ? '&' : '?';
      final url = '$rawGist${sep}t=${DateTime.now().millisecondsSinceEpoch}';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        activeProviders = jsonDecode(res.body)['active_providers'] ?? [];
      }
    } catch (_) {}
  }

  Future _fetchHomeCatalogContent() async {
    if (TvConfig.tmdbKey.isEmpty) return;
    await Future.wait([
      () async {
        try {
          final netflixRes = await http
              .get(Uri.parse(
                  '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_watch_providers=8&watch_region=IN&sort_by=primary_release_date.desc'))
              .timeout(const Duration(seconds: 6));
          if (netflixRes.statusCode == 200) {
            homeNetflixList = _parseTvList(jsonDecode(netflixRes.body)['results']);
            if (homeNetflixList.isNotEmpty) {
              activeShowcaseItem = homeNetflixList.first;
            }
          }
        } catch (_) {}
      }(),
      () async {
        try {
          final primeRes = await http
              .get(Uri.parse(
                  '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_watch_providers=119&watch_region=IN&sort_by=primary_release_date.desc'))
              .timeout(const Duration(seconds: 6));
          if (primeRes.statusCode == 200) {
            homePrimeList = _parseTvList(jsonDecode(primeRes.body)['results']);
            if (activeShowcaseItem == null && homePrimeList.isNotEmpty) {
              activeShowcaseItem = homePrimeList.first;
            }
          }
        } catch (_) {}
      }(),
      () async {
        try {
          final hotstarRes = await http
              .get(Uri.parse(
                  '${TvConfig.tmdbBase}/movie/now_playing?api_key=${TvConfig.tmdbKey}&language=en-US&region=IN'))
              .timeout(const Duration(seconds: 6));
          if (hotstarRes.statusCode == 200) {
            homeHotstarList = _parseTvList(jsonDecode(hotstarRes.body)['results']);
          }
        } catch (_) {}
      }(),
      () async {
        try {
          final hindiTvRes = await http
              .get(Uri.parse(
                  '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=hi&without_genres=10766&sort_by=popularity.desc&vote_count.gte=5'))
              .timeout(const Duration(seconds: 6));
          if (hindiTvRes.statusCode == 200) {
            homeHindiSeriesList =
                _parseTvList(jsonDecode(hindiTvRes.body)['results'], isTv: true)
                    .where((item) => !isSoapShow(item['title'] ?? ''))
                    .toList();
          }
        } catch (_) {}
      }(),
      () async {
        try {
          final engTvRes = await http
              .get(Uri.parse(
                  '${TvConfig.tmdbBase}/tv/on_the_air?api_key=${TvConfig.tmdbKey}&language=en-US'))
              .timeout(const Duration(seconds: 6));
          if (engTvRes.statusCode == 200) {
            homeEnglishSeriesList =
                _parseTvList(jsonDecode(engTvRes.body)['results'], isTv: true);
          }
        } catch (_) {}
      }(),
    ]);
  }

  Future _fetchDeepCatalogs() async {
    if (TvConfig.tmdbKey.isEmpty) return;
    final sortQuery = _catalogSortType == 'latest'
        ? 'primary_release_date.desc'
        : 'popularity.desc';
    final sortTvQuery = _catalogSortType == 'latest'
        ? 'first_air_date.desc'
        : 'popularity.desc';

    await Future.wait([
      _fetchPages(
        baseUrl:
            '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=hi&sort_by=$sortQuery',
        isTv: false,
        onDone: (list) {
          if (mounted) setState(() => allBollywoodMovies = list);
        },
      ),
      _fetchPages(
        baseUrl:
            '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn&sort_by=$sortQuery',
        isTv: false,
        onDone: (list) {
          if (mounted) setState(() => allSouthMovies = list);
        },
      ),
      _fetchPages(
        baseUrl:
            '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&sort_by=$sortQuery',
        isTv: false,
        onDone: (list) {
          if (mounted) setState(() => allHollywoodMovies = list);
        },
      ),
      _fetchPages(
        baseUrl:
            '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=hi&without_genres=10766&vote_count.gte=5&sort_by=$sortTvQuery',
        isTv: true,
        onDone: (list) {
          if (mounted) {
            setState(() => allHindiSeries =
                list.where((i) => !isSoapShow(i['title'] ?? '')).toList());
          }
        },
      ),
      _fetchPages(
        baseUrl:
            '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_networks=213&without_genres=10766&sort_by=$sortTvQuery',
        isTv: true,
        onDone: (list) {
          if (mounted) {
            setState(() => allNetflixSeries =
                list.where((i) => !isSoapShow(i['title'] ?? '')).toList());
          }
        },
      ),
      _fetchPages(
        baseUrl:
            '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_networks=1024&without_genres=10766&sort_by=$sortTvQuery',
        isTv: true,
        onDone: (list) {
          if (mounted) {
            setState(() => allAmazonSeries =
                list.where((i) => !isSoapShow(i['title'] ?? '')).toList());
          }
        },
      ),
      _fetchPages(
        baseUrl:
            '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=te%7Cta%7Cml&sort_by=$sortTvQuery',
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
        final res = await http
            .get(Uri.parse('$baseUrl&page=$p'))
            .timeout(const Duration(seconds: 6));
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
        'year': (m['release_date'] ?? m['first_air_date'] ?? currentYear)
            .toString()
            .split('-')[0],
        'rating': m['vote_average']?.toString() ?? '7.5',
        'backdrop': m['backdrop_path'] != null
            ? '${TvConfig.backdropBase}${m['backdrop_path']}'
            : '${TvConfig.imgBase}${m['poster_path']}',
        'poster': m['poster_path'] != null
            ? '${TvConfig.imgBase}${m['poster_path']}'
            : '${TvConfig.backdropBase}${m['backdrop_path']}',
        'overview': m['overview'] ?? '',
        'isTv': isTv,
      });
    }
    return res;
  }

  void _onTvItemSelect(dynamic item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TvMediaDetailScreen(
          item: item,
          onPlaySaved: () => _loadContinueWatching(),
        ),
      ),
    );
  }

  Widget _buildNetflixNavRail() {
    final icons = [
      Icons.person_outline_rounded,
      Icons.search_rounded,
      Icons.home_filled,
      Icons.movie_creation_outlined,
      Icons.tv_rounded,
      Icons.grid_view_rounded,
    ];

    return Container(
      width: 58,
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
          const SizedBox(height: 28),
          Expanded(
            child: ListView.separated(
              itemCount: icons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                return NetflixSidebarIcon(
                  focusNode: _sidebarFocusNodes[i],
                  icon: icons[i],
                  isSelected: _selectedNavIndex == i,
                  onRightArrow: _jumpFocusToContent,
                  onTap: () {
                    setState(() => _selectedNavIndex = i);
                    _jumpFocusToContent();
                  },
                );
              },
            ),
          ),
          NetflixSidebarIcon(
            focusNode: _gistSidebarFocusNode,
            icon: Icons.link_rounded,
            isSelected: _hasGistUrl,
            onRightArrow: _jumpFocusToContent,
            onTap: _showGistConfigDialog,
          ),
        ],
      ),
    );
  }

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
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF141414)),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x66141414),
                    Color(0xFF141414)
                  ],
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('NETFLIX PRO',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['isTv'] == true ? 'S E R I E S' : 'M O V I E',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold),
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
                    Text('${item['rating']} ★ Match',
                        style: const TextStyle(
                            color: Color(0xFF46D369),
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Text('${item['year']}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    const SizedBox(width: 12),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.white38),
                          borderRadius: BorderRadius.circular(3)),
                      child: const Text('Ultra HD 4K',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 9)),
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
                            backgroundColor:
                                focused ? Colors.white : const Color(0xFFE50914),
                            foregroundColor:
                                focused ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            side: BorderSide(
                              color: focused ? Colors.white : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          onPressed: () => _onTvItemSelect(item),
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: const Text('Watch Now',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        );
                      }),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.add,
                          color: Colors.white70, size: 20),
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
                  style: const TextStyle(
                      color: Color(0xFFE50914),
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                                  ? [
                                      BoxShadow(
                                          color: const Color(0xFFE50914)
                                              .withOpacity(0.55),
                                          blurRadius: 10,
                                          spreadRadius: 2)
                                    ]
                                  : [],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.grid_view_rounded,
                                    color: Color(0xFFE50914), size: 32),
                                SizedBox(height: 6),
                                Text('See All',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text('Explore Catalog',
                                    style: TextStyle(
                                        color: Colors.white60, fontSize: 11)),
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
                focusNode:
                    (isFirstRow && idx == 0) ? _firstContentCardFocus : null,
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
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: focused ? Colors.white : const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _catalogSortType == 'latest'
                            ? Icons.fiber_new_rounded
                            : Icons.whatshot_rounded,
                        size: 15,
                        color: focused ? Colors.black : const Color(0xFFE50914),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _catalogSortType == 'latest'
                            ? 'Filter: Latest Releases'
                            : 'Filter: Most Popular',
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
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE50914)))
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
                            if (_selectedNavIndex == 2 ||
                                _selectedNavIndex == 0) ...[
                              if (activeShowcaseItem != null)
                                _buildNetflixBillboard(activeShowcaseItem!),
                              if (continueWatchingList.isNotEmpty)
                                _buildNetflixRow(
                                  'Continue Watching',
                                  continueWatchingList,
                                  '',
                                  isFirstRow: true,
                                ),
                              if (homeNetflixList.isNotEmpty)
                                _buildNetflixRow(
                                  'Latest Netflix Blockbusters (Hindi + Global)',
                                  homeNetflixList,
                                  '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_watch_providers=8&watch_region=IN',
                                  isFirstRow: continueWatchingList.isEmpty,
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
                            if (_selectedNavIndex == 3) ...[
                              _buildCategoryHeader(
                                  'All Movies (200+ Titles Per Hub)'),
                              if (activeShowcaseItem != null)
                                _buildNetflixBillboard(activeShowcaseItem!),
                              _buildNetflixRow(
                                'Bollywood Hit Movies',
                                allBollywoodMovies.isNotEmpty
                                    ? allBollywoodMovies
                                    : homeNetflixList,
                                '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=hi',
                                isFirstRow: true,
                              ),
                              _buildNetflixRow(
                                'South Indian Blockbusters (Hindi Dubbed)',
                                allSouthMovies.isNotEmpty
                                    ? allSouthMovies
                                    : homePrimeList,
                                '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}&with_original_language=te%7Cta%7Cml%7Ckn',
                              ),
                              _buildNetflixRow(
                                'Hollywood Blockbusters (Hindi Dubbed & Global)',
                                allHollywoodMovies.isNotEmpty
                                    ? allHollywoodMovies
                                    : homeHotstarList,
                                '${TvConfig.tmdbBase}/discover/movie?api_key=${TvConfig.tmdbKey}',
                              ),
                            ],
                            if (_selectedNavIndex == 4) ...[
                              _buildCategoryHeader(
                                  'All Web Series (Hindi, Netflix, Amazon & South)'),
                              if (activeShowcaseItem != null)
                                _buildNetflixBillboard(activeShowcaseItem!),
                              _buildNetflixRow(
                                'All Hindi Web Series',
                                allHindiSeries.isNotEmpty
                                    ? allHindiSeries
                                    : homeHindiSeriesList,
                                '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_original_language=hi&without_genres=10766&vote_count.gte=5',
                                isFirstRow: true,
                                isTv: true,
                              ),
                              _buildNetflixRow(
                                'All Netflix Series',
                                allNetflixSeries.isNotEmpty
                                    ? allNetflixSeries
                                    : homeEnglishSeriesList,
                                '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_networks=213&without_genres=10766',
                                isTv: true,
                              ),
                              _buildNetflixRow(
                                'All Amazon Series',
                                allAmazonSeries.isNotEmpty
                                    ? allAmazonSeries
                                    : homeHindiSeriesList,
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
                            if (_selectedNavIndex == 5) ...[
                              _buildCategoryHeader('Explore All Collections'),
                              _buildNetflixRow(
                                'Bollywood Top Rated',
                                homeNetflixList,
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
                                allNetflixSeries.isNotEmpty
                                    ? allNetflixSeries
                                    : homeEnglishSeriesList,
                                '${TvConfig.tmdbBase}/discover/tv?api_key=${TvConfig.tmdbKey}&with_networks=213&without_genres=10766',
                                isTv: true,
                              ),
                              _buildNetflixRow(
                                'Amazon Prime Originals',
                                allAmazonSeries.isNotEmpty
                                    ? allAmazonSeries
                                    : homeHindiSeriesList,
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

class NetflixSidebarIcon extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onRightArrow;
  final VoidCallback onTap;

  const NetflixSidebarIcon({
    super.key,
    required this.focusNode,
    required this.icon,
    required this.isSelected,
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
            color: _isFocused
                ? Colors.white
                : widget.isSelected
                    ? const Color(0xFFE50914)
                    : Colors.white38,
            size: 20,
          ),
        ),
      ),
    );
  }
}

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
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              widget.isFirstInRow) {
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
                    errorBuilder: (_, __, ___) =>
                        Container(color: const Color(0xFF222222)),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
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
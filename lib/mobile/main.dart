import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'internal_player.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const NetflixProMobileApp());
}

class NetflixProMobileApp extends StatelessWidget {
  const NetflixProMobileApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netflix Pro Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1014),
        primaryColor: const Color(0xFFE50914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          secondary: Color(0xFFE50914),
        ),
      ),
      home: const MobileHomeScreen(),
    );
  }
}

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({Key? key}) : super(key: key);

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic> _config = {};
  
  List trendingMovies = [];
  List bollywoodMovies = [];
  List southMovies = [];
  List actionMovies = [];
  List watchlist = [];
  
  final String gistConfigUrl =
      'https://gist.githubusercontent.com/Rahul6051276/5d1dbbe072236fa7c61bf64c9ca4e8df/raw/providers.json';
  final String tmdbApiKey = 'e69ec06ce3bc891f9b3662d558a5e3df';

  @override
  void initState() {
    super.initState();
    _loadAllContent();
  }

  Future<void> _loadAllContent() async {
    setState(() => _isLoading = true);
    await _loadWatchlist();
    await _fetchGistConfig();
    await _fetchTMDBContent();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('mobile_watchlist');
    if (saved != null) {
      try {
        watchlist = jsonDecode(saved);
      } catch (_) {}
    }
  }

  Future<void> _toggleWatchlist(Map movie) async {
    final prefs = await SharedPreferences.getInstance();
    final id = movie['id'];
    final exists = watchlist.any((item) => item['id'] == id);

    setState(() {
      if (exists) {
        watchlist.removeWhere((item) => item['id'] == id);
      } else {
        watchlist.add(movie);
      }
    });

    await prefs.setString('mobile_watchlist', jsonEncode(watchlist));
  }

  Future<void> _fetchGistConfig() async {
    try {
      final res = await http.get(Uri.parse(gistConfigUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        _config = jsonDecode(res.body);
      }
    } catch (_) {}
  }

  Future<void> _fetchTMDBContent() async {
    try {
      final tRes = await http.get(Uri.parse(
        'https://api.themoviedb.org/3/trending/movie/week?api_key=$tmdbApiKey',
      ));
      if (tRes.statusCode == 200) {
        final data = jsonDecode(tRes.body);
        trendingMovies = data['results'] ?? [];
      }

      final bRes = await http.get(Uri.parse(
        'https://api.themoviedb.org/3/discover/movie?api_key=$tmdbApiKey&with_original_language=hi&sort_by=popularity.desc',
      ));
      if (bRes.statusCode == 200) {
        final data = jsonDecode(bRes.body);
        bollywoodMovies = data['results'] ?? [];
      }

      final sRes = await http.get(Uri.parse(
        'https://api.themoviedb.org/3/discover/movie?api_key=$tmdbApiKey&with_original_language=te|ta|ml|kn&sort_by=popularity.desc',
      ));
      if (sRes.statusCode == 200) {
        final data = jsonDecode(sRes.body);
        southMovies = data['results'] ?? [];
      }

      final aRes = await http.get(Uri.parse(
        'https://api.themoviedb.org/3/discover/movie?api_key=$tmdbApiKey&with_genres=28&sort_by=popularity.desc',
      ));
      if (aRes.statusCode == 200) {
        final data = jsonDecode(aRes.body);
        actionMovies = data['results'] ?? [];
      }
    } catch (_) {}
  }

  void _openStreamSheet(Map item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileStreamSheet(
        item: item,
        config: _config,
      ),
    );
  }

  Widget _buildHomeView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      );
    }

    final billboardItem = trendingMovies.isNotEmpty ? trendingMovies[0] : null;

    final List allCategories = [
      {'title': 'Latest & Trending', 'items': trendingMovies},
      {'title': 'Bollywood Blockbusters', 'items': bollywoodMovies},
      {'title': 'South Cinema Special', 'items': southMovies},
      {'title': 'Action & Adventure', 'items': actionMovies},
    ];

    return RefreshIndicator(
      color: const Color(0xFFE50914),
      backgroundColor: const Color(0xFF1E2029),
      onRefresh: _loadAllContent,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0F1014),
            pinned: true,
            expandedHeight: billboardItem != null ? 360 : 60,
            flexibleSpace: billboardItem != null
                ? FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://image.tmdb.org/t/p/w780${billboardItem['backdrop_path'] ?? billboardItem['poster_path']}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.black26),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0x880F1014),
                                Color(0xFF0F1014),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                billboardItem['title'] ?? billboardItem['name'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Play'),
                                    onPressed: () => _openStreamSheet(billboardItem),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white54),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    icon: Icon(
                                      watchlist.any((e) => e['id'] == billboardItem['id'])
                                          ? Icons.check
                                          : Icons.add,
                                    ),
                                    label: const Text('My List'),
                                    onPressed: () => _toggleWatchlist(billboardItem),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
            title: const Text(
              'NETFLIX PRO',
              style: TextStyle(
                color: Color(0xFFE50914),
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                fontSize: 20,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: MovieSearchDelegate(
                      apiKey: tmdbApiKey,
                      onMovieSelected: _openStreamSheet,
                    ),
                  );
                },
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cat = allCategories[index];
                final List items = cat['items'] ?? [];
                if (items.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        cat['title'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final poster = item['poster_path'];
                          return GestureDetector(
                            onTap: () => _openStreamSheet(item),
                            child: Container(
                              width: 120,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: const Color(0xFF1E2029),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: poster != null
                                    ? Image.network(
                                        'https://image.tmdb.org/t/p/w342$poster',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Center(child: Icon(Icons.movie, color: Colors.white24)),
                                      )
                                    : const Center(child: Icon(Icons.movie, color: Colors.white24)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              childCount: allCategories.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildLiveView() {
    final banner = _config['live_sports_banner'] ?? {};
    final List sportsChannels = _config['sports_channels'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Sports & TV Channels'),
        backgroundColor: const Color(0xFF0F1014),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (banner['is_live'] == true)
            GestureDetector(
              onTap: () {
                _openStreamSheet({
                  'title': banner['title'] ?? 'Live Match',
                  'keywords': banner['search_keywords'] ?? [],
                  'is_live': true,
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF1E2029),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      if (banner['backdrop'] != null)
                        Image.network(
                          banner['backdrop'],
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(height: 180, color: Colors.black45),
                        ),
                      Container(
                        height: 180,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xCC000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE NOW',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              banner['title'] ?? 'LIVE SPORTS EVENT',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              banner['subtitle'] ?? '',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Text(
            'Channels',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sportsChannels.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemBuilder: (context, idx) {
              final ch = sportsChannels[idx];
              return InkWell(
                onTap: () {
                  _openStreamSheet({
                    'title': ch['title'] ?? 'Live Channel',
                    'keywords': ch['search_keywords'] ?? [ch['title']],
                    'is_live': true,
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2029),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (ch['poster'] != null && ch['poster'].toString().isNotEmpty)
                        Image.network(
                          ch['poster'],
                          height: 48,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.tv, size: 36, color: Colors.white54),
                        )
                      else
                        const Icon(Icons.tv, size: 36, color: Colors.white54),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          ch['title'] ?? '',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlistView() {
    if (watchlist.isEmpty) {
      return const Center(
        child: Text(
          'Your watchlist is empty.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Watchlist'),
        backgroundColor: const Color(0xFF0F1014),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: watchlist.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.68,
        ),
        itemBuilder: (context, i) {
          final item = watchlist[i];
          final poster = item['poster_path'];
          return GestureDetector(
            onTap: () => _openStreamSheet(item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: poster != null
                  ? Image.network(
                      'https://image.tmdb.org/t/p/w342$poster',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E2029)),
                    )
                  : Container(color: const Color(0xFF1E2029)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeView(),
          _buildLiveView(),
          _buildWatchlistView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF14151B),
        selectedItemColor: const Color(0xFFE50914),
        unselectedItemColor: Colors.white54,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.live_tv),
            label: 'Live',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmarks),
            label: 'My List',
          ),
        ],
      ),
    );
  }
}

class MobileStreamSheet extends StatefulWidget {
  final Map item;
  final Map config;

  const MobileStreamSheet({
    Key? key,
    required this.item,
    required this.config,
  }) : super(key: key);

  @override
  State<MobileStreamSheet> createState() => _MobileStreamSheetState();
}

class _MobileStreamSheetState extends State<MobileStreamSheet> {
  bool _searching = true;
  List streams = [];

  @override
  void initState() {
    super.initState();
    _fetchDirectStreams();
  }

  Future<void> _fetchDirectStreams() async {
    setState(() => _searching = true);
    final List found = [];
    final activeProviders = widget.config['active_providers'] ?? [];

    if (widget.item['is_live'] == true) {
      final List keywords = widget.item['keywords'] ?? [];
      for (var prov in activeProviders) {
        if (prov['type'] == 'xtream') {
          final host = (prov['host'] ?? '').toString().replaceAll(RegExp(r'/+$'), '');
          final user = prov['username'] ?? '';
          final pass = prov['password'] ?? '';

          try {
            final api = '$host/player_api.php?username=$user&password=$pass&action=get_live_streams';
            final res = await http.get(Uri.parse(api)).timeout(const Duration(seconds: 12));
            if (res.statusCode == 200) {
              final liveList = jsonDecode(res.body);
              for (var ch in (liveList is List ? liveList : [])) {
                final chName = (ch['name'] ?? '').toString().toLowerCase();

                if (chName.contains('plus') || chName.contains('gold') || chName.contains('bharat') || chName.contains('utsav')) {
                  continue;
                }

                bool matches = false;
                for (var kw in keywords) {
                  final cleanKw = kw.toString().toLowerCase();
                  if (cleanKw.isNotEmpty && chName.contains(cleanKw)) {
                    matches = true;
                    break;
                  }
                }

                if (matches) {
                  found.add({
                    'server': prov['name'] ?? 'Xtream Live IPTV',
                    'title': ch['name'] ?? widget.item['title'],
                    'url': '$host/live/$user/$pass/${ch['stream_id']}.m3u8',
                  });
                }
              }
            }
          } catch (_) {}
        }
      }
    } else {
      for (var prov in activeProviders) {
        if (prov['type'] == 'stremio') {
          var manifestUrl = prov['url'] ?? '';
          var baseUrl = manifestUrl.replaceAll('/manifest.json', '');
          var imdbId = widget.item['imdb_id'];

          if (imdbId == null && widget.item['id'] != null) {
            try {
              final tmdbRes = await http.get(Uri.parse(
                'https://api.themoviedb.org/3/movie/${widget.item['id']}/external_ids?api_key=e69ec06ce3bc891f9b3662d558a5e3df',
              )).timeout(const Duration(seconds: 4));
              if (tmdbRes.statusCode == 200) {
                final ids = jsonDecode(tmdbRes.body);
                imdbId = ids['imdb_id'];
              }
            } catch (_) {}
          }

          if (imdbId != null && imdbId.toString().startsWith('tt')) {
            try {
              final streamUrl = '$baseUrl/stream/movie/$imdbId.json';
              final res = await http.get(Uri.parse(streamUrl)).timeout(const Duration(seconds: 8));
              if (res.statusCode == 200) {
                final data = jsonDecode(res.body);
                for (var s in (data['streams'] is List ? data['streams'] : [])) {
                  found.add({
                    'server': prov['name'] ?? 'HD Streams',
                    'title': s['title'] ?? s['name'] ?? widget.item['title'],
                    'url': s['url'] ?? (s['infoHash'] != null ? 'magnet:?xt=urn:btih:${s['infoHash']}' : ''),
                  });
                }
              }
            } catch (_) {}
          }
        } else if (prov['type'] == 'xtream') {
          final host = (prov['host'] ?? '').toString().replaceAll(RegExp(r'/+$'), '');
          final user = prov['username'] ?? '';
          final pass = prov['password'] ?? '';

          try {
            final searchApi = '$host/player_api.php?username=$user&password=$pass&action=get_vod_streams';
            final xtreamRes = await http.get(Uri.parse(searchApi)).timeout(const Duration(seconds: 15));
            if (xtreamRes.statusCode == 200) {
              final vodList = jsonDecode(xtreamRes.body);
              final queryTitle = (widget.item['title'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

              for (var movie in (vodList is List ? vodList : [])) {
                final movieName = (movie['name'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                if (queryTitle.isNotEmpty && movieName.contains(queryTitle)) {
                  final ext = movie['container_extension'] ?? 'mp4';
                  found.add({
                    'server': prov['name'] ?? 'Xtream VOD Server',
                    'title': movie['name'] ?? widget.item['title'],
                    'url': '$host/movie/$user/$pass/${movie['stream_id']}.$ext',
                  });
                }
              }
            }
          } catch (_) {}
        }
      }
    }

    if (mounted) {
      setState(() {
        streams = found;
        _searching = false;
      });
    }
  }

  void _playInternal(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InternalPlayerScreen(
          streamUrl: url,
          title: title,
        ),
      ),
    );
  }

  Future<void> _playExternalVlc(String streamUrl) async {
    try {
      final intent = AndroidIntent(
        action: 'action_view',
        data: streamUrl,
        type: 'video/*',
        package: 'org.videolan.vlc',
      );
      await intent.launch();
    } catch (_) {
      try {
        final genericIntent = AndroidIntent(
          action: 'action_view',
          data: streamUrl,
          type: 'video/*',
        );
        await genericIntent.launch();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot launch video player: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2029),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.item['title'] ?? 'Select Stream',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_searching)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: Color(0xFFE50914)),
              ),
            )
          else if (streams.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No active streams found on server.',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: streams.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                itemBuilder: (context, idx) {
                  final s = streams[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      s['title'] ?? 'Stream Source',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 2,
                    ),
                    subtitle: Text(
                      s['server'] ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text('Play'),
                          onPressed: () => _playInternal(s['url'], s['title']),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text('VLC'),
                          onPressed: () => _playExternalVlc(s['url']),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class MovieSearchDelegate extends SearchDelegate {
  final String apiKey;
  final Function(Map) onMovieSelected;

  MovieSearchDelegate({required this.apiKey, required this.onMovieSelected});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F1014),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF14151B)),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _search();

  @override
  Widget buildSuggestions(BuildContext context) => _search();

  Widget _search() {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Type a movie name...', style: TextStyle(color: Colors.white54)));
    }

    return FutureBuilder<http.Response>(
      future: http.get(Uri.parse('https://api.themoviedb.org/3/search/movie?api_key=$apiKey&query=$query')),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
        }

        final data = jsonDecode(snapshot.data!.body);
        final List list = data['results'] ?? [];

        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final movie = list[i];
            return ListTile(
              leading: movie['poster_path'] != null
                  ? Image.network(
                      'https://image.tmdb.org/t/p/w92${movie['poster_path']}',
                      width: 40,
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.movie),
              title: Text(movie['title'] ?? ''),
              subtitle: Text(movie['release_date'] ?? ''),
              onTap: () {
                close(context, null);
                onMovieSelected(movie);
              },
            );
          },
        );
      },
    );
  }
}

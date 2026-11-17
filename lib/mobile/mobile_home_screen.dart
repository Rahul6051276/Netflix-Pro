// ============================================================================
// NETFLIX PRO MOBILE HOME & NAVIGATION SUITE (STRICT USER GIST SOURCE MANAGER)
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
  String currentGistUrl = '';
  bool isGistConnected = false;

  @override
  void initState() {
    super.initState();
    _fetchGlobalProviders();
  }

  Future<void> _fetchGlobalProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGist = (prefs.getString('custom_gist_url') ?? '').trim();

    if (savedGist.isEmpty) {
      await prefs.remove('cached_active_providers');
      if (mounted) {
        setState(() {
          currentGistUrl = '';
          activeProviders = [];
          isGistConnected = false;
        });
        // Open Gist prompt automatically if no Gist link is set yet
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && currentGistUrl.isEmpty) {
            _openGistManagerDialog();
          }
        });
      }
      return;
    }

    currentGistUrl = savedGist;
    final cached = prefs.getString('cached_active_providers');
    if (cached != null && cached.isNotEmpty && mounted) {
      try {
        final decodedCache = jsonDecode(cached) as List<dynamic>;
        setState(() {
          activeProviders = decodedCache;
          isGistConnected = decodedCache.isNotEmpty;
        });
      } catch (_) {}
    }

    try {
      final sep = currentGistUrl.contains('?') ? '&' : '?';
      final freshUrl = '$currentGistUrl${sep}t=${DateTime.now().millisecondsSinceEpoch}';
      final res = await http.get(Uri.parse(freshUrl)).timeout(const Duration(seconds: 12));
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
              isGistConnected = true;
            });
          }
        }
      }
    } catch (_) {}
  }

  void _openGistManagerDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _GistManagerDialog(
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      MobileHomeScreen(
        providers: activeProviders,
        isGistConnected: isGistConnected,
        onOpenGistDialog: _openGistManagerDialog,
      ),
      MobileSearchScreen(
        providers: activeProviders,
        isGistConnected: isGistConnected,
        onOpenGistDialog: _openGistManagerDialog,
      ),
      MobileMyListScreen(
        providers: activeProviders,
        isGistConnected: isGistConnected,
        onOpenGistDialog: _openGistManagerDialog,
      ),
      MobileMoreScreen(
        providers: activeProviders,
        isGistConnected: isGistConnected,
        onOpenGistDialog: _openGistManagerDialog,
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
// GITHUB GIST RAW SOURCE POPUP DIALOG (EMPTY BY DEFAULT + LIVE IPTV TEST)
// ============================================================================
class _GistManagerDialog extends StatefulWidget {
  final String initialUrl;
  final List<dynamic> currentProviders;
  final Function(String url, List<dynamic> providers) onSynced;

  const _GistManagerDialog({
    required this.initialUrl,
    required this.currentProviders,
    required this.onSynced,
  });

  @override
  State<_GistManagerDialog> createState() => _GistManagerDialogState();
}

class _GistManagerDialogState extends State<_GistManagerDialog> {
  late TextEditingController _urlController;
  bool isSyncing = false;
  String statusMessage = '';
  bool isSuccess = false;
  List<dynamic> loadedList = [];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    loadedList = List<dynamic>.from(widget.currentProviders);
    if (widget.initialUrl.isNotEmpty && loadedList.isNotEmpty) {
      isSuccess = true;
      final names = loadedList.map((p) => (p['name'] ?? p['type'] ?? 'Source').toString()).join(' + ');
      statusMessage = 'Connected: $names';
    } else {
      isSuccess = false;
      statusMessage = 'Gist Link Required! Paste your GitHub Gist Raw link below to activate playback.';
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<String> _checkSingleProviderStatus(dynamic prov) async {
    final name = (prov['name'] ?? 'Source').toString();
    final type = (prov['type'] ?? '').toString().toLowerCase();
    if (type != 'xtream') return name;

    final rawHost = (prov['xc_host'] ?? prov['host'] ?? '').toString().trim().replaceAll(RegExp(r'/+$'), '');
    final user = (prov['xc_username'] ?? prov['username'] ?? '').toString().trim();
    final pass = (prov['xc_password'] ?? prov['password'] ?? '').toString().trim();
    if (rawHost.isEmpty || user.isEmpty || pass.isEmpty) return '$name (Invalid)';

    final cleanHost = rawHost.endsWith(':80') ? rawHost.substring(0, rawHost.length - 3) : rawHost;
    final hostsToTry = {rawHost, cleanHost}.toList();

    for (final h in hostsToTry) {
      try {
        final authUrl = '$h/player_api.php?username=$user&password=$pass';
        final res = await http.get(
          Uri.parse(authUrl),
          headers: {'User-Agent': 'IPTVSmartersPro', 'Accept': '*/*'},
        ).timeout(const Duration(seconds: 7));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final userInfo = data['user_info'];
          if (userInfo != null) {
            final status = (userInfo['status'] ?? '').toString();
            if (status.toLowerCase() == 'active') {
              return '$name (Active ✓)';
            } else {
              return '$name ($status)';
            }
          }
        }
      } catch (_) {}
    }
    return '$name (Offline/Blocked)';
  }

  Future<void> _connectAndSync() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        isSuccess = false;
        statusMessage = 'Please paste a valid GitHub Gist Raw link first.';
      });
      return;
    }

    setState(() {
      isSyncing = true;
      statusMessage = 'Connecting & testing all IPTV / Stremio servers...';
    });

    try {
      final sep = rawUrl.contains('?') ? '&' : '?';
      final fetchUrl = '$rawUrl${sep}t=${DateTime.now().millisecondsSinceEpoch}';
      final res = await http.get(Uri.parse(fetchUrl)).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['active_providers'] ?? decoded['providers'] ?? []);

        if (list is List && list.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('custom_gist_url', rawUrl);
          await prefs.setString('cached_active_providers', jsonEncode(list));

          final statuses = await Future.wait(list.map((p) => _checkSingleProviderStatus(p)));
          widget.onSynced(rawUrl, list);

          if (mounted) {
            setState(() {
              isSyncing = false;
              isSuccess = true;
              loadedList = list;
              statusMessage = 'Connected: ${statuses.join(' + ')}';
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          isSyncing = false;
          isSuccess = false;
          statusMessage = 'Failed to load providers (Invalid JSON or URL).';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSyncing = false;
          isSuccess = false;
          statusMessage = 'Connection Error: Check URL or Internet.';
        });
      }
    }
  }

  Future<void> _clearGist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_gist_url', '');
    await prefs.remove('cached_active_providers');
    _urlController.clear();
    widget.onSynced('', []);
    if (mounted) {
      setState(() {
        isSuccess = false;
        loadedList = [];
        statusMessage = 'Cleared! App playback disabled until you add a Gist link.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141B2D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF2B3654), width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.link_rounded, color: Color(0xFFFACC15), size: 22),
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
                        'Paste your Gist Raw URL to activate all IPTV & Stremio sources',
                        style: TextStyle(color: Color(0xFFFACC15), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'GitHub Gist Raw Link (Required)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _urlController,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35),
                decoration: const InputDecoration(
                  hintText: 'Paste https://gist.githubusercontent.com/.../raw/providers.json here',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSuccess
                    ? const Color(0xFF064E3B).withOpacity(0.65)
                    : const Color(0xFF3F1D2E).withOpacity(0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    color: isSuccess ? const Color(0xFF22C55E) : const Color(0xFFF87171),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusMessage,
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
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSyncing ? null : _connectAndSync,
                      icon: isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        isSyncing ? 'Checking...' : 'Connect & Sync',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF87171),
                        side: const BorderSide(color: Color(0xFF7F1D1D), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSyncing ? null : _clearGist,
                      child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${loadedList.length} Sources Ready',
                style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 1. HOME SCREEN
// ============================================================================
class MobileHomeScreen extends StatefulWidget {
  final List<dynamic> providers;
  final bool isGistConnected;
  final VoidCallback onOpenGistDialog;

  const MobileHomeScreen({
    super.key,
    required this.providers,
    required this.isGistConnected,
    required this.onOpenGistDialog,
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
    if (!widget.isGistConnected || widget.providers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFE50914),
          content: Text('Please add your GitHub Gist link first to play content!'),
          duration: Duration(seconds: 2),
        ),
      );
      widget.onOpenGistDialog();
      return;
    }

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
      if (!widget.isGistConnected || widget.providers.isEmpty) {
        widget.onOpenGistDialog();
        return;
      }
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

                // TOP BAR WITH NETFLIX PRO LOGO + GIST BUTTON + SEARCH
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.only(top: 40, left: 14, right: 10, bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.92), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'NETFLIX PRO',
                          style: TextStyle(
                            color: Color(0xFFE50914),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: widget.onOpenGistDialog,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: widget.isGistConnected
                                  ? const Color(0xFF064E3B).withOpacity(0.85)
                                  : const Color(0xFF7F1D1D).withOpacity(0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: widget.isGistConnected
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFEF4444),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  size: 14,
                                  color: widget.isGistConnected
                                      ? const Color(0xFF4ADE80)
                                      : const Color(0xFFFCA5A5),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  widget.isGistConnected ? 'Gist Active' : 'Add Gist',
                                  style: TextStyle(
                                    color: widget.isGistConnected
                                        ? const Color(0xFF4ADE80)
                                        : Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.isGistConnected
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.white, size: 24),
                          onPressed: () {
                            if (!widget.isGistConnected || widget.providers.isEmpty) {
                              widget.onOpenGistDialog();
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MobileSearchScreen(
                                  providers: widget.providers,
                                  isGistConnected: widget.isGistConnected,
                                  onOpenGistDialog: widget.onOpenGistDialog,
                                  onPlaySaved: _loadContinueWatching,
                                ),
                              ),
                            );
                          },
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
  final bool isGistConnected;
  final VoidCallback onOpenGistDialog;
  final VoidCallback? onPlaySaved;

  const MobileSearchScreen({
    super.key,
    required this.providers,
    required this.isGistConnected,
    required this.onOpenGistDialog,
    this.onPlaySaved,
  });

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
                        if (!widget.isGistConnected || widget.providers.isEmpty) {
                          widget.onOpenGistDialog();
                          return;
                        }
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
// 3. MY LIST SCREEN
// ============================================================================
class MobileMyListScreen extends StatefulWidget {
  final List<dynamic> providers;
  final bool isGistConnected;
  final VoidCallback onOpenGistDialog;

  const MobileMyListScreen({
    super.key,
    required this.providers,
    required this.isGistConnected,
    required this.onOpenGistDialog,
  });

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
    if (!widget.isGistConnected || widget.providers.isEmpty) {
      widget.onOpenGistDialog();
      return;
    }
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
// 4. MORE SCREEN
// ============================================================================
class MobileMoreScreen extends StatelessWidget {
  final List<dynamic> providers;
  final bool isGistConnected;
  final VoidCallback onOpenGistDialog;

  const MobileMoreScreen({
    super.key,
    required this.providers,
    required this.isGistConnected,
    required this.onOpenGistDialog,
  });

  void _openCategory(BuildContext context, String title, String url, bool isTv) {
    if (!isGistConnected || providers.isEmpty) {
      onOpenGistDialog();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MobileCategoryGridScreen(
          title: title,
          baseUrl: url,
          isTv: isTv,
          providers: providers,
          onPlaySaved: () {},
        ),
      ),
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Latest Genres & OTT Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFE50914)),
            title: const Text('Action & Adventure (Bolly + South + Eng)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () => _openCategory(
              context,
              'Action & Adventure Latest',
              '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=28&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&vote_count.gte=20',
              false,
            ),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.psychology_rounded, color: Color(0xFFE50914)),
            title: const Text('Thriller & Suspense (Bolly + South + Eng)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () => _openCategory(
              context,
              'Thriller & Suspense Latest',
              '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=53&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&vote_count.gte=15',
              false,
            ),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.search_rounded, color: Color(0xFFE50914)),
            title: const Text('Crime & Mystery Suspense (Latest Mix)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () => _openCategory(
              context,
              'Crime & Mystery Suspense',
              '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_genres=9648,80&with_original_language=$mixedLangs&primary_release_date.lte=$todayIso&vote_count.gte=15',
              false,
            ),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.movie_filter_rounded, color: Color(0xFFE50914)),
            title: const Text('Bollywood Latest Movies', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () => _openCategory(
              context,
              'Bollywood Latest Movies',
              '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=hi&primary_release_date.lte=$todayIso&vote_count.gte=8',
              false,
            ),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.local_movies_rounded, color: Color(0xFFE50914)),
            title: const Text('South Latest Movies (Hindi Dubbed)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () => _openCategory(
              context,
              'South Latest Movies',
              '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=te|ta|ml|kn&primary_release_date.lte=$todayIso&vote_count.gte=10',
              false,
            ),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.theaters_rounded, color: Color(0xFFE50914)),
            title: const Text('English / Hollywood Latest Movies', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () => _openCategory(
              context,
              'English / Hollywood Latest',
              '${MobileConfig.tmdbBase}/discover/movie?api_key=${MobileConfig.tmdbKey}&with_original_language=en&primary_release_date.lte=$todayIso&vote_count.gte=50',
              false,
            ),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.video_collection, color: Color(0xFFE50914)),
            title: const Text('Netflix Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () => _openCategory(
              context,
              'Netflix Web Series',
              '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=213&without_genres=10766',
              true,
            ),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.video_library, color: Color(0xFFE50914)),
            title: const Text('Amazon Web Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () => _openCategory(
              context,
              'Amazon Web Series',
              '${MobileConfig.tmdbBase}/discover/tv?api_key=${MobileConfig.tmdbKey}&with_networks=1024&without_genres=10766',
              true,
            ),
          ),
        ],
      ),
    );
  }
}
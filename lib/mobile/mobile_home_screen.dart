import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gist_source_controls.dart';

class MobileHomeScreen extends StatefulWidget {
  final List<String> trendingTitles;
  final void Function(String title)? onPlayTitle;
  final VoidCallback? onSearchTap;

  const MobileHomeScreen({
    super.key,
    this.trendingTitles = const <String>[
      'Guarding Stars',
      'Mike Ward: Modest',
      'Heartland',
      'The Christmas Switch',
      'Allen',
    ],
    this.onPlayTitle,
    this.onSearchTap,
  });

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  static const String _gistPrefKey = 'saved_gist_raw_url';

  String _gistUrl = '';
  int _selectedTabIndex = 0;

  final List<String> _tabs = const <String>['Home', 'Movies', 'Series', 'Specials'];
  final List<String> _filters = const <String>[
    'All Platforms',
    'Bollywood',
    'South Cinema',
  ];
  int _selectedFilterIndex = 0;

  @override
  void initState() {
    super.initState();
    // ऐप खुलते ही पॉप-अप नहीं आएगा; सिर्फ सेव किया हुआ Gist URL लोड होगा
    _loadSavedGistSilently();
  }

  Future<void> _loadSavedGistSilently() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String saved = prefs.getString(_gistPrefKey) ?? '';
    if (!mounted) return;
    setState(() {
      _gistUrl = saved;
    });
    if (saved.isNotEmpty) {
      await _syncGistProviders(saved);
    }
  }

  Future<void> _saveAndLoadGist(String newUrl) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gistPrefKey, newUrl);
    if (!mounted) return;
    setState(() {
      _gistUrl = newUrl;
    });
    if (newUrl.isNotEmpty) {
      await _syncGistProviders(newUrl);
    }
  }

  Future<void> _clearGistUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_gistPrefKey);
    if (!mounted) return;
    setState(() {
      _gistUrl = '';
    });
  }

  Future<void> _syncGistProviders(String url) async {
    // यहाँ अपना मौजूदा Gist URL sync लॉजिक रखें
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  Future<void> _openGistDialog() async {
    await showGistRawUrlDialog(
      context: context,
      initialUrl: _gistUrl,
      onSaveAndLoad: _saveAndLoadGist,
      onClear: _clearGistUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String heroTitle =
        widget.trendingTitles.isNotEmpty ? widget.trendingTitles.first : 'Guarding Stars';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // सबसे ऊपर Top Bar में छोटा सा Gist Badge + Search Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: <Widget>[
                  const Text(
                    'NETFLIX PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  GistMobileBadge(
                    isConnected: _gistUrl.isNotEmpty,
                    onTap: _openGistDialog,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: widget.onSearchTap,
                    icon: const Icon(Icons.search, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Tabs Row
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 18),
                itemBuilder: (BuildContext context, int index) {
                  final bool active = index == _selectedTabIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          _tabs[index],
                          style: TextStyle(
                            color: active ? Colors.white : Colors.white60,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (active)
                          Container(
                            height: 2.5,
                            width: 24,
                            color: Colors.orangeAccent,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // Filter Chips
            SizedBox(
              height: 32,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int index) {
                  final bool selected = index == _selectedFilterIndex;
                  return ChoiceChip(
                    label: Text(
                      _filters[index],
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    selected: selected,
                    selectedColor: Colors.blueAccent.withOpacity(0.35),
                    backgroundColor: const Color(0xFF182032),
                    onSelected: (_) => setState(() => _selectedFilterIndex = index),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Main Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF162033),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            heroTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => widget.onPlayTitle?.call(heroTitle),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Watch Now'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Trending Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.trendingTitles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final String item = widget.trendingTitles[index];
                          return GestureDetector(
                            onTap: () => widget.onPlayTitle?.call(item),
                            child: Container(
                              width: 140,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF182236),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                item,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'tmdb_config.dart';

class TvSearchScreen extends StatefulWidget {
  final FocusNode searchBoxFocusNode;
  final VoidCallback onLeftBoundaryHit;
  final Function(dynamic item) onItemSelected;

  const TvSearchScreen({
    super.key,
    required this.searchBoxFocusNode,
    required this.onLeftBoundaryHit,
    required this.onItemSelected,
  });

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<dynamic> _results = [];
  bool _isLoading = false;
  bool _isShowingTrending = true;

  @override
  void initState() {
    super.initState();
    _fetchTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // जब सर्च बॉक्स खाली हो तो Trending दिखाएँ
  Future<void> _fetchTrending() async {
    setState(() {
      _isLoading = true;
      _isShowingTrending = true;
    });

    try {
      final url =
          '${TvConfig.tmdbBase}/trending/all/day?api_key=${TvConfig.tmdbKey}&language=en-US';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final rawList = jsonDecode(res.body)['results'] ?? [];
        if (mounted) {
          setState(() {
            _results = _parseSearchResults(rawList);
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // टाइप करने के 500ms बाद TMDB Search कॉल करें
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) {
        _fetchTrending();
      } else {
        _performSearch(cleanQuery);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _isShowingTrending = false;
    });

    try {
      final encoded = Uri.encodeQueryComponent(query);
      final url =
          '${TvConfig.tmdbBase}/search/multi?api_key=${TvConfig.tmdbKey}&query=$encoded&include_adult=false&language=en-US&page=1';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final rawList = jsonDecode(res.body)['results'] ?? [];
        if (mounted) {
          setState(() {
            _results = _parseSearchResults(rawList);
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _parseSearchResults(List<dynamic> list) {
    final currentYear = DateTime.now().year.toString();
    var parsed = [];

    for (var m in list) {
      final mediaType = (m['media_type'] ?? '').toString();
      // केवल Movie और TV Series लें (Actors/Person हटा दें)
      if (mediaType != 'movie' && mediaType != 'tv') continue;
      if (m['poster_path'] == null && m['backdrop_path'] == null) continue;

      final isTv = mediaType == 'tv';
      final title = (m['title'] ?? m['name'] ?? 'Untitled').toString();
      if (isTv && isSoapShow(title)) continue;

      parsed.add({
        'tmdb_id': m['id'],
        'title': title,
        'year': (m['release_date'] ?? m['first_air_date'] ?? currentYear)
            .toString()
            .split('-')[0],
        'rating': (m['vote_average'] is num)
            ? (m['vote_average'] as num).toStringAsFixed(1)
            : '7.5',
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
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================================================================
          // SEARCH INPUT BAR (TV REMOTE FRIENDLY)
          // ==================================================================
          Row(
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                        _searchController.text.isEmpty) {
                      widget.onLeftBoundaryHit();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    focusNode: widget.searchBoxFocusNode,
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) _performSearch(val.trim());
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    cursorColor: const Color(0xFFE50914),
                    decoration: InputDecoration(
                      hintText: 'Search Movies, Web Series, South, Hindi...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFE50914), size: 24),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white70),
                              onPressed: () {
                                _searchController.clear();
                                _fetchTrending();
                                widget.searchBoxFocusNode.requestFocus();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF222222),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white, width: 2.2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ==================================================================
          // SECTION HEADER
          // ==================================================================
          Row(
            children: [
              Icon(
                _isShowingTrending ? Icons.local_fire_department_rounded : Icons.movie_filter_rounded,
                color: const Color(0xFFE50914),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isShowingTrending
                    ? 'Trending Searches Today'
                    : 'Search Results (${_results.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ==================================================================
          // RESULTS GRID (5 COLUMNS)
          // ==================================================================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          'No results found for "${_searchController.text}"',
                          style: const TextStyle(color: Colors.white54, fontSize: 15),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (ctx, idx) {
                          final item = _results[idx];
                          final isFirstInRow = (idx % 5 == 0);

                          return _SearchGridCard(
                            item: item,
                            isFirstInRow: isFirstInRow,
                            onLeftBoundaryHit: widget.onLeftBoundaryHit,
                            onTap: () => widget.onItemSelected(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SearchGridCard extends StatefulWidget {
  final dynamic item;
  final bool isFirstInRow;
  final VoidCallback onLeftBoundaryHit;
  final VoidCallback onTap;

  const _SearchGridCard({
    required this.item,
    required this.isFirstInRow,
    required this.onLeftBoundaryHit,
    required this.onTap,
  });

  @override
  State<_SearchGridCard> createState() => _SearchGridCardState();
}

class _SearchGridCardState extends State<_SearchGridCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isTv = widget.item['isTv'] == true;

    return Focus(
      onFocusChange: (f) => setState(() => _isFocused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: _isFocused ? 3.0 : 0.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFE50914).withOpacity(0.55),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                widget.item['poster'],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF222222)),
              ),
              // Top Badge (MOVIE / SERIES)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isTv ? const Color(0xFFE50914) : Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Text(
                    isTv ? 'SERIES' : 'MOVIE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Bottom Title & Rating
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
                        widget.item['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${widget.item['rating']} ★',
                            style: const TextStyle(color: Color(0xFF46D369), fontSize: 11),
                          ),
                          Text(
                            '${widget.item['year']}',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
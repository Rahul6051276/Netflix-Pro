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
  final FocusNode _inputFocusNode = FocusNode();
  final FocusNode _firstGridItemFocus = FocusNode();
  Timer? _debounce;
  List<dynamic> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    // जब Sidebar से focus भेजा जाए तो सीधे TextField के असली FocusNode पर ट्रांसफर करें
    widget.searchBoxFocusNode.addListener(_forwardFocusToInput);
  }

  void _forwardFocusToInput() {
    if (widget.searchBoxFocusNode.hasFocus && mounted) {
      _inputFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    widget.searchBoxFocusNode.removeListener(_forwardFocusToInput);
    _debounce?.cancel();
    _searchController.dispose();
    _inputFocusNode.dispose();
    _firstGridItemFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {});
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) {
        if (mounted) {
          setState(() {
            _results = [];
            _hasSearched = false;
            _isLoading = false;
          });
        }
      } else {
        _performSearch(cleanQuery);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
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
      } else {
        if (mounted) setState(() => _isLoading = false);
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
          // SEARCH INPUT BAR (PROPER ANDROID TV IME CONNECTION)
          // ==================================================================
          Focus(
            skipTraversal: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                // बॉक्स खाली होने पर Left दबाने से वापस Sidebar पर जाएँ
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                    _searchController.text.isEmpty) {
                  widget.onLeftBoundaryHit();
                  return KeyEventResult.handled;
                }
                // रिजल्ट आने पर Down दबाने से नीचे पोस्टर पर जाएँ
                if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                    _results.isNotEmpty) {
                  _firstGridItemFocus.requestFocus();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              focusNode: _inputFocusNode,
              autofocus: true,
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  _performSearch(val.trim());
                }
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
                          setState(() {
                            _results = [];
                            _hasSearched = false;
                          });
                          _inputFocusNode.requestFocus();
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

          const SizedBox(height: 16),

          // ==================================================================
          // HEADER (केवल सर्च करने पर ही दिखेगा)
          // ==================================================================
          if (_hasSearched) ...[
            Row(
              children: [
                const Icon(
                  Icons.movie_filter_rounded,
                  color: Color(0xFFE50914),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Search Results (${_results.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // ==================================================================
          // SEARCH RESULTS GRID (NO DEFAULT TRENDING ITEMS)
          // ==================================================================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : !_hasSearched
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_rounded, color: Colors.white24, size: 54),
                            SizedBox(height: 10),
                            Text(
                              'Type any Movie or Web Series name above to search',
                              style: TextStyle(color: Colors.white54, fontSize: 15),
                            ),
                          ],
                        ),
                      )
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
                              final isTopRow = (idx < 5);

                              return _SearchGridCard(
                                focusNode: idx == 0 ? _firstGridItemFocus : null,
                                item: item,
                                isFirstInRow: isFirstInRow,
                                isTopRow: isTopRow,
                                onUpBoundaryHit: () {
                                  _inputFocusNode.requestFocus();
                                },
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
  final FocusNode? focusNode;
  final dynamic item;
  final bool isFirstInRow;
  final bool isTopRow;
  final VoidCallback onUpBoundaryHit;
  final VoidCallback onLeftBoundaryHit;
  final VoidCallback onTap;

  const _SearchGridCard({
    this.focusNode,
    required this.item,
    required this.isFirstInRow,
    required this.isTopRow,
    required this.onUpBoundaryHit,
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
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _isFocused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft && widget.isFirstInRow) {
            widget.onLeftBoundaryHit();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp && widget.isTopRow) {
            widget.onUpBoundaryHit();
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
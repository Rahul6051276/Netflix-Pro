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
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();

    // Prime Flix का Exact Keyboard Focus Logic (बिना किसी onKeyEvent रुकावट के)
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
      if (_searchFocusNode.hasFocus) {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    setState(() {});
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final encodedQuery = Uri.encodeComponent(query);

    try {
      final url = Uri.parse(
        '${TvConfig.tmdbBase}/search/multi?api_key=${TvConfig.tmdbKey}&query=$encodedQuery&include_adult=false&page=1',
      );

      final res = await http.get(url).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawList = data['results'] as List? ?? [];
        final currentYear = DateTime.now().year.toString();
        List<dynamic> parsed = [];

        for (var m in rawList) {
          final mediaType = m['media_type'];
          if (mediaType != 'movie' && mediaType != 'tv') continue;
          final bool isTv = (mediaType == 'tv');

          final title = (isTv ? (m['name'] ?? m['original_name'] ?? '') : (m['title'] ?? m['original_title'] ?? '')).toString();
          if (isTv && isSoapShow(title)) continue;

          final posterPath = m['poster_path'];
          if (posterPath != null && posterPath.toString().isNotEmpty) {
            parsed.add({
              'tmdb_id': m['id'],
              'title': title,
              'poster': '${TvConfig.imgBase}$posterPath',
              'backdrop': m['backdrop_path'] != null
                  ? '${TvConfig.backdropBase}${m['backdrop_path']}'
                  : '${TvConfig.imgBase}$posterPath',
              'year': (isTv ? (m['first_air_date'] ?? '') : (m['release_date'] ?? '')).toString().split('-').first.isNotEmpty
                  ? (isTv ? (m['first_air_date'] ?? '') : (m['release_date'] ?? '')).toString().split('-').first
                  : currentYear,
              'rating': (m['vote_average'] is num)
                  ? (m['vote_average'] as num).toStringAsFixed(1)
                  : '7.5',
              'overview': m['overview'] ?? '',
              'isTv': isTv,
            });
          }
        }

        if (mounted) {
          setState(() {
            _searchResults = parsed;
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================================================================
          // PRIME FLIX STYLE SEARCH BAR (100% WORKING GBOARD TYPING)
          // ==================================================================
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _searchFocusNode.hasFocus ? Colors.white : Colors.white24,
                width: _searchFocusNode.hasFocus ? 2.2 : 1.2,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: const Color(0xFFE50914),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _performSearch(v.trim()),
              onChanged: _onSearchChanged,
              onTap: () {
                SystemChannels.textInput.invokeMethod('TextInput.show');
              },
              decoration: InputDecoration(
                hintText: 'Search Movies, Web Series, South, Hindi...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFE50914), size: 24),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                          _searchFocusNode.requestFocus();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_searchResults.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.movie_filter_rounded, color: Color(0xFFE50914), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Search Results (${_searchResults.length})',
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
          // 5-COLUMN POSTER GRID (NETFLIX PRO THEME & SIZE)
          // ==================================================================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_rounded, color: Colors.white24, size: 54),
                            const SizedBox(height: 10),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Type any Movie or Web Series name above to search'
                                  : 'No movies or series found',
                              style: const TextStyle(color: Colors.white54, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: _searchResults.length,
                        itemBuilder: (ctx, idx) {
                          final item = _searchResults[idx];
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
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedScale(
          scale: _isFocused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
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
                  : null,
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
      ),
    );
  }
}
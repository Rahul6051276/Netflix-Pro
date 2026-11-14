import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'tmdb_config.dart';
import 'stream_resolver_sheet.dart';

// ============================================================================
// FULL SCREEN VERTICAL GRID SCREEN (DIRECT NATIVE PLAYER LAUNCH)
// ============================================================================
class TVCategoryGridScreen extends StatefulWidget {
  final String title;
  final String baseUrl;
  final bool isTv;
  final List providers;
  final VoidCallback onPlaySaved;

  const TVCategoryGridScreen({
    super.key,
    required this.title,
    required this.baseUrl,
    required this.isTv,
    required this.providers,
    required this.onPlaySaved,
  });

  @override
  State createState() => _TVCategoryGridScreenState();
}

class _TVCategoryGridScreenState extends State<TVCategoryGridScreen> {
  var items = [];
  bool isLoading = true;
  String sortType = 'latest';

  @override
  void initState() {
    super.initState();
    _fetchGridData();
  }

  void _toggleSort() {
    setState(() {
      sortType = sortType == 'latest' ? 'popular' : 'latest';
      isLoading = true;
      items.clear();
    });
    _fetchGridData();
  }

  Future _fetchGridData() async {
    final sortQuery = sortType == 'latest'
        ? (widget.isTv ? 'first_air_date.desc' : 'primary_release_date.desc')
        : 'popularity.desc';

    var cleanUrl = widget.baseUrl;
    cleanUrl = cleanUrl.replaceAll(RegExp(r'sort_by=[^&]+'), '');
    final sep = cleanUrl.contains('?') ? '&' : '?';

    var accumulated = [];
    for (int p = 1; p <= 10; p++) {
      try {
        final url = '$cleanUrl${sep}sort_by=$sortQuery&page=$p';
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body)['results'];
          final currentYear = DateTime.now().year.toString();
          for (var m in (data ?? [])) {
            if (m['backdrop_path'] == null && m['poster_path'] == null) continue;
            final t = (m['title'] ?? m['name'] ?? 'Untitled').toString();
            if (isSoapShow(t)) continue;

            accumulated.add({
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
              'isTv': widget.isTv,
            });
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        items = accumulated;
        isLoading = false;
      });
    }
  }

  void _handleItemClick(dynamic item) {
    if (item['isTv'] == true) {
      showDialog(
        context: context,
        builder: (ctx) => TvEpisodeDialog(
          item: item,
          onSelected: (season, episode) {
            launchTvDirectNativePlayer(
              item: item,
              season: season,
              episode: episode,
              onPlaySaved: widget.onPlaySaved,
            );
          },
        ),
      );
    } else {
      launchTvDirectNativePlayer(
        item: item,
        onPlaySaved: widget.onPlaySaved,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.9),
        title: Row(
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(4)),
              child: Text('${items.length} Titles', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Focus(
              onKey: (node, event) {
                if (event is RawKeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter)) {
                  _toggleSort();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(builder: (c) {
                final focused = Focus.of(c).hasFocus;
                return InkWell(
                  onTap: _toggleSort,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: focused ? Colors.white : const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: focused ? Colors.white : const Color(0xFFE50914),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          sortType == 'latest' ? Icons.fiber_new_rounded : Icons.whatshot_rounded,
                          size: 18,
                          color: focused ? Colors.black : const Color(0xFFE50914),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sortType == 'latest' ? 'Filter: Latest Releases' : 'Filter: Most Popular',
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
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                  childAspectRatio: 0.68,
                ),
                itemCount: items.length,
                itemBuilder: (ctx, idx) {
                  final item = items[idx];
                  return Focus(
                    onKey: (node, event) {
                      if (event is RawKeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.enter)) {
                        _handleItemClick(item);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Builder(
                      builder: (context) {
                        final isFocused = Focus.of(context).hasFocus;
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _handleItemClick(item),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isFocused ? Colors.white : Colors.transparent,
                                width: isFocused ? 3.0 : 0.0,
                              ),
                              boxShadow: isFocused
                                  ? [BoxShadow(color: const Color(0xFFE50914).withOpacity(0.55), blurRadius: 12, spreadRadius: 2)]
                                  : [],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  item['poster'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF222222)),
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
                                          item['title'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('${item['rating']} ★', style: const TextStyle(color: Color(0xFF46D369), fontSize: 11)),
                                            Text('${item['year']}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
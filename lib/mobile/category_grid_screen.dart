import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'tmdb_config.dart';
import 'stream_resolver_sheet.dart';
import 'media_detail_sheet.dart';

class MobileCategoryGridScreen extends StatefulWidget {
  final String title;
  final String baseUrl;
  final bool isTv;
  final List<dynamic> providers;
  final VoidCallback onPlaySaved;

  const MobileCategoryGridScreen({
    super.key,
    required this.title,
    required this.baseUrl,
    required this.isTv,
    required this.providers,
    required this.onPlaySaved,
  });

  @override
  State<MobileCategoryGridScreen> createState() => _MobileCategoryGridScreenState();
}

class _MobileCategoryGridScreenState extends State<MobileCategoryGridScreen> {
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

  Future<void> _fetchGridData() async {
    final sortQuery = sortType == 'latest'
        ? (widget.isTv ? 'first_air_date.desc' : 'primary_release_date.desc')
        : 'popularity.desc';

    var cleanUrl = widget.baseUrl;
    cleanUrl = cleanUrl.replaceAll(RegExp(r'sort_by=[^&]+'), '');
    final sep = cleanUrl.contains('?') ? '&' : '?';

    var accumulated = [];
    for (int p = 1; p <= 8; p++) {
      try {
        final url = '$cleanUrl${sep}sort_by=$sortQuery&page=$p';
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body)['results'];
          final currentYear = DateTime.now().year.toString();
          for (var m in (data ?? [])) {
            if (m['backdrop_path'] == null && m['poster_path'] == null) continue;
            final t = (m['title'] ?? m['name'] ?? 'Untitled').toString();
            if (widget.isTv && isSoapShow(t)) continue;

            accumulated.add({
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

  void _onGridItemClick(dynamic item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MediaDetailSheet(
        item: item,
        providers: widget.providers,
        onPlaySaved: widget.onPlaySaved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.9),
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _toggleSort,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE50914), width: 1.2),
                ),
                child: Row(
                  children: [
                    Icon(
                      sortType == 'latest' ? Icons.fiber_new_rounded : Icons.whatshot_rounded,
                      size: 16,
                      color: const Color(0xFFE50914),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sortType == 'latest' ? 'Latest' : 'Popular',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 10,
                childAspectRatio: 0.64,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, idx) {
                final item = items[idx];
                return InkWell(
                  onTap: () => _onGridItemClick(item),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                                  item['title'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${item['rating']} ★', style: const TextStyle(color: Color(0xFF46D369), fontSize: 9)),
                                    Text('${item['year']}', style: const TextStyle(color: Colors.white60, fontSize: 9)),
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
  }
}
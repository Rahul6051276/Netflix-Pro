import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MobileRootScreen extends StatelessWidget {
  const MobileRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MobileHomeScreen();
  }
}

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
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  Future<void> _openGistDialog() async {
    await _showMobileGistDialog(
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
                  _GistMobileBadge(
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

class _GistMobileBadge extends StatelessWidget {
  final VoidCallback onTap;
  final bool isConnected;

  const _GistMobileBadge({
    required this.onTap,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isConnected
              ? const Color(0xFF143626)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isConnected ? Colors.greenAccent.withOpacity(0.6) : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.link,
              size: 14,
              color: isConnected ? Colors.greenAccent : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              isConnected ? 'Gist Active' : 'Gist Link',
              style: TextStyle(
                color: isConnected ? Colors.greenAccent : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isConnected) ...<Widget>[
              const SizedBox(width: 5),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showMobileGistDialog({
  required BuildContext context,
  required String initialUrl,
  required Future<void> Function(String newUrl) onSaveAndLoad,
  required Future<void> Function() onClear,
}) async {
  final TextEditingController controller = TextEditingController(text: initialUrl);
  bool isSaving = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          Future<void> handleSave() async {
            if (isSaving) return;
            final String trimmed = controller.text.trim();
            setModalState(() => isSaving = true);
            try {
              await onSaveAndLoad(trimmed);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            } finally {
              if (dialogContext.mounted) {
                setModalState(() => isSaving = false);
              }
            }
          }

          Future<void> handleClear() async {
            if (isSaving) return;
            controller.clear();
            setModalState(() => isSaving = true);
            try {
              await onClear();
            } finally {
              if (dialogContext.mounted) {
                setModalState(() => isSaving = false);
              }
            }
          }

          return Dialog(
            backgroundColor: const Color(0xFF1F242D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.white24, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.link, color: Colors.orangeAccent),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'GitHub Gist Raw Source',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'अपना GitHub Gist Raw Link (providers.json) यहाँ पेस्ट करें:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !isSaving,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'https://gist.githubusercontent.com/.../raw/providers.json',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF14181F),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: isSaving ? null : handleClear,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: isSaving ? null : handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Connect & Sync'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  controller.dispose();
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TvHomeScreen extends StatefulWidget {
  final List<String> featuredTitles;
  final List<String> latestBlocks;
  final void Function(String title)? onPlayTitle;

  const TvHomeScreen({
    super.key,
    this.featuredTitles = const <String>[
      'Guarding Stars',
      'Mike Ward: Modest',
      'Heartland',
      'The Christmas Switch',
      'Allen',
    ],
    this.latestBlocks = const <String>[
      'Guarding Stars',
      'Mike Ward: Modest',
      'Heartland',
      'The Christmas Switch',
      'Allen',
    ],
    this.onPlayTitle,
  });

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  static const String _gistPrefKey = 'saved_gist_raw_url';

  String _gistUrl = '';
  int _selectedNavIndex = 2;
  bool _isLoadingGist = false;

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
      await _syncGistProviders(saved, showToast: false);
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
      await _syncGistProviders(newUrl, showToast: true);
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

  Future<void> _syncGistProviders(String url, {required bool showToast}) async {
    setState(() => _isLoadingGist = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted && showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gist URL saved & synced')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGist = false);
      }
    }
  }

  Future<void> _openGistDialog() async {
    await _showTvGistDialog(
      context: context,
      initialUrl: _gistUrl,
      onSaveAndLoad: _saveAndLoadGist,
      onClear: _clearGistUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String heroTitle =
        widget.featuredTitles.isNotEmpty ? widget.featuredTitles.first : 'Guarding Stars';

    return Scaffold(
      backgroundColor: const Color(0xFF0E1117),
      body: Row(
        children: <Widget>[
          // TV Left Sidebar (रिमोट D-Pad फोकस के साथ)
          Container(
            width: 68,
            color: const Color(0xFF141821),
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    _TvSidebarIconButton(
                      icon: Icons.person_outline,
                      selected: _selectedNavIndex == 0,
                      onPressed: () => setState(() => _selectedNavIndex = 0),
                    ),
                    _TvSidebarIconButton(
                      icon: Icons.search,
                      selected: _selectedNavIndex == 1,
                      onPressed: () => setState(() => _selectedNavIndex = 1),
                    ),
                    _TvSidebarIconButton(
                      icon: Icons.home_outlined,
                      selected: _selectedNavIndex == 2,
                      onPressed: () => setState(() => _selectedNavIndex = 2),
                    ),
                    _TvSidebarIconButton(
                      icon: Icons.tv,
                      selected: _selectedNavIndex == 3,
                      onPressed: () => setState(() => _selectedNavIndex = 3),
                    ),
                    _TvSidebarIconButton(
                      icon: Icons.movie_outlined,
                      selected: _selectedNavIndex == 4,
                      onPressed: () => setState(() => _selectedNavIndex = 4),
                    ),
                    _TvSidebarIconButton(
                      icon: Icons.grid_view,
                      selected: _selectedNavIndex == 5,
                      onPressed: () => setState(() => _selectedNavIndex = 5),
                    ),
                  ],
                ),
                _TvGistSidebarButton(
                  isConnected: _gistUrl.isNotEmpty,
                  onPressed: _openGistDialog,
                ),
              ],
            ),
          ),

          // Main TV Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    height: 270,
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF1E293B), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text(
                          'NETFLIX PRO • MOVIE',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          heroTitle.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _TvFocusableActionButton(
                          label: 'Watch Now',
                          icon: Icons.play_arrow,
                          onPressed: () => widget.onPlayTitle?.call(heroTitle),
                        ),
                        if (_isLoadingGist) ...<Widget>[
                          const SizedBox(height: 10),
                          const Text(
                            'Syncing Gist...',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Latest Netflix Blockbusters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 135,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.latestBlocks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (BuildContext context, int index) {
                        final String title = widget.latestBlocks[index];
                        return _TvCatalogueCard(
                          title: title,
                          onSelect: () => widget.onPlayTitle?.call(title),
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
    );
  }
}

class _TvGistSidebarButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isConnected;

  const _TvGistSidebarButton({
    required this.onPressed,
    this.isConnected = false,
  });

  @override
  State<_TvGistSidebarButton> createState() => _TvGistSidebarButtonState();
}

class _TvGistSidebarButtonState extends State<_TvGistSidebarButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (bool focused) => setState(() => _hasFocus = focused),
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white.withOpacity(0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hasFocus ? Colors.orangeAccent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Icon(
                Icons.link,
                size: 24,
                color: _hasFocus ? Colors.orangeAccent : Colors.white70,
              ),
              if (widget.isConnected)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
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

Future<void> _showTvGistDialog({
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
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
                            'Enter Gist Raw URL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
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
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      enabled: !isSaving,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onSubmitted: (_) => handleSave(),
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
                    const SizedBox(height: 18),
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
                            backgroundColor: const Color(0xFFFF6D00),
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
                              : const Text('Save & Load'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  controller.dispose();
}

class _TvSidebarIconButton extends StatefulWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _TvSidebarIconButton({
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  State<_TvSidebarIconButton> createState() => _TvSidebarIconButtonState();
}

class _TvSidebarIconButtonState extends State<_TvSidebarIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (bool f) => setState(() => _focused = f),
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _focused
                ? Colors.white.withOpacity(0.16)
                : (widget.selected ? Colors.white.withOpacity(0.08) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? Colors.orangeAccent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 22,
            color: _focused
                ? Colors.orangeAccent
                : (widget.selected ? Colors.white : Colors.white70),
          ),
        ),
      ),
    );
  }
}

class _TvFocusableActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _TvFocusableActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_TvFocusableActionButton> createState() => _TvFocusableActionButtonState();
}

class _TvFocusableActionButtonState extends State<_TvFocusableActionButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (bool f) => setState(() => _focused = f),
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvCatalogueCard extends StatefulWidget {
  final String title;
  final VoidCallback onSelect;

  const _TvCatalogueCard({
    required this.title,
    required this.onSelect,
  });

  @override
  State<_TvCatalogueCard> createState() => _TvCatalogueCardState();
}

class _TvCatalogueCardState extends State<_TvCatalogueCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (bool f) => setState(() => _focused = f),
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onSelect();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Container(
          width: 190,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A202C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? Colors.orangeAccent : Colors.white12,
              width: _focused ? 2.5 : 1,
            ),
          ),
          alignment: Alignment.bottomLeft,
          child: Text(
            widget.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
  String _formatTvConnectedProviders() {
    if (activeProviders.isEmpty) {
      return 'Connected: Gist Source Active';
    }
    final names = activeProviders
        .map((p) => p is Map ? (p['name'] ?? p['title'] ?? p['id'] ?? '').toString() : p.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      return 'Connected: ${activeProviders.length} Active Sources';
    }
    return 'Connected: ${names.join(' + ')}';
  }

  bool _isRemoteOkKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  void _showGistConfigDialog() {
    final controller = TextEditingController();
    final FocusNode inputFocus = FocusNode(debugLabel: 'tv_gist_input');
    final FocusNode syncFocus = FocusNode(debugLabel: 'tv_gist_sync');
    final FocusNode clearFocus = FocusNode(debugLabel: 'tv_gist_clear');
    final FocusNode closeFocus = FocusNode(debugLabel: 'tv_gist_close');

    TvConfig.getGistUrl().then((existing) {
      controller.text = existing;
      if (!mounted) return;
      bool isSyncing = false;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) {
            final bool isConnected = controller.text.trim().isNotEmpty;

            Future<void> handleConnectAndSync() async {
              if (isSyncing) return;
              final val = controller.text.trim();
              if (val.isEmpty) return;
              setModalState(() => isSyncing = true);
              try {
                await TvConfig.saveGistUrl(val);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  setState(() {
                    _hasGistUrl = true;
                    isLoading = true;
                  });
                }
                await _loadAllTvData();
              } finally {
                if (mounted) {
                  setModalState(() => isSyncing = false);
                }
              }
            }

            Future<void> handleClear() async {
              if (isSyncing) return;
              controller.clear();
              await TvConfig.saveGistUrl('');
              if (mounted) {
                setState(() {
                  activeProviders = [];
                  _hasGistUrl = false;
                });
              }
              setModalState(() {});
            }

            return Dialog(
              backgroundColor: const Color(0xFF1A2234),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Colors.white12, width: 1),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Icon(Icons.link_rounded, color: Color(0xFFEAB308), size: 22),
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
                                    'Supports Xtream IPTV, Stremio Addons & JSON',
                                    style: TextStyle(
                                      color: Color(0xFFEAB308),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(4),
                              child: Focus(
                                focusNode: closeFocus,
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent && _isRemoteOkKey(event.logicalKey)) {
                                    Navigator.of(ctx).pop();
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: Builder(builder: (c) {
                                  final focused = Focus.of(c).hasFocus;
                                  return IconButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: focused ? Colors.white : Colors.white70,
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // English Label & Input Box
                        const Text(
                          'GitHub Gist Raw Link (or IPTV / Stremio link)',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(1),
                          child: TextField(
                            controller: controller,
                            focusNode: inputFocus,
                            autofocus: true,
                            maxLines: 2,
                            minLines: 1,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5),
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => setModalState(() {}),
                            onSubmitted: (_) => handleConnectAndSync(),
                            decoration: InputDecoration(
                              hintText: 'https://gist.githubusercontent.com/.../raw/providers.json',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFF131926),
                              contentPadding: const EdgeInsets.all(14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Connected Status Box
                        if (isConnected) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF123528),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.45)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _formatTvConnectedProviders(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Connect & Sync + Clear Buttons (Full TV Remote D-Pad + OK Support)
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: FocusTraversalOrder(
                                order: const NumericFocusOrder(2),
                                child: Focus(
                                  focusNode: syncFocus,
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent && _isRemoteOkKey(event.logicalKey)) {
                                      handleConnectAndSync();
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: Builder(builder: (c) {
                                    final focused = Focus.of(c).hasFocus;
                                    return SizedBox(
                                      height: 46,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          side: BorderSide(
                                            color: focused ? Colors.white : Colors.transparent,
                                            width: 2.2,
                                          ),
                                        ),
                                        onPressed: isSyncing ? null : handleConnectAndSync,
                                        icon: const Icon(Icons.refresh_rounded, size: 18),
                                        label: const Text(
                                          'Connect & Sync',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FocusTraversalOrder(
                                order: const NumericFocusOrder(3),
                                child: Focus(
                                  focusNode: clearFocus,
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent && _isRemoteOkKey(event.logicalKey)) {
                                      handleClear();
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: Builder(builder: (c) {
                                    final focused = Focus.of(c).hasFocus;
                                    return SizedBox(
                                      height: 46,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFEF4444),
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          side: BorderSide(
                                            color: focused
                                                ? Colors.white
                                                : const Color(0xFFEF4444).withOpacity(0.55),
                                            width: focused ? 2.2 : 1,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: isSyncing ? null : handleClear,
                                        child: const Text(
                                          'Clear',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ).then((_) {
        inputFocus.dispose();
        syncFocus.dispose();
        clearFocus.dispose();
        closeFocus.dispose();
        controller.dispose();
      });
    });
  }
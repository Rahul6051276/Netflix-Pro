// ============================================================================
// TV GIST MANAGER DIALOG (100% TV REMOTE & MOBILE REMOTE KEYBOARD FRIENDLY)
// ============================================================================
class _TvGistManagerDialog extends StatefulWidget {
  final String initialUrl;
  final List currentProviders;
  final Function(String url, List providers) onSynced;

  const _TvGistManagerDialog({
    required this.initialUrl,
    required this.currentProviders,
    required this.onSynced,
  });

  @override
  State<_TvGistManagerDialog> createState() => _TvGistManagerDialogState();
}

class _TvGistManagerDialogState extends State<_TvGistManagerDialog> {
  late TextEditingController _urlController;
  final FocusNode _inputFocusNode = FocusNode();
  final FocusNode _connectBtnFocusNode = FocusNode();
  final FocusNode _clearBtnFocusNode = FocusNode();
  final FocusNode _closeBtnFocusNode = FocusNode();

  bool isSyncing = false;
  String statusMessage = '';
  bool isSuccess = false;
  List loadedList = [];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    loadedList = List.from(widget.currentProviders);

    _inputFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _connectBtnFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _clearBtnFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _closeBtnFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.initialUrl.isNotEmpty && loadedList.isNotEmpty) {
      isSuccess = true;
      final names = loadedList.map((p) => (p['name'] ?? p['type'] ?? 'Source').toString()).join(' + ');
      statusMessage = 'Connected: $names';
    } else {
      isSuccess = false;
      statusMessage = 'Gist Link Required! Paste your GitHub Gist Raw link below to activate playback.';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (widget.initialUrl.isNotEmpty) {
          _connectBtnFocusNode.requestFocus();
        } else {
          _inputFocusNode.requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _inputFocusNode.dispose();
    _connectBtnFocusNode.dispose();
    _clearBtnFocusNode.dispose();
    _closeBtnFocusNode.dispose();
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
    for (final h in {rawHost, cleanHost}) {
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
            return status.toLowerCase() == 'active' ? '$name (Active ✓)' : '$name ($status)';
          }
        }
      } catch (_) {}
    }
    return '$name (Offline/Blocked)';
  }

  Future<void> _connectAndSync() async {
    FocusScope.of(context).unfocus();
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        isSuccess = false;
        statusMessage = 'Please paste a valid GitHub Gist Raw link first.';
      });
      _inputFocusNode.requestFocus();
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
          await prefs.setString('tv_custom_gist_url', rawUrl);
          await prefs.setString('tv_cached_active_providers', jsonEncode(list));

          final statuses = await Future.wait(list.map((p) => _checkSingleProviderStatus(p)));
          widget.onSynced(rawUrl, list);

          if (mounted) {
            setState(() {
              isSyncing = false;
              isSuccess = true;
              loadedList = list;
              statusMessage = 'Connected: ${statuses.join(' + ')}';
            });
            _closeBtnFocusNode.requestFocus();
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
        _connectBtnFocusNode.requestFocus();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isSyncing = false;
          isSuccess = false;
          statusMessage = 'Connection Error: Check URL or Internet.';
        });
        _connectBtnFocusNode.requestFocus();
      }
    }
  }

  Future<void> _clearGist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tv_custom_gist_url', '');
    await prefs.remove('tv_cached_active_providers');
    _urlController.clear();
    widget.onSynced('', []);
    if (mounted) {
      setState(() {
        isSuccess = false;
        loadedList = [];
        statusMessage = 'Cleared! TV playback disabled until you add a Gist link.';
      });
      _inputFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141B2D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF2B3654), width: 1.5),
      ),
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.link_rounded, color: Color(0xFFFACC15), size: 26),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TV GitHub Gist Raw Source',
                          style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Paste URL & press Done/Enter or Down arrow to Sync',
                          style: TextStyle(color: Color(0xFFFACC15), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Focus(
                    focusNode: _closeBtnFocusNode,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          _inputFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          Navigator.pop(context);
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _closeBtnFocusNode.hasFocus ? const Color(0xFFE50914) : Colors.white12,
                          border: Border.all(
                            color: _closeBtnFocusNode.hasFocus ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Single-line D-Pad aware Input Box
              Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                      _connectBtnFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                      _closeBtnFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _inputFocusNode.hasFocus ? Colors.white : const Color(0xFF334155),
                      width: _inputFocusNode.hasFocus ? 2.2 : 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: _urlController,
                    focusNode: _inputFocusNode,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _connectAndSync(),
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: const InputDecoration(
                      hintText: 'Paste https://gist.githubusercontent.com/.../raw/providers.json',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                    ),
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
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
                child: Text(
                  statusMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Focus(
                      focusNode: _connectBtnFocusNode,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                            _inputFocusNode.requestFocus();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                            _clearBtnFocusNode.requestFocus();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.enter) {
                            if (!isSyncing) _connectAndSync();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: InkWell(
                        onTap: isSyncing ? null : _connectAndSync,
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: _connectBtnFocusNode.hasFocus
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _connectBtnFocusNode.hasFocus ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: _connectBtnFocusNode.hasFocus
                                ? [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.6), blurRadius: 12)]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.sync_rounded, color: Colors.white, size: 19),
                              const SizedBox(width: 8),
                              Text(
                                isSyncing ? 'Checking...' : 'Connect & Sync',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Focus(
                      focusNode: _clearBtnFocusNode,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                            _inputFocusNode.requestFocus();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                            _connectBtnFocusNode.requestFocus();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.enter) {
                            if (!isSyncing) _clearGist();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: InkWell(
                        onTap: isSyncing ? null : _clearGist,
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: _clearBtnFocusNode.hasFocus
                                ? const Color(0xFF991B1B)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _clearBtnFocusNode.hasFocus ? Colors.white : const Color(0xFF7F1D1D),
                              width: _clearBtnFocusNode.hasFocus ? 2.5 : 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Clear',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
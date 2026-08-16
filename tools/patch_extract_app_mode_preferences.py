from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import '../features/history/history_selection.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one settings import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/settings/app_mode_preferences.dart';\n", 1)

const_line = "  static const _appModePreferenceKey = 'wavezero.app_mode';\n"
if text.count(const_line) != 1:
    raise SystemExit(f'expected one app mode key, found {text.count(const_line)}')
text = text.replace(const_line, '', 1)

field_anchor = "  final WzPlaybackPreferences _playbackPreferences = const WzPlaybackPreferences();\n"
if text.count(field_anchor) != 1:
    raise SystemExit(f'expected one playback prefs field anchor, found {text.count(field_anchor)}')
text = text.replace(field_anchor, field_anchor + "  final WzAppModePreferences _appModePreferences = const WzAppModePreferences();\n", 1)

old_load = """  Future<void> _loadAppMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_appModePreferenceKey);
    if (!mounted) return;
    setState(() {
      _appMode = savedMode == WzAppMode.developer.name && widget.appConfig.showDeveloperEntry ? WzAppMode.developer : WzAppMode.consumer;
      if (_appMode == WzAppMode.consumer && _selectedTab == WzAppTab.engine) {
        _selectedTab = WzAppTab.home;
      }
    });
  }
"""
new_load = """  Future<void> _loadAppMode() async {
    final mode = await _appModePreferences.load(allowDeveloper: widget.appConfig.showDeveloperEntry);
    if (!mounted) return;
    setState(() {
      _appMode = mode;
      if (_appMode == WzAppMode.consumer && _selectedTab == WzAppTab.engine) {
        _selectedTab = WzAppTab.home;
      }
    });
  }
"""
if text.count(old_load) != 1:
    raise SystemExit(f'expected one app mode loader, found {text.count(old_load)}')
text = text.replace(old_load, new_load, 1)

old_save = """    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appModePreferenceKey, mode.name);
"""
new_save = """    await _appModePreferences.save(mode);
"""
if text.count(old_save) != 1:
    raise SystemExit(f'expected one app mode save block, found {text.count(old_save)}')
text = text.replace(old_save, new_save, 1)

path.write_text(text)

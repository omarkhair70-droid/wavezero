from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import 'theme/wavezero_theme.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one theme import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import 'theme/wavezero_theme_preferences.dart';\n", 1)

state_anchor = "class _WaveZeroLiveMetricsAppState extends State<WaveZeroLiveMetricsApp> {\n  WzThemeConfig _themeConfig = const WzThemeConfig();\n"
replacement_state = "class _WaveZeroLiveMetricsAppState extends State<WaveZeroLiveMetricsApp> {\n  final WzThemePreferences _themePreferences = const WzThemePreferences();\n  WzThemeConfig _themeConfig = const WzThemeConfig();\n"
if text.count(state_anchor) != 1:
    raise SystemExit(f'expected one root theme state anchor, found {text.count(state_anchor)}')
text = text.replace(state_anchor, replacement_state, 1)

old_load = """  Future<void> _loadThemeConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _themeConfig = WzThemeConfig.fromPrefs(prefs));
  }
"""
new_load = """  Future<void> _loadThemeConfig() async {
    final config = await _themePreferences.load();
    if (!mounted) return;
    setState(() => _themeConfig = config);
  }
"""
if text.count(old_load) != 1:
    raise SystemExit(f'expected one theme loader, found {text.count(old_load)}')
text = text.replace(old_load, new_load, 1)

old_save = """  Future<void> _setThemeConfig(WzThemeConfig config) async {
    setState(() => _themeConfig = config);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WzThemeConfig.themePreferenceKey, config.themePreset.name);
    await prefs.setString(WzThemeConfig.accentPreferenceKey, config.accentPreset.name);
  }
"""
new_save = """  Future<void> _setThemeConfig(WzThemeConfig config) async {
    setState(() => _themeConfig = config);
    await _themePreferences.save(config);
  }
"""
if text.count(old_save) != 1:
    raise SystemExit(f'expected one theme saver, found {text.count(old_save)}')
text = text.replace(old_save, new_save, 1)

if 'SharedPreferences.' not in text:
    text = text.replace("import 'package:shared_preferences/shared_preferences.dart';\n", '')

path.write_text(text)

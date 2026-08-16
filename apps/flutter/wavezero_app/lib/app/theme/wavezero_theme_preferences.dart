import 'package:shared_preferences/shared_preferences.dart';

import 'wavezero_theme.dart';

class WzThemePreferences {
  const WzThemePreferences();

  Future<WzThemeConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WzThemeConfig.fromPrefs(prefs);
  }

  Future<void> save(WzThemeConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      WzThemeConfig.themePreferenceKey,
      config.themePreset.name,
    );
    await prefs.setString(
      WzThemeConfig.accentPreferenceKey,
      config.accentPreset.name,
    );
  }
}

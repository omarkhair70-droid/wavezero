import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/app/theme/wavezero_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme config defaults to Porcelain and Mist Blue', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final config = WzThemeConfig.fromPrefs(prefs);

    expect(config.themePreset, WzThemePreset.porcelain);
    expect(config.accentPreset, WzAccentPreset.mistBlue);
  });

  test('theme config restores persisted light theme and accent names', () async {
    SharedPreferences.setMockInitialValues({
      WzThemeConfig.themePreferenceKey: WzThemePreset.softBlue.name,
      WzThemeConfig.accentPreferenceKey: WzAccentPreset.peach.name,
    });
    final prefs = await SharedPreferences.getInstance();

    final config = WzThemeConfig.fromPrefs(prefs);

    expect(config.themePreset, WzThemePreset.softBlue);
    expect(config.accentPreset, WzAccentPreset.peach);
  });

  test('legacy dark preference names migrate to Porcelain defaults', () async {
    SharedPreferences.setMockInitialValues({
      WzThemeConfig.themePreferenceKey: 'midnight',
      WzThemeConfig.accentPreferenceKey: 'wavePurple',
    });
    final prefs = await SharedPreferences.getInstance();

    final config = WzThemeConfig.fromPrefs(prefs);

    expect(config.themePreset, WzThemePreset.porcelain);
    expect(config.accentPreset, WzAccentPreset.mistBlue);
  });
}

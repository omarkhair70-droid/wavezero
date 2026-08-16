import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/app/theme/wavezero_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme config defaults to midnight and wave purple', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final config = WzThemeConfig.fromPrefs(prefs);

    expect(config.themePreset, WzThemePreset.midnight);
    expect(config.accentPreset, WzAccentPreset.wavePurple);
  });

  test('theme config restores persisted theme and accent names', () async {
    SharedPreferences.setMockInitialValues({
      WzThemeConfig.themePreferenceKey: WzThemePreset.oledDark.name,
      WzThemeConfig.accentPreferenceKey: WzAccentPreset.sunset.name,
    });
    final prefs = await SharedPreferences.getInstance();

    final config = WzThemeConfig.fromPrefs(prefs);

    expect(config.themePreset, WzThemePreset.oledDark);
    expect(config.accentPreset, WzAccentPreset.sunset);
  });
}

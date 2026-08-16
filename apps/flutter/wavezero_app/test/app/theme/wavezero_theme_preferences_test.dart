import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/app/theme/wavezero_theme.dart';
import 'package:wavezero_app/app/theme/wavezero_theme_preferences.dart';

void main() {
  const store = WzThemePreferences();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to the existing Midnight / Wave Purple theme', () async {
    final config = await store.load();
    expect(config.themePreset, WzThemePreset.midnight);
    expect(config.accentPreset, WzAccentPreset.wavePurple);
  });

  test('restores persisted theme and accent names', () async {
    SharedPreferences.setMockInitialValues({
      WzThemeConfig.themePreferenceKey: WzThemePreset.oledDark.name,
      WzThemeConfig.accentPreferenceKey: WzAccentPreset.cyan.name,
    });
    final config = await store.load();
    expect(config.themePreset, WzThemePreset.oledDark);
    expect(config.accentPreset, WzAccentPreset.cyan);
  });

  test('saves the existing persisted enum names', () async {
    const config = WzThemeConfig(
      themePreset: WzThemePreset.wavePurple,
      accentPreset: WzAccentPreset.sunset,
    );
    await store.save(config);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(WzThemeConfig.themePreferenceKey),
      WzThemePreset.wavePurple.name,
    );
    expect(
      prefs.getString(WzThemeConfig.accentPreferenceKey),
      WzAccentPreset.sunset.name,
    );
  });
}

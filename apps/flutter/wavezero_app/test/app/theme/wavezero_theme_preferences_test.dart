import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/app/theme/wavezero_theme.dart';
import 'package:wavezero_app/app/theme/wavezero_theme_preferences.dart';

void main() {
  const store = WzThemePreferences();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to Porcelain / Mist Blue', () async {
    final config = await store.load();
    expect(config.themePreset, WzThemePreset.porcelain);
    expect(config.accentPreset, WzAccentPreset.mistBlue);
  });

  test('restores persisted Porcelain theme and accent names', () async {
    SharedPreferences.setMockInitialValues({
      WzThemeConfig.themePreferenceKey: WzThemePreset.warmLight.name,
      WzThemeConfig.accentPreferenceKey: WzAccentPreset.sage.name,
    });
    final config = await store.load();
    expect(config.themePreset, WzThemePreset.warmLight);
    expect(config.accentPreset, WzAccentPreset.sage);
  });

  test('saves persisted light enum names', () async {
    const config = WzThemeConfig(
      themePreset: WzThemePreset.softBlue,
      accentPreset: WzAccentPreset.graphite,
    );
    await store.save(config);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(WzThemeConfig.themePreferenceKey),
      WzThemePreset.softBlue.name,
    );
    expect(
      prefs.getString(WzThemeConfig.accentPreferenceKey),
      WzAccentPreset.graphite.name,
    );
  });
}

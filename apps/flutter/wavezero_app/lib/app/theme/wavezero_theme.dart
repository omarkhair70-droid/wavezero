import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/wavezero_design_system.dart';

enum WzThemePreset { midnight, oledDark, wavePurple }

enum WzAccentPreset { wavePurple, cyan, green, sunset }

class WzThemeConfig {
  const WzThemeConfig({
    this.themePreset = WzThemePreset.midnight,
    this.accentPreset = WzAccentPreset.wavePurple,
  });

  static const themePreferenceKey = 'wavezero.theme_preset';
  static const accentPreferenceKey = 'wavezero.accent_preset';

  final WzThemePreset themePreset;
  final WzAccentPreset accentPreset;

  WzThemeConfig copyWith({WzThemePreset? themePreset, WzAccentPreset? accentPreset}) => WzThemeConfig(
        themePreset: themePreset ?? this.themePreset,
        accentPreset: accentPreset ?? this.accentPreset,
      );

  Color get accent => switch (accentPreset) {
        WzAccentPreset.wavePurple => const Color(0xFF9A8CFF),
        WzAccentPreset.cyan => const Color(0xFF36D7FF),
        WzAccentPreset.green => const Color(0xFF38D996),
        WzAccentPreset.sunset => const Color(0xFFFFA85C),
      };

  Color get accentAlt => switch (accentPreset) {
        WzAccentPreset.wavePurple => const Color(0xFF36D7FF),
        WzAccentPreset.cyan => const Color(0xFF9A8CFF),
        WzAccentPreset.green => const Color(0xFF8DFFCB),
        WzAccentPreset.sunset => const Color(0xFFFF6B8A),
      };

  Color get canvas => switch (themePreset) {
        WzThemePreset.midnight => WzColors.canvas,
        WzThemePreset.oledDark => Colors.black,
        WzThemePreset.wavePurple => const Color(0xFF090615),
      };

  Color get surfaceMuted => switch (themePreset) {
        WzThemePreset.midnight => WzColors.surfaceMuted,
        WzThemePreset.oledDark => const Color(0xFF050505),
        WzThemePreset.wavePurple => const Color(0xFF110D22),
      };

  LinearGradient get shellGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: switch (themePreset) {
          WzThemePreset.midnight => [const Color(0xFF1A2140), WzColors.surfaceMuted, accent.withOpacity(0.18)],
          WzThemePreset.oledDark => [Colors.black, const Color(0xFF050505), accent.withOpacity(0.16)],
          WzThemePreset.wavePurple => [const Color(0xFF261846), const Color(0xFF110D22), accent.withOpacity(0.24)],
        },
      );

  LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, accentAlt],
      );

  ThemeData toThemeData() {
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark).copyWith(
      primary: accent,
      secondary: accentAlt,
      surface: WzColors.surface,
      surfaceContainerHighest: surfaceMuted,
    );
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: canvas,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? accent : null),
        trackColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? accent.withOpacity(0.42) : null),
      ),
      chipTheme: ChipThemeData(
        selectedColor: accent.withOpacity(0.26),
        labelStyle: const TextStyle(color: WzColors.textPrimary),
        side: BorderSide(color: accent.withOpacity(0.34)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WzRadius.md),
          borderSide: const BorderSide(color: WzColors.border),
        ),
      ),
      useMaterial3: true,
    );
  }

  static WzThemeConfig fromPrefs(SharedPreferences prefs) => WzThemeConfig(
        themePreset: WzThemePreset.values.firstWhere(
          (preset) => preset.name == prefs.getString(themePreferenceKey),
          orElse: () => WzThemePreset.midnight,
        ),
        accentPreset: WzAccentPreset.values.firstWhere(
          (preset) => preset.name == prefs.getString(accentPreferenceKey),
          orElse: () => WzAccentPreset.wavePurple,
        ),
      );
}

extension WzThemePresetLabel on WzThemePreset {
  String get label => switch (this) {
        WzThemePreset.midnight => 'Midnight',
        WzThemePreset.oledDark => 'OLED Dark',
        WzThemePreset.wavePurple => 'Wave Purple',
      };
}

extension WzAccentPresetLabel on WzAccentPreset {
  String get label => switch (this) {
        WzAccentPreset.wavePurple => 'Wave Purple',
        WzAccentPreset.cyan => 'Cyan',
        WzAccentPreset.green => 'Green',
        WzAccentPreset.sunset => 'Amber / Sunset',
      };
}

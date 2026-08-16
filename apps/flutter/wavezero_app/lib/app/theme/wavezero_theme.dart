import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/wavezero_design_system.dart';

enum WzThemePreset { porcelain, warmLight, softBlue }

enum WzAccentPreset { mistBlue, graphite, peach, sage }

class WzThemeConfig {
  const WzThemeConfig({
    this.themePreset = WzThemePreset.porcelain,
    this.accentPreset = WzAccentPreset.mistBlue,
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
        WzAccentPreset.mistBlue => const Color(0xFF6F9FCA),
        WzAccentPreset.graphite => const Color(0xFF35434E),
        WzAccentPreset.peach => const Color(0xFFC38E78),
        WzAccentPreset.sage => const Color(0xFF78998A),
      };

  Color get accentAlt => switch (accentPreset) {
        WzAccentPreset.mistBlue => const Color(0xFFA9CBE7),
        WzAccentPreset.graphite => const Color(0xFF8FA0AC),
        WzAccentPreset.peach => const Color(0xFFE8C8B9),
        WzAccentPreset.sage => const Color(0xFFB7D0C4),
      };

  Color get canvas => switch (themePreset) {
        WzThemePreset.porcelain => WzColors.canvas,
        WzThemePreset.warmLight => const Color(0xFFFAF7F2),
        WzThemePreset.softBlue => const Color(0xFFF1F7FC),
      };

  Color get surfaceMuted => switch (themePreset) {
        WzThemePreset.porcelain => WzColors.surfaceMuted,
        WzThemePreset.warmLight => const Color(0xFFF4EFE8),
        WzThemePreset.softBlue => const Color(0xFFEAF3FA),
      };

  LinearGradient get shellGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: switch (themePreset) {
          WzThemePreset.porcelain => [const Color(0xFFFFFFFF), const Color(0xFFF8FBFD), accent.withValues(alpha: 0.10)],
          WzThemePreset.warmLight => [const Color(0xFFFFFFFF), const Color(0xFFFFFAF4), accent.withValues(alpha: 0.08)],
          WzThemePreset.softBlue => [const Color(0xFFFFFFFF), const Color(0xFFF1F8FD), accent.withValues(alpha: 0.12)],
        },
      );

  LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, accentAlt.withValues(alpha: 0.62), Colors.white],
      );

  ThemeData toThemeData() {
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.light).copyWith(
      primary: accent,
      secondary: accentAlt,
      surface: WzColors.surface,
      surfaceContainerHighest: surfaceMuted,
      onSurface: WzColors.textPrimary,
      onPrimary: Colors.white,
    );
    final baseText = ThemeData.light().textTheme.apply(
          bodyColor: WzColors.textPrimary,
          displayColor: WzColors.textPrimary,
        );
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: canvas,
      colorScheme: scheme,
      textTheme: baseText,
      splashColor: accent.withValues(alpha: 0.08),
      highlightColor: Colors.white.withValues(alpha: 0.44),
      dividerColor: WzColors.borderSoft,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? accent : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? accent.withValues(alpha: 0.32) : WzColors.border),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xCCFFFFFF),
        selectedColor: accent.withValues(alpha: 0.14),
        labelStyle: const TextStyle(color: WzColors.textPrimary, fontWeight: FontWeight.w600),
        side: BorderSide(color: accent.withValues(alpha: 0.18)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: WzColors.textPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WzColors.textPrimary,
          side: const BorderSide(color: WzColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: WzColors.textPrimary),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(WzColors.textPrimary),
          overlayColor: WidgetStatePropertyAll(accent.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xDFFFFFFF),
        labelStyle: const TextStyle(color: WzColors.textMuted),
        hintStyle: const TextStyle(color: WzColors.textSubtle),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WzRadius.lg),
          borderSide: const BorderSide(color: WzColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WzRadius.lg),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.58), width: 1.2),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: WzColors.textPrimary,
        inactiveTrackColor: WzColors.border,
        thumbColor: Colors.white,
        overlayColor: accent.withValues(alpha: 0.08),
        trackHeight: 3,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xF7FFFFFF),
        selectedItemColor: accent,
        unselectedItemColor: WzColors.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      useMaterial3: true,
    );
  }

  static WzThemeConfig fromPrefs(SharedPreferences prefs) => WzThemeConfig(
        themePreset: WzThemePreset.values.firstWhere(
          (preset) => preset.name == prefs.getString(themePreferenceKey),
          orElse: () => WzThemePreset.porcelain,
        ),
        accentPreset: WzAccentPreset.values.firstWhere(
          (preset) => preset.name == prefs.getString(accentPreferenceKey),
          orElse: () => WzAccentPreset.mistBlue,
        ),
      );
}

extension WzThemePresetLabel on WzThemePreset {
  String get label => switch (this) {
        WzThemePreset.porcelain => 'Pure White',
        WzThemePreset.warmLight => 'Warm Light',
        WzThemePreset.softBlue => 'Soft Blue',
      };
}

extension WzAccentPresetLabel on WzAccentPreset {
  String get label => switch (this) {
        WzAccentPreset.mistBlue => 'Mist Blue',
        WzAccentPreset.graphite => 'Graphite',
        WzAccentPreset.peach => 'Soft Peach',
        WzAccentPreset.sage => 'Sage',
      };
}

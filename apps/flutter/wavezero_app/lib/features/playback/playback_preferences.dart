import 'package:shared_preferences/shared_preferences.dart';

import 'playback_modes.dart';

class WzPlaybackPreferenceSnapshot {
  const WzPlaybackPreferenceSnapshot({
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.sleepTimerPreset,
  });

  final bool shuffleEnabled;
  final WzRepeatMode repeatMode;
  final WzSleepTimerPreset sleepTimerPreset;
}

class WzPlaybackPreferences {
  const WzPlaybackPreferences();

  static const shufflePreferenceKey = 'wavezero.shuffle_enabled';
  static const repeatModePreferenceKey = 'wavezero.repeat_mode';
  static const sleepTimerPresetPreferenceKey = 'wavezero.sleep_timer_preset';

  Future<WzPlaybackPreferenceSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final repeatName = prefs.getString(repeatModePreferenceKey);
    final presetName = prefs.getString(sleepTimerPresetPreferenceKey);
    return WzPlaybackPreferenceSnapshot(
      shuffleEnabled: prefs.getBool(shufflePreferenceKey) ?? false,
      repeatMode: WzRepeatMode.values.firstWhere(
        (mode) => mode.name == repeatName,
        orElse: () => WzRepeatMode.off,
      ),
      sleepTimerPreset: WzSleepTimerPreset.values.firstWhere(
        (preset) => preset.name == presetName,
        orElse: () => WzSleepTimerPreset.off,
      ),
    );
  }

  Future<void> setShuffleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(shufflePreferenceKey, enabled);
  }

  Future<void> setRepeatMode(WzRepeatMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(repeatModePreferenceKey, mode.name);
  }

  Future<void> setSleepTimerPreset(WzSleepTimerPreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sleepTimerPresetPreferenceKey, preset.name);
  }
}

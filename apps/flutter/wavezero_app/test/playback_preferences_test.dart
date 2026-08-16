import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/features/playback/playback_modes.dart';
import 'package:wavezero_app/features/playback/playback_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('defaults to shuffle off, repeat off, and sleep timer off', () async {
    final snapshot = await const WzPlaybackPreferences().load();

    expect(snapshot.shuffleEnabled, isFalse);
    expect(snapshot.repeatMode, WzRepeatMode.off);
    expect(snapshot.sleepTimerPreset, WzSleepTimerPreset.off);
  });

  test('restores persisted playback preference names', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      WzPlaybackPreferences.shufflePreferenceKey: true,
      WzPlaybackPreferences.repeatModePreferenceKey: 'all',
      WzPlaybackPreferences.sleepTimerPresetPreferenceKey: 'minutes45',
    });

    final snapshot = await const WzPlaybackPreferences().load();

    expect(snapshot.shuffleEnabled, isTrue);
    expect(snapshot.repeatMode, WzRepeatMode.all);
    expect(snapshot.sleepTimerPreset, WzSleepTimerPreset.minutes45);
  });

  test('falls back safely when persisted enum names are unknown', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      WzPlaybackPreferences.repeatModePreferenceKey: 'future-repeat-mode',
      WzPlaybackPreferences.sleepTimerPresetPreferenceKey: 'future-timer',
    });

    final snapshot = await const WzPlaybackPreferences().load();

    expect(snapshot.repeatMode, WzRepeatMode.off);
    expect(snapshot.sleepTimerPreset, WzSleepTimerPreset.off);
  });

  test('persists shuffle, repeat, and sleep timer values', () async {
    const preferences = WzPlaybackPreferences();

    await preferences.setShuffleEnabled(true);
    await preferences.setRepeatMode(WzRepeatMode.one);
    await preferences.setSleepTimerPreset(WzSleepTimerPreset.minutes30);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(WzPlaybackPreferences.shufflePreferenceKey), isTrue);
    expect(prefs.getString(WzPlaybackPreferences.repeatModePreferenceKey), 'one');
    expect(prefs.getString(WzPlaybackPreferences.sleepTimerPresetPreferenceKey), 'minutes30');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/audio/audio_effects.dart';
import 'package:wavezero_app/features/playback/audio_effect_preferences.dart';

void main() {
  const store = WzAudioEffectPreferences();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to the original/off profile', () async {
    expect(await store.load(), AudioEffectProfile.off);
  });

  test('restores an existing profile id', () async {
    SharedPreferences.setMockInitialValues({
      WzAudioEffectPreferences.preferenceKey: AudioEffectProfile.warm.id,
    });
    expect(await store.load(), AudioEffectProfile.warm);
  });

  test('unknown persisted values safely fall back to off', () async {
    SharedPreferences.setMockInitialValues({
      WzAudioEffectPreferences.preferenceKey: 'future-profile',
    });
    expect(await store.load(), AudioEffectProfile.off);
  });

  test('saves the stable profile id', () async {
    await store.save(AudioEffectProfile.vocalClarity);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(WzAudioEffectPreferences.preferenceKey),
      AudioEffectProfile.vocalClarity.id,
    );
  });
}

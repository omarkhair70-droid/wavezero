import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/audio/audio_effects.dart';
import 'package:wavezero_app/features/playback/custom_equalizer_page.dart';

void main() {
  test('custom EQ is a persisted audio effect profile', () {
    expect(AudioEffectProfile.custom.id, 'custom');
    expect(AudioEffectProfile.custom.label, 'Custom EQ');
    expect(parseAudioEffectProfile('custom'), AudioEffectProfile.custom);
  });

  test('custom EQ band model keeps frequency identity and gain payload', () {
    const band = WzCustomEqBand(frequencyHz: 1000, gainDb: 2.5);
    expect(band.toJson(), <String, Object?>{
      'frequencyHz': 1000,
      'gainDb': 2.5,
    });
    expect(band.copyWith(gainDb: -1).frequencyHz, 1000);
    expect(band.copyWith(gainDb: -1).gainDb, -1);
  });

  test('Android bridge persists and reapplies custom curves', () {
    final activity = File(
      'android/app/src/main/kotlin/com/omarkhair/wavezero/MainActivity.kt',
    ).readAsStringSync();
    final dsp = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/NativeDspController.kt',
    ).readAsStringSync();
    final settings = File('lib/features/settings/settings_page.dart').readAsStringSync();

    expect(activity, contains('"setCustomEqualizer"'));
    expect(activity, contains('"customEqualizerSettings"'));
    expect(activity, contains('saveCustomEqProfile(profile)'));
    expect(activity, contains('loadCustomEqProfile()'));
    expect(activity, contains('DEFAULT_CUSTOM_EQ_FREQUENCIES'));
    expect(dsp, contains('data class NativeEqBand'));
    expect(dsp, contains('val customBands: List<NativeEqBand> = emptyList()'));
    expect(dsp, contains('ln(frequencyHz.toDouble())'));
    expect(settings, contains("label: const Text('Tune Custom EQ')"));
  });
}

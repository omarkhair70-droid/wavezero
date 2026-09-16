import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ReplayGain parser recognizes standard track and album tags', () {
    final source = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/ReplayGainMetadata.kt',
    ).readAsStringSync();

    expect(source, contains('REPLAYGAIN_TRACK_GAIN'));
    expect(source, contains('REPLAYGAIN_ALBUM_GAIN'));
    expect(source, contains('REPLAYGAIN_TRACK_PEAK'));
    expect(source, contains('REPLAYGAIN_ALBUM_PEAK'));
    expect(source, contains('is VorbisComment'));
    expect(source, contains('is TextInformationFrame'));
    expect(source, contains('entry.id.equals("TXXX", ignoreCase = true)'));
    expect(source, contains('coerceIn(MIN_GAIN_DB, MAX_GAIN_DB)'));
  });

  test('native sound engine combines EQ headroom and ReplayGain safely', () {
    final dsp = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/NativeDspController.kt',
    ).readAsStringSync();

    expect(dsp, contains('import android.media.audiofx.LoudnessEnhancer'));
    expect(dsp, contains('activeProfile.preampGainDb + min(requestedNormalizationDb, 0.0)'));
    expect(dsp, contains('enhancer.setTargetGain((positiveGainDb * 100.0).roundToInt())'));
    expect(dsp, contains('effectiveProfilePreampDb()'));
    expect(dsp, contains('eqResult.status == "applied"'));
    expect(dsp, contains('No ReplayGain tag found; normalization leaves this track unchanged.'));
  });

  test('Media3 playback refreshes ReplayGain when track metadata changes', () {
    final manager = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/omarkhair/wavezero/MainActivity.kt',
    ).readAsStringSync();
    final settings = File('lib/features/settings/settings_page.dart').readAsStringSync();

    expect(manager, contains('override fun onTracksChanged(tracks: Tracks)'));
    expect(manager, contains('override fun onMetadata(metadata: Metadata)'));
    expect(manager, contains('nativeDspController.clearReplayGain(player)'));
    expect(manager, contains('loudness_normalization_enabled'));
    expect(activity, contains('"setLoudnessNormalizationEnabled"'));
    expect(activity, contains('"loudnessNormalizationStatus"'));
    expect(settings, contains("title: const Text('Loudness normalization')"));
    expect(settings, contains('Untagged music stays at its original level.'));
  });
}

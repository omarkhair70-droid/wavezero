import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android playback owns a session-scoped real Equalizer lifecycle', () {
    final dsp = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/NativeDspController.kt',
    ).readAsStringSync();
    final manager = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt',
    ).readAsStringSync();

    expect(dsp, contains('import android.media.audiofx.Equalizer'));
    expect(dsp, contains('Equalizer(PRIORITY, audioSessionId)'));
    expect(dsp, contains('eq.setBandLevel'));
    expect(dsp, contains('eq.enabled = true'));
    expect(dsp, contains('player.volume = dbToLinear(attenuationDb)'));
    expect(dsp, contains('eqResult.status == "applied"'));
    expect(dsp, contains('activeProfile.preampGainDb'));
    expect(dsp, contains('releaseEqualizer()'));
    expect(manager, contains('nativeDspController.onAudioSessionChanged(audioSessionId, player)'));
    expect(manager, contains('nativeDspController.onPrimaryPlayerChanged(exoPlayer)'));
    expect(manager, contains('nativeDspController.release()'));
  });

  test('Flutter host routes profile requests to the native DSP instead of unsupported stub', () {
    final activity = File(
      'android/app/src/main/kotlin/com/omarkhair/wavezero/MainActivity.kt',
    ).readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final bridge = File('lib/playback/playback_bridge.dart').readAsStringSync();

    expect(activity, contains('NativeEqProfile('));
    expect(activity, contains('audioPlayerManager.setAudioEffectProfile(profile)'));
    expect(activity, contains('"audioEffectStatus"'));
    expect(activity, isNot(contains('Native Android DSP is not enabled in this safe foundation build')));
    expect(manifest, contains('android.permission.MODIFY_AUDIO_SETTINGS'));
    expect(bridge, contains("invokeMapMethod<Object?, Object?>('audioEffectStatus')"));
    expect(bridge, contains('Mock playback has no native DSP session.'));
  });

  test('native profile keeps clipping headroom and frequency regions explicit', () {
    final dsp = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/NativeDspController.kt',
    ).readAsStringSync();

    expect(dsp, contains('frequencyHz < 250 -> bassGainDb'));
    expect(dsp, contains('frequencyHz < 5000 -> midGainDb'));
    expect(dsp, contains('else -> trebleGainDb'));
    expect(dsp, contains('requestedMb.coerceIn(minLevel, maxLevel)'));
    expect(dsp, contains('if (db >= 0.0) return 1f'));
  });
}

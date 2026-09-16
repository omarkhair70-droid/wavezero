import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('crossfade is prepared-next only with explicit user durations', () {
    final manager = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt',
    ).readAsStringSync();

    expect(manager, contains('ALLOWED_CROSSFADE_DURATIONS = setOf(0L, 2_000L, 4_000L, 6_000L)'));
    expect(manager, contains('CROSSFADE_DURATION_KEY = "crossfade_duration_ms"'));
    expect(manager, contains('private fun maybeStartNaturalCrossfade()'));
    expect(manager, contains('if (!isPreparedNextTrackReady(trackId, url)) return'));
    expect(manager, contains('manualSkipMode" to "immediate_prepared"'));
    expect(manager, contains('autoMode" to "prepared_natural_end"'));
  });

  test('crossfade envelopes compose inside the single native gain owner', () {
    final manager = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt',
    ).readAsStringSync();
    final dsp = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/NativeDspController.kt',
    ).readAsStringSync();

    expect(dsp, contains('IdentityHashMap<ExoPlayer, PlayerDspState>()'));
    expect(dsp, contains('fun setTransitionGain(player: ExoPlayer, gain: Float)'));
    expect(dsp, contains('player.volume = (baseGain * state.transitionGain).coerceIn(0f, 1f)'));
    expect(dsp, contains('fun promoteSecondaryPlayer(player: ExoPlayer)'));
    expect(manager, contains('nativeDspController.setTransitionGain(outgoing, 1f - progress)'));
    expect(manager, contains('nativeDspController.setTransitionGain(incoming, progress)'));
    expect(manager, contains('configurePrimaryPlayer(transition.incoming, preserveTransitionGain = true)'));
  });

  test('Flutter bridge and consumer settings expose persisted crossfade controls', () {
    final activity = File(
      'android/app/src/main/kotlin/com/omarkhair/wavezero/MainActivity.kt',
    ).readAsStringSync();
    final controls = File(
      'lib/features/settings/crossfade_controls.dart',
    ).readAsStringSync();
    final consumerSettings = File(
      'lib/features/settings/consumer_settings_page.dart',
    ).readAsStringSync();

    expect(activity, contains('"setCrossfadeDuration"'));
    expect(activity, contains('"crossfadeStatus"'));
    expect(controls, contains("'crossfadeStatus'"));
    expect(controls, contains("'setCrossfadeDuration'"));
    expect(controls, contains('<int>[0, 2000, 4000, 6000]'));
    expect(controls, contains('Manual Next / Previous stay immediate.'));
    expect(consumerSettings, contains("import 'crossfade_controls.dart';"));
    expect(consumerSettings, contains('child: WzCrossfadeControls()'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepared handoff promotes the ready player before stopping old primary', () {
    final manager = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt',
    ).readAsStringSync();

    final start = manager.indexOf('private fun playPreparedNextTrackIfReady(');
    final end = manager.indexOf('private fun clearNativePrebuffer(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final handoff = manager.substring(start, end);
    final detachOld = handoff.indexOf('previousPrimaryPlayer.removeListener(playerListener)');
    final promoteIncoming = handoff.indexOf('configurePrimaryPlayer(preparedPlayer)');
    final pauseOld = handoff.indexOf('previousPrimaryPlayer.pause()');
    final startIncoming = handoff.indexOf('player.playWhenReady = true');
    final recycleOld = handoff.indexOf('clearNativePrebufferState()');

    expect(detachOld, greaterThanOrEqualTo(0));
    expect(promoteIncoming, greaterThan(detachOld));
    expect(pauseOld, greaterThan(promoteIncoming));
    expect(startIncoming, greaterThan(pauseOld));
    expect(recycleOld, greaterThan(startIncoming));
    expect(handoff, isNot(contains('previousPrimaryPlayer.stop()')));
    expect(handoff, isNot(contains('previousPrimaryPlayer.clearMediaItems()')));
  });

  test('prepared handoff preserves native sound-engine ownership', () {
    final manager = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt',
    ).readAsStringSync();

    final start = manager.indexOf('private fun playPreparedNextTrackIfReady(');
    final end = manager.indexOf('private fun clearNativePrebuffer(', start);
    final handoff = manager.substring(start, end);

    expect(handoff, contains('nativeDspController.clearReplayGain(previousPrimaryPlayer)'));
    expect(handoff, contains('configurePrimaryPlayer(preparedPlayer)'));
    expect(handoff, contains('applyReplayGainFromTracks(player.currentTracks, player)'));
    expect(manager, contains('WaveZeroAudioRenderersFactory(appContext, channelAudioState)'));
    expect(RegExp(r'NativeDspController\(\)').allMatches(manager).length, 1);
  });

  test('gapless diagnostics are explicit and do not overclaim guarantees', () {
    final manager = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt',
    ).readAsStringSync();
    final metrics = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/PlaybackMetrics.kt',
    ).readAsStringSync();

    expect(manager, contains('PREPARED_HANDOFF_STRATEGY = "prepared_player_min_gap"'));
    expect(manager, contains('"nativePreparedHandoffStrategy" to PREPARED_HANDOFF_STRATEGY'));
    expect(manager, contains('"nativeGaplessGuarantee" to false'));
    expect(metrics, contains('nativeHandoffToPlayingMs'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native playback publishes and preserves an explicit end event', () {
    final manager = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt',
    ).readAsStringSync();
    final metrics = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/PlaybackMetrics.kt',
    ).readAsStringSync();

    final endedStart = manager.indexOf('Player.STATE_ENDED -> {');
    final idleStart = manager.indexOf('Player.STATE_IDLE -> {', endedStart);
    expect(endedStart, greaterThanOrEqualTo(0));
    expect(idleStart, greaterThan(endedStart));
    final endedBlock = manager.substring(endedStart, idleStart);

    expect(
      endedBlock,
      contains('metricsTracker.markEnded(player.currentPosition)'),
    );
    expect(metrics, contains('fun markEnded(positionMs: Long)'));
    expect(metrics, contains('update("playback_ended")'));
    expect(
      manager,
      contains('if (player.playbackState == Player.STATE_ENDED) return'),
    );
  });

  test('auto advance only consumes its dedupe guard when a route can run', () {
    final app = File('lib/app/wavezero_app.dart').readAsStringSync();
    final start = app.indexOf('Future<void> _maybeAutoAdvance');
    final end = app.indexOf('void _recordSmartDownloadSkip', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final autoAdvance = app.substring(start, end);

    final triggerGate = autoAdvance.indexOf('if (!trigger.shouldAdvance) return;');
    final repeatBranch = autoAdvance.indexOf('if (_repeatMode == WzRepeatMode.one)');
    final firstGuardWrite = autoAdvance.indexOf(
      '_lastAutoAdvanceTrackId = trigger.trackId;',
      triggerGate,
    );
    expect(repeatBranch, greaterThan(triggerGate));
    expect(firstGuardWrite, greaterThan(repeatBranch));
    expect(autoAdvance, contains('if (shuffled) {'));
    expect(autoAdvance, contains('if (_canNext) {'));
  });

  test('direct track taps play immediately instead of only selecting', () {
    final app = File('lib/app/wavezero_app.dart').readAsStringSync();

    expect(
      app,
      contains(
        'onSelectTrack: (track) => _loadCatalogTrack(\n'
        '              trackId: track.trackId,\n'
        '              autoPlay: true,\n'
        '            ),',
      ),
    );
    expect(
      app,
      contains(
        'onPlayTrack: (track) =>\n'
        '                _playQueueTrack(track, autoStart: true),',
      ),
    );
  });

  test('direct library playback adopts a bounded continuation context', () {
    final app = File('lib/app/wavezero_app.dart').readAsStringSync();

    expect(app, contains("import '../features/queue/playback_context.dart';"));
    expect(app, contains('void _adoptPlaybackContextForTrackId(String trackId)'));
    expect(app, contains('wzPlaybackContextForTrack('));
    expect(app, contains('_adoptPlaybackContextForTrackId(id);'));
    expect(app, contains('_adoptPlaybackContextForTrackId(track.trackId);'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native playback publishes an explicit end event', () {
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

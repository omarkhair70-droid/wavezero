import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/playback/playback_status.dart';
import 'package:wavezero_app/features/playback/player_operation_state.dart';

void main() {
  test('headline keeps playback status precedence', () {
    expect(
      WzPlaybackStatusPresentation.headline(
        lastError: 'boom',
        playbackError: null,
        operation: PlayerOperation.loadingTrack,
        isPlaying: true,
        hasLoadedTrack: true,
      ),
      'Error',
    );
    expect(
      WzPlaybackStatusPresentation.headline(
        lastError: null,
        playbackError: null,
        operation: PlayerOperation.loadingTrack,
        isPlaying: true,
        hasLoadedTrack: true,
      ),
      'Loading track',
    );
    expect(
      WzPlaybackStatusPresentation.headline(
        lastError: null,
        playbackError: null,
        operation: PlayerOperation.idle,
        isPlaying: true,
        hasLoadedTrack: true,
      ),
      'Playing',
    );
    expect(
      WzPlaybackStatusPresentation.headline(
        lastError: null,
        playbackError: null,
        operation: PlayerOperation.idle,
        isPlaying: false,
        hasLoadedTrack: true,
      ),
      'Paused / Ready',
    );
    expect(
      WzPlaybackStatusPresentation.headline(
        lastError: null,
        playbackError: null,
        operation: PlayerOperation.idle,
        isPlaying: false,
        hasLoadedTrack: false,
      ),
      'Ready',
    );
  });

  test('detail preserves developer and consumer error copy', () {
    final developer = WzPlaybackStatusPresentation.detail(
      lastError: 'raw bridge error',
      playbackError: null,
      developerMode: true,
      refreshingMetrics: false,
      upNextTitle: null,
      queueStatus: 'Queue is ready.',
      consumerError: (error) => 'friendly:$error',
    );
    final consumer = WzPlaybackStatusPresentation.detail(
      lastError: null,
      playbackError: 'raw bridge error',
      developerMode: false,
      refreshingMetrics: false,
      upNextTitle: null,
      queueStatus: 'Queue is ready.',
      consumerError: (error) => 'friendly:$error',
    );

    expect(developer, 'raw bridge error');
    expect(consumer, 'friendly:raw bridge error');
  });

  test('detail keeps refresh, up-next, and queue fallback precedence', () {
    expect(
      WzPlaybackStatusPresentation.detail(
        lastError: null,
        playbackError: null,
        developerMode: false,
        refreshingMetrics: true,
        upNextTitle: 'Next song',
        queueStatus: 'Queue is ready.',
        consumerError: (error) => error,
      ),
      'Updating playback status.',
    );
    expect(
      WzPlaybackStatusPresentation.detail(
        lastError: null,
        playbackError: null,
        developerMode: true,
        refreshingMetrics: true,
        upNextTitle: null,
        queueStatus: 'Queue is ready.',
        consumerError: (error) => error,
      ),
      'Metrics refresh is running without blocking controls.',
    );
    expect(
      WzPlaybackStatusPresentation.detail(
        lastError: null,
        playbackError: null,
        developerMode: false,
        refreshingMetrics: false,
        upNextTitle: 'Next song',
        queueStatus: 'Queue is ready.',
        consumerError: (error) => error,
      ),
      'Up next: Next song',
    );
    expect(
      WzPlaybackStatusPresentation.detail(
        lastError: null,
        playbackError: null,
        developerMode: false,
        refreshingMetrics: false,
        upNextTitle: null,
        queueStatus: 'Queue is ready.',
        consumerError: (error) => error,
      ),
      'Queue is ready.',
    );
  });
}

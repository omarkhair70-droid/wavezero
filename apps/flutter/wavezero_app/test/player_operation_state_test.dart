import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/playback/player_operation_state.dart';

void main() {
  test('operation labels and display names remain stable', () {
    expect(PlayerOperation.idle.label, 'idle');
    expect(PlayerOperation.idle.displayName, 'Ready');
    expect(PlayerOperation.loadingCatalog.label, 'loadingCatalog');
    expect(PlayerOperation.loadingCatalog.displayName, 'Loading catalog');
    expect(PlayerOperation.loadingTrack.displayName, 'Loading track');
    expect(PlayerOperation.loadingManualTrack.displayName, 'Loading manual track');
    expect(PlayerOperation.playbackCommand.displayName, 'Updating playback');
    expect(PlayerOperation.seeking.displayName, 'Seeking');
    expect(PlayerOperation.queueAdvance.displayName, 'Advancing queue');
    expect(PlayerOperation.autoAdvance.displayName, 'Auto-advancing');
    expect(PlayerOperation.copyingMetrics.displayName, 'Copying metrics');
    expect(PlayerOperation.resettingMetrics.displayName, 'Resetting metrics');
  });

  test('track loading and queue advancing groups remain stable', () {
    expect(PlayerOperation.loadingTrack.isTrackLoading, isTrue);
    expect(PlayerOperation.loadingManualTrack.isTrackLoading, isTrue);
    expect(PlayerOperation.queueAdvance.isQueueAdvancing, isTrue);
    expect(PlayerOperation.autoAdvance.isQueueAdvancing, isTrue);
    expect(PlayerOperation.idle.isTrackLoading, isFalse);
    expect(PlayerOperation.idle.isQueueAdvancing, isFalse);
  });

  test('control disabling matrix remains stable', () {
    expect(PlayerOperation.idle.disablesPlayerControls, isFalse);
    expect(PlayerOperation.loadingCatalog.disablesPlayerControls, isFalse);
    expect(PlayerOperation.playbackCommand.disablesPlayerControls, isTrue);
    expect(PlayerOperation.seeking.disablesPlayerControls, isTrue);
    expect(PlayerOperation.loadingTrack.disablesPlayerControls, isTrue);
    expect(PlayerOperation.loadingManualTrack.disablesPlayerControls, isTrue);
    expect(PlayerOperation.queueAdvance.disablesPlayerControls, isTrue);
    expect(PlayerOperation.autoAdvance.disablesPlayerControls, isTrue);

    expect(PlayerOperation.loadingCatalog.disablesCatalogRefresh, isTrue);
    expect(PlayerOperation.loadingTrack.disablesCatalogRefresh, isTrue);
    expect(PlayerOperation.queueAdvance.disablesCatalogRefresh, isTrue);
    expect(PlayerOperation.playbackCommand.disablesCatalogRefresh, isFalse);

    expect(PlayerOperation.loadingTrack.disablesQueueControls, isTrue);
    expect(PlayerOperation.autoAdvance.disablesQueueControls, isTrue);
    expect(PlayerOperation.playbackCommand.disablesQueueControls, isFalse);

    expect(PlayerOperation.loadingManualTrack.disablesManualTrackControls, isTrue);
    expect(PlayerOperation.queueAdvance.disablesManualTrackControls, isTrue);
    expect(PlayerOperation.seeking.disablesManualTrackControls, isFalse);
  });
}

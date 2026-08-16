enum PlayerOperation {
  idle,
  loadingCatalog,
  loadingTrack,
  loadingManualTrack,
  playbackCommand,
  seeking,
  queueAdvance,
  autoAdvance,
  copyingMetrics,
  resettingMetrics,
}

extension PlayerOperationState on PlayerOperation {
  String get label {
    return switch (this) {
      PlayerOperation.idle => 'idle',
      PlayerOperation.loadingCatalog => 'loadingCatalog',
      PlayerOperation.loadingTrack => 'loadingTrack',
      PlayerOperation.loadingManualTrack => 'loadingManualTrack',
      PlayerOperation.playbackCommand => 'playbackCommand',
      PlayerOperation.seeking => 'seeking',
      PlayerOperation.queueAdvance => 'queueAdvance',
      PlayerOperation.autoAdvance => 'autoAdvance',
      PlayerOperation.copyingMetrics => 'copyingMetrics',
      PlayerOperation.resettingMetrics => 'resettingMetrics',
    };
  }

  String get displayName {
    return switch (this) {
      PlayerOperation.idle => 'Ready',
      PlayerOperation.loadingCatalog => 'Loading catalog',
      PlayerOperation.loadingTrack => 'Loading track',
      PlayerOperation.loadingManualTrack => 'Loading manual track',
      PlayerOperation.playbackCommand => 'Updating playback',
      PlayerOperation.seeking => 'Seeking',
      PlayerOperation.queueAdvance => 'Advancing queue',
      PlayerOperation.autoAdvance => 'Auto-advancing',
      PlayerOperation.copyingMetrics => 'Copying metrics',
      PlayerOperation.resettingMetrics => 'Resetting metrics',
    };
  }

  bool get isTrackLoading {
    return this == PlayerOperation.loadingTrack ||
        this == PlayerOperation.loadingManualTrack;
  }

  bool get isQueueAdvancing {
    return this == PlayerOperation.queueAdvance ||
        this == PlayerOperation.autoAdvance;
  }

  bool get disablesPlayerControls {
    return this == PlayerOperation.playbackCommand ||
        isTrackLoading ||
        isQueueAdvancing ||
        this == PlayerOperation.seeking;
  }

  bool get disablesCatalogRefresh {
    return this == PlayerOperation.loadingCatalog ||
        isTrackLoading ||
        isQueueAdvancing;
  }

  bool get disablesQueueControls => isTrackLoading || isQueueAdvancing;

  bool get disablesManualTrackControls => isTrackLoading || isQueueAdvancing;
}

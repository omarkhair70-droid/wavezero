import 'player_operation_state.dart';

class WzPlaybackStatusPresentation {
  const WzPlaybackStatusPresentation._();

  static String headline({
    required String? lastError,
    required String? playbackError,
    required PlayerOperation operation,
    required bool isPlaying,
    required bool hasLoadedTrack,
  }) {
    if ((lastError ?? playbackError) != null) return 'Error';
    if (operation != PlayerOperation.idle) return operation.displayName;
    if (isPlaying) return 'Playing';
    if (hasLoadedTrack) return 'Paused / Ready';
    return 'Ready';
  }

  static String detail({
    required String? lastError,
    required String? playbackError,
    required bool developerMode,
    required bool refreshingMetrics,
    required String? upNextTitle,
    required String queueStatus,
    required String Function(String error) consumerError,
  }) {
    final error = lastError ?? playbackError;
    if (error != null && error.isNotEmpty) {
      return developerMode ? error : consumerError(error);
    }
    if (refreshingMetrics) {
      return developerMode
          ? 'Metrics refresh is running without blocking controls.'
          : 'Updating playback status.';
    }
    if (upNextTitle != null) return 'Up next: $upNextTitle';
    return queueStatus;
  }
}

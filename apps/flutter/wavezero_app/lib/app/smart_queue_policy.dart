import '../catalog/catalog_client.dart';
import '../playback/playback_metrics.dart';

class SmartQueueReason {
  const SmartQueueReason._();

  static const smartPreloadOff = 'smart_preload_off';
  static const queueEmpty = 'queue_empty';
  static const noUpNext = 'no_up_next';
  static const upNext = 'up_next';
  static const candidateChanged = 'candidate_changed';
  static const alreadyPrepared = 'already_prepared';
}

class SmartQueueDecision {
  const SmartQueueDecision({required this.reason, this.candidate});

  final String reason;
  final CatalogTrackSummary? candidate;

  String? get candidateTrackId => candidate?.trackId;
  bool get hasCandidate => candidate != null;
}

SmartQueueDecision decideSmartQueueCandidate({
  required bool smartPreloadEnabled,
  required List<CatalogTrackSummary> queue,
  required Set<String> catalogTrackIds,
  required String? currentTrackId,
  required String? selectedTrackId,
  required String? previousCandidateTrackId,
  required bool manifestPrefetched,
  required PlaybackMetrics metrics,
}) {
  if (!smartPreloadEnabled) {
    return const SmartQueueDecision(reason: SmartQueueReason.smartPreloadOff);
  }
  if (queue.isEmpty) {
    return const SmartQueueDecision(reason: SmartQueueReason.queueEmpty);
  }

  final validQueue = queue.where((track) => catalogTrackIds.contains(track.trackId)).toList(growable: false);
  if (validQueue.isEmpty) {
    return const SmartQueueDecision(reason: SmartQueueReason.queueEmpty);
  }

  final currentIndex = _safeQueueIndex(
    queue: validQueue,
    currentTrackId: currentTrackId,
    selectedTrackId: selectedTrackId,
  );
  if (currentIndex < 0 || currentIndex >= validQueue.length - 1) {
    return const SmartQueueDecision(reason: SmartQueueReason.noUpNext);
  }

  final candidate = validQueue[currentIndex + 1];
  if (candidate.trackId == currentTrackId || (candidate.trackId == selectedTrackId && currentTrackId == null)) {
    return const SmartQueueDecision(reason: SmartQueueReason.noUpNext);
  }

  final nativePrepared = metrics.nativePrebufferTrackId == candidate.trackId && metrics.nativePrebufferReady;
  if (previousCandidateTrackId == candidate.trackId && manifestPrefetched && nativePrepared) {
    return SmartQueueDecision(reason: SmartQueueReason.alreadyPrepared, candidate: candidate);
  }

  final reason = previousCandidateTrackId != null && previousCandidateTrackId != candidate.trackId
      ? SmartQueueReason.candidateChanged
      : SmartQueueReason.upNext;
  return SmartQueueDecision(reason: reason, candidate: candidate);
}

int _safeQueueIndex({
  required List<CatalogTrackSummary> queue,
  required String? currentTrackId,
  required String? selectedTrackId,
}) {
  final currentIndex = _indexOfTrack(queue, currentTrackId);
  if (currentIndex >= 0) return currentIndex;

  final selectedIndex = _indexOfTrack(queue, selectedTrackId);
  if (selectedIndex >= 0) return selectedIndex;

  return queue.length > 1 ? 0 : -1;
}

int _indexOfTrack(List<CatalogTrackSummary> queue, String? trackId) {
  if (trackId == null) return -1;
  return queue.indexWhere((track) => track.trackId == trackId);
}

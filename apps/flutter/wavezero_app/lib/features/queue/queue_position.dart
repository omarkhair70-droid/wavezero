import '../../catalog/catalog_track_manifest.dart';

class WzQueuePosition {
  const WzQueuePosition({
    required this.index,
    required this.currentTrack,
    required this.upNextTrack,
    required this.canPrevious,
    required this.canNext,
    required this.canShuffleNext,
    this.transitionPending = false,
  });

  final int index;
  final CatalogTrackSummary? currentTrack;
  final CatalogTrackSummary? upNextTrack;
  final bool canPrevious;
  final bool canNext;
  final bool canShuffleNext;
  final bool transitionPending;

  bool get canPlayNext => canNext || canShuffleNext;
}

WzQueuePosition resolveWzQueuePosition({
  required List<CatalogTrackSummary> queue,
  required String? currentTrackId,
  required String? selectedTrackId,
  required bool shuffleEnabled,
}) {
  final currentIndex = currentTrackId == null
      ? -1
      : queue.indexWhere((track) => track.trackId == currentTrackId);
  final selectedIndex = selectedTrackId == null
      ? -1
      : queue.indexWhere((track) => track.trackId == selectedTrackId);
  final transitionPending =
      currentTrackId != null &&
      selectedTrackId != null &&
      currentTrackId != selectedTrackId &&
      currentIndex >= 0 &&
      selectedIndex >= 0;

  if (transitionPending) {
    return WzQueuePosition(
      index: -1,
      currentTrack: queue[selectedIndex],
      upNextTrack: null,
      canPrevious: false,
      canNext: false,
      canShuffleNext: false,
      transitionPending: true,
    );
  }

  final index = currentIndex >= 0 ? currentIndex : selectedIndex;
  final currentTrack = index >= 0 && index < queue.length ? queue[index] : null;
  final upNextTrack = index >= 0 && index < queue.length - 1 ? queue[index + 1] : null;
  final canPrevious = index > 0;
  final canNext = index >= 0 && index < queue.length - 1;
  final canShuffleNext = shuffleEnabled && queue.length > 1 && index >= 0;

  return WzQueuePosition(
    index: index,
    currentTrack: currentTrack,
    upNextTrack: upNextTrack,
    canPrevious: canPrevious,
    canNext: canNext,
    canShuffleNext: canShuffleNext,
  );
}

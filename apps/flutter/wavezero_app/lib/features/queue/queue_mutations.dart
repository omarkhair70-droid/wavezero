import '../../catalog/catalog_track_manifest.dart';

class WzQueueAddResult {
  const WzQueueAddResult({
    required this.queue,
    required this.currentTrackId,
    required this.alreadyPresent,
  });

  final List<CatalogTrackSummary> queue;
  final String? currentTrackId;
  final bool alreadyPresent;
}

class WzQueueReorderResult {
  const WzQueueReorderResult({
    required this.queue,
    required this.changed,
  });

  final List<CatalogTrackSummary> queue;
  final bool changed;
}

class WzQueueRemovalResult {
  const WzQueueRemovalResult({
    required this.queue,
    required this.currentTrackId,
    required this.currentTrack,
    required this.wasCurrent,
  });

  final List<CatalogTrackSummary> queue;
  final String? currentTrackId;
  final CatalogTrackSummary? currentTrack;
  final bool wasCurrent;
}

WzQueueAddResult addWzQueueTrack({
  required List<CatalogTrackSummary> queue,
  required CatalogTrackSummary track,
  required String? currentTrackId,
}) {
  final alreadyPresent = queue.any((item) => item.trackId == track.trackId);
  return WzQueueAddResult(
    queue: alreadyPresent ? queue : <CatalogTrackSummary>[...queue, track],
    currentTrackId: currentTrackId ?? track.trackId,
    alreadyPresent: alreadyPresent,
  );
}

WzQueueReorderResult moveWzQueueTrack({
  required List<CatalogTrackSummary> queue,
  required String trackId,
  required int delta,
}) {
  final index = queue.indexWhere((item) => item.trackId == trackId);
  if (index < 0) return WzQueueReorderResult(queue: queue, changed: false);
  final target = (index + delta).clamp(0, queue.length - 1).toInt();
  if (target == index) return WzQueueReorderResult(queue: queue, changed: false);

  final nextQueue = <CatalogTrackSummary>[...queue];
  final moved = nextQueue.removeAt(index);
  nextQueue.insert(target, moved);
  return WzQueueReorderResult(queue: nextQueue, changed: true);
}

WzQueueReorderResult moveWzQueueTrackNext({
  required List<CatalogTrackSummary> queue,
  required String trackId,
  required int resolvedCurrentIndex,
  required String? currentTrackId,
}) {
  final sourceIndex = queue.indexWhere((item) => item.trackId == trackId);
  if (resolvedCurrentIndex < 0 || sourceIndex < 0 || sourceIndex == resolvedCurrentIndex) {
    return WzQueueReorderResult(queue: queue, changed: false);
  }

  final nextQueue = <CatalogTrackSummary>[...queue];
  final moved = nextQueue.removeAt(sourceIndex);
  final adjustedCurrentIndex = nextQueue.indexWhere((item) => item.trackId == currentTrackId);
  final insertIndex = (adjustedCurrentIndex + 1).clamp(0, nextQueue.length).toInt();
  nextQueue.insert(insertIndex, moved);
  return WzQueueReorderResult(queue: nextQueue, changed: true);
}

WzQueueRemovalResult removeWzQueueTrack({
  required List<CatalogTrackSummary> queue,
  required String trackId,
  required String? currentTrackId,
}) {
  final index = queue.indexWhere((item) => item.trackId == trackId);
  final wasCurrent = trackId == currentTrackId;
  final nextQueue = queue.where((item) => item.trackId != trackId).toList(growable: false);

  String? nextCurrentTrackId = currentTrackId;
  CatalogTrackSummary? nextCurrentTrack;
  if (nextQueue.isEmpty) {
    nextCurrentTrackId = null;
  } else if (wasCurrent) {
    final nextIndex = index.clamp(0, nextQueue.length - 1).toInt();
    nextCurrentTrack = nextQueue[nextIndex];
    nextCurrentTrackId = nextCurrentTrack.trackId;
  } else if (currentTrackId != null) {
    for (final item in nextQueue) {
      if (item.trackId == currentTrackId) {
        nextCurrentTrack = item;
        break;
      }
    }
  }

  return WzQueueRemovalResult(
    queue: nextQueue,
    currentTrackId: nextCurrentTrackId,
    currentTrack: nextCurrentTrack,
    wasCurrent: wasCurrent,
  );
}

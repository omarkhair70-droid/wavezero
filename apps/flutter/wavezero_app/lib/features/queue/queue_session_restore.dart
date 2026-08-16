import '../../catalog/catalog_track_manifest.dart';
import 'queue_session_store.dart';

QueueSessionSnapshot? sanitizeWzQueueSessionSnapshot({
  required List<CatalogTrackSummary> catalogTracks,
  required QueueSessionSnapshot snapshot,
}) {
  final validIds = catalogTracks.map((track) => track.trackId).toSet();
  final restoredIds = snapshot.queueTrackIds.where(validIds.contains).toList(growable: false);
  if (restoredIds.isEmpty && snapshot.currentTrackId == null && snapshot.selectedTrackId == null) return null;

  return QueueSessionSnapshot(
    queueTrackIds: restoredIds,
    currentTrackId: validIds.contains(snapshot.currentTrackId) ? snapshot.currentTrackId : null,
    selectedTrackId: validIds.contains(snapshot.selectedTrackId) ? snapshot.selectedTrackId : null,
    autoAdvanceEnabled: snapshot.autoAdvanceEnabled,
  );
}

List<CatalogTrackSummary> resolveWzQueueFromSnapshot({
  required List<CatalogTrackSummary> catalogTracks,
  required QueueSessionSnapshot snapshot,
}) {
  final byId = {for (final track in catalogTracks) track.trackId: track};
  return snapshot.queueTrackIds.map((id) => byId[id]).whereType<CatalogTrackSummary>().toList(growable: false);
}

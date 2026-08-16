from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    text = text.replace(old, new, 1)


replace_once(
    """import '../features/queue/queue_session_store.dart';
import '../features/queue/queue_mutations.dart';""",
    """import '../features/queue/queue_session_store.dart';
import '../features/queue/queue_session_restore.dart';
import '../features/queue/queue_mutations.dart';""",
    'queue session restore import',
)

replace_once(
    """        final restoredQueue = restored == null ? const <CatalogTrackSummary>[] : _queueFromSnapshot(catalog.tracks, restored);""",
    """        final restoredQueue = restored == null
            ? const <CatalogTrackSummary>[]
            : resolveWzQueueFromSnapshot(catalogTracks: catalog.tracks, snapshot: restored);""",
    'restored queue resolution',
)

replace_once(
    """    if (snapshot == null) return null;
    final validIds = catalogTracks.map((track) => track.trackId).toSet();
    final restoredIds = snapshot.queueTrackIds.where(validIds.contains).toList(growable: false);
    if (restoredIds.isEmpty && snapshot.currentTrackId == null && snapshot.selectedTrackId == null) return null;
    return QueueSessionSnapshot(
      queueTrackIds: restoredIds,
      currentTrackId: validIds.contains(snapshot.currentTrackId) ? snapshot.currentTrackId : null,
      selectedTrackId: validIds.contains(snapshot.selectedTrackId) ? snapshot.selectedTrackId : null,
      autoAdvanceEnabled: snapshot.autoAdvanceEnabled,
    );""",
    """    if (snapshot == null) return null;
    return sanitizeWzQueueSessionSnapshot(
      catalogTracks: catalogTracks,
      snapshot: snapshot,
    );""",
    'session sanitization',
)

replace_once(
    """  List<CatalogTrackSummary> _queueFromSnapshot(List<CatalogTrackSummary> catalogTracks, QueueSessionSnapshot snapshot) {
    final byId = {for (final track in catalogTracks) track.trackId: track};
    return snapshot.queueTrackIds.map((id) => byId[id]).whereType<CatalogTrackSummary>().toList(growable: false);
  }

""",
    "",
    'old queue snapshot resolver',
)

path.write_text(text)

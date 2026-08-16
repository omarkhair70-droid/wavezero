import '../../catalog/catalog_track_manifest.dart';
import 'listening_history_service.dart';

CatalogTrackSummary? wzResolveHistoryEntry({
  required List<CatalogTrackSummary> libraryTracks,
  required WzListeningHistoryEntry entry,
  CatalogTrackSummary? fallbackTrack,
}) {
  for (final track in libraryTracks) {
    if (track.trackId == entry.trackId) return track;
  }
  return fallbackTrack;
}

WzListeningHistoryEntry wzHistorySnapshotForManifest(
  CatalogTrackManifest manifest, {
  required WzListeningHistorySource source,
  required String? playableUrl,
  required int nowMs,
}) {
  return WzListeningHistoryEntry(
    trackId: manifest.trackId,
    title: manifest.title,
    subtitle: manifest.subtitle,
    artworkUrl: manifest.artworkUrl,
    source: source,
    primaryUrl: playableUrl ?? manifest.streamUrl,
    qualityLabel: manifest.qualityLabel,
    codec: manifest.codec,
    license: source == WzListeningHistorySource.device
        ? LicenseMetadata.userDevice
        : manifest.license,
    lastPlayedAtMs: nowMs,
    firstPlayedAtMs: nowMs,
    playCount: 1,
    lastPositionMs: 0,
    durationMs: manifest.durationMs,
  );
}

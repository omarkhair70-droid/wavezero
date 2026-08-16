import '../../catalog/catalog_track_manifest.dart';
import '../history/listening_history_service.dart';
import 'device_music_track.dart';

CatalogTrackSummary wzCatalogSummaryFromDeviceTrack(DeviceMusicTrack track) {
  return CatalogTrackSummary(
    trackId: track.trackId,
    title: track.title,
    artistId: null,
    artistName: track.artistName,
    albumName: track.albumName,
    displayName: track.displayName,
    durationMs: track.durationMs,
    artworkUrl: track.artworkUri,
    source: 'device',
    license: LicenseMetadata.userDevice,
    primaryAsset: CatalogTrackAssetSummary(
      assetId: 'device-${track.trackId}',
      manifestUrl: track.contentUri,
      qualityLabel: track.qualityLabel,
      codec: track.codec,
      bitrateKbps: track.bitrateKbps,
      fileSizeBytes: track.sizeBytes,
    ),
  );
}

DeviceMusicTrack? wzDeviceTrackFromHistory(WzListeningHistoryEntry entry) {
  final contentUri = entry.primaryUrl?.trim();
  if (entry.source != WzListeningHistorySource.device ||
      contentUri == null ||
      contentUri.isEmpty ||
      !contentUri.startsWith('content://')) {
    return null;
  }

  final subtitle = entry.subtitle.trim();
  return DeviceMusicTrack(
    trackId: entry.trackId,
    title: entry.title,
    contentUri: contentUri,
    artistName: subtitle.isEmpty || subtitle == 'Device music' ? null : subtitle,
    albumName: entry.albumName,
    durationMs: entry.durationMs,
    codec: entry.codec,
    artworkUri: entry.artworkUrl,
  );
}

CatalogTrackManifest wzDeviceManifest(DeviceMusicTrack track) {
  return CatalogTrackManifest(
    trackId: track.trackId,
    title: track.title,
    streamUrl: track.contentUri,
    artistId: null,
    artistName: track.artistName,
    durationMs: track.durationMs,
    artworkUrl: track.artworkUri,
    assetId: 'device-${track.trackId}',
    qualityLabel: track.qualityLabel ?? 'unknown',
    codec: track.codec,
    bitrateKbps: track.bitrateKbps,
    fileSizeBytes: track.sizeBytes,
  );
}

import '../../catalog/catalog_track_manifest.dart';
import 'cache_service.dart';

CatalogTrackSummary wzCatalogSummaryFromCachedTrack(CachedTrackMetadata track) {
  return CatalogTrackSummary(
    trackId: track.trackId,
    title: track.title,
    artistId: null,
    artistName: track.artistName,
    durationMs: track.durationMs,
    artworkUrl: track.artworkUrl,
    displayName: '${track.downloadSource} cached download ${track.qualityLabel} ${track.codec ?? ''}',
    source: 'cached',
    license: track.license,
    primaryAsset: CatalogTrackAssetSummary(
      assetId: 'cached-${track.trackId}',
      manifestUrl: track.originalRemoteUrl,
      qualityLabel: track.qualityLabel,
      codec: track.codec,
      bitrateKbps: track.bitrateKbps,
    ),
  );
}

String formatWzCacheBytes(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

String wzDownloadSourceLabel(String source) {
  switch (source) {
    case 'manual':
      return 'Manual';
    case 'smart_current':
      return 'Smart Current';
    case 'smart_up_next':
      return 'Smart Up Next';
    default:
      return 'Unknown';
  }
}

String wzCachedSourceBadgeLabel(String? displayName) {
  final source = displayName?.split(' ').first ?? 'unknown';
  return wzDownloadSourceLabel(source);
}

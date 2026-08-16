import '../../catalog/catalog_track_manifest.dart';

bool isWzDeviceTrackId(String? trackId) =>
    trackId != null && trackId.startsWith('device-audio-');

bool isWzDeviceUrl(String? url) =>
    url != null && url.startsWith('content://');

bool isWzDeviceCatalogTrack(CatalogTrackSummary track) =>
    track.source == 'device' ||
    isWzDeviceTrackId(track.trackId) ||
    isWzDeviceUrl(track.primaryAsset?.manifestUrl);

bool isWzCachedCatalogTrack(CatalogTrackSummary track) =>
    track.source == 'cached' ||
    track.primaryAsset?.assetId.startsWith('cached-') == true;

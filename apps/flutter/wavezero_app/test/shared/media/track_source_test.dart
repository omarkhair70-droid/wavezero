import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/shared/media/track_source.dart';

void main() {
  CatalogTrackSummary track({
    required String id,
    String source = 'api',
    String? assetId,
    String? url,
  }) =>
      CatalogTrackSummary(
        trackId: id,
        title: id,
        source: source,
        primaryAsset: CatalogTrackAssetSummary(
          assetId: assetId ?? 'asset-$id',
          manifestUrl: url ?? 'https://example.test/$id.mp3',
        ),
      );

  test('device ids and content URIs preserve existing detection', () {
    expect(isWzDeviceTrackId('device-audio-42'), isTrue);
    expect(isWzDeviceTrackId('track-42'), isFalse);
    expect(isWzDeviceUrl('content://media/audio/42'), isTrue);
    expect(isWzDeviceUrl('https://example.test/42.mp3'), isFalse);
  });

  test('device catalog classification accepts source, id, or content URI', () {
    expect(isWzDeviceCatalogTrack(track(id: 'a', source: 'device')), isTrue);
    expect(isWzDeviceCatalogTrack(track(id: 'device-audio-b')), isTrue);
    expect(
      isWzDeviceCatalogTrack(track(id: 'c', url: 'content://media/audio/c')),
      isTrue,
    );
    expect(isWzDeviceCatalogTrack(track(id: 'd')), isFalse);
  });

  test('cached catalog classification accepts source or cached asset id', () {
    expect(isWzCachedCatalogTrack(track(id: 'a', source: 'cached')), isTrue);
    expect(
      isWzCachedCatalogTrack(track(id: 'b', assetId: 'cached-b')),
      isTrue,
    );
    expect(isWzCachedCatalogTrack(track(id: 'c')), isFalse);
  });
}

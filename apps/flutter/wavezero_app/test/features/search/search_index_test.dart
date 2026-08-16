import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/collections/collections_service.dart';
import 'package:wavezero_app/features/history/listening_history_service.dart';
import 'package:wavezero_app/features/search/search_index.dart';
import 'package:wavezero_app/features/search/search_results.dart';

void main() {
  CatalogTrackSummary track(String id, {String source = 'api'}) =>
      CatalogTrackSummary(
        trackId: id,
        title: id,
        source: source,
        license: const LicenseMetadata(status: LicenseStatus.verified),
        primaryAsset: CatalogTrackAssetSummary(
          assetId: 'asset-$id',
          manifestUrl: 'https://example.test/$id.mp3',
        ),
      );

  List<WzSearchResult> build({
    List<CatalogTrackSummary> catalog = const [],
    List<CatalogTrackSummary> device = const [],
    List<CatalogTrackSummary> downloads = const [],
    List<CatalogTrackSummary> cloud = const [],
    List<WzCollection> collections = const [],
    List<WzListeningHistoryEntry> history = const [],
    CatalogTrackSummary? Function(WzListeningHistoryEntry)? resolver,
  }) =>
      buildWzSearchIndex(
        catalogTracks: catalog,
        deviceTracks: device,
        downloadedTracks: downloads,
        cloudTracks: cloud,
        collections: collections,
        historyEntries: history,
        resolveHistoryEntry: resolver ?? (_) => null,
        isDeviceTrack: (item) => item.source == 'device',
        historySourceLabel: (source) => source.name,
      );

  test('composes track sources in existing source order', () {
    final results = build(
      catalog: [track('catalog')],
      device: [track('device', source: 'device')],
      downloads: [track('download', source: 'cached')],
      cloud: [track('cloud', source: 'cloud')],
    );
    expect(
      results.map((item) => item.source),
      [
        WzSearchSource.apiCatalog,
        WzSearchSource.deviceMusic,
        WzSearchSource.downloads,
        WzSearchSource.cloudVault,
      ],
    );
    expect(results.every((item) => item.available), isTrue);
  });

  test('adds collections and searchable collection metadata', () {
    const snapshot = WzCollectionTrackSnapshot(
      trackId: 'inside',
      title: 'Inside Song',
      subtitle: 'Inside Artist',
      source: WzCollectionTrackSource.unknown,
      addedAtMs: 1,
    );
    const collection = WzCollection(
      id: 'collection-1',
      name: 'Night Mix',
      type: WzCollectionType.user,
      createdAtMs: 1,
      updatedAtMs: 1,
      tracks: [snapshot],
    );
    final result = build(collections: [collection]).single;
    expect(result.type, WzSearchResultType.collection);
    expect(result.collection, same(collection));
    expect(result.searchText, contains('night mix'));
    expect(result.searchText, contains('inside song'));
  });

  test('history availability follows live resolver', () {
    const history = WzListeningHistoryEntry(
      trackId: 'history-track',
      title: 'History Song',
      subtitle: 'Artist',
      source: WzListeningHistorySource.api,
      lastPlayedAtMs: 20,
      firstPlayedAtMs: 10,
      playCount: 2,
    );
    final live = track('history-track');
    final available = build(
      history: [history],
      resolver: (_) => live,
    ).single;
    final unavailable = build(history: [history]).single;
    expect(available.available, isTrue);
    expect(available.track, same(live));
    expect(unavailable.available, isFalse);
    expect(unavailable.track, isNull);
  });
}

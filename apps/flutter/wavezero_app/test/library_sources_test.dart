import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/library/library_controls.dart';
import 'package:wavezero_app/features/library/library_sources.dart';

void main() {
  CatalogTrackSummary track(String id) => CatalogTrackSummary(trackId: id, title: id);

  final catalog = [track('catalog-1'), track('catalog-2')];
  final device = [track('device-1')];
  final downloads = [track('download-1')];
  final cloud = [track('cloud-1')];

  List<String> ids(WzLibrarySourceFilter filter) {
    return composeWzLibraryTracks(
      filter: filter,
      catalogTracks: catalog,
      deviceTracks: device,
      downloadedTracks: downloads,
      cloudTracks: cloud,
    ).map((track) => track.trackId).toList();
  }

  test('all sources preserve the existing catalog-device-download-cloud order', () {
    expect(
      ids(WzLibrarySourceFilter.all),
      const ['catalog-1', 'catalog-2', 'device-1', 'download-1', 'cloud-1'],
    );
  });

  test('individual source filters return only their existing source list', () {
    expect(ids(WzLibrarySourceFilter.api), const ['catalog-1', 'catalog-2']);
    expect(ids(WzLibrarySourceFilter.device), const ['device-1']);
    expect(ids(WzLibrarySourceFilter.downloads), const ['download-1']);
    expect(ids(WzLibrarySourceFilter.cloud), const ['cloud-1']);
  });

  test('all returns a composed list while individual filters preserve source identity', () {
    final all = composeWzLibraryTracks(
      filter: WzLibrarySourceFilter.all,
      catalogTracks: catalog,
      deviceTracks: device,
      downloadedTracks: downloads,
      cloudTracks: cloud,
    );
    final onlyCatalog = composeWzLibraryTracks(
      filter: WzLibrarySourceFilter.api,
      catalogTracks: catalog,
      deviceTracks: device,
      downloadedTracks: downloads,
      cloudTracks: cloud,
    );

    expect(identical(all, catalog), isFalse);
    expect(identical(onlyCatalog, catalog), isTrue);
  });
}

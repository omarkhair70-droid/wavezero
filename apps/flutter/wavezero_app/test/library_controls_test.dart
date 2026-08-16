import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/library/library_controls.dart';

void main() {
  test('library source filter order and labels remain stable', () {
    expect(
      WzLibrarySourceFilter.values,
      const [
        WzLibrarySourceFilter.all,
        WzLibrarySourceFilter.api,
        WzLibrarySourceFilter.device,
        WzLibrarySourceFilter.downloads,
        WzLibrarySourceFilter.cloud,
      ],
    );
    expect(WzLibrarySourceFilter.all.label, 'All');
    expect(WzLibrarySourceFilter.api.label, 'Catalog');
    expect(WzLibrarySourceFilter.device.label, 'Device music');
    expect(WzLibrarySourceFilter.downloads.label, 'Downloaded');
    expect(WzLibrarySourceFilter.cloud.label, 'Cloud');
  });

  test('library sort order and labels remain stable', () {
    expect(
      WzLibrarySortMode.values,
      const [
        WzLibrarySortMode.recentlyAdded,
        WzLibrarySortMode.titleAz,
        WzLibrarySortMode.artistAz,
        WzLibrarySortMode.longestDuration,
        WzLibrarySortMode.shortestDuration,
        WzLibrarySortMode.quality,
      ],
    );
    expect(WzLibrarySortMode.recentlyAdded.label, 'Recently added / imported');
    expect(WzLibrarySortMode.titleAz.label, 'Title A-Z');
    expect(WzLibrarySortMode.artistAz.label, 'Artist A-Z');
    expect(WzLibrarySortMode.longestDuration.label, 'Longest duration');
    expect(WzLibrarySortMode.shortestDuration.label, 'Shortest duration');
    expect(WzLibrarySortMode.quality.label, 'Quality');
  });
}

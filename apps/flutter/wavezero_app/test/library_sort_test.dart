import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/library/library_controls.dart';
import 'package:wavezero_app/features/library/library_sort.dart';

void main() {
  CatalogTrackSummary track(
    String id,
    String title, {
    String? artist,
    String? album,
    int? durationMs,
    String? quality,
  }) {
    return CatalogTrackSummary(
      trackId: id,
      title: title,
      artistName: artist,
      albumName: album,
      durationMs: durationMs,
      primaryAsset: quality == null
          ? null
          : CatalogTrackAssetSummary(
              assetId: 'asset-$id',
              manifestUrl: 'https://example.invalid/$id',
              qualityLabel: quality,
            ),
    );
  }

  List<String> ids(
    List<CatalogTrackSummary> tracks,
    WzLibrarySortMode mode, {
    Map<String, int> added = const <String, int>{},
  }) {
    return sortWzLibraryTracks(
      tracks,
      mode: mode,
      addedRank: (track) => added[track.trackId] ?? 0,
    ).map((track) => track.trackId).toList();
  }

  test('recently added sorts newest first and keeps ties stable', () {
    final tracks = [track('a', 'A'), track('b', 'B'), track('c', 'C')];

    expect(
      ids(
        tracks,
        WzLibrarySortMode.recentlyAdded,
        added: const {'a': 100, 'b': 200, 'c': 200},
      ),
      const ['b', 'c', 'a'],
    );
  });

  test('title and artist sorts keep the existing lowercase and missing-value rules', () {
    final tracks = [
      track('missing', 'Zulu'),
      track('b', 'beta', artist: 'Beta'),
      track('a', 'Alpha', album: 'alpha album'),
    ];

    expect(ids(tracks, WzLibrarySortMode.titleAz), const ['a', 'b', 'missing']);
    expect(ids(tracks, WzLibrarySortMode.artistAz), const ['a', 'b', 'missing']);
  });

  test('duration sorts keep missing durations at the end in both directions', () {
    final tracks = [
      track('missing', 'Missing'),
      track('short', 'Short', durationMs: 1000),
      track('long', 'Long', durationMs: 5000),
    ];

    expect(ids(tracks, WzLibrarySortMode.longestDuration), const ['long', 'short', 'missing']);
    expect(ids(tracks, WzLibrarySortMode.shortestDuration), const ['short', 'long', 'missing']);
  });

  test('quality sort is case-insensitive text order with missing quality last', () {
    final tracks = [
      track('missing', 'Missing'),
      track('high', 'High', quality: 'High'),
      track('lossless', 'Lossless', quality: 'lossless'),
    ];

    expect(ids(tracks, WzLibrarySortMode.quality), const ['high', 'lossless', 'missing']);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/collections/collection_resolution.dart';
import 'package:wavezero_app/features/collections/collections_service.dart';

void main() {
  const snapshot = WzCollectionTrackSnapshot(
    trackId: 'track-2',
    title: 'Two',
    subtitle: 'Artist',
  );

  test('collection membership is determined by track id', () {
    const collection = WzCollection(
      id: 'c1',
      name: 'List',
      type: WzCollectionType.user,
      createdAtMs: 1,
      updatedAtMs: 1,
      tracks: [snapshot],
    );
    expect(wzCollectionContainsTrack(collection, 'track-2'), isTrue);
    expect(wzCollectionContainsTrack(collection, 'missing'), isFalse);
  });

  test('resolution prefers the live library track with the same id', () {
    final live = CatalogTrackSummary(trackId: 'track-2', title: 'Live Two');
    final resolved = wzResolveCollectionTrack(
      libraryTracks: [CatalogTrackSummary(trackId: 'track-1', title: 'One'), live],
      snapshot: snapshot,
    );
    expect(resolved, same(live));
  });

  test('resolution returns null when the snapshot is unavailable', () {
    final resolved = wzResolveCollectionTrack(
      libraryTracks: [CatalogTrackSummary(trackId: 'track-1', title: 'One')],
      snapshot: snapshot,
    );
    expect(resolved, isNull);
  });
}

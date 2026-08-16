import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/collections/collection_mutations.dart';
import 'package:wavezero_app/features/collections/collections_service.dart';

void main() {
  WzCollectionTrackSnapshot track(String id, {String? title}) =>
      WzCollectionTrackSnapshot(
        trackId: id,
        title: title ?? id,
        subtitle: 'Artist',
        source: WzCollectionTrackSource.unknown,
        addedAtMs: 1,
      );

  WzCollection collection({
    String id = 'c1',
    String name = 'List',
    List<WzCollectionTrackSnapshot> tracks = const [],
  }) =>
      WzCollection(
        id: id,
        name: name,
        type: WzCollectionType.user,
        createdAtMs: 1,
        updatedAtMs: 1,
        tracks: tracks,
      );

  test('toggle removes an existing track and preserves other order', () {
    final result = wzToggleCollectionTrack(
      collections: [collection(tracks: [track('a'), track('b')])],
      collectionId: 'c1',
      snapshot: track('a'),
      removeExisting: true,
      updatedAtMs: 10,
    ).single;
    expect(result.tracks.map((item) => item.trackId), ['b']);
    expect(result.updatedAtMs, 10);
  });

  test('upsert deduplicates then appends the newest snapshot', () {
    final newest = track('a', title: 'Newest');
    final result = wzUpsertCollectionTrack(
      collections: [collection(tracks: [track('a'), track('b')])],
      collectionId: 'c1',
      snapshot: newest,
      updatedAtMs: 20,
    ).single;
    expect(result.tracks.map((item) => item.trackId), ['b', 'a']);
    expect(result.tracks.last.title, 'Newest');
  });

  test('remove, rename, and delete target only the requested collection', () {
    final first = collection(id: 'c1', tracks: [track('a')]);
    final second = collection(id: 'c2', name: 'Second', tracks: [track('b')]);
    final removed = wzRemoveCollectionTrack(
      collections: [first, second],
      collectionId: 'c1',
      trackId: 'a',
      updatedAtMs: 30,
    );
    expect(removed.first.tracks, isEmpty);
    expect(removed.last.tracks.single.trackId, 'b');

    final renamed = wzRenameCollection(
      collections: removed,
      collectionId: 'c2',
      name: 'Renamed',
      updatedAtMs: 40,
    );
    expect(renamed.last.name, 'Renamed');

    final deleted = wzDeleteCollection(
      collections: renamed,
      collectionId: 'c1',
    );
    expect(deleted.map((item) => item.id), ['c2']);
  });
}
